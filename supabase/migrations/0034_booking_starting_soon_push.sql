-- ============================================================================
-- 0034_booking_starting_soon_push.sql — Task #288 (afronding).
--
-- CONTEXT
-- ----------------------------------------------------------------------------
-- Task #288 beloofde vier NL-templates voor OCPP sessie-events:
--   1. START            — reeds live via 0025/0026 (`charging_started`)
--   2. TARGET-BEREIKT   — reeds live via 0025/0027 (`charging_target_reached`)
--   3. ETA-10-MIN       — reeds live via 0025 (`charging_eta_10min`)
--   4. COMPLETED        — reeds live via 0025 (`charging_completed`)
--
-- Nazorg #291 (0028) dekt ook al de "reservering loopt zo af" T-15 push
-- (`booking_ending_soon`). Wat #288 nog mist is de OMGEKEERDE T-15 push
-- vóór het venster begint: "over 15 minuten heb je een laadsessie
-- gereserveerd bij X". Dat is precies de push die de nieuwe #315-banner
-- op paal-detail visueel dubbelt — maar niet iedereen zit dan met de app
-- open, dus een OS-push is noodzakelijk om de boeker te herinneren.
--
-- DESIGN
-- ----------------------------------------------------------------------------
-- Zelfde cron-pattern als 0028, uitgebreid met een Stap C:
--
--   Stap C: 15-min-startwarning
--     Voor confirmed bookings die (a) op een smart paal staan (chargers
--     .ocpp_charger_id != null) en (b) waarvan start_time over 13-15 min
--     valt, en (c) notified_starting_soon_at nog NULL is: push versturen
--     + stempel zetten.
--
-- Waarom ALLEEN smart palen? Bij manueel-bediende palen is er geen
-- "start-in-de-app"-moment; de boeker rijdt gewoon naar de paal en de
-- eigenaar zet 'm aan. Een T-15 push heeft dan minder call-to-action.
-- Voor smart palen is 'ie perfect: "loop naar buiten, stekker erin,
-- druk Start in de app".
--
-- Waarom een aparte idempotency-kolom en niet notified_ending_soon_at?
-- Dat zou beide events collideren als een boeking maar 30 min duurt
-- (start T-15 en end T-15 vallen dan door elkaar). Aparte kolom = clean.
--
-- IDEMPOTENT: create or replace + IF NOT EXISTS. Deze migratie is een pure
-- toevoeging op 0028 — proces_booking_window_events wordt uitgebreid, de
-- cron-schedule blijft ongewijzigd.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Idempotentie-kolom + index
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists notified_starting_soon_at timestamptz;

comment on column public.bookings.notified_starting_soon_at is
  'Timestamp toen we de "je laadsessie begint over 15 min" push verzonden. NULL = nog niet gepusht. Voorkomt duplicates bij minuutlijkse cron. Alleen relevant voor smart palen (ocpp_charger_id != null).';

-- Aparte partial index — de bestaande bookings_window_events_idx uit 0028
-- filtert alleen op notified_ending_soon_at / auto_stop_attempted_at.
create index if not exists bookings_starting_soon_idx
  on public.bookings(start_time)
  where status = 'confirmed'
    and notified_starting_soon_at is null;

-- ---------------------------------------------------------------------------
-- 2. process_booking_window_events uitbreiden met Stap C
--
-- We vervangen de hele functie (create or replace) omdat we een lus toevoegen.
-- Stap A + Stap B zijn 1:1 gekopieerd uit 0028. Stap C is nieuw.
-- ---------------------------------------------------------------------------
create or replace function public.process_booking_window_events()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
  v_charger_name text;
  v_title text;
  v_body  text;
