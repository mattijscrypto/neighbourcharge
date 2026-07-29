-- ---------------------------------------------------------------------------
-- 0039_chargers_online_status.sql
--
-- Task #356 (deel 1): kolommen voor de CSMS-bridge om per-paal online-status
-- bij te houden. De bridge zelf (die deze velden op OCPP BootNotification,
-- Heartbeat, StatusNotification en connection-close events bijwerkt) komt in
-- een aparte deploy — maar de kolommen zijn nu al nodig omdat het host-
-- dashboard erop leunt (statustegel + start-CTA-guard).
--
-- Defaults:
--   • is_online     = true  → bestaande palen renderen niet automatisch als
--                              "offline" voordat de bridge live is.
--   • last_seen_at  = NULL  → onbekend tot de bridge de eerste heartbeat
--                              binnenkrijgt.
--
-- Als de bridge later live gaat, zet deze twee velden dan bij:
--   • BootNotification / Heartbeat / MeterValues  → is_online=true, last_seen_at=now()
--   • Connection close / keepalive-timeout        → is_online=false
-- ---------------------------------------------------------------------------

alter table public.chargers
  add column if not exists is_online boolean not null default true;

alter table public.chargers
  add column if not exists last_seen_at timestamptz;

comment on column public.chargers.is_online is
  'true = paal heeft recent (< keepalive-interval) een OCPP-heartbeat gestuurd. '
  'false = CSMS-verbinding is verbroken of paal reageert niet meer. '
  'Beheerd door de CSMS-bridge (task #356). Default true bij aanmaak zodat '
  'nieuwe palen niet automatisch als offline verschijnen.';

comment on column public.chargers.last_seen_at is
  'Timestamp van laatste OCPP-event van deze paal. NULL = nog nooit gezien. '
  'Wordt gebruikt om stale is_online-status te detecteren als de bridge crasht.';

-- Partial index: host-dashboard filtert typisch op eigen palen (owner_id) en
-- toont daarbij online-status. Dit voorkomt sequential scan zodra we >1000
-- palen hebben.
create index if not exists chargers_owner_online_idx
  on public.chargers(owner_id, is_online);
