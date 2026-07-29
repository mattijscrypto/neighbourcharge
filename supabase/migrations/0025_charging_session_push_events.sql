-- ============================================================================
-- 0025_charging_session_push_events.sql — Pluggo: push meldingen bij OCPP-events
--
-- Task #288: Push notifications OCPP sessie-events (start, target, ETA-10min, stop).
--
-- WAAROM SERVER-SIDE (trigger) I.P.V. IN DE APP?
--   Push notificaties verliezen 90% van hun waarde als de app open moet zijn
--   om ze te versturen. De echte use case is: "user parkeert, drukt op start,
--   loopt weg, sluit de app of legt de telefoon in zak. Vier momenten later
--   trilt de telefoon met een update." Dat kan alleen als de trigger in de
--   database staat: elke UPDATE op charging_sessions — of die nu van OCPP
--   MeterValues komt, van dev_tick, of van RemoteStopTransaction — passeert
--   dan langs deze logica.
--
-- WELKE 4 EVENTS?
--   1. START           — bij INSERT met status='in_progress' (of transitie).
--                        Body noemt de charger-naam zodat de user weet welke.
--   2. TARGET REACHED  — SoC >= bookings.target_soc_pct.
--                        Alleen mogelijk als start_soc_pct én vehicle_capacity
--                        bekend zijn (anders kunnen we geen SoC berekenen).
--   3. ETA 10 MIN      — geschatte tijd tot target ≤ 10 min. Voor de user om
--                        terug te lopen naar zijn/haar auto (met name als de
--                        paal bij iemand anders op de oprit staat).
--   4. STOP            — status transitie naar 'completed'.
--
-- WAAROM BEFORE-TRIGGER MET NEW-MUTATIE VOOR IDEMPOTENTIE?
--   Elke event heeft een `notified_*_at` timestamp-kolom. In een BEFORE-trigger
--   kunnen we die op de te-schrijven NEW-row zetten in dezelfde INSERT/UPDATE,
--   zonder recursie of losse audit-tabel. Bij elke evaluatie eerst checken of
--   de kolom NULL is — pas dan pushen én stempelen.
--
-- WAAROM PG_NET.HTTP_POST NAAR send-push EDGE FUNCTION?
--   Zelfde patroon als 0020 (welkomstmail). pg_net is async, dus de UPDATE
--   blijft snel. Als de edge function 500t, blijft de sessie draaien — een
--   gemiste push is geen showstopper.
--
-- IDEMPOTENT: gebruikt IF NOT EXISTS / DROP IF EXISTS overal.
-- ============================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Notified-timestamps op charging_sessions
--
-- Alle 4 nullable. Non-null = "we hebben deze push al gestuurd, niet nog eens".
-- ---------------------------------------------------------------------------
alter table public.charging_sessions
  add column if not exists notified_started_at   timestamptz;
alter table public.charging_sessions
  add column if not exists notified_target_at    timestamptz;
alter table public.charging_sessions
  add column if not exists notified_eta10_at     timestamptz;
alter table public.charging_sessions
  add column if not exists notified_completed_at timestamptz;

comment on column public.charging_sessions.notified_started_at is
  'Timestamp toen we de "sessie gestart" push verzonden. NULL = nog niet gepusht. Voorkomt duplicates bij opnieuw draaien van de trigger.';
comment on column public.charging_sessions.notified_target_at is
  'Timestamp toen we de "auto is op target %" push verzonden. NULL = nog niet gepusht (of onmogelijk te berekenen wegens missende voertuig-data).';
comment on column public.charging_sessions.notified_eta10_at is
  'Timestamp toen we de "nog ~10 min tot target" push verzonden. NULL = nog niet gepusht.';
comment on column public.charging_sessions.notified_completed_at is
  'Timestamp toen we de "sessie afgelopen" push verzonden. NULL = nog niet gepusht.';

