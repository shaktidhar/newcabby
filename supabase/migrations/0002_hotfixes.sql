revoke select on public.vehicles from anon, authenticated;

grant select (id, vehicle_type_id, make, model, year, color, photos)
on public.vehicles to anon, authenticated;

alter table public.vehicles enable row level security;

create policy vehicles_public_read_active
on public.vehicles
for select to anon, authenticated
using (active = true and verified = true);
