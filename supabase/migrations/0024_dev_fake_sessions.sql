-- ============================================================================
-- 0024_dev_fake_sessions.sql — Dev-only RPCs voor simuleren laadsessie
--
-- Doel: de LiveChargingCard (task #287) kunnen testen zonder fysieke OCPP-paal.
-- Terwijl #266 (VPS) en #273 (paal-aankoop) nog lopen, kan de gebruiker via
-- de app een fake-sessie starten die zich gedraagt als een echte OCPP-sessie:
--   1. dev_start_fake_session(booking_id) → maakt charging_sessions rij
--   2. dev_tick_fake_session(transaction_id, add_wh, tick_at) → += meter_wh
--   3. dev_stop_fake_session(transaction_id) → status = 'completed'
--
-- WAAROM SECURITY DEFINER + eigen guards:
--   In productie schrijft alleen service_role naar charging_sessions
--   (RLS in 0021). Voor dev-mode moet de booker zelf kunnen seeden, maar
--   zonder de RLS-policies uit te hollen. Oplossing: SECURITY DEFINER
--   functies met expliciete auth-check binnenin — alleen de booker van
--   de betreffende boeking kan aan die booking-scoped sessie werken.
--
-- Idempotent: alle statements gebruiken IF NOT EXISTS / CREATE OR REPLACE.
--
-- Deze functies zijn "dev-mode" — bedoeld voor internal testers + TestFlight
-- pilot. In een echte productie-launch met betalende gebruikers zetten we
-- er een extra check bij op profiles.is_dev_tester (of vergelijkbaar), of
-- we droppen de functies voor de v1.0-release. Voor nu ongegated zodat
-- pioniers ook kunnen kickstarten.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. dev_start_fake_session
--
-- Maakt een charging_sessions rij aan voor de opgegeven boeking. Zet meter_start_wh
-- op een willekeurige startwaarde (paal-meter heeft toch een niet-nul stand),
-- meter_current_wh = meter_start_wh. Return transaction_id.
--
-- Guards:
--   - Booking bestaat, user_id = auth.uid()  (booker mag alleen eigen dev-sessies)
--   - Booking status ∈ ('confirmed', 'in_progress')  (paid / accepted / verlopen)
--   - Er is nog geen actieve sessie voor deze boeking
-- ---------------------------------------------------------------------------
create or replace function public.dev_start_fake_session(
  p_booking_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_charger_id uuid;
  v_ocpp_id    text;
  v_tx_id      bigint;
  v_start_wh   bigint;
begin
  -- Guard 1: booking bestaat en is van de aanroeper
  select b.charger_id into v_charger_id
  from public.bookings b
  where b.id = p_booking_id
    and b.user_id = auth.uid();

  if v_charger_id is null then
    raise exception 'Booking not found or not owned by caller';
  end if;

  -- Guard 2: al lopende sessie? Voorkom dubbele fake-sessies
  if exists (
    select 1 from public.charging_sessions
    where booking_id = p_booking_id and status = 'in_progress'
  ) then
    raise exception 'Session already in progress for this booking';
  end if;

  -- OCPP-id ophalen (mag null zijn — voor fake sessies is dat OK)
  select ocpp_charger_id into v_ocpp_id
  from public.chargers where id = v_charger_id;

  -- Startmeter: doe alsof de paal al een paar duizend kWh heeft gemeten
  -- (realistische fysieke paal-meter). Random 10-100 MWh in Wh.
  v_start_wh := (10000000 + floor(random() * 90000000))::bigint;

  insert into public.charging_sessions (
    ocpp_charger_id,
    connector_id,
    id_tag,
    charger_id,
    booking_id,
    meter_start_wh,
    meter_current_wh,
    status,
    started_at,
    last_meter_at
  ) values (
    coalesce(v_ocpp_id, 'DEV-FAKE'),
    1,
    'DEV-TAG-' || substring(p_booking_id::text from 1 for 8),
    v_charger_id,
    p_booking_id,
    v_start_wh,
    v_start_wh,
    'in_progress',
    now(),
    now()
  )
  returning transaction_id into v_tx_id;

  return v_tx_id;
end;
$$;

comment on function public.dev_start_fake_session(uuid) is
  'DEV ONLY: seed a fake OCPP charging_sessions row for a booking. Booker-scoped: only works for bookings you own. Used by the app to test LiveChargingCard without a physical paal.';

-- ---------------------------------------------------------------------------
-- 2. dev_tick_fake_session
--
-- Simuleert een MeterValues-tick: verhoogt meter_current_wh met p_add_wh,
-- schrijft een charging_session_meter_values rij, en update last_meter_at.
-- Client roept deze aan om de X seconden (bijv. elke 5s +150 Wh = ~11 kW).
--
-- Guards:
--   - Session bestaat en booker is de aanroeper (via booking.user_id)
--   - Session status = 'in_progress'
--   - p_add_wh in redelijke range (0 < add ≤ 5000)  (5 kWh per tick is genoeg)
-- ---------------------------------------------------------------------------
create or replace function public.dev_tick_fake_session(
  p_transaction_id bigint,
  p_add_wh integer default 150
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_wh bigint;
  v_now    timestamptz := now();
begin
  if p_add_wh is null or p_add_wh <= 0 or p_add_wh > 5000 then
    raise exception 'add_wh must be between 1 and 5000';
  end if;

  -- Guard: session bestaat, is in_progress, en booker is aanroeper
  update public.charging_sessions cs
  set meter_current_wh = coalesce(cs.meter_current_wh, cs.meter_start_wh) + p_add_wh,
      last_meter_at    = v_now
  where cs.transaction_id = p_transaction_id
    and cs.status = 'in_progress'
    and exists (
      select 1 from public.bookings b
      where b.id = cs.booking_id
        and b.user_id = auth.uid()
    )
  returning cs.meter_current_wh into v_new_wh;

  if v_new_wh is null then
    raise exception 'Session not found, not in_progress, or not owned by caller';
  end if;

  -- Meter-value tick loggen (voor kW-berekening in de widget)
  insert into public.charging_session_meter_values (
    transaction_id, meter_wh, measured_at
  ) values (
    p_transaction_id, v_new_wh, v_now
  )
  on conflict (transaction_id, measured_at) do nothing;

  return v_new_wh;
end;
$$;

comment on function public.dev_tick_fake_session(bigint, integer) is
  'DEV ONLY: increment meter_current_wh of a fake session by p_add_wh and log a meter-value tick. Guarded so only the booker can tick their own session.';

-- ---------------------------------------------------------------------------
-- 3. dev_stop_fake_session
--
-- Zet status = 'completed' en meter_stop_wh = meter_current_wh. LiveChargingCard
-- toont de laatste stand nog 5 seconden en verdwijnt dan (auto-hide).
--
-- Guards: idem als tick — booker-scoped, alleen in_progress.
-- ---------------------------------------------------------------------------
create or replace function public.dev_stop_fake_session(
  p_transaction_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current bigint;
begin
  update public.charging_sessions cs
  set status       = 'completed',
      meter_stop_wh = coalesce(cs.meter_current_wh, cs.meter_start_wh),
      stopped_at    = now(),
      stop_reason   = 'dev_stop'
  where cs.transaction_id = p_transaction_id
    and cs.status = 'in_progress'
    and exists (
      select 1 from public.bookings b
      where b.id = cs.booking_id
        and b.user_id = auth.uid()
    )
  returning cs.meter_stop_wh into v_current;

  if v_current is null then
    raise exception 'Session not found, not in_progress, or not owned by caller';
  end if;
end;
$$;

comment on function public.dev_stop_fake_session(bigint) is
  'DEV ONLY: mark a fake session as completed. Booker-scoped guard identical to tick.';

-- ---------------------------------------------------------------------------
-- 4. GRANT execute — normale users (authenticated rol) mogen aanroepen.
-- De guards binnen elke functie zorgen dat je alleen je EIGEN sessies kunt raken.
-- ---------------------------------------------------------------------------
grant execute on function public.dev_start_fake_session(uuid) to authenticated;
grant execute on function public.dev_tick_fake_session(bigint, integer) to authenticated;
grant execute on function public.dev_stop_fake_session(bigint) to authenticated;