-- ---------------------------------------------------------------------------
-- 2. Helper: _cs_current_soc_pct
--
-- Rekent uit hoever de auto momenteel geladen is als percentage.
-- Formule: start_soc + (charged_kwh / capacity_kwh) * 100
--
-- Returns NULL als een van deze ontbreekt (data-hygiëne):
--   - bookings.start_soc_pct
--   - profiles.vehicle_battery_capacity_kwh
--   - een geldige meter_current_wh (>= meter_start_wh)
--
-- Gecapt op 100% zodat een lekkere over-schatting (bv. capacity onderschat)
-- geen 105% oplevert.
-- ---------------------------------------------------------------------------
create or replace function public._cs_current_soc_pct(
  p_booking_id       uuid,
  p_meter_start_wh   bigint,
  p_meter_current_wh bigint
) returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when p_booking_id is null then null
    when p_meter_current_wh is null then null
    when p_meter_current_wh < p_meter_start_wh then null
    else (
      select case
        when b.start_soc_pct is null then null
        when p.vehicle_battery_capacity_kwh is null or p.vehicle_battery_capacity_kwh <= 0 then null
        else least(
          100::numeric,
          b.start_soc_pct::numeric +
            ((p_meter_current_wh - p_meter_start_wh)::numeric / 1000.0)
              / p.vehicle_battery_capacity_kwh * 100.0
        )
      end
      from public.bookings b
      join public.profiles p on p.id = b.user_id
      where b.id = p_booking_id
    )
  end;
$$;

comment on function public._cs_current_soc_pct(uuid, bigint, bigint) is
  'Berekent huidige SoC-percentage van een lopende sessie op basis van start_soc_pct, vehicle_battery_capacity_kwh en de geladen Wh. Return NULL als data ontbreekt.';

-- ---------------------------------------------------------------------------
-- 3. Helper: _cs_eta_minutes
--
-- Rekent uit hoeveel minuten er nog nodig zijn om target_soc_pct te bereiken.
--
-- Gebruikt SESSIE-GEMIDDELDE laadvermogen (charged_kwh / elapsed_hours) i.p.v.
-- een rolling window uit de meter values tabel. Voor push-thresholding is
-- gemiddelde ruim voldoende: we hoeven geen 30-sec-nauwkeurige ETA. Voor een
-- exacte ETA moet je in de client kijken (zie live_charging_widget.dart).
--
-- Returns NULL als:
--   - Geen booking / geen vehicle capacity
--   - Elapsed < 60s (te weinig data om zinnig te schatten)
--   - avg_kw ≤ 0 (paal levert nog geen stroom, of net gepauzeerd)
--   - Al voorbij target (dan is dit niet relevant, target-event fires apart)
-- ---------------------------------------------------------------------------
create or replace function public._cs_eta_minutes(
  p_booking_id       uuid,
  p_meter_start_wh   bigint,
  p_meter_current_wh bigint,
  p_started_at       timestamptz,
  p_last_meter_at    timestamptz
) returns numeric
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_start_soc   smallint;
  v_target_soc  smallint;
  v_capacity    numeric;
  v_current_soc numeric;
  v_elapsed_sec numeric;
  v_charged_kwh numeric;
  v_avg_kw      numeric;
  v_remaining_kwh numeric;
begin
  if p_booking_id is null or p_meter_current_wh is null then
    return null;
  end if;
  if p_meter_current_wh < p_meter_start_wh then
    return null;
  end if;

  select b.start_soc_pct, b.target_soc_pct, p.vehicle_battery_capacity_kwh
    into v_start_soc, v_target_soc, v_capacity
  from public.bookings b
  join public.profiles p on p.id = b.user_id
  where b.id = p_booking_id;

  if v_start_soc is null or v_target_soc is null then
    return null;
  end if;
  if v_capacity is null or v_capacity <= 0 then
    return null;
  end if;

  -- Elapsed in seconden. Val terug op now() als last_meter_at nog niet gezet is.
  v_elapsed_sec := extract(epoch from (coalesce(p_last_meter_at, now()) - p_started_at));
  if v_elapsed_sec < 60 then
    return null;
  end if;

  v_charged_kwh := (p_meter_current_wh - p_meter_start_wh)::numeric / 1000.0;
  v_avg_kw      := v_charged_kwh / (v_elapsed_sec / 3600.0);
  if v_avg_kw is null or v_avg_kw <= 0 then
    return null;
  end if;

  v_current_soc := least(
    100::numeric,
    v_start_soc::numeric + (v_charged_kwh / v_capacity * 100.0)
  );

  -- Als we al voorbij target zitten: geen ETA meer nodig.
  if v_current_soc >= v_target_soc then
    return null;
  end if;

  v_remaining_kwh := ((v_target_soc - v_current_soc) / 100.0) * v_capacity;
  return (v_remaining_kwh / v_avg_kw) * 60.0;
end;
$$;

