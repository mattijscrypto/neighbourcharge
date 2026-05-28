-- ============================================================================
-- Fuzzy locatie op publieke kaart
--
-- Aanleiding: een tester signaleerde dat de exacte locatie van iedere paal
-- + zijn beschikbaarheids-schema publiek op de kaart staat. Risico: iemand
-- zonder boeking rijdt naar een paal en laadt zonder te betalen.
--
-- Mitigatie: op de publieke kaart tonen we voortaan een fuzzy positie met
-- een random offset van 100-200m. De offset is *deterministisch* per paal
-- (uit md5(id)) zodat dezelfde paal niet steeds rondspringt op de kaart.
-- De exacte locatie krijgt de boeker pas te zien na een 'confirmed' boeking;
-- de eigenaar ziet 'm altijd in zijn eigen "Mijn palen"-scherm.
--
-- Architectuur:
--   1. Twee extra kolommen op chargers: lat_public, lng_public
--   2. Trigger berekent fuzzy bij insert + recompute bij wijziging van lat/lng
--   3. Backfill voor bestaande rijen
--   4. View chargers_public die alleen fuzzy coords en publieke velden toont
--
-- Niet in deze migratie (volgende sprint):
--   - RLS-policies op chargers om directe REST-abuse via anon-key te blokkeren.
--     Voor nu vertrouwen we op de app-code: kaart bevraagt chargers_public,
--     detail valt naar chargers_public terug als er geen confirmed booking is.
--   - Een door owner aan te passen `address_public` (nu auto-derived in Dart).
--
-- Idempotent — kan meerdere keren gedraaid worden.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Fuzzy lat/lng kolommen
-- ---------------------------------------------------------------------------
alter table public.chargers
  add column if not exists lat_public numeric;
alter table public.chargers
  add column if not exists lng_public numeric;

comment on column public.chargers.lat_public is
  'Fuzzy latitude (100-200m random offset vanaf exacte locatie). Deterministisch berekend uit charger.id via trigger. Gebruikt op publieke kaart om thuisadres niet te verraden. Update gebeurt automatisch bij wijziging van lat.';
comment on column public.chargers.lng_public is
  'Fuzzy longitude — zie lat_public.';

-- ---------------------------------------------------------------------------
-- 2. Trigger-functie: deterministische fuzzy offset uit charger.id
--
-- Algoritme:
--   - Seed = eerste 32 bits van md5(id), gecast naar bigint
--   - Angle (richting) = (seed mod 10000) * 2π / 10000   — [0, 2π)
--   - Distance = 100 + ((seed div 10000) mod 100) meter  — [100, 200)
--   - Offset:
--       Δlat = (distance * cos(angle)) / 111320          (1° lat ≈ 111320 m)
--       Δlng = (distance * sin(angle)) / (111320 * cos(lat))  (longitude shrinkt richting de polen)
--
-- Edge case: lat/lng NULL → fuzzy NULL (geen exceptie, geen kaart-pin).
-- ---------------------------------------------------------------------------
create or replace function public.compute_charger_fuzzy_location()
returns trigger
language plpgsql
as $$
declare
  seed bigint;
  angle double precision;
  distance_m double precision;
begin
  if new.lat is null or new.lng is null then
    new.lat_public := null;
    new.lng_public := null;
    return new;
  end if;

  -- Deterministische seed uit eerste 8 hex chars van md5(id)
  seed := ('x' || substring(md5(new.id::text), 1, 8))::bit(32)::bigint;

  -- Schaal naar angle [0, 2π) en distance [100, 200) meter
  angle := (abs(seed) % 10000) * 2 * pi() / 10000.0;
  distance_m := 100.0 + ((abs(seed) / 10000) % 100);

  -- Offset coordinaten — 1° latitude ≈ 111320 m wereldwijd;
  -- 1° longitude ≈ 111320 * cos(lat) m (smaller toward poles).
  new.lat_public := new.lat + (distance_m * cos(angle)) / 111320.0;
  new.lng_public := new.lng + (distance_m * sin(angle)) / (111320.0 * cos(radians(new.lat)));

  return new;
end;
$$;

comment on function public.compute_charger_fuzzy_location() is
  'Berekent fuzzy locatie (lat_public, lng_public) uit exacte lat/lng + charger.id seed. Deterministisch — zelfde paal krijgt altijd zelfde fuzzy positie.';

-- ---------------------------------------------------------------------------
-- 3. Trigger: vul fuzzy bij insert + recompute bij update van lat/lng
-- ---------------------------------------------------------------------------
drop trigger if exists chargers_fuzzy_on_change on public.chargers;
create trigger chargers_fuzzy_on_change
  before insert or update of lat, lng on public.chargers
  for each row execute function public.compute_charger_fuzzy_location();

-- ---------------------------------------------------------------------------
-- 4. Backfill bestaande rijen — UPDATE triggert de functie
-- ---------------------------------------------------------------------------
update public.chargers set lat = lat where lat is not null and lat_public is null;

-- ---------------------------------------------------------------------------
-- 5. Publieke view voor de kaart — toont GEEN exacte lat/lng
--
-- De Flutter app bevraagt deze view voor de kaart-listing en voor detail-
-- screens van niet-geautoriseerde gebruikers. Eigenaars en confirmed bookers
-- bevragen direct de chargers-tabel.
--
-- We includen owner_email + Pionier-info zodat de Charger.fromMap factory
-- precies dezelfde shape krijgt als bij de oude chargers-query — minimal
-- code change in Flutter.
-- ---------------------------------------------------------------------------
create or replace view public.chargers_public as
select
  c.id,
  c.name,
  c.address,
  c.lat_public as lat,
  c.lng_public as lng,
  c.price,
  c.type,
  c.available,
  c.solar,
  c.description,
  c.instructions,
  c.owner_id,
  c.owner_email,
  c.photo_urls,
  c.cable_included,
  c.access_type,
  c.created_at,
  -- Inline embed voor Pionier-badge (anders moet de app een join doen)
  jsonb_build_object('is_pioneer', coalesce(p.is_pioneer, false)) as owner_profile
from public.chargers c
left join public.profiles p on p.id = c.owner_id;

comment on view public.chargers_public is
  'Publieke view van chargers — toont alleen fuzzy locatie (lat_public, lng_public). Wordt door de kaart en niet-geautoriseerde detail-screens gebruikt. Voor exacte locatie: query direct chargers (owner en confirmed bookers).';

grant select on public.chargers_public to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Sanity check — zorg dat backfill alles heeft gevuld
-- (alleen iets opmerken, geen exceptie zodat de migratie altijd doorgaat)
-- ---------------------------------------------------------------------------
do $$
declare
  missing int;
begin
  select count(*) into missing
  from public.chargers
  where lat is not null and lat_public is null;
  if missing > 0 then
    raise notice 'Pluggo fuzzy-location migratie: % rijen met lat maar zonder lat_public. Check de trigger.', missing;
  end if;
end;
$$;
