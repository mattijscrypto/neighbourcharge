-- ============================================================================
-- 0021_ocpp_charging_sessions.sql — Pluggo CSMS: OCPP-laadsessies opslag
--
-- Deze migratie voegt twee tabellen toe waarin Pluggo's eigen CSMS
-- (Central System Management System) OCPP-laadsessies vastlegt:
--
--   1. charging_sessions            — één rij per OCPP-transactie
--   2. charging_session_meter_values — append-only log van MeterValues-ticks
--
-- Ook wordt de chargers-tabel uitgebreid met een ocpp_charger_id (text) om
-- fysieke palen aan Pluggo-charger-uuids te kunnen mappen.
--
-- Realtime wordt aangezet op charging_sessions zodat de Flutter-app live
-- kWh-updates ontvangt tijdens een lopende sessie.
--
-- RLS: service_role heeft volle toegang (CSMS-server schrijft), en er is
-- read-toegang voor de paal-eigenaar en de aan de sessie gekoppelde booker.
--
-- Idempotent: gebruikt IF NOT EXISTS / DROP POLICY IF EXISTS overal.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. chargers uitbreiden met OCPP-identifier
--
-- ocpp_charger_id is de string waarmee de fysieke paal zich meldt op de CSMS
-- WebSocket-URL (bijv. 'ALFEN-ALF12345' of 'CP-001'). Meestal identiek aan
-- het serienummer van de paal. Unique zodat we deze rechtstreeks kunnen
-- opzoeken vanuit inkomende OCPP-berichten.
-- ---------------------------------------------------------------------------
alter table public.chargers
  add column if not exists ocpp_charger_id text unique;

comment on column public.chargers.ocpp_charger_id is
  'OCPP identity die de paal gebruikt om zich te melden bij de CSMS. Doorgaans het serienummer. Nullable voor palen zonder OCPP-integratie.';

-- ---------------------------------------------------------------------------
-- 2. charging_sessions — één rij per OCPP-transactie
--
-- transaction_id is een bigint identity — DE CSMS wijst deze toe in de
-- StartTransaction response. Zo is 'ie persistent over server-restarts heen,
-- geen risico op collisies bij crash-recovery.
--
-- meter_start_wh / meter_stop_wh in Wh (OCPP-native), niet kWh, om afronding
-- te vermijden. Frontend converteert bij weergave.
-- ---------------------------------------------------------------------------
create table if not exists public.charging_sessions (
  transaction_id       bigint generated always as identity primary key,

  -- OCPP-identifiers (raw, wat de paal stuurt)
  ocpp_charger_id      text not null,
  connector_id         integer not null default 1,
  id_tag               text,

  -- Koppeling naar Pluggo-model (kan later ingevuld worden)
  charger_id           uuid references public.chargers(id) on delete set null,
  booking_id           uuid references public.bookings(id) on delete set null,

  -- Meterstanden
  meter_start_wh       bigint not null,
  meter_current_wh    bigint,
  meter_stop_wh        bigint,

  -- Status
  status               text not null default 'in_progress'
    check (status in ('in_progress', 'completed', 'orphaned', 'errored')),
  stop_reason          text,

  -- Timestamps
  started_at           timestamptz not null default now(),
  last_meter_at        timestamptz,
  stopped_at           timestamptz,
  created_at           timestamptz not null default now(),

  -- Raw payloads voor debugging / auditing
  boot_payload         jsonb,
  stop_payload         jsonb
);

create index if not exists charging_sessions_ocpp_charger_idx
  on public.charging_sessions(ocpp_charger_id);
create index if not exists charging_sessions_charger_idx
  on public.charging_sessions(charger_id);
create index if not exists charging_sessions_booking_idx
  on public.charging_sessions(booking_id);
create index if not exists charging_sessions_status_idx
  on public.charging_sessions(status)
  where status = 'in_progress';   -- partial index: alleen actieve sessies

comment on table public.charging_sessions is
  'Één rij per OCPP-transactie tussen Pluggo CSMS en een fysieke laadpaal. transaction_id is server-assigned bigint identity die 1-op-1 mapt naar OCPP transactionId in StartTransaction/StopTransaction messages.';

-- ---------------------------------------------------------------------------
-- 3. charging_session_meter_values — append-only log
--
-- Elke MeterValues-message van de paal wordt hier bijgeschreven. Unique key
-- op (transaction_id, measured_at) zorgt voor idempotentie: als de paal na
-- offline-periode een backlog dumpt kunnen dubbele records veilig genegeerd
-- worden via ON CONFLICT DO NOTHING.
-- ---------------------------------------------------------------------------
create table if not exists public.charging_session_meter_values (
  id                bigint generated always as identity primary key,
  transaction_id    bigint not null references public.charging_sessions(transaction_id) on delete cascade,
  meter_wh          bigint not null,
  measured_at       timestamptz not null,
  received_at       timestamptz not null default now(),
  raw_payload       jsonb,
  unique (transaction_id, measured_at)
);

create index if not exists meter_values_transaction_idx
  on public.charging_session_meter_values(transaction_id, measured_at);

comment on table public.charging_session_meter_values is
  'Append-only log van alle OCPP MeterValues per transactie. Idempotent via unique (transaction_id, measured_at); veilig herhaalbaar als paal na offline periode een backlog dumpt.';

-- ---------------------------------------------------------------------------
-- 4. Row-Level Security
--
-- - service_role heeft altijd volle toegang (bypass RLS via server-side key)
-- - Paal-eigenaar mag zijn eigen sessies + meter values lezen
-- - Booker mag de aan zijn/haar booking gekoppelde sessie lezen
-- - Niemand kan schrijven vanuit de client (alleen server-side via service key)
-- ---------------------------------------------------------------------------
alter table public.charging_sessions              enable row level security;
alter table public.charging_session_meter_values  enable row level security;

drop policy if exists charging_sessions_owner_read on public.charging_sessions;
create policy charging_sessions_owner_read on public.charging_sessions
  for select to authenticated
  using (
    charger_id is not null and exists (
      select 1 from public.chargers c
      where c.id = charging_sessions.charger_id
        and c.owner_id = auth.uid()
    )
  );

drop policy if exists charging_sessions_booker_read on public.charging_sessions;
create policy charging_sessions_booker_read on public.charging_sessions
  for select to authenticated
  using (
    booking_id is not null and exists (
      select 1 from public.bookings b
      where b.id = charging_sessions.booking_id
        and b.user_id = auth.uid()
    )
  );

drop policy if exists meter_values_via_session_read on public.charging_session_meter_values;
create policy meter_values_via_session_read on public.charging_session_meter_values
  for select to authenticated
  using (
    exists (
      select 1 from public.charging_sessions s
      where s.transaction_id = charging_session_meter_values.transaction_id
        and (
          -- paal-eigenaar
          (s.charger_id is not null and exists (
            select 1 from public.chargers c
            where c.id = s.charger_id and c.owner_id = auth.uid()
          ))
          -- booker
          or (s.booking_id is not null and exists (
            select 1 from public.bookings b
            where b.id = s.booking_id and b.user_id = auth.uid()
          ))
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Realtime — live kWh updates naar de Flutter-app
--
-- Elke UPDATE op charging_sessions (bijvoorbeeld meter_current_wh die per
-- MeterValues-tick opgehoogd wordt) wordt via Supabase Realtime uitgezonden
-- naar clients die op deze row gesubscribed zijn.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'charging_sessions'
  ) then
    alter publication supabase_realtime add table public.charging_sessions;
  end if;
end $$;
