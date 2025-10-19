import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Json = Record<string, unknown>;

const ALLOWED = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map(s => s.trim()).filter(Boolean);
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY"); // optional

function cors(origin?: string) {
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
  if (req.method === "OPTIONS") return new Response(null, { headers: cors(origin) });

  try {
    // Require a Supabase access token (user must be logged in)
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) {
      return json({ error: "unauthorized" }, 401, origin);
    }
    const accessToken = auth.slice("Bearer ".length);

    const body = await req.json() as Record<string, unknown>;
    const {
      pickup_address, pickup_lat, pickup_lng,
      dropoff_address, dropoff_lat, dropoff_lng,
      when, pax = 1, luggage = 0,
      vehicle_type_id,
      currency = "EUR",
      payment_method = "card", // <--- add this
    } = body;

    // Basic validation
    if (!vehicle_type_id) return json({ error: "missing_vehicle_type" }, 400, origin);
    const nums: Record<string, unknown> = { pickup_lat, pickup_lng, dropoff_lat, dropoff_lng };
    for (const [k, v] of Object.entries(nums)) {
      if (typeof v !== "number" || !isFinite(v as number)) {
        return json({ error: `invalid_${k}` }, 400, origin);
      }
    }

    const whenIso = typeof when === "string" ? when : new Date().toISOString();

    // Who is booking?
    const profileRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { "Authorization": `Bearer ${accessToken}`, "apikey": SUPABASE_ANON_KEY },
    });
    if (!profileRes.ok) return json({ error: "auth_user_fetch_failed" }, 401, origin);
    const user = await profileRes.json() as { id: string; email?: string };
    const user_id = user.id;

    // 1) Recompute distance/duration via your distance function (server->server)
    const distRes = await fetch(`${SUPABASE_URL}/functions/v1/distance`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE}`, // service role to bypass CORS/auth at function
      },
      body: JSON.stringify({
        fromLat: pickup_lat, fromLng: pickup_lng,
        toLat: dropoff_lat, toLng: dropoff_lng,
        lang: "pt",
      }),
    });
    const distJson = await distRes.json();
    if (!distRes.ok) return json({ error: "distance_failed", detail: distJson }, 502, origin);

    const distance_km = Number(distJson.distance_km ?? 0);
    const duration_min = Number(distJson.duration_min ?? 0);
    if (!isFinite(distance_km) || !isFinite(duration_min) || distance_km <= 0) {
      return json({ error: "no_route" }, 400, origin);
    }

    // 2) Pull vehicle_type pricing
    const vtRes = await fetch(`${SUPABASE_URL}/rest/v1/vehicle_types?id=eq.${vehicle_type_id}&active=is.true&select=*,code,label,is_premium,base_per_km,base_per_min,base_start_fee`, {
      headers: { "apikey": SUPABASE_SERVICE_ROLE, "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE}` },
    });
    const vtArr = await vtRes.json();
    const vt = vtArr?.[0];
    if (!vt) return json({ error: "vehicle_type_not_found_or_inactive" }, 400, origin);

    const base_per_km = Number(vt.base_per_km);
    const base_per_min = Number(vt.base_per_min);
    const base_start_fee = Number(vt.base_start_fee);
    const is_premium = !!vt.is_premium;

    // 3) Region/overnight adjustments (stubbed for now)
    const overnight = await getOvernightMultiplier("Europe/Lisbon", new Date(whenIso));
    const regionMultiplier = 1.0;
    const regionFixed = 0.0;

    // 4) Compute price
    let price =
      base_start_fee +
      base_per_km * distance_km +
      base_per_min * duration_min;

    if (is_premium) price *= 1.10;        // small premium uplift
    price = price * overnight.multiplier + overnight.fixed_addon;
    price = price * regionMultiplier + regionFixed;

    price = Math.round(price * 100) / 100;

    const pricing_breakdown = {
      base: { base_start_fee, base_per_km, base_per_min },
      inputs: { distance_km, duration_min, pax, luggage },
      adjustments: {
        is_premium,
        overnight,
        region: { multiplier: regionMultiplier, fixed_addon: regionFixed },
      },
    };

    // 5) Insert booking
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/bookings`, {
      method: "POST",
      headers: {
        "apikey": SUPABASE_SERVICE_ROLE,
        "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
      },
      body: JSON.stringify([{
        user_id,
        vehicle_type_id,
        pickup_address,
        pickup_lat, pickup_lng,
        dropoff_address,
        dropoff_lat, dropoff_lng,
        pax, luggage,
        distance_km, duration_min,
        price, currency,
        status: STRIPE_SECRET_KEY && payment_method === "card" ? "pending_payment" : "pending",
        pricing_version: 1,
        pricing_breakdown,
      }]),
    });

    if (!insertRes.ok) {
      const t = await insertRes.text();
      return json({ error: "insert_failed", detail: t }, 500, origin);
    }
    const [booking] = await insertRes.json();


    // 6) Optional Stripe PaymentIntent
    // Only create PaymentIntent if card
    let client_secret: string | null = null;
    if (STRIPE_SECRET_KEY && payment_method === "card") {

    }


    let client_secret: string | null = null;
    if (STRIPE_SECRET_KEY  && payment_method === "card") {
      const amountCents = Math.max(50, Math.round(price * 100)); // min €0.50
      const form = new URLSearchParams();
      form.set("amount", String(amountCents));
      form.set("currency", String(currency));
      form.set("automatic_payment_methods[enabled]", "true");
      form.set("metadata[booking_id]", String(booking.id));

      const piRes = await fetch("https://api.stripe.com/v1/payment_intents", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: form,
      });
      const pi = await piRes.json();
      if (piRes.ok && typeof pi?.client_secret === "string") {
        client_secret = pi.client_secret;
      } else {
        console.warn("stripe PI failed", pi);
        // don’t fail the whole booking; client can retry payment later
      }
    }

    return json({ booking, client_secret }, 200, origin);

  } catch (e) {
    return json({ error: "internal", message: String(e) }, 500, origin);
  }
});

function json(body: Json, status = 200, origin?: string) {
  return new Response(JSON.stringify(body), { status, headers: cors(origin) });
}

async function getOvernightMultiplier(_tz: string, _when: Date) {
  // TODO: query your overnight_windows table and compute multiplier by local time.
  return { tz: _tz, multiplier: 1.0, fixed_addon: 0.0 };
}
