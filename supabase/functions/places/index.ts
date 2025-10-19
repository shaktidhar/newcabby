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
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Content-Type": "application/json",
  };
}

serve(async (req) => {
  const origin = req.headers.get("Origin") ?? undefined;
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(origin) });

  try {
    const GOOGLE_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!GOOGLE_KEY) {
      return json({ error: "server_misconfig", message: "Missing GOOGLE_MAPS_API_KEY" }, 500, origin);
    }

    const url = new URL(req.url);
    let body: Record<string, unknown> = {};
    if (req.method === "POST") {
      try { body = await req.json(); } catch { body = {}; }
    }
    const get = (k: string, def?: string) =>
      (body[k] as string | undefined) ?? url.searchParams.get(k) ?? def;

    const mode = get("mode");
    const lang = get("lang", "pt")!;
    const country = get("country") ?? undefined;
    const sessionToken = get("session_token") ?? undefined;

    if (mode === "autocomplete") {
      const q = (get("q", "") ?? "").trim();
      if (q.length < 2 || q.length > 120) {
        return json({ error: "bad_request", message: "Query length 2–120 required" }, 400, origin);
      }

      const gUrl = new URL("https://maps.googleapis.com/maps/api/place/autocomplete/json");
      gUrl.searchParams.set("input", q);
      gUrl.searchParams.set("language", lang);
      if (country) gUrl.searchParams.set("components", `country:${country}`);
      if (sessionToken) gUrl.searchParams.set("sessiontoken", sessionToken);
      gUrl.searchParams.set("key", GOOGLE_KEY);

      const r = await fetch(gUrl);
      const data = await safeJson(r);
      if (data.status && data.status !== "OK" && data.status !== "ZERO_RESULTS") {
        return json({ error: "upstream_error", message: "Autocomplete failed", upstream: data }, 502, origin);
      }

      const suggestions = (data.predictions ?? []).map((p: any) => ({
        place_id: p.place_id,
        description: p.description,
        main_text: p.structured_formatting?.main_text,
        secondary_text: p.structured_formatting?.secondary_text,
      }));

      return json({ suggestions, predictions: data.predictions ?? [] }, 200, origin);
    }

    if (mode === "details") {
      const placeId = (get("place_id", "") ?? "").trim();
      if (!placeId) {
        return json({ error: "bad_request", message: "place_id required" }, 400, origin);
      }

      const gUrl = new URL("https://maps.googleapis.com/maps/api/place/details/json");
      gUrl.searchParams.set("place_id", placeId);
      gUrl.searchParams.set("language", lang);
      gUrl.searchParams.set("fields", "place_id,formatted_address,geometry/location,address_components");
      if (sessionToken) gUrl.searchParams.set("sessiontoken", sessionToken);
      gUrl.searchParams.set("key", GOOGLE_KEY);

      const r = await fetch(gUrl);
      const data = await safeJson(r);
      if (data.status && data.status !== "OK") {
        return json({ error: "upstream_error", message: "Details failed", upstream: data }, 502, origin);
      }

      const res = data.result ?? {};
      const loc = res.geometry?.location ?? {};
      const normalized = {
        place_id: res.place_id,
        formatted_address: res.formatted_address ?? "",
        lat: loc.lat ?? null,
        lng: loc.lng ?? null,
        country: res.address_components?.find((c: any) => c.types?.includes("country"))?.short_name ?? null,
        // keep raw for compatibility
        result: data.result,
        status: data.status ?? "OK",
      };
      return json(normalized, 200, origin);
    }

    return json({ error: "bad_request", message: "Invalid mode" }, 400, origin);
  } catch (e) {
    return json({ error: "internal", message: String(e) }, 500, origin);
  }
});

function json(body: unknown, status = 200, origin?: string) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(origin) });
}

async function safeJson(res: Response) {
  const text = await res.text();
  try { return JSON.parse(text); }
  catch { return { statusCode: res.status, body: text?.slice(0, 500) }; }
}
