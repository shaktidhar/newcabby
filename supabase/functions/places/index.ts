// supabase/functions/distance/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: cors
    });
  }
  try {
    const { fromLat, fromLng, toLat, toLng, mode = "driving", lang = "pt" } = await req.json();
    // IMPORTANT: server-side key (no HTTP referrer restrictions; allow server IPs or leave unrestricted)
    const apiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({
        error: "Missing GOOGLE_MAPS_API_KEY"
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...cors
        }
      });
    }
    const url = new URL("https://maps.googleapis.com/maps/api/distancematrix/json");
    url.searchParams.set("origins", `${fromLat},${fromLng}`);
    url.searchParams.set("destinations", `${toLat},${toLng}`);
    url.searchParams.set("mode", mode);
    url.searchParams.set("language", lang);
    url.searchParams.set("key", apiKey);
    const gmRes = await fetch(url.toString());
    const payload = await gmRes.json();
    // Forward Google response directly (status/rows/elements)
    return new Response(JSON.stringify(payload), {
      headers: {
        "Content-Type": "application/json",
        ...cors
      }
    });
  } catch (e) {
    return new Response(JSON.stringify({
      error: String(e)
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        ...cors
      }
    });
  }
});
