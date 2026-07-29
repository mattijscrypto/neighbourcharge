-- ============================================================================
-- 0029_booking_extend_flow.sql
--
-- Task #292: Booking-verlengen vanaf de 15-min-warning push.
--
-- USER-FLOW:
--   1. 14:45 — user krijgt "Je reservering loopt zo af" push (uit 0028).
--   2. Op het lockscreen ziet de user knoppen: "Verleng 15", "30", "60".
--      Alleen die opties die conflict-vrij zijn worden getoond.
--   3. Tap → app roept public.extend_booking(booking_id, minutes) aan.
--   4. end_time schuift op. Cron plant een NIEUWE warning tegen de nieuwe
--      end_time (want notified_ending_soon_at + auto_stop_attempted_at
--      worden gereset).
--
-- DEZE MIGRATIE BEVAT:
--   A) Helper _bw_available_extension_minutes(booking_id) → integer[]
--      → welke van {15, 30, 60} zijn conflict-vrij tegen andere confirmed
--        bookings op dezelfde paal, en zonder over end-of-day te schieten?
--        (End-of-day cap: we willen niet dat een 23:50-boeking opeens 60 min
--         doorloopt tot 00:50 volgende dag — kan later, is nu niet in scope.)
--
--   B) RPC extend_booking(p_booking_id uuid, p_extra_minutes integer)
--      → SECURITY DEFINER. Guards:
--          - Booking bestaat en b.user_id = auth.uid()
--          - Booking status = 'confirmed'
--          - Booking heeft een actieve charging_session (anders is verlengen
--            niet zinnig — dan boek je gewoon een nieuwe slot)
--          - p_extra_minutes ∈ {15, 30, 60}
--          - Geen conflict met andere confirmed bookings op dezelfde paal
--        Bij succes:
--          - end_time := end_time + interval
--          - notified_ending_soon_at := NULL  (zodat cron opnieuw kan waarschuwen)
--          - auto_stop_attempted_at  := NULL  (zodat auto-stop bij nieuwe eind kan)
--        Return: jsonb met new_end_time.
--
--   C) Update van process_booking_window_events (uit 0028) zodat de
--      15-min-warning-push nu ook `category` en `available_extensions` in
--      de data-payload meestuurt. De send-push edge function (aparte deploy)
--      vertaalt dat naar de juiste iOS category / Android notification actions.
--
--      Om dit te doen introduceer ik een NIEUWE helper _cs_fire_push_rich
--      (in migration 0025 zit alleen _cs_fire_push met vaste payload-vorm).
--      _cs_fire_push_rich neemt een jsonb 'extra_data' die bij het bestaande
--      data-object gemerged wordt.
--
-- WAAROM GEEN EIGEN URL-ROUTE / DEEP LINK PER MINUUT?
--   Deep link (pluggo://booking/extend?minutes=15) is een fallback voor
--   platforms waar action-buttons niet renderen (bv. Android op oudere
--   OS-versies zonder rijke notif). De primaire tap-flow gaat via
--   UNNotificationAction (iOS) / NotificationCompat.Action (Android) direct
--   naar de RPC — de app roept extend_booking aan zonder deep link.
--   Deep link is dus optioneel; we hoeven er in SQL niets voor te doen.
--
-- IDEMPOTENT: create or replace overal.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- A. Helper: _bw_available_extension_minutes
--
-- Return: integer[] met welke van {15, 30, 60} minuten conflict-vrij zijn.
--
-- Conflict-check: voor elke kandidaat-verlenging kijken of er een andere
-- confirmed booking bestaat op dezelfde paal die overlap heeft met het
-- verlengde venster [b.end_time, b.end_time + minutes).
--
-- Returnt een LEEG array als de booking niet bestaat / niet meer confirmed
-- is / afgelopen — dan is verlengen sowieso niet zinvol.
-- ---------------------------------------------------------------------------
create or replace function public._bw_available_extension_minutes(
  p_booking_id uuid
) returns integer[]
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_result integer[] := array[]::integer[];
  v_minutes integer;
  v_conflict boolean;
begin
  select id, charger_id, end_time, status
    into v_booking
  from public.bookings
  where id = p_booking_id;

  if v_booking.id is null then
    return v_result;
  end if;
  if v_booking.status <> 'confirmed' then
    return v_result;
  end if;

  -- Loop over de drie kandidaten. Simpel en expliciet — geen loop-tabel nodig.
  foreach v_minutes in array array[15, 30, 60] loop
    -- Bestaat er een andere confirmed booking op dezelfde paal die overlapt
    -- met het verlengingsvenster [end_time, end_time + minutes)?
    select exists (
      select 1
      from public.bookings other
      where other.charger_id = v_booking.charger_id
        and other.id <> v_booking.id
        and other.status = 'confirmed'
        -- Overlap-check: other.start_time < window_end AND other.end_time > window_start
        and other.start_time < v_booking.end_time + make_interval(mins => v_minutes)
        and other.end_time   > v_booking.end_time
    ) into v_conflict;

    if not v_conflict then
      v_result := array_append(v_result, v_minutes);
    end if;
  end loop;

  return v_result;
end;
$$;

comment on function public._bw_available_extension_minutes(uuid) is
  'Return array van {15, 30, 60} minuten die als extension conflict-vrij zijn t.o.v. andere confirmed bookings op dezelfde paal. Leeg array = niet verlengbaar (booking bestaat niet / niet confirmed / alles conflicteert).';

-- ---------------------------------------------------------------------------
-- B. RPC: extend_booking
--
-- Aangeroepen vanuit de Flutter-app na een tap op een lockscreen-action.
-- SECURITY DEFINER omdat we door RLS heen willen kunnen updaten (we checken
-- self hier expliciet met auth.uid()).
--
-- Return: jsonb {
--   status: 'ok' | 'not_owner' | 'not_confirmed' | 'no_active_session'
--         | 'conflict' | 'invalid_minutes' | 'not_found',
--   new_end_time: timestamptz  (alleen bij status = 'ok'),
--   requested_minutes: integer,
-- }
--
-- We returnen structured jsonb i.p.v. te raisen, zodat de client een nette
-- error-toast kan tonen zonder try/except op HTTP-error.
-- ---------------------------------------------------------------------------
create or replace function public.extend_booking(
  p_booking_id     uuid,
  p_extra_minutes  integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user      uuid;
  v_booking   record;
  v_new_end   timestamptz;
  v_conflict  boolean;
  v_has_session boolean;
begin
  v_user := auth.uid();

  if p_extra_minutes not in (15, 30, 60) then
    return jsonb_build_object(
      'status', 'invalid_minutes',
      'requested_minutes', p_extra_minutes
    );
  end if;

  select id, user_id, charger_id, end_time, status
    into v_booking
  from public.bookings
  where id = p_booking_id;

  if v_booking.id is null then
    return jsonb_build_object(
      'status', 'not_found',
      'requested_minutes', p_extra_minutes
    );
  end if;

  if v_user is null or v_booking.user_id <> v_user then
    return jsonb_build_object(
      'status', 'not_owner',
      'requested_minutes', p_extra_minutes
    );
  end if;

  if v_booking.status <> 'confirmed' then
    return jsonb_build_object(
      'status', 'not_confirmed',
      'requested_minutes', p_extra_minutes,
      'current_status', v_booking.status
    );
  end if;

  -- Alleen verlengen als er ook echt een sessie loopt. Anders bezorg je
  -- de user het valse gevoel dat hij nog extra tijd heeft terwijl er
  -- eigenlijk niets loopt (en de auto-stop-cron slaat de aankomende
  -- verlenging over zonder actie).
  select exists (
    select 1 from public.charging_sessions cs
    where cs.booking_id = v_booking.id
      and cs.status = 'in_progress'
  ) into v_has_session;

  if not v_has_session then
    return jsonb_build_object(
      'status', 'no_active_session',
      'requested_minutes', p_extra_minutes
    );
  end if;

  v_new_end := v_booking.end_time + make_interval(mins => p_extra_minutes);

  -- Conflict-check tegen andere confirmed bookings op dezelfde paal.
  -- Merk op: als er in de tussentijd door iemand anders geboekt is (race
  -- tussen availability-check en tap), krijgen we hier alsnog een conflict-
  -- return. Geen "gedeeltelijk verlengen" — user krijgt gewoon 'conflict'
  -- en kan een kortere optie proberen.
  select exists (
    select 1
    from public.bookings other
    where other.charger_id = v_booking.charger_id
      and other.id <> v_booking.id
      and other.status = 'confirmed'
      and other.start_time < v_new_end
      and other.end_time   > v_booking.end_time
  ) into v_conflict;

  if v_conflict then
    return jsonb_build_object(
      'status', 'conflict',
      'requested_minutes', p_extra_minutes
    );
  end if;

  -- Alles OK — update.
  --   end_time schuift op.
  --   notified_ending_soon_at NULL → cron plant nieuwe 15-min-warning.
  --   auto_stop_attempted_at  NULL → cron kan straks bij nieuwe eind stoppen.
  update public.bookings
  set end_time                = v_new_end,
      notified_ending_soon_at = null,
      auto_stop_attempted_at  = null
  where id = v_booking.id;

  return jsonb_build_object(
    'status', 'ok',
    'requested_minutes', p_extra_minutes,
    'new_end_time', v_new_end
  );
end;
$$;

comment on function public.extend_booking(uuid, integer) is
  'Verleng een confirmed booking met 15/30/60 min. Auth-guard op auth.uid() = booking.user_id. Conflict-check tegen andere confirmed bookings op dezelfde paal. Reset notified_ending_soon_at + auto_stop_attempted_at zodat cron opnieuw kan waarschuwen tegen de nieuwe eind-tijd. Return jsonb met status.';

-- Grant zodat de Flutter-client (authenticated role) 'm mag aanroepen.
grant execute on function public.extend_booking(uuid, integer) to authenticated;
grant execute on function public._bw_available_extension_minutes(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- C. Nieuwe fire-push helper met rich data-payload
--
-- _cs_fire_push (uit 0025) bouwt een vaste data-shape {type, transaction_id,
-- booking_id}. Voor de 15-min-warning willen we óók 'category' en
-- 'available_extensions' meesturen zodat de send-push edge function de
-- juiste APNs category / Android notification actions kan zetten.
--
-- Nieuwe naam om 0025 niet te breken. Zelfde secret-lookup / async-post.
-- ---------------------------------------------------------------------------
create or replace function public._cs_fire_push_rich(
  p_user_id    uuid,
  p_title      text,
  p_body       text,
  p_data       jsonb
) returns void
language plpgsql
security definer
set search_path = extensions, public, vault, pg_temp
as $$
declare
  v_url text;
  v_key text;
begin
  if p_user_id is null then
    return;
  end if;

  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'supabase_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'service_role_key';

  if v_url is null or v_key is null then
    raise notice '_cs_fire_push_rich: vault secrets ontbreken, push overgeslagen';
    return;
  end if;

  perform net.http_post(
    url     := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', p_user_id::text,
      'title',   p_title,
      'body',    p_body,
      'data',    coalesce(p_data, '{}'::jsonb)
    )
  );
end;
$$;

comment on function public._cs_fire_push_rich(uuid, text, text, jsonb) is
  'Fire-and-forget push notification met een vrij data-object. Zelfde send-push edge function als _cs_fire_push maar zonder vaste payload-shape. Bedoeld voor pushes die category / actions / andere metadata meesturen.';

-- ---------------------------------------------------------------------------
-- D. process_booking_window_events — REPLACE met rijke 15-min-warning-push
--
-- Wat is veranderd t.o.v. 0028:
--   Stap A vervangt _cs_fire_push door _cs_fire_push_rich met een jsonb
--   die category='BOOKING_ENDING_SOON' en available_extensions bevat.
--   available_extensions is een comma-separated string (bv "15,30,60") zodat
--   de FCM data-payload alle waarden als strings kan hebben (FCM data-vereiste).
--
--   Als _bw_available_extension_minutes een leeg array teruggeeft (bv. omdat
--   er al direct achter een andere boeking staat), sturen we een LEGE
--   available_extensions string — client toont dan geen action-knoppen, alleen
--   de informerende push.
--
-- Stap B (auto-stop) is ongewijzigd — kopie uit 0028.
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
  v_extensions integer[];
  v_extensions_csv text;
  v_data jsonb;
begin
  -- =====================================================================
  -- Stap A: 15-min-warning met verleng-actions
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

      -- Beschikbare verleng-opties uitrekenen
      v_extensions := public._bw_available_extension_minutes(r.booking_id);
      -- Naar CSV-string voor FCM data-payload (alle waarden moeten strings zijn)
      v_extensions_csv := array_to_string(v_extensions, ',');

      -- iOS UNNotificationCategory-id moet exact matchen met een geregistreerde
      -- category client-side. Client (AppDelegate.swift) registreert er één
      -- per non-empty subset van {15,30,60}. Naming-conventie:
      --   BOOKING_ENDING_SOON_15_30_60 / _15_30 / _15_60 / _30_60 / _15 / _30 / _60
      --
      -- Als er GEEN extension mogelijk is (leeg array), sturen we category NULL
      -- zodat iOS geen actions probeert te renderen en gewoon de plain
      -- notificatie toont — user krijgt dan alleen de informatieve warning.
      if array_length(v_extensions, 1) is null then
        v_data := jsonb_build_object(
          'type',                 'booking_ending_soon',
          'transaction_id',       r.transaction_id::text,
          'booking_id',           r.booking_id::text,
          'available_extensions', ''
        );
      else
        v_data := jsonb_build_object(
          'type',                 'booking_ending_soon',
          'transaction_id',       r.transaction_id::text,
          'booking_id',           r.booking_id::text,
          'category',             'BOOKING_ENDING_SOON_' || replace(v_extensions_csv, ',', '_'),
          'available_extensions', v_extensions_csv
        );
      end if;

      perform public._cs_fire_push_rich(
        r.booker_id, v_title, v_body, v_data
      );

      update public.bookings
      set notified_ending_soon_at = now()
      where id = r.booking_id;
    exception when others then
      raise notice 'process_booking_window_events A: booking % faalde: %', r.booking_id, sqlerrm;
    end;
  end loop;

  -- =====================================================================
  -- Stap B: Auto-stop bij einde venster (ongewijzigd t.o.v. 0028)
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
end;
$$;

comment on function public.process_booking_window_events() is
  'Cron entry-point voor task #291 + #292. Stap A: 15-min-warning met verleng-action-payload (category + available_extensions). Stap B: auto-stop bij einde venster. Idempotent via notified_ending_soon_at / auto_stop_attempted_at kolommen op bookings.';

-- ---------------------------------------------------------------------------
-- E. Handmatig testen
--
-- 1) Availability check:
--      select public._bw_available_extension_minutes('<booking-uuid>');
--    Verwacht: {15,30,60} als er niks achter zit, of subset.
--
-- 2) Verleng testen (als authenticated user via de app, of via SQL editor
--    met een role-switch — auth.uid() is null als postgres):
--      select public.extend_booking('<booking-uuid>', 30);
--    Verwacht bij role=authenticated + juiste user:
--      { "status":"ok", "requested_minutes":30, "new_end_time": ... }
--    Verwacht bij role=postgres (auth.uid() NULL):
--      { "status":"not_owner", ... }
--
-- 3) Warning-push met payload — force process meteen (i.p.v. wachten op cron):
--      select public.process_booking_window_events();
--    Dan in de app: verwacht een push waarvan de data payload
--      { type: 'booking_ending_soon', category: 'BOOKING_ENDING_SOON',
--        available_extensions: '15,30,60', ... }
--    bevat. Zichtbaar in de FCM-response:
--      select * from net._http_response order by created desc limit 3;
-- ---------------------------------------------------------------------------
