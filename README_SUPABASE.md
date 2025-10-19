# Autocomplete
curl -X POST "$SUPABASE_URL/functions/v1/places" \
-H "Authorization: Bearer $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
-d '{"mode":"autocomplete","q":"porto air","lang":"pt","country":"pt","session_token":"abc123"}'

# Details
curl -X POST "$SUPABASE_URL/functions/v1/places" \
-H "Authorization: Bearer $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
-d '{"mode":"details","place_id":"<PID>","lang":"pt","session_token":"abc123"}'

# Distance (Routes API)
curl -X POST "$SUPABASE_URL/functions/v1/distance" \
-H "Authorization: Bearer $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
-d '{"fromLat":41.1579,"fromLng":-8.6291,"toLat":40.6405,"toLng":-8.6538,"lang":"pt"}'
