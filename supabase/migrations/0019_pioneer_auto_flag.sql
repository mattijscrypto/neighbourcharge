-- ============================================================================
-- Migratie 0019 — Pionier auto-flag + publieke teller
--
-- Waarom:
--   Migratie 0009 introduceerde is_pioneer + pioneer_since als handmatige
--   admin-actie. De pioniers-landingspage belooft echter automatische
--   toekenning ("Zodra je paal actief is, krijg je automatisch de Pionier-
--   badge"). Deze migratie sluit dat gat: elke gebruiker die z'n eerste
--   paal toevoegt wordt automatisch Pionier, mits het totaal onder de 100
--   blijft. Bestaande handmatige backfill blijft mogelijk.
--
-- Wat:
--   1. Trigger op chargers INSERT die owner_id promoveert tot Pionier
--   2. Aanpassing van guard_pioneer_status_update() zodat de auto-flag
--      trigger door de guard mag (via session-config marker)
--   3. Publieke view + read-grant zodat pluggoapp.nl anon de teller
--      kan lezen zonder profiles-lekken
--
-- Idempotent — kan meerdere keren gedraaid worden.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Guard aanpassen: bypass wanneer set_config('pluggo.internal_pioneer_update')
--    is gezet door een trusted trigger. auth.uid()-check blijft intact voor
--    externe user-updates.
-- ---------------------------------------------------------------------------
create or replace function public.guard_pioneer_status_update()
returns trigger
language plpgsql
security definer
as $$
begin
  -- Trusted trigger context: onze eigen auto_flag_pioneer_on_first_charger
  -- zet deze config-var voordat 'ie profiles update. Config is TX-local
  -- (derde argument 'true' bij set_config), dus lekt niet naar de volgende
  -- statement/connection.
  if current_setting('pluggo.internal_pioneer_update', true) = 'true' then
    return new;
  end if;

  -- service_role bypasst RLS én deze trigger (auth.uid() is dan null).
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

-- ---------------------------------------------------------------------------
-- 2. Auto-flag trigger op chargers INSERT
--
--    Regels:
--      - Skip als owner al Pionier is (idempotent — 2e paal geeft geen
--        double-toekenning, en de badge zit sowieso al goed)
--      - Skip als er al 100 Pioniers zijn (Pioniers-pakket = eerste 100)
--      - Anders: is_pioneer=true, pioneer_since=now()
--
--    Race-condition met de 100-cap: als twee inserts tegelijk komen bij
--    Pionier #100 kunnen er kortstondig 101 zijn. Dat is voor deze use-case
--    acceptabel — we hebben nog niet de schaal waarop dat regelmatig
--    voorkomt en het is een hard business-cap, geen safety-boundary.
-- ---------------------------------------------------------------------------
create or replace function public.auto_flag_pioneer_on_first_charger()
returns trigger
language plpgsql
security definer
as $$
declare
  already_pioneer boolean;
  current_count   integer;
begin
  -- Skip als owner al Pionier is
  select is_pioneer into already_pioneer
    from public.profiles
    where id = new.owner_id;
  if already_pioneer is true then
    return new;
  end if;

  -- Cap op 100 Pioniers
  select count(*) into current_count
    from public.profiles
    where is_pioneer = true;
  if current_count >= 100 then
    return new;
  end if;

  -- Trusted context markeren → guard laat de update door
  perform set_config('pluggo.internal_pioneer_update', 'true', true);

  update public.profiles
    set is_pioneer    = true,
        pioneer_since = now()
    where id = new.owner_id;

  return new;
end;
$$;

drop trigger if exists auto_flag_pioneer on public.chargers;
create trigger auto_flag_pioneer
  after insert on public.chargers
  for each row
  execute function public.auto_flag_pioneer_on_first_charger();

-- ---------------------------------------------------------------------------
-- 3. Publieke teller-view — alleen het aantal Pioniers, niet de rijen zelf.
--    Zo kan pluggoapp.nl/pioniers de teller live tonen zonder dat er
--    identificeerbare data lekt.
-- ---------------------------------------------------------------------------
create or replace view public.pioneer_public_count as
  select count(*)::int as pioneer_count
  from public.profiles
  where is_pioneer = true;

comment on view public.pioneer_public_count is
  'Public read-only teller van Pluggo Pioniers. Gebruikt door pluggoapp.nl/pioniers om de live teller te tonen. Bevat alleen een aggregaat, geen identificeerbare profielen.';

-- Anon + authenticated mogen alleen de count zien
grant select on public.pioneer_public_count to anon, authenticated;
