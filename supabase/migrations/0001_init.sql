create extension if not exists "uuid-ossp";

-- USERS & ROLES
create table public.users (
  id uuid primary key default uuid_generate_v4(),
  email text unique not null,
  phone text,
  display_name text,
  role text not null default 'customer' check (role in ('customer','owner','driver','admin')),
  locale text not null default 'en',
  created_at timestamptz not null default now()
);

-- OWNERS / FLEETS
create table public.owners (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  is_fleet boolean not null default false,
  stripe_connect_id text,
  revenue_share_pct numeric(5,2) default 0.00, -- optional owner split
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  created_at timestamptz not null default now()
);

-- DRIVERS
create table public.drivers (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  owner_id uuid not null references public.owners(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

-- VEHICLE TYPES
create table public.vehicle_types (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,           -- ECONOMY, SEDAN_PREMIUM, VAN_6, VAN_8, VAN_8_PREMIUM
  label text not null,                 -- i18n key
  seats int not null check (seats > 0),
  luggage int not null default 0,
  is_premium boolean not null default false,
  base_per_km numeric(10,2) not null default 0.80,
  base_per_min numeric(10,2) not null default 0.20,
  base_start_fee numeric(10,2) not null default 3.00,
  active boolean not null default true
);

-- VEHICLES
create table public.vehicles (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.owners(id) on delete cascade,
  vehicle_type_id uuid not null references public.vehicle_types(id),
  make text, model text, year int, color text,
  license_plate text unique not null,
  photos jsonb default '[]'::jsonb,
  active boolean not null default true,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

-- ASSIGNMENTS (vehicle ↔ driver)
create table public.vehicle_driver_assignments (
  id uuid primary key default uuid_generate_v4(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  assigned_from timestamptz not null default now(),
  assigned_to   timestamptz
);

-- AVAILABILITY
create table public.vehicle_availability (
  id uuid primary key default uuid_generate_v4(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  start_ts timestamptz not null,
  end_ts   timestamptz not null,
  recurrence_rule text,
  blackout boolean not null default false
);

-- REGIONS / RULES
create table public.regions (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  geojson jsonb,                 -- polygon/multipolygon
  postal_codes text[],           -- fallback by postcodes
  active boolean not null default true
);

create table public.region_rules (
  id uuid primary key default uuid_generate_v4(),
  region_id uuid not null references public.regions(id) on delete cascade,
  premium_multiplier numeric(6,3) not null default 1.00,
  fixed_surcharge numeric(10,2) not null default 0.00,
  restricted boolean not null default false,
  applies_on text not null default 'pickup' check (applies_on in ('pickup','dropoff','either'))
);

create table public.driver_region_prefs (
  id uuid primary key default uuid_generate_v4(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  region_id uuid not null references public.regions(id) on delete cascade,
  accepts boolean not null default true,
  unique(driver_id, region_id)
);

-- TIME-BASED PRICING WINDOWS
create table public.overnight_windows (
  id uuid primary key default uuid_generate_v4(),
  tz text not null default 'Europe/Lisbon',
  start_local time not null,
  end_local   time not null,
  multiplier numeric(6,3) not null default 1.15,
  fixed_addon numeric(10,2) not null default 0.00,
  active boolean not null default true
);

-- TOURS & SLOTS
create table public.tours (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  route_json jsonb default '{}'::jsonb,
  base_price numeric(10,2) not null,
  capacity int not null default 8,
  images jsonb default '[]'::jsonb,
  active boolean not null default true
);

create table public.tour_slots (
  id uuid primary key default uuid_generate_v4(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  start_ts timestamptz not null,
  end_ts   timestamptz not null,
  capacity_remaining int not null,
  price_override numeric(10,2)
);

-- BOOKINGS
create table public.bookings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id),
  tour_slot_id uuid references public.tour_slots(id),
  vehicle_type_id uuid references public.vehicle_types(id),
  pickup_address text, pickup_lat numeric(9,6), pickup_lng numeric(9,6),
  dropoff_address text, dropoff_lat numeric(9,6), dropoff_lng numeric(9,6),
  pax int not null default 1,
  luggage int not null default 0,
  distance_km numeric(10,2),
  duration_min numeric(10,2),
  price numeric(10,2) not null,
  currency text not null default 'EUR',
  status text not null default 'pending' check (status in ('pending','confirmed','in_progress','completed','cancelled','refunded')),
  stripe_payment_intent text,
  region_rule_id uuid references public.region_rules(id),
  overnight_minutes int default 0,
  surcharge_total numeric(10,2) default 0.00,
  pricing_version int not null default 1,
  pricing_breakdown jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- PAYOUTS
create table public.payouts (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.owners(id) on delete cascade,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  amount numeric(10,2) not null,
  currency text not null default 'EUR',
  status text not null default 'queued' check (status in ('queued','transferred','failed')),
  stripe_transfer_id text,
  created_at timestamptz not null default now()
);

-- DOCUMENTS (compliance)
create table public.documents (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.owners(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id),
  doc_type text not null, -- driver_license, insurance, inspection
  url text not null,
  status text not null default 'submitted' check (status in ('submitted','approved','rejected')),
  uploaded_at timestamptz not null default now()
);

-- B2B PARTNERS (hotels, agencies) + codes
create table public.partners (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  email text,
  phone text,
  commission_pct numeric(5,2) default 0.00,
  referral_code text unique
);

alter table public.bookings
  add column if not exists partner_id uuid references public.partners(id),
  add column if not exists referral_code text;

-- AUDIT LOG
create table public.audit_logs (
  id uuid primary key default uuid_generate_v4(),
  entity text not null,
  entity_id uuid,
  action text not null,
  by_user uuid references public.users(id),
  meta jsonb,
  created_at timestamptz not null default now()
);

-- Helpful indexes
create index on public.vehicle_availability(vehicle_id, start_ts, end_ts);
create index on public.bookings(user_id, created_at);
create index on public.bookings(status);
create index on public.tour_slots(tour_id, start_ts);

-- Insert example vehicle types
insert into public.vehicle_types (code,label,seats,luggage,is_premium,base_per_km,base_per_min,base_start_fee) values
('ECONOMY','vehicle.type.economy',4,2,false,0.80,0.20,3.00),
('SEDAN_PREMIUM','vehicle.type.sedan_premium',4,3,true,1.10,0.30,4.50),
('VAN_6','vehicle.type.van_6',6,4,false,1.20,0.30,5.00),
('VAN_8','vehicle.type.van_8',8,6,false,1.30,0.35,6.00),
('VAN_8_PREMIUM','vehicle.type.van_8_premium',8,6,true,1.60,0.45,8.00);

-- Enabling RLS
alter table public.bookings enable row level security;
create policy "users see own bookings"
on public.bookings for select
using (auth.uid() = user_id OR
       exists(select 1 from public.users u where u.id = auth.uid() and u.role='admin') OR
       exists(select 1 from public.owners o join public.vehicles v on v.owner_id=o.id
              where o.user_id=auth.uid() and (v.id=bookings.vehicle_id)));

create policy "users insert own bookings"
on public.bookings for insert
with check (auth.uid() = user_id OR
            exists(select 1 from public.users u where u.id = auth.uid() and u.role in ('admin')));


-- OFFERS (rider -> marketplace). One offer references a proposed trip.
create table public.offers (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  vehicle_type_id uuid not null references public.vehicle_types(id),
  pickup_address text,
  pickup_lat numeric(9,6),
  pickup_lng numeric(9,6),
  dropoff_address text,
  dropoff_lat numeric(9,6),
  dropoff_lng numeric(9,6),
  when_ts timestamptz not null,             -- desired pickup time
  pax int not null default 1,
  luggage int not null default 0,
  base_quote numeric(10,2),                 -- optional: what your server would have charged
  offer_amount numeric(10,2) not null,      -- rider’s proposed total (incl. taxes/fees if any)
  currency text not null default 'EUR',
  status text not null default 'open' check (status in ('open','accepted','countered','declined','expired','cancelled')),
  region_rule_id uuid references public.region_rules(id),
  pricing_version int not null default 1,
  breakdown jsonb default '{}'::jsonb,      -- your server’s reference calculations
  expires_at timestamptz,                   -- server sets (e.g., now() + interval '20 min')
  created_at timestamptz not null default now()
);

-- COUNTEROFFERS (driver/owner -> rider)
create table public.offer_counters (
  id uuid primary key default uuid_generate_v4(),
  offer_id uuid not null references public.offers(id) on delete cascade,
  by_owner_id uuid references public.owners(id),  -- who proposed the counter (owner)
  by_driver_id uuid references public.drivers(id),
  amount numeric(10,2) not null,
  message text,
  created_at timestamptz not null default now()
);

-- If an offer is accepted, we bind it to a booking:
alter table public.bookings
  add column if not exists offer_id uuid references public.offers(id);

-- TIPS: can be pre-trip (to entice) or post-trip (gratitude)
create table public.tips (
  id uuid primary key default uuid_generate_v4(),
  booking_id uuid references public.bookings(id) on delete set null,
  offer_id uuid references public.offers(id) on delete set null, -- optional pre-trip tip attached to offer
  from_user uuid not null references public.users(id) on delete cascade,
  to_owner_id uuid references public.owners(id),                 -- payout target
  to_driver_id uuid references public.drivers(id),               -- optional if you split later
  amount numeric(10,2) not null,
  currency text not null default 'EUR',
  status text not null default 'pledged' check (status in ('pledged','captured','refunded','cancelled')),
  stripe_payment_intent text,
  created_at timestamptz not null default now()
);


--Test DATA
-- USERS
insert into public.users (id, email, phone, display_name, role, locale)
values
('00000000-0000-0000-0000-000000000001', 'rider1@test.com', '+351900000001', 'Test Rider 1', 'customer', 'en'),
('00000000-0000-0000-0000-000000000002', 'owner1@test.com', '+351900000002', 'Fleet Owner', 'owner', 'en'),
('00000000-0000-0000-0000-000000000003', 'driver1@test.com', '+351900000003', 'Driver 1', 'driver', 'en'),
('00000000-0000-0000-0000-000000000004', 'driver2@test.com', '+351900000004', 'Driver 2', 'driver', 'en'),
('00000000-0000-0000-0000-000000000005', 'owner2@test.com', '+351900000005', 'Solo Owner', 'owner', 'pt');

-- OWNERS
insert into public.owners (id, user_id, is_fleet, status)
values
('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', true, 'approved'),
('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', false, 'approved');

-- DRIVERS
insert into public.drivers (id, user_id, owner_id, status, is_available)
values
('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'approved', true),
('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'approved', true);

-- VEHICLES
insert into public.vehicles (id, owner_id, vehicle_type_id, make, model, year, color, license_plate, active, verified)
select
  uuid_generate_v4(),
  '10000000-0000-0000-0000-000000000001',
  vt.id,
  v.make, v.model, v.year, v.color, v.plate, true, true
from (values
  ('Toyota', 'Corolla', 2018, 'White', 'AA-11-AA', 'ECONOMY'),
  ('Mercedes', 'E-Class', 2020, 'Black', 'BB-22-BB', 'SEDAN_PREMIUM'),
  ('Renault', 'Trafic', 2019, 'Grey', 'CC-33-CC', 'VAN_8')
) as v(make, model, year, color, plate, code)
join public.vehicle_types vt on vt.code = v.code;

insert into public.vehicles (id, owner_id, vehicle_type_id, make, model, year, color, license_plate, active, verified)
select
  uuid_generate_v4(),
  '10000000-0000-0000-0000-000000000002',
  vt.id,
  'Ford', 'Galaxy', 2017, 'Silver', 'DD-44-DD', true, true
from public.vehicle_types vt where vt.code='VAN_6';

-- VEHICLE ↔ DRIVER ASSIGNMENTS
insert into public.vehicle_driver_assignments (vehicle_id, driver_id)
select v.id, '20000000-0000-0000-0000-000000000001' from public.vehicles v limit 1;
insert into public.vehicle_driver_assignments (vehicle_id, driver_id)
select v.id, '20000000-0000-0000-0000-000000000002' from public.vehicles v offset 1 limit 1;

-- AVAILABILITY (next 3 days)
insert into public.vehicle_availability (vehicle_id, start_ts, end_ts)
select v.id, now() + interval '1 hour', now() + interval '8 hour' from public.vehicles v;

insert into public.vehicle_availability (vehicle_id, start_ts, end_ts)
select v.id, now() + interval '1 day', now() + interval '9 hour' from public.vehicles v;

-- TOURS
insert into public.tours (id, title, description, route_json, base_price, capacity, active)
values
(uuid_generate_v4(),
 'Aveiro Canal Cruise + City Walk',
 'Half-day guided tour of Aveiro with canal boat and old town walking route.',
 '{"stops":[{"name":"Aveiro Station","lat":40.6405,"lng":-8.6538},{"name":"Canal Central","lat":40.6392,"lng":-8.6550},{"name":"Costa Nova Beach","lat":40.6191,"lng":-8.7490}]}',
 65.00, 8, true);

insert into public.tour_slots (tour_id, start_ts, end_ts, capacity_remaining)
select t.id, now() + interval '1 day 09:00', now() + interval '1 day 14:00', 8 from public.tours t;


-- === ADMIN ROLES & MEMBERSHIPS ===
create table if not exists public.admin_roles (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,           -- e.g. SUPER_ADMIN, OPS_MANAGER
  name text not null,
  level int not null,                  -- higher = more power
  permissions jsonb not null default '[]'::jsonb
);

create table if not exists public.admin_memberships (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  role_id uuid not null references public.admin_roles(id) on delete cascade,
  active boolean not null default true,
  unique(user_id, role_id)
);

-- Seed common roles
insert into public.admin_roles (code, name, level, permissions) values
('SUPER_ADMIN','Super Admin',100,'["manage_all","view_finance","process_refunds","manage_regions","manage_pricing","dispatch","impersonate","manage_admins"]'),
('OPS_MANAGER','Operations Manager',80,'["dispatch","manage_regions","manage_pricing","approve_owners","verify_documents","view_finance"]'),
('FINANCE','Finance',70,'["view_finance","process_refunds","view_payouts"]'),
('DISPATCHER','Dispatcher',60,'["dispatch","view_all_bookings"]'),
('SUPPORT','Support',50,'["view_users","view_bookings","issue_credits"]'),
('VIEWER','Read Only',10,'["view_dashboards"]')
on conflict (code) do nothing;

-- Create an admin user
insert into public.users (id, email, phone, display_name, role, locale)
values ('00000000-0000-0000-0000-0000000000aa','admin@test.com','+351900000000','System Admin','admin','en')
on conflict (email) do nothing;

-- Give admin memberships (SUPER_ADMIN + DISPATCHER just for testing)
insert into public.admin_memberships (user_id, role_id)
select '00000000-0000-0000-0000-0000000000aa', ar.id
from public.admin_roles ar
where ar.code in ('SUPER_ADMIN','DISPATCHER')
on conflict do nothing;


-- More test data
-- === REGIONS (postal-based examples; add GeoJSON later if you want polygons) ===
-- Porto Airport / Maia area (prefixes 4470, 4471, 4475 as examples)
insert into public.regions (id, name, postal_codes, active)
values
('30000000-0000-0000-0000-000000000001','OPO Airport Zone', array['4470','4471','4475'], true)
on conflict (id) do nothing;

-- Douro Valley (generic prefixes: 5000 Vila Real, 5050 Peso da Régua)
insert into public.regions (id, name, postal_codes, active)
values
('30000000-0000-0000-0000-000000000002','Douro Valley', array['5000','5050'], true)
on conflict (id) do nothing;

-- Porto Historic Center (narrow streets; add premium + can be restricted)
insert into public.regions (id, name, postal_codes, active)
values
('30000000-0000-0000-0000-000000000003','Porto Historic Center', array['4000','4050'], true)
on conflict (id) do nothing;

-- === REGION RULES ===
-- Airport premium (applies on pickup; modest surcharge)
insert into public.region_rules (region_id, premium_multiplier, fixed_surcharge, restricted, applies_on)
values ('30000000-0000-0000-0000-000000000001', 1.20, 2.50, false, 'pickup')
on conflict do nothing;

-- Douro Valley premium (either pickup or dropoff triggers premium; longer distances)
insert into public.region_rules (region_id, premium_multiplier, fixed_surcharge, restricted, applies_on)
values ('30000000-0000-0000-0000-000000000002', 1.15, 0.00, false, 'either')
on conflict do nothing;

-- Historic Center premium + restricted (some drivers opt out)
insert into public.region_rules (region_id, premium_multiplier, fixed_surcharge, restricted, applies_on)
values ('30000000-0000-0000-0000-000000000003', 1.30, 3.00, true, 'either')
on conflict do nothing;

-- === DRIVER REGION PREFERENCES (opt-out Historic Center for Driver 1) ===
insert into public.driver_region_prefs (driver_id, region_id, accepts)
values ('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003', false)
on conflict (driver_id, region_id) do update set accepts=excluded.accepts;

-- Standard overnight: 22:00–06:00, +15%
insert into public.overnight_windows (tz, start_local, end_local, multiplier, fixed_addon, active)
values ('Europe/Lisbon','22:00','06:00',1.15,0.00,true);

-- Late night extra: 00:00–04:00, +25% (keeps both; your pricing can apply the highest that overlaps)
insert into public.overnight_windows (tz, start_local, end_local, multiplier, fixed_addon, active)
values ('Europe/Lisbon','00:00','04:00',1.25,0.00,true);

-- Helper: pick some vehicle_type ids
with vt as (
  select id as econ_id from public.vehicle_types where code='ECONOMY' limit 1
)
-- OPEN offer: rider proposes €30 for a short Porto city ride (likely Historic Center)
insert into public.offers (id, user_id, vehicle_type_id, pickup_address, pickup_lat, pickup_lng,
                           dropoff_address, dropoff_lat, dropoff_lng, when_ts, pax, luggage,
                           base_quote, offer_amount, currency, status, expires_at, pricing_version)
select
  '40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',  -- rider1@test.com
  vt.econ_id,
  'Sé do Porto, 4000 Porto', 41.142, -8.611,
  'Jardins do Palácio de Cristal, 4050 Porto', 41.148, -8.628,
  now() + interval '2 hour', 2, 2,
  24.00, 30.00, 'EUR', 'open', now() + interval '20 minutes', 1
from vt
on conflict (id) do nothing;

-- COUNTERED offer: rider lowballs airport transfer; owner counters
with vt as (
  select id as van8_id from public.vehicle_types where code='VAN_8' limit 1
)
insert into public.offers (id, user_id, vehicle_type_id, pickup_address, pickup_lat, pickup_lng,
                           dropoff_address, dropoff_lat, dropoff_lng, when_ts, pax, luggage,
                           base_quote, offer_amount, currency, status, expires_at, pricing_version)
select
  '40000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  vt.van8_id,
  'Francisco Sá Carneiro Airport (OPO) 4470', 41.242, -8.678,
  'Aliados, 4000 Porto', 41.147, -8.609,
  now() + interval '1 day 10:30', 5, 4,
  38.00, 28.00, 'EUR', 'open', now() + interval '30 minutes', 1
from vt
on conflict (id) do nothing;

-- Owner counteroffers €42
insert into public.offer_counters (offer_id, by_owner_id, amount, message)
values ('40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001', 42.00, 'Airport pickup, meet & greet included.')
on conflict do nothing;

-- ACCEPTED offer → create confirmed booking (simulate payment succeeded)
with sel as (
  select o.id as offer_id, o.user_id, o.vehicle_type_id
  from public.offers o where o.id='40000000-0000-0000-0000-000000000002'
), veh as (
  -- pick any vehicle from fleet owner to assign
  select v.id as vehicle_id from public.vehicles v
  where v.owner_id='10000000-0000-0000-0000-000000000001' limit 1
)
insert into public.bookings (user_id, vehicle_id, vehicle_type_id, pickup_address, pickup_lat, pickup_lng,
                             dropoff_address, dropoff_lat, dropoff_lng, pax, luggage,
                             distance_km, duration_min, price, currency, status, offer_id, pricing_breakdown)
select
  sel.user_id, veh.vehicle_id, sel.vehicle_type_id,
  'Francisco Sá Carneiro Airport (OPO) 4470', 41.242, -8.678,
  'Aliados, 4000 Porto', 41.147, -8.609,
  5, 4,
  16.2, 26, 42.00, 'EUR', 'confirmed', sel.offer_id,
  '{"source":"offer_accepted","notes":"owner counteraccepted at €42"}'::jsonb
from sel, veh;

-- Mark offer as accepted
update public.offers set status='accepted'
where id='40000000-0000-0000-0000-000000000002';

-- Optional: a pledged tip (post-trip)
insert into public.tips (booking_id, from_user, to_owner_id, amount, currency, status)
values (
  (select id from public.bookings order by created_at desc limit 1),
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  5.00,'EUR','pledged'
);

-- Give each vehicle a night availability window today to test overnight pricing
insert into public.vehicle_availability (vehicle_id, start_ts, end_ts)
select v.id, date_trunc('day', now()) + interval '22 hour', date_trunc('day', now()) + interval '30 hour'  -- 22:00–06:00
from public.vehicles v
on conflict do nothing;

