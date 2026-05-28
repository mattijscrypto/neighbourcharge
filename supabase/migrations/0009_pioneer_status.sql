-- ============================================================================
-- Pluggo Pionier-status op profiles
--
-- "Pioniers" zijn de mensen die er vroeg in geloofden — degenen die hun paal
-- al deelden vóór de officiële launch. Ze krijgen:
--   1. Een zichtbare gouden badge op hun profiel
--   2. Voorrang in de search results binnen hetzelfde postcode-gebied
--      (sorteer-key: is_pioneer DESC, daarna afstand ASC)
--
-- We zetten de vlag op profiles, niet op chargers — een Pionier blijft een
-- Pionier ook als 'ie z'n eerste paal verkoopt en een tweede toevoegt. Het
-- gaat om de pérsoon die het mogelijk maakte, niet om de hardware.
--
-- Initiële Pioniers markeren we handmatig in Supabase Studio:
--   update public.profiles set is_pioneer = true, pioneer_since = now()
--   where id = '<user_uuid>';
--
-- Idempotent — kan meerdere keren gedraaid worden zonder fouten.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Kolommen toevoegen
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_pioneer boolean not null default false;

alter table public.profiles
  add column if not exists pioneer_since timestamptz;

comment on column public.profiles.is_pioneer is
  'Markeert deze gebruiker als Pluggo Pionier (vroeg-adopter). Geeft een gouden badge op het profiel en voorrang in search results binnen hetzelfde postcode-gebied.';

comment on column public.profiles.pioneer_since is
  'Wanneer deze gebruiker Pionier werd. NULL voor niet-Pioniers. Wordt gebruikt voor "Pionier sinds <maand jaar>"-label op het profiel.';

-- ---------------------------------------------------------------------------
-- 2. Index voor snelle sort/filter in search queries
-- ---------------------------------------------------------------------------
-- Partial index — alleen Pioniers indexen, scheelt ruimte en is precies
-- wat we nodig hebben (we sorteren is_pioneer DESC, dus we willen snel
-- de Pioniers vinden).
create index if not exists profiles_is_pioneer_idx
  on public.profiles(is_pioneer)
  where is_pioneer = true;

-- ---------------------------------------------------------------------------
-- 3. RLS — bestaande SELECT-policy op profiles laat al "authenticated using
-- (true)" toe, dus boekers kunnen de is_pioneer van paaleigenaren al lezen.
-- WRITE op is_pioneer mag NIET door de gebruiker zelf — die zou zichzelf
-- anders simpelweg promoveren. We voegen daarom een column-level CHECK toe
-- via een trigger die wijzigingen door non-service_role tegenhoudt.
-- ---------------------------------------------------------------------------
create or replace function public.guard_pioneer_status_update()
returns trigger
language plpgsql
security definer
as $$
begin
  -- service_role bypasst RLS én deze trigger (auth.uid() is dan null).
  -- Voor ingelogde users: wijzigingen aan is_pioneer of pioneer_since
  -- zijn niet toegestaan.
  if auth.uid() is not null then
    if new.is_pioneer is distinct from old.is_pioneer then
      raise exception 'is_pioneer kan alleen door Pluggo zelf worden gewijzigd';
    end if;
    if new.pioneer_since is distinct from old.pioneer_since then
      raise exception 'pioneer_since kan alleen door Pluggo zelf worden gewijzigd';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_pioneer_status on public.profiles;
create trigger guard_pioneer_status
  before update on public.profiles
  for each row
  execute function public.guard_pioneer_status_update();

-- ---------------------------------------------------------------------------
-- 4. Helper-view voor Flutter — wordt nog niet gebruikt, maar handig voor
-- toekomstige analytics (hoeveel Pioniers per postcode-gebied?). Niet
-- verplicht voor de feature; commented out tot we 'm nodig hebben.
-- ---------------------------------------------------------------------------
-- create or replace view public.pioneer_summary as
-- select
--   substring(c.address from '\d{4}') as postcode_prefix,
--   count(*) filter (where p.is_pioneer) as pioneer_count,
--   count(*) as total_chargers
-- from public.chargers c
-- left join public.profiles p on p.id = c.owner_id
-- group by 1;