comment on function public._cs_eta_minutes(uuid, bigint, bigint, timestamptz, timestamptz) is
  'Schat resterende minuten tot target_soc_pct op basis van sessie-gemiddeld laadvermogen. Return NULL als schatting niet mogelijk (data ontbreekt of paal levert (nog) niets).';

-- ---------------------------------------------------------------------------
-- 4. Helper: _cs_fire_push
--
-- Wrapper rond pg_net.http_post naar de send-push edge function. Leest vault
-- secrets en doet een fire-and-forget call. Return VOID — we willen NIET dat
-- een falende push een trigger doet crashen (en daarmee een MeterValues-tick
-- doet rollbacken).
-- ---------------------------------------------------------------------------
create or replace function public._cs_fire_push(
  p_user_id    uuid,
  p_title      text,
  p_body       text,
  p_event_type text,
  p_tx_id      bigint,
  p_booking_id uuid
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
    return;  -- geen ontvanger, silent skip
  end if;

  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'supabase_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'service_role_key';

  if v_url is null or v_key is null then
    raise notice '_cs_fire_push: vault secrets ontbreken, push overgeslagen (event %, tx %)', p_event_type, p_tx_id;
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
      'data',    jsonb_build_object(
        'type',           p_event_type,
        'transaction_id', p_tx_id::text,
        'booking_id',     coalesce(p_booking_id::text, '')
      )
    )
  );
end;
$$;

comment on function public._cs_fire_push(uuid, text, text, text, bigint, uuid) is
  'Fire-and-forget push notification via send-push edge function. Slikt fouten stilletjes — een gemiste push mag nooit een charging_sessions-write blokkeren.';

-- ---------------------------------------------------------------------------
-- 5. Trigger-functie: on_charging_session_push_events
--
-- BEFORE INSERT OR UPDATE — zodat we notified_*_at op NEW kunnen zetten in
-- dezelfde write. Geen recursie mogelijk (BEFORE trigger + zelfde row).
--
-- Volgorde van evaluatie:
--   a) START      — bij INSERT met status='in_progress', of UPDATE waar status
--                   naar 'in_progress' flipt en notified_started_at nog NULL.
--   b) TARGET     — als SoC >= target en target nog niet gepusht.
--   c) ETA10      — als eta_minutes <= 10 en SoC < target en niet gepusht.
--                   (Als we al voorbij target zijn hoeft dit ook niet meer.)
--   d) COMPLETED  — bij transitie naar status='completed' en niet gepusht.
--
-- Templates in NL, zonder apostrofes (SQL-vriendelijk in $$..$$ blokken).
-- ---------------------------------------------------------------------------
create or replace function public.on_charging_session_push_events()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booker_id    uuid;
  v_target_soc   smallint;
  v_charger_name text;
  v_current_soc  numeric;
  v_eta_min      numeric;
  v_title        text;
  v_body         text;
  v_charger_lbl  text;
