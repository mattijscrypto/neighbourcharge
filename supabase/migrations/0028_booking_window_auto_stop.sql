-- ============================================================================
-- 0028_booking_window_auto_stop.sql
--
-- Task #291: Auto-stop bij einde boekingsvenster + 15-min-warning push.
--
-- WAAROM?
--   Als paal A om 14:00 - 15:00 geboekt is door Booker 1, en om 15:00 - 16:00
--   door Booker 2, dan is het "netjes" (user's woorden) om:
--     • 14:45 — push naar Booker 1: "je reservering loopt zo af"
--     • 15:00 — als Booker 1 nog laadt: paal automatisch stoppen zodat Booker 2
--                  om 15:00 kan starten. Booker 1 krijgt daarna via de bestaande
--                  0025-completed-push automatisch de melding dat de sessie is
--                  afgelopen.
--     • Als Booker 1 al zelf gestopt is voor 15:00: geen enkele push, laat 'm.
--
-- HOE?
--   1. Extra idempotentie-kolommen op bookings:
--        notified_ending_soon_at  → nooit dubbele 15-min-warning
--        auto_stop_attempted_at   → nooit dubbele auto-stop
--
--   2. pg_cron elke minuut → process_booking_window_events() SECURITY DEFINER.
--        Loopt in twee stappen:
--          a) 15-min-warning voor confirmed bookings met een actieve sessie
--             die 13-15 min voor einde zitten
--          b) Auto-stop voor confirmed bookings met een actieve sessie waarvan
--             end_time zojuist is verstreken (tot 5 min terug om gemiste cron
--             executions te vangen).
--
--   3. Auto-stop-actie is afhankelijk van type sessie:
--        • Fake dev-sessie (ocpp_charger_id = 'DEV-FAKE' / prefix) → direct
--          `status = completed` op charging_sessions zetten. De bestaande
--          0025-trigger vuurt dan de completed-push.
--        • Echte OCPP-sessie → pg_net POST naar CSMS
--          `/chargers/:ocpp_id/remote-stop` met X-CSMS-API-Key header. De paal
--          antwoordt met StopTransaction, de CSMS-bridge zet zelf status en
--          meter_stop_wh, en dan vuurt de 0025-trigger de completed-push.
--
-- WAAROM NIET DE remote-stop-session EDGE FUNCTION?
--   Die vereist een user-JWT en verifieert booker/owner. Cron heeft geen user.
--   Direct pg_net → CSMS met CSMS_API_KEY is het simpelste pad; het is precies
--   wat remote-stop-session onder de motorkap ook doet (regel 255 van die fn).
--
-- VAULT-VEREISTEN (eenmalig, in SQL Editor):
--   select vault.create_secret('https://csms.pluggoapp.nl', 'csms_http_base');
--   select vault.create_secret('<CSMS_API_KEY>',            'csms_api_key');
--
--   Als deze secrets NIET bestaan, slaat de auto-stop voor echte OCPP-sessies
--   stilletjes over (met raise notice). Dev-fake sessies stoppen sowieso.
--   De 15-min-warning-push heeft deze secrets niet nodig (gebruikt supabase_url
--   + service_role_key uit 0025).
--
-- IDEMPOTENT: create or replace + IF NOT EXISTS overal.
-- ============================================================================

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Idempotentie-kolommen op bookings
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists notified_ending_soon_at timestamptz;

alter table public.bookings
  add column if not exists auto_stop_attempted_at timestamptz;

comment on column public.bookings.notified_ending_soon_at is
  'Timestamp toen we de "reservering loopt zo af" (15 min voor end_time) push verzonden. NULL = nog niet gepusht. Voorkomt duplicates bij minuutlijkse cron.';
comment on column public.bookings.auto_stop_attempted_at is
  'Timestamp toen we een auto-stop aan het einde van het boekingsvenster hebben geinitieerd (via CSMS RemoteStop of directe fake-sessie completion). NULL = nog niet geprobeerd. Voorkomt herhaaldelijke stopcommands vanuit cron.';

-- Index om de cron-query goedkoop te houden: alleen bookings waarvan een
-- van beide markers nog leeg is EN die confirmed zijn, zijn interessant.
create index if not exists bookings_window_events_idx
  on public.bookings(end_time)
  where status = 'confirmed'
    and (notified_ending_soon_at is null or auto_stop_attempted_at is null);

-- ---------------------------------------------------------------------------
-- 2. Helper: _bw_csms_remote_stop
--
-- Async POST naar de CSMS remote-stop endpoint via pg_net. Leest CSMS-secrets
-- uit de vault. Faalt stilletjes als secrets missen (dev/staging).
-- ---------------------------------------------------------------------------
create or replace function public._bw_csms_remote_stop(
  p_ocpp_charger_id text,
  p_transaction_id  bigint
) returns void
language plpgsql
security definer
set search_path = extensions, public, vault, pg_temp
as $$
declare
  v_base text;
  v_key  text;
