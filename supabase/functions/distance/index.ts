import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const ALLOWED = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map(s => s.trim()).filter(Boolean);

function corsHeaders(origin?: string) {
  const isLocal = origin?.startsWith("http://localhost:");
  const allowAll = ALLOWED.includes("*");
  const allowed =
    allowAll ? "*" :
    (origin && (ALLOWED.includes(origin) || isLocal)) ? origin :
    (ALLOWED.length === 0 ? "*" : ALLOWED[0]);

  return {
    "Access-Control-Allow-Origin": allowed,
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };
}

serve(async (req) => {
  const origin = req.headers.get("Origin") ?? undefined;
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders(origin) });

  try {
    const { fromLat, fromLng, toLat, toLng, lang = "pt" } = await req.json();

    if ([fromLat, fromLng, toLat, toLng].some((v: any) => typeof v !== "number")) {
      return new Response(JSON.stringify({ error: "bad_request", message: "Numeric lat/lng required" }),
        { status: 400, headers: corsHeaders(origin) });
    }

    const API_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!API_KEY) {
      return new Response(JSON.stringify({ error: "server_misconfig", message: "Missing GOOGLE_MAPS_API_KEY" }),
        { status: 500, headers: corsHeaders(origin) });
    }

    const routeReq = {
      origin: { location: { latLng: { latitude: fromLat, longitude: fromLng } } },
      destination: { location: { latLng: { latitude: toLat, longitude: toLng } } },
      travelMode: "DRIVE",
      languageCode: lang,
      computeAlternativeRoutes: false,
      routeModifiers: { avoidTolls: false, avoidHighways: false, avoidFerries: false },
      routingPreference: "TRAFFIC_AWARE"
    };

    const gmRes = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": API_KEY,
        "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline"
      },
      body: JSON.stringify(routeReq)
    });

    const text = await gmRes.text();
    let json: any;
    try { json = JSON.parse(text); }
    catch {
      return new Response(JSON.stringify({ error: "upstream_non_json", status: gmRes.status, body: text.slice(0,500) }),
        { status: 502, headers: corsHeaders(origin) });
    }

    if (!gmRes.ok) {
      return new Response(JSON.stringify({ error: "upstream_error", message: "Routing failed", upstream: json }),
        { status: 502, headers: corsHeaders(origin) });
    }

    const route = json.routes?.[0];
    if (!route) {
      return new Response(JSON.stringify({ error: "no_route", message: "No route found" }),
        { status: 404, headers: corsHeaders(origin) });
    }

    const out = {
      distance_km: route.distanceMeters ? Math.round(route.distanceMeters) / 1000 : null,
      duration_min: route.duration ? parseDurationToMin(route.duration) : null,
      polyline: route.polyline?.encodedPolyline ?? null
    };

    return new Response(JSON.stringify(out), { status: 200, headers: corsHeaders(origin) });
  } catch (e) {
    return new Response(JSON.stringify({ error: "internal", message: String(e) }),
      { status: 500, headers: corsHeaders(origin) });
  }
});

function parseDurationToMin(dur: string): number | null {
  const m = /^(\d+)s$/.exec(dur ?? "");
  if (!m) return null;
  return Math.round((Number(m[1]) / 60) * 10) / 10;
}
