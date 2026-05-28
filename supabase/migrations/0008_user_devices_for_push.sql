-- ============================================================================
-- user_devices — opslag van FCM device tokens voor push notifications
--
-- Eén user kan meerdere devices hebben (telefoon + iPad, of oude telefoon nog
-- ingelogd). We slaan per device de FCM token op samen met platform en de
-- laatste keer dat het device "gezien" is.
--
-- Wanneer een token op meerdere accounts geregistreerd staat (bv. user logt
-- uit op telefoon en iemand anders logt in op hetzelfde toestel) wint de
-- nieuwste registratie — daarom is er een UNIQUE op fcm_token, geen composite.
-- Dit voorkomt dat we per ongeluk pushes naar de vorige eigenaar van het
-- device blijven sturen.
--
-- RLS: een user kan alleen z'n eigen devices zien/bewerken. De edge function
-- die pushes verstuurt gebruikt service_role en omzeilt RLS.
-- ============================================================================

create table if not exists public.user_devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fcm_token   text not null unique,
  platform    text not null check (platform in ('ios', 'android', 'web')),
  app_version text,
  created_at  timestamptz not null default now(),
  last_seen   timestamptz not null default now()
);

create index if not exists user_devices_user_id_idx
  on public.user_devices(user_id);

create index if not exists user_devices_last_seen_idx
  on public.user_devices(last_seen desc);

alter table public.user_devices enable row level security;

-- User mag eigen devices zien
drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own"
  on public.user_devices
  for select
  to authenticated
  using (auth.uid() = user_id);

-- User mag eigen devices toevoegen
drop policy if exists "user_devices_insert_own" on public.user_devices;
create policy "user_devices_insert_own"
  on public.user_devices
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- User mag eigen devices updaten (last_seen refresh, of token-overdracht)
drop policy if exists "user_devices_update_own" on public.user_devices;
create policy "user_devices_update_own"
  on public.user_devices
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- User mag eigen devices verwijderen (logout, app verwijderd-detectie)
drop policy if exists "user_devices_delete_own" on public.user_devices;
create policy "user_devices_delete_own"
  on public.user_devices
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Helper: upsert voor de Flutter app. Voorkomt dat een token onder meerdere
-- users tegelijk komt te staan: bij conflict op fcm_token wordt user_id
-- overschreven met de huidige auth.uid(). last_seen wordt altijd vernieuwd.
create or replace function public.register_device_token(
  p_token       text,
  p_platform    text,
  p_app_version text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.user_devices (user_id, fcm_token, platform, app_version, last_seen)
  values (auth.uid(), p_token, p_platform, p_app_version, now())
  on conflict (fcm_token)
  do update set
    user_id     = excluded.user_id,
    platform    = excluded.platform,
    app_version = excluded.app_version,
    last_seen   = now();
end;
$$;

grant execute on function public.register_device_token(text, text, text)
  to authenticated;