begin
  if p_ocpp_charger_id is null or p_transaction_id is null then
    return;
  end if;

  select decrypted_secret into v_base
    from vault.decrypted_secrets where name = 'csms_http_base';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'csms_api_key';

  if v_base is null or v_key is null then
    raise notice '_bw_csms_remote_stop: csms_http_base of csms_api_key ontbreekt in vault, remote-stop overgeslagen (tx %)', p_transaction_id;
    return;
  end if;

  -- Verwijder trailing slash en bouw de URL — zelfde structuur als
  -- remote-stop-session edge function.
  perform net.http_post(
    url     := regexp_replace(v_base, '/+$', '') ||
               '/chargers/' || p_ocpp_charger_id || '/remote-stop',
    headers := jsonb_build_object(
      'Content-Type',    'application/json',
      'X-CSMS-API-Key',  v_key
    ),
    body    := jsonb_build_object('transactionId', p_transaction_id)
  );
end;
$$;

comment on function public._bw_csms_remote_stop(text, bigint) is
  'Fire-and-forget RemoteStopTransaction via CSMS HTTP API. Gebruikt csms_http_base + csms_api_key uit vault. Slikt fouten stilletjes zodat cron niet crasht op een tijdelijk niet-bereikbare CSMS.';

-- ---------------------------------------------------------------------------
-- 3. Helper: _bw_complete_fake_session
--
-- Voor dev-fake sessies (ocpp_charger_id begint met 'DEV-FAKE'): direct de
-- charging_sessions-rij op status='completed' zetten. De 0025-trigger vuurt
-- dan automatisch de completed-push naar de booker.
-- ---------------------------------------------------------------------------
create or replace function public._bw_complete_fake_session(
  p_transaction_id bigint
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.charging_sessions cs
  set status       = 'completed',
      meter_stop_wh = coalesce(cs.meter_current_wh, cs.meter_start_wh),
      stopped_at    = now(),
      stop_reason   = 'auto_end_of_window'
  where cs.transaction_id = p_transaction_id
    and cs.status = 'in_progress';
end;
$$;

comment on function public._bw_complete_fake_session(bigint) is
  'Sluit een dev-fake sessie direct op DB-niveau af (status=completed + meter_stop_wh + stop_reason). Triggert automatisch de 0025 completed-push. Gebruikt door cron voor sessies waarvan ocpp_charger_id een DEV-FAKE prefix heeft.';

-- ---------------------------------------------------------------------------
-- 4. Hoofdfunctie: process_booking_window_events
--
-- Draait elke minuut via pg_cron. Twee onafhankelijke stappen:
--
--   Stap A: 15-min-warning
--     Voor confirmed bookings met een actieve charging_session, waarvan end_time
--     over 13-15 minuten valt (2-min-window om gemiste cron-ticks te vangen)
--     en notified_ending_soon_at nog NULL is: push sturen + stempel zetten.
--
--   Stap B: Auto-stop
--     Voor confirmed bookings met een actieve charging_session waarvan end_time
--     <= now() (en niet meer dan 5 min terug), en auto_stop_attempted_at nog
--     NULL: stopcommand versturen + stempel zetten.
--     Voor dev-fake: direct DB-completion (fires 0025-push).
--     Voor echt OCPP: pg_net → CSMS RemoteStop (CSMS updated DB, 0025-push volgt).
--
-- SECURITY DEFINER zodat cron (=postgres role) door RLS heen kan.
-- Exception-handler om te voorkomen dat één rotte booking de hele cron-tick
-- laat crashen.
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
  -- Stap A: 15-min-warning
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
  -- Stap B: Auto-stop bij einde venster
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
      -- Eerst stempelen, DAN pas actie. Zo krijgen we bij een crash van
      -- pg_net geen dubbele stop-attempt bij de volgende cron-tick.
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
  'Cron entry-point voor task #291. Verstuurt 15-min-warning push en initieert auto-stop bij einde boekingsvenster. Idempotent via notified_ending_soon_at + auto_stop_attempted_at kolommen op bookings.';

-- ---------------------------------------------------------------------------
-- 5. Cron-job: elke minuut
--
-- Idempotent — bestaande job met dezelfde naam eerst weghalen.
-- ---------------------------------------------------------------------------
do $$
declare
  jid bigint;
begin
  select jobid into jid from cron.job where jobname = 'process-booking-window-events';
  if jid is not null then
    perform cron.unschedule(jid);
  end if;
end $$;

select cron.schedule(
  'process-booking-window-events',
  '* * * * *',  -- elke minuut
  $$ select public.process_booking_window_events(); $$
);

-- ---------------------------------------------------------------------------
-- 6. Grants — cron draait als 'postgres', geen extra grants nodig voor de
-- helpers. Voor eventuele handmatige tests vanuit authenticated: NIET grant
-- geven, deze functies zijn dev/service-side only.
-- ---------------------------------------------------------------------------

-- Klaar. Test handmatig met:
--   select public.process_booking_window_events();
--
-- Debug: bekijk cron-job details en run-history:
--   select * from cron.job where jobname = 'process-booking-window-events';
--   select * from cron.job_run_details
--     where jobid = (select jobid from cron.job where jobname = 'process-booking-window-events')
--     order by start_time desc limit 20;
