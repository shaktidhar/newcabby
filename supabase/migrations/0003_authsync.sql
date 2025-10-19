-- 0003_auth_sync.sql
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.users (id, email, display_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), 'customer')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

alter table public.bookings enable row level security;

-- read own bookings
create policy bookings_read_own
on public.bookings for select to authenticated
using (user_id = auth.uid());

-- create own booking (server will compute price)
create policy bookings_insert_own
on public.bookings for insert to authenticated
with check (user_id = auth.uid());

-- optional: admins see all
create policy bookings_admin_read_all
on public.bookings for select
using (exists (select 1 from public.users u where u.id = auth.uid() and u.role='admin'));