begin
  -- =====================================================================
  -- Stap A: 15-min-END-warning (bestaand, uit 0028)
  -- =====================================================================
  for r in
    select
      b.id            as booking_id,
      b.user_id       as booker_id,
      b.end_time      as end_time,
      cs.transaction_id,
      cs.charger_id
    from public.bookings b
    join public.charging_sessions cs on cs.booking_id = b.id
    where b.status = 'confirmed'
      and b.notified_ending_soon_at is null
      and cs.status = 'in_progress'
      and b.end_time >  now() + interval '13 minutes'
      and b.end_time <= now() + interval '15 minutes'
  loop
    begin
      v_charger_name := null;
      if r.charger_id is not null then
        select c.name into v_charger_name
          from public.chargers c where c.id = r.charger_id;
      end if;

      v_title := 'Je reservering loopt zo af';
      v_body  := 'Nog ongeveer 15 minuten op ' ||
                 coalesce(v_charger_name, 'de laadpaal') ||
                 '. Als je nog aan het laden bent, stoppen we straks automatisch zodat de volgende boeker kan starten.';

      perform public._cs_fire_push(
        r.booker_id, v_title, v_body,
        'booking_ending_soon', r.transaction_id, r.booking_id
      );

      update public.bookings
      set notified_ending_soon_at = now()
      where id = r.booking_id;
    exception when others then
      raise notice 'process_booking_window_events A: booking % faalde: %', r.booking_id, sqlerrm;
    end;
  end loop;

  -- =====================================================================
  -- Stap B: Auto-stop bij einde venster (bestaand, uit 0028)
  -- =====================================================================
  for r in
    select
      b.id                    as booking_id,
      b.user_id               as booker_id,
      cs.transaction_id       as transaction_id,
      cs.ocpp_charger_id      as ocpp_charger_id
    from public.bookings b
    join public.charging_sessions cs on cs.booking_id = b.id
    where b.status = 'confirmed'
      and b.auto_stop_attempted_at is null
      and cs.status = 'in_progress'
      and b.end_time <= now()
      and b.end_time >  now() - interval '5 minutes'
  loop
    begin
      update public.bookings
      set auto_stop_attempted_at = now()
      where id = r.booking_id;

      if r.ocpp_charger_id like 'DEV-FAKE%' then
        perform public._bw_complete_fake_session(r.transaction_id);
      else
        perform public._bw_csms_remote_stop(r.ocpp_charger_id, r.transaction_id);
      end if;
    exception when others then
      raise notice 'process_booking_window_events B: booking % faalde: %', r.booking_id, sqlerrm;
    end;
  end loop;

  -- =====================================================================
  -- Stap C: 15-min-STARTwarning voor smart palen (NIEUW in 0034)
  -- =====================================================================
  --
  -- Voor confirmed bookings op smart palen waarvan start_time over 13-15
  -- min valt (2-min-window om gemiste cron-ticks te vangen) en die nog geen
  -- starting-soon-push hebben gehad: reminder versturen + stempel zetten.
  --
  -- We joinen NIET op charging_sessions want die is er nog niet — de sessie
  -- start pas als de boeker de "Start" knop drukt. We joinen wél op
  -- chargers om de smart-check (ocpp_charger_id != null) te doen én de
  -- paalnaam op te halen voor in de push-body.
  for r in
    select
      b.id            as booking_id,
      b.user_id       as booker_id,
      b.start_time    as start_time,
      c.name          as charger_name,
      c.id            as charger_id
    from public.bookings b
    join public.chargers c on c.id = b.charger_id
    where b.status = 'confirmed'
      and b.notified_starting_soon_at is null
      and c.ocpp_charger_id is not null
      and b.start_time >  now() + interval '13 minutes'
      and b.start_time <= now() + interval '15 minutes'
  loop
    begin
      v_title := 'Je laadsessie begint zo';
      v_body  := 'Over 15 minuten kun je laden bij ' ||
                 coalesce(r.charger_name, 'de laadpaal') ||
                 '. Kom aan, plug in en druk op Start in de app.';

      -- _cs_fire_push accepteert (booker_id, title, body, event_type,
      -- transaction_id_nullable, booking_id). Transaction bestaat hier
      -- nog niet, dus we geven NULL door.
      perform public._cs_fire_push(
        r.booker_id, v_title, v_body,
        'booking_starting_soon', null, r.booking_id
      );

      update public.bookings
      set notified_starting_soon_at = now()
      where id = r.booking_id;
    exception when others then
      raise notice 'process_booking_window_events C: booking % faalde: %', r.booking_id, sqlerrm;
    end;
  end loop;
end;
$$;

comment on function public.process_booking_window_events() is
  'Cron entry-point (uitgebreid in 0034). Stap A: end-15-min-warning + auto-stop (task #291). Stap B: auto-stop. Stap C: start-15-min-warning voor smart palen (task #288). Idempotent via notified_ending_soon_at, auto_stop_attempted_at, notified_starting_soon_at kolommen.';

-- ---------------------------------------------------------------------------
-- 3. Cron-schedule blijft ongewijzigd (elke minuut). 0028 heeft 'em al
--    ingericht onder de naam 'process-booking-window-events'.
-- ---------------------------------------------------------------------------

-- ============================================================================
-- ROLLBACK
-- ----------------------------------------------------------------------------
--   Recreate process_booking_window_events() vanuit 0028 (zonder Stap C).
--   alter table public.bookings drop column if exists notified_starting_soon_at;
--   drop index if exists public.bookings_starting_soon_idx;
--
-- VERIFICATIE (na deploy)
-- ----------------------------------------------------------------------------
--   1. Handmatig triggeren:
--        select public.process_booking_window_events();
--      → geen errors, geen dubbele pushes op reeds-genotificeerde bookings.
--   2. Maak een test-booking op een smart paal met start_time 14 min
--      vanaf nu. Wacht tot de eerstvolgende cron-tick binnen 13-15 min:
--      • De booker ontvangt de "Je laadsessie begint zo" push.
--      • bookings.notified_starting_soon_at is nu gevuld.
--      • Bij de volgende cron-tick wordt de push NIET opnieuw verstuurd.
--   3. Voor een MANUEEL paal: geen push (chargers.ocpp_charger_id is null).
-- ============================================================================