begin
  -- Snel eruit als er geen booking-koppeling is: dan kunnen we niks pushen.
  if new.booking_id is null then
    return new;
  end if;

  -- Booker + target uit boeking, charger-naam voor tekstvriendelijkheid.
  select b.user_id, b.target_soc_pct
    into v_booker_id, v_target_soc
  from public.bookings b
  where b.id = new.booking_id;

  if v_booker_id is null then
    return new;
  end if;

  if new.charger_id is not null then
    select c.name into v_charger_name
      from public.chargers c where c.id = new.charger_id;
  end if;
  v_charger_lbl := coalesce(v_charger_name, 'de laadpaal');

  -- ---------------------------------------------------------------------
  -- a) START-push
  -- ---------------------------------------------------------------------
  if new.notified_started_at is null and new.status = 'in_progress' then
    -- Firing op INSERT (nieuwe sessie) of transitie in UPDATE naar in_progress.
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and coalesce(old.status, '') <> 'in_progress') then
      v_title := 'Laadsessie gestart';
      v_body  := 'Je auto laadt nu op bij ' || v_charger_lbl ||
                 '. We geven je een seintje als hij bijna vol is.';
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_started', new.transaction_id, new.booking_id
      );
      new.notified_started_at := now();
    end if;
  end if;

  -- Voor target en eta10 hebben we een geldige meter-stand nodig.
  if new.meter_current_wh is not null and new.meter_current_wh >= new.meter_start_wh then
    v_current_soc := public._cs_current_soc_pct(
      new.booking_id, new.meter_start_wh, new.meter_current_wh
    );

    -- -------------------------------------------------------------------
    -- b) TARGET-REACHED-push
    -- -------------------------------------------------------------------
    if new.notified_target_at is null
       and v_current_soc is not null
       and v_target_soc is not null
       and v_current_soc >= v_target_soc then
      v_title := 'Auto is op ' || v_target_soc || '%';
      v_body  := 'Je target-SoC is bereikt. Je kunt de kabel eruit halen wanneer je wilt.';
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_target_reached', new.transaction_id, new.booking_id
      );
      new.notified_target_at := now();
    end if;

    -- -------------------------------------------------------------------
    -- c) ETA-10-MIN-push
    --
    -- Alleen zinvol als we nog NIET voorbij target zijn (dan is target
    -- al de push die je krijgt). Threshold: <= 10 minuten resterend.
    -- -------------------------------------------------------------------
    if new.notified_eta10_at is null
       and (v_current_soc is null or v_target_soc is null or v_current_soc < v_target_soc) then
      v_eta_min := public._cs_eta_minutes(
        new.booking_id,
        new.meter_start_wh,
        new.meter_current_wh,
        new.started_at,
        new.last_meter_at
      );
      if v_eta_min is not null and v_eta_min <= 10 and v_eta_min > 0 then
        v_title := 'Bijna klaar met laden';
        v_body  := 'Nog ongeveer ' || round(v_eta_min)::text ||
                   ' min tot ' || v_target_soc || '%. ' ||
                   'Tijd om terug te lopen naar je auto.';
        perform public._cs_fire_push(
          v_booker_id, v_title, v_body,
          'charging_eta_10min', new.transaction_id, new.booking_id
        );
        new.notified_eta10_at := now();
      end if;
    end if;
  end if;

  -- ---------------------------------------------------------------------
  -- d) COMPLETED-push
  -- ---------------------------------------------------------------------
  if new.notified_completed_at is null and new.status = 'completed' then
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and coalesce(old.status, '') <> 'completed') then
      v_title := 'Laadsessie afgelopen';
      v_body  := 'Je sessie bij ' || v_charger_lbl ||
                 ' is beeindigd. Open de app voor je verbruik en betaling.';
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_completed', new.transaction_id, new.booking_id
      );
      new.notified_completed_at := now();
    end if;
  end if;

  return new;
exception when others then
  -- Verzekeringsclausule: mocht wat dan ook fout gaan (vault-secret weg,
  -- pg_net down, jsonb-fout), laat de trigger NOOIT een MeterValues-tick
  -- rollbacken. Log en laat de write door.
  raise notice 'on_charging_session_push_events: fout onderdrukt (%): %', tg_op, sqlerrm;
  return new;
end;
$$;

comment on function public.on_charging_session_push_events() is
  'BEFORE INSERT OR UPDATE trigger op charging_sessions. Vuurt push notifications voor start / target / eta10 / completed events, idempotent via notified_*_at kolommen. Fail-safe: exception-handler voorkomt dat een gefaalde push een write rollbackt.';

-- ---------------------------------------------------------------------------
-- 6. Trigger aanhaken
-- ---------------------------------------------------------------------------
drop trigger if exists charging_session_push_events on public.charging_sessions;
create trigger charging_session_push_events
  before insert or update on public.charging_sessions
  for each row
  execute function public.on_charging_session_push_events();

-- ---------------------------------------------------------------------------
-- 7. Handmatig testen
--
--   -- Start een dev fake sessie via de app of via SQL:
--   select public.dev_start_fake_session('<booking-uuid>');
--   -- → verwacht direct een 'Laadsessie gestart' push
--
--   -- Tick tot voorbij target (bv. 80%). Voor een 77 kWh accu die op 20%
--   -- staat: (80-20)% * 770 Wh = 46200 Wh nodig. Doe 20 ticks van 2400 Wh:
--   select public.dev_tick_fake_session(<tx>, 2400);
--   -- → verwacht bij overschrijding: 'Auto is op 80%' push
--
--   -- Stop:
--   select public.dev_stop_fake_session(<tx>);
--   -- → verwacht 'Laadsessie afgelopen' push
--
--   -- Debug: kijk in net._http_response
--   select * from net._http_response order by created desc limit 10;
-- ---------------------------------------------------------------------------
