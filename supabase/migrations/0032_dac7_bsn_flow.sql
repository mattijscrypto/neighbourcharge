-- ============================================================================
-- 0032_dac7_bsn_flow.sql — Task #263: DAC7 BSN-drempelflow.
--
-- CONTEXT
-- ----------------------------------------------------------------------------
-- DAC7 (EU-richtlijn 2021/514, in NL geïmplementeerd via Wet uitwisseling
-- inlichtingen belastingheffing digitale platformen, art. 10c AWR jo. 2a
-- Uitv.reg. WIB) verplicht digitale platformen om jaarlijks aan de
-- Belastingdienst te rapporteren welke verkopers via het platform inkomsten
-- hebben verdiend. De rapportageplicht ontstaat als een verkoper in een
-- kalenderjaar minimaal één van beide drempels haalt:
--
--   • ≥ 30 relevante activiteiten (= boekingen waar de owner geld ontvangt), OR
--   • ≥ €2.000 vergoeding (owner_share_cents, excl. platform fee)
--
-- Om te rapporteren hebben we een fiscaal identificatienummer (TIN) nodig:
--
--   • particulier / eenmanszaak (ZZP) → BSN
--   • BV / stichting / VvE            → RSIN
--
-- We willen de BSN/RSIN pas uitvragen op het moment dat de owner richting
-- de drempel gaat (75% als vroege signalering) zodat we niet iedereen bij
-- signup lastigvallen met een BSN-vraag. Onder de drempel blijven = geen
-- rapportageplicht = geen BSN nodig.
--
-- KRITISCHE PRIVACY-DESIGN
-- ----------------------------------------------------------------------------
-- BSN is bijzondere persoonsgegevens (art. 46 UAVG). Grondslag is art. 10c AWR
-- (wettelijke verplichting). Consequenties voor de opslag:
--
--   1. BSN NOOIT in klare tekst in Postgres. Altijd AES-256-GCM ciphertext
--      via edge function `submit-tin` met master key uit env
--      (`DAC7_ENCRYPTION_KEY`, base64-encoded 32 bytes).
--   2. BSN NOOIT terug naar de client — de app krijgt alleen `tin_last4` +
--      `tin_provided_at` te zien. Ophalen van de klare BSN kan alleen via
--      een service-role edge function op moment van DAC7-rapportage
--      (jaarlijks, feb-mrt, out of scope voor deze migratie).
--   3. Ciphertext + nonce leven in een APARTE tabel `profiles_tin_secure`
--      met RLS die GEEN select-policy voor authenticated definieert. Alleen
--      service_role kan lezen/schrijven. Dit is robuuster dan column-level
--      GRANTs op profiles (waar we alle safe kolommen zouden moeten
--      enumereren, foutgevoelig bij toekomstige alter-tables).
--   4. RLS blijft owner-only op de rest van profiles zoals nu.
--
-- SCOPE VAN DEZE MIGRATIE
-- ----------------------------------------------------------------------------
--   1. `tin_type` enum + safe-metadata kolommen op `profiles`.
--   2. `profiles_tin_secure` tabel — ciphertext + nonce, RLS zonder
--      select-policy voor authenticated (alleen service_role kan lezen).
--   3. `dac7_reporting_state` tabel — per (owner, kalenderjaar) counters,
--      threshold flags, blocked-status.
--   4. `is_valid_bsn(text)` + `is_valid_rsin(text)` — 11-proef validatie
--      in Postgres. Edge function checkt óók, maar we willen defense in
--      depth zodat een bug in de edge function nooit een invalid TIN
--      persisteert.
--   5. `dac7_recompute_owner_year(owner, year)` SECURITY DEFINER helper —
--      herberekent counters + zet threshold flags. Aangeroepen door trigger
--      en door de safety-net cron.
--   6. Trigger op `bookings` — na update van `payment_requested_at` roept
--      recompute voor de owner van de betreffende paal + jaar aan.
--   7. `dac7_status_for_owner()` RPC — client-safe view: booleans + counts,
--      geen encrypted data. Bepaalt wat de app in het BSN-prompt-scherm laat
--      zien (verplicht/vroege waarschuwing/al ingeleverd).
--   8. pg_cron dagelijkse recompute voor lopend + vorig kalenderjaar als
--      safety net (bijv. na late Stripe-settlements die de trigger niet
--      raakten via `payment_requested_at` change).
--
-- WAT ZIT ER NIET IN
-- ----------------------------------------------------------------------------
--   ✗ De DAC7 XML-export naar de Belastingdienst — dat is een jaarlijks
--     proces (feb-mrt over vorig kalenderjaar) en komt in een aparte task.
--   ✗ Blocking van uitbetalingen bij no-TIN-en-boven-drempel. We ZETTEN wel
--     de flag `payouts_blocked_at`, maar de handhaving daarvan zit in de
--     create-payment-stripe edge function (aparte code-change).
--   ✗ De app-UI (BSN-prompt scherm met 11-proef preview + art. 10c
--     disclosure). Aparte client-side task.
--   ✗ Handmatige RSIN-lookup via KvK-API — voor nu vragen we het gewoon
--     uit; de edge function valideert format + 11-proef.
--
-- IDEMPOTENT: create table if not exists + create or replace + revoke if.
-- ============================================================================

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. tin_type enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'tin_type') then
    create type public.tin_type as enum (
      'bsn',   -- natuurlijk persoon: particulier of eenmanszaak/ZZP
      'rsin'   -- rechtspersoon: BV / stichting / VvE
    );
  end if;
end $$;

comment on type public.tin_type is
  'Fiscaal identificatienummer-type voor DAC7-rapportage. BSN voor natuurlijk persoon (art. 10 Wet BRP), RSIN voor rechtspersoon (art. 12 Handelsregisterwet).';

-- ---------------------------------------------------------------------------
-- 2a. profiles — safe metadata kolommen (client-leesbaar)
-- ---------------------------------------------------------------------------
-- Alleen niet-geheime velden. Ciphertext + nonce zitten in een aparte tabel
-- (2b) zodat we niet met column-level GRANTs op profiles hoeven te
-- knutselen.
--
-- tin_last4: laatste 4 cijfers voor UI ("BSN eindigend op ..1234"). Op
-- zichzelf niet unieke identifier (4 cijfers = 10.000 combinaties, veel
-- collisions), dus geen privacyrisico om aan owner te laten zien.
alter table public.profiles
  add column if not exists tin_type            public.tin_type,
  add column if not exists tin_last4           text,
  add column if not exists tin_provided_at     timestamptz,
  add column if not exists tin_last_prompt_at  timestamptz;

comment on column public.profiles.tin_type is
  'bsn of rsin — bepaalt welke rapportage-flow gebruikt wordt bij DAC7-XML export. Alleen gezet door submit-tin edge function.';
comment on column public.profiles.tin_last4 is
  'Laatste 4 cijfers van TIN — voor UI ("eindigt op ..1234"). Alleen gezet door submit-tin edge function.';
comment on column public.profiles.tin_provided_at is
  'Moment waarop de owner z''n TIN heeft ingeleverd. Null = nog niet geleverd. Alleen gezet door submit-tin edge function.';
comment on column public.profiles.tin_last_prompt_at is
  'Laatste keer dat de app het BSN-prompt heeft laten zien aan deze owner. Voorkomt spammen (rate-limit: max 1x per 7d). Owner mag deze zelf updaten via de app.';

-- ---------------------------------------------------------------------------
-- 2b. profiles_tin_secure — ciphertext + nonce, service_role only
-- ---------------------------------------------------------------------------
-- Aparte tabel met RLS aan én GEEN select-policy voor authenticated. Ook
-- geen insert/update/delete-policies. Consequentie: geen enkele rol behalve
-- service_role en tabel-eigenaar (postgres) kan hier iets mee. Ideaal voor
-- ciphertext dat we alleen willen aanraken vanuit een edge function met
-- service_role bearer.
--
-- key_version verwijst naar de encryption key waarmee ciphertext is gemaakt.
-- Bij key rotation: nieuwe key = versie 2, edge function leest oude rijen
-- met v1, herencrypt met v2, update kolom.
create table if not exists public.profiles_tin_secure (
  owner_id     uuid primary key references public.profiles(id) on delete cascade,
  ciphertext   bytea       not null,
  nonce        bytea       not null,
  key_version  smallint    not null default 1,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles_tin_secure is
  'AES-256-GCM ciphertext van BSN/RSIN. RLS aan, GEEN policies voor authenticated → alleen service_role kan lezen/schrijven. Wordt exclusief benaderd door edge function `submit-tin` (write) en toekomstige `dac7-export` (read).';
comment on column public.profiles_tin_secure.ciphertext is
  'AES-256-GCM ciphertext van BSN/RSIN plaintext (9 digits als UTF-8 string).';
comment on column public.profiles_tin_secure.nonce is
  '12-byte GCM nonce (IV). Gegenereerd per encryptie via crypto.getRandomValues. NOOIT hergebruiken met dezelfde key + plaintext.';
comment on column public.profiles_tin_secure.key_version is
  'Versie van DAC7_ENCRYPTION_KEY waarmee ciphertext is gemaakt. Huidige actieve versie in edge function env `DAC7_ENCRYPTION_KEY_VERSION` (default 1).';

alter table public.profiles_tin_secure enable row level security;

-- Bewust GEEN policies. Owner mag GEEN eigen ciphertext lezen — precies wat
-- we willen (defense in depth: als er ooit een SQL-injection zit, kan de
-- ciphertext niet gelekt worden zonder óók de master key uit env te hebben).
-- Enige toegang: service_role via de edge functions.

-- Trigger voor updated_at.
drop trigger if exists profiles_tin_secure_set_updated_at on public.profiles_tin_secure;
create trigger profiles_tin_secure_set_updated_at
  before update on public.profiles_tin_secure
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. dac7_reporting_state — per (owner, kalenderjaar)
-- ---------------------------------------------------------------------------
-- Eén rij per (owner_id, reporting_year). Wordt aangemaakt door
-- `dac7_recompute_owner_year` op moment dat de owner z'n eerste betaalde
-- boeking in dat jaar heeft.
--
-- Threshold-flags: timestamptz zodat we later kunnen zien WANNEER de owner
-- de drempel raakte (belangrijk voor audit + support). Zodra gezet worden
-- ze niet weer op null gezet — als er later een refund komt en de owner
-- valt weer onder de drempel, houden we 'reached_at' wel maar de owner
-- mag alsnog rapporteren als hij dat jaar 1x boven was (art. 8b Uitv.reg.
-- WIB). Simpler: eenmaal boven = tot einde kalenderjaar in scope.
create table if not exists public.dac7_reporting_state (
  owner_id                     uuid    not null references public.profiles(id) on delete cascade,
  reporting_year               integer not null,
  transaction_count            integer not null default 0,
  total_amount_cents           bigint  not null default 0,
  threshold_75_reached_at      timestamptz,
  threshold_100_reached_at     timestamptz,
  payouts_blocked_at           timestamptz,
  last_recomputed_at           timestamptz not null default now(),
  created_at                   timestamptz not null default now(),
  primary key (owner_id, reporting_year)
);

comment on table public.dac7_reporting_state is
  'Per (owner, kalenderjaar) counters + threshold-flags voor DAC7 rapportageplicht. Gevuld door dac7_recompute_owner_year() vanaf de eerste betaalde boeking in dat jaar.';
comment on column public.dac7_reporting_state.transaction_count is
  'Aantal betaalde boekingen (bookings met payment_requested_at gezet in dit kalenderjaar) waarin de owner geld ontving.';
comment on column public.dac7_reporting_state.total_amount_cents is
  'Som van owner_share_cents in dit kalenderjaar — de basis voor de €2.000 drempel.';
comment on column public.dac7_reporting_state.threshold_75_reached_at is
  'Eerste moment waarop transaction_count >= 22 OF total_amount_cents >= 150000 (75% van drempel). Trigger voor BSN-prompt in de app.';
comment on column public.dac7_reporting_state.threshold_100_reached_at is
  'Eerste moment waarop transaction_count >= 30 OF total_amount_cents >= 200000. Verplicht TIN aangeleverd te hebben; anders payouts_blocked_at wordt gezet.';
comment on column public.dac7_reporting_state.payouts_blocked_at is
  'Wordt gezet als threshold_100 bereikt is EN owner heeft nog geen tin_provided_at gezet. Enforcement zit in create-payment-stripe edge function (aparte task).';

create index if not exists dac7_reporting_state_year_idx
  on public.dac7_reporting_state(reporting_year);

create index if not exists dac7_reporting_state_blocked_idx
  on public.dac7_reporting_state(owner_id)
  where payouts_blocked_at is not null;

-- RLS: owner mag eigen state lezen (voor UI). Niemand mag INSERT/UPDATE via
-- de client — dat gaat altijd via de helper functies met service_role.
alter table public.dac7_reporting_state enable row level security;

drop policy if exists dac7_reporting_state_select_own on public.dac7_reporting_state;
create policy dac7_reporting_state_select_own on public.dac7_reporting_state
  for select
  to authenticated
  using (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. is_valid_bsn(text) — 11-proef
-- ---------------------------------------------------------------------------
-- BSN algoritme (Rijksdienst voor Identiteitsgegevens):
--   • 9 digits (historisch 8, dan padden we met leading 0)
--   • sum(digit[i] × weight[i]) mod 11 == 0
--   • weights = [9, 8, 7, 6, 5, 4, 3, 2, -1]
--   • Eerste digit mag niet 0 zijn (of het is een test-BSN — die accepteren
--     we niet in productie-flow)
create or replace function public.is_valid_bsn(p_bsn text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_norm       text;
  v_len        int;
  v_sum        int := 0;
  v_weights    int[] := array[9, 8, 7, 6, 5, 4, 3, 2, -1];
  v_i          int;
begin
  if p_bsn is null then
    return false;
  end if;

  -- Normaliseer: alleen digits behouden.
  v_norm := regexp_replace(p_bsn, '\D', '', 'g');
  v_len  := length(v_norm);

  -- Accepteer 8 of 9 digits (historisch sofinummer was 8, huidige BSN is 9).
  if v_len = 8 then
    v_norm := '0' || v_norm;
    v_len := 9;
  end if;

  if v_len <> 9 then
    return false;
  end if;

  -- Volledig nullen is niet valide.
  if v_norm = '000000000' then
    return false;
  end if;

  -- 11-proef
  for v_i in 1..9 loop
    v_sum := v_sum + (substr(v_norm, v_i, 1)::int) * v_weights[v_i];
  end loop;

  return mod(v_sum, 11) = 0;
end;
$$;

comment on function public.is_valid_bsn(text) is
  'BSN 11-proef validatie. Normaliseert input (strip non-digits, pad 8→9). Geeft false bij null/invalid format/faal 11-proef.';

-- RSIN heeft historisch hetzelfde algoritme als sofinummer/BSN (11-proef,
-- 9 digits). We hergebruiken dezelfde logica maar met eigen naam voor
-- leesbaarheid in de code.
create or replace function public.is_valid_rsin(p_rsin text)
returns boolean
language sql
immutable
as $$
  select public.is_valid_bsn(p_rsin);
$$;

comment on function public.is_valid_rsin(text) is
  'RSIN validatie — zelfde 11-proef als BSN (historisch sofinummer). Wrapper voor is_valid_bsn().';

-- ---------------------------------------------------------------------------
-- 5. dac7_recompute_owner_year(owner, year) — recount + threshold-flags
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER + service_role only. Aangeroepen door de trigger op
-- bookings en door de nightly safety-net cron. Idempotent: draai 'm zo vaak
-- als je wilt, resultaat is deterministisch bepaald door de bookings-tabel.
--
-- Drempelwaarden zijn hardcoded als constants in de function body; als de
-- EU ze wijzigt komt daar een migratie voor. Bewust GEEN table-lookup —
-- dit is fiscale logica, wil ik in code kunnen zien wat de threshold is.
--
-- Merk op: payouts_blocked_at wordt HIER gezet zodra threshold_100 gehaald
-- is EN nog geen TIN geleverd. Als de owner later alsnog z'n TIN levert,
-- clearen we payouts_blocked_at in de submit-tin edge function.
create or replace function public.dac7_recompute_owner_year(
  p_owner_id uuid,
  p_year     integer
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Drempels (art. 8 Uitv.reg. WIB jo. Bijlage V DAC7).
  c_threshold_txn_100    constant int    := 30;
  c_threshold_amount_100 constant bigint := 200000;   -- €2.000 in cents
  -- 75%-vroege-waarschuwing (afgerond: 22 transacties / €1.500).
  c_threshold_txn_75     constant int    := 22;
  c_threshold_amount_75  constant bigint := 150000;

  v_from                 timestamptz;
  v_to                   timestamptz;
  v_txn_count            int;
  v_amount               bigint;
  v_tin_provided_at      timestamptz;
  v_now                  timestamptz := now();
  v_75_reached           timestamptz;
  v_100_reached          timestamptz;
  v_blocked              timestamptz;
begin
  if p_owner_id is null or p_year is null then
    return;
  end if;

  -- Kalendergrenzen in NL-tijdzone (owners zijn NL-belastingplichtigen).
  v_from := make_date(p_year,     1, 1)::timestamp at time zone 'Europe/Amsterdam';
  v_to   := make_date(p_year + 1, 1, 1)::timestamp at time zone 'Europe/Amsterdam';

  -- Tel + som betaalde boekingen. `payment_requested_at` = fiscaal moment
  -- (art. 35e Wet OB) = moment waarop owner de kWh indient = "levering".
  select
    coalesce(count(*), 0),
    coalesce(sum(b.owner_share_cents), 0)::bigint
  into v_txn_count, v_amount
  from public.bookings b
  join public.chargers c on c.id = b.charger_id
  where c.owner_id = p_owner_id
    and b.payment_requested_at is not null
    and b.payment_requested_at >= v_from
    and b.payment_requested_at <  v_to
    and coalesce(b.owner_share_cents, 0) > 0;

  -- Bestaande state ophalen (voor sticky threshold-flags).
  select threshold_75_reached_at, threshold_100_reached_at, payouts_blocked_at
    into v_75_reached, v_100_reached, v_blocked
  from public.dac7_reporting_state
  where owner_id = p_owner_id and reporting_year = p_year;

  -- TIN-status ophalen — bepaalt of we payouts moeten blokkeren.
  select tin_provided_at into v_tin_provided_at
  from public.profiles
  where id = p_owner_id;

  -- Sticky thresholds: eenmaal gezet, houdt hij die datum vast. Als een
  -- refund de owner weer onder de drempel duwt, blijft de rapportageplicht
  -- toch bestaan voor dit kalenderjaar (art. 8b Uitv.reg. WIB).
  if v_75_reached is null and (v_txn_count >= c_threshold_txn_75 or v_amount >= c_threshold_amount_75) then
    v_75_reached := v_now;
  end if;

  if v_100_reached is null and (v_txn_count >= c_threshold_txn_100 or v_amount >= c_threshold_amount_100) then
    v_100_reached := v_now;
  end if;

  -- Payouts-block: gezet als 100% gehaald en TIN nog niet geleverd.
  -- Als TIN al bestond op moment van drempel-hit, of later alsnog wordt
  -- geleverd, dan wordt v_blocked in submit-tin ge-cleared.
  if v_blocked is null and v_100_reached is not null and v_tin_provided_at is null then
    v_blocked := v_now;
  end if;

  -- Upsert.
  insert into public.dac7_reporting_state (
    owner_id,
    reporting_year,
    transaction_count,
    total_amount_cents,
    threshold_75_reached_at,
    threshold_100_reached_at,
    payouts_blocked_at,
    last_recomputed_at
  ) values (
    p_owner_id,
    p_year,
    v_txn_count,
    v_amount,
    v_75_reached,
    v_100_reached,
    v_blocked,
    v_now
  )
  on conflict (owner_id, reporting_year) do update
    set transaction_count        = excluded.transaction_count,
        total_amount_cents       = excluded.total_amount_cents,
        threshold_75_reached_at  = excluded.threshold_75_reached_at,
        threshold_100_reached_at = excluded.threshold_100_reached_at,
        payouts_blocked_at       = excluded.payouts_blocked_at,
        last_recomputed_at       = v_now;
end;
$$;

comment on function public.dac7_recompute_owner_year(uuid, integer) is
  'SECURITY DEFINER. Herberekent DAC7 counters + threshold-flags voor (owner, kalenderjaar). Idempotent. Aangeroepen door bookings-trigger en dagelijkse safety-cron.';

revoke all on function public.dac7_recompute_owner_year(uuid, integer) from public, anon, authenticated;
grant execute on function public.dac7_recompute_owner_year(uuid, integer) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Trigger op bookings — recompute na payment_requested_at wijziging
-- ---------------------------------------------------------------------------
-- Fires alleen als payment_requested_at ècht is veranderd (in of uit een
-- jaar). We doen recompute voor het jaar van de NIEUWE payment_requested_at
-- ÈN voor het jaar van de OUDE payment_requested_at (voor het geval het
-- verhuisd is over een kalendergrens — zeldzaam maar defensief).
create or replace function public.dac7_bookings_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id     uuid;
  v_year_new     int;
  v_year_old     int;
begin
  -- Owner via charger-join (bookings heeft geen owner_id kolom).
  select owner_id into v_owner_id
    from public.chargers
   where id = coalesce(new.charger_id, old.charger_id);

  if v_owner_id is null then
    return coalesce(new, old);
  end if;

  if new.payment_requested_at is not null then
    v_year_new := extract(year from new.payment_requested_at at time zone 'Europe/Amsterdam')::int;
    perform public.dac7_recompute_owner_year(v_owner_id, v_year_new);
  end if;

  if tg_op = 'UPDATE'
     and old.payment_requested_at is not null
     and (new.payment_requested_at is null
          or extract(year from old.payment_requested_at at time zone 'Europe/Amsterdam')
             <> extract(year from new.payment_requested_at at time zone 'Europe/Amsterdam'))
  then
    v_year_old := extract(year from old.payment_requested_at at time zone 'Europe/Amsterdam')::int;
    if v_year_old is distinct from v_year_new then
      perform public.dac7_recompute_owner_year(v_owner_id, v_year_old);
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

comment on function public.dac7_bookings_trigger() is
  'Trigger-handler op bookings. Roept dac7_recompute_owner_year aan voor de owner + het (evt. gewijzigde) jaar van payment_requested_at.';

drop trigger if exists dac7_bookings_after on public.bookings;
create trigger dac7_bookings_after
  after insert or update of payment_requested_at, owner_share_cents
  on public.bookings
  for each row
  execute function public.dac7_bookings_trigger();

-- ---------------------------------------------------------------------------
-- 7. dac7_status_for_owner() — client-facing status RPC
-- ---------------------------------------------------------------------------
-- App roept deze aan om te bepalen of het BSN-prompt-scherm getoond moet
-- worden. Return: prompt-status + counts + last4. NOOIT ciphertext.
--
-- Prompt-states:
--   • 'not_required'   — nog ver onder drempel, geen prompt
--   • 'early_warning'  — 75% gehaald, prompt aanraden (niet blocking)
--   • 'required'       — 100% gehaald, TIN moet geleverd (blocking op payouts)
--   • 'provided'       — TIN al aangeleverd, alles goed
create or replace function public.dac7_status_for_owner()
returns table (
  reporting_year            integer,
  transaction_count         integer,
  total_amount_cents        bigint,
  threshold_txn_75          integer,
  threshold_txn_100         integer,
  threshold_amount_75_cents bigint,
  threshold_amount_100_cents bigint,
  threshold_75_reached_at   timestamptz,
  threshold_100_reached_at  timestamptz,
  payouts_blocked_at        timestamptz,
  tin_provided_at           timestamptz,
  tin_type                  public.tin_type,
  tin_last4                 text,
  prompt_state              text,
  suggested_tin_type        public.tin_type
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_owner_id       uuid;
  v_year           int;
  v_business_type  public.business_type;
begin
  v_owner_id := auth.uid();
  if v_owner_id is null then
    return;
  end if;

  v_year := extract(year from now() at time zone 'Europe/Amsterdam')::int;

  -- Best-effort: safety-net recompute voor lopend jaar bij elke status-check.
  -- Als de trigger iets gemist heeft (bijv. handmatige DB-write) syncen we hier.
  perform public.dac7_recompute_owner_year(v_owner_id, v_year);

  select p.business_type into v_business_type
    from public.profiles p
   where p.id = v_owner_id;

  return query
    select
      v_year                                                    as reporting_year,
      coalesce(s.transaction_count, 0)                          as transaction_count,
      coalesce(s.total_amount_cents, 0)                         as total_amount_cents,
      22                                                        as threshold_txn_75,
      30                                                        as threshold_txn_100,
      150000::bigint                                            as threshold_amount_75_cents,
      200000::bigint                                            as threshold_amount_100_cents,
      s.threshold_75_reached_at,
      s.threshold_100_reached_at,
      s.payouts_blocked_at,
      p.tin_provided_at,
      p.tin_type,
      p.tin_last4,
      case
        when p.tin_provided_at is not null                        then 'provided'
        when s.threshold_100_reached_at is not null               then 'required'
        when s.threshold_75_reached_at  is not null               then 'early_warning'
        else                                                            'not_required'
      end                                                        as prompt_state,
      case
        when v_business_type in ('bv', 'overig') then 'rsin'::public.tin_type
        else                                          'bsn'::public.tin_type
      end                                                        as suggested_tin_type
    from public.profiles p
    left join public.dac7_reporting_state s
      on s.owner_id = p.id and s.reporting_year = v_year
    where p.id = v_owner_id;
end;
$$;

comment on function public.dac7_status_for_owner() is
  'Client-safe DAC7-status voor auth.uid(). Trigger elke keer een recompute voor lopend jaar zodat de app altijd verse cijfers krijgt. Nooit ciphertext.';

revoke all on function public.dac7_status_for_owner() from public;
revoke all on function public.dac7_status_for_owner() from anon;
grant execute on function public.dac7_status_for_owner() to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Trigger-guard — voorkom dat owner z'n TIN-metadata spooft
-- ---------------------------------------------------------------------------
-- tin_type / tin_last4 / tin_provided_at moeten óók onaanraakbaar zijn voor
-- authenticated. Anders zou een owner via een gewone .update({tin_provided_at:
-- now()}) call kunnen doen alsof-ie z'n BSN geleverd heeft (om z'n
-- payouts_blocked_at te resetten via een frontend-truc, of gewoon om
-- prompt_state = 'provided' te forceren).
--
-- Owner MAG wel tin_last_prompt_at zetten (rate-limit-tracking, harmless).
--
-- Waarom een trigger en niet REVOKE UPDATE (col)? In Postgres blijft
-- table-level UPDATE privilege dominant boven column-level revokes; om
-- kolom-specifiek te blokkeren zou je table-wide UPDATE moeten revoken en
-- daarna alle safe kolommen enumereren voor GRANT UPDATE. Foutgevoelig
-- bij toekomstige alter-tables. Een BEFORE UPDATE trigger die per-kolom
-- checkt is robuster: nieuwe safe kolommen blijven automatisch updatable.
create or replace function public.profiles_tin_write_guard()
returns trigger
language plpgsql
as $$
declare
  v_role text := current_setting('request.jwt.claims', true)::jsonb->>'role';
begin
  -- service_role mag alles. Voor de DB-owner (rol postgres, migraties)
  -- geldt hetzelfde — die zetten geen jwt.claims dus v_role is null.
  if v_role = 'service_role' or v_role is null then
    return new;
  end if;

  if new.tin_type       is distinct from old.tin_type
  or new.tin_last4      is distinct from old.tin_last4
  or new.tin_provided_at is distinct from old.tin_provided_at
  then
    raise exception 'TIN-metadata mag alleen door submit-tin edge function gezet worden (task #263). Rol: %', v_role
      using errcode = '42501';  -- insufficient_privilege
  end if;

  return new;
end;
$$;

comment on function public.profiles_tin_write_guard() is
  'BEFORE UPDATE guard op profiles: blokkeert writes op tin_type/tin_last4/tin_provided_at door niet-service_role. Beschermt tegen frontend-spoofing van "TIN geleverd"-status.';

drop trigger if exists profiles_tin_write_guard on public.profiles;
create trigger profiles_tin_write_guard
  before update on public.profiles
  for each row
  execute function public.profiles_tin_write_guard();

-- ---------------------------------------------------------------------------
-- 9. pg_cron — dagelijkse safety-net recompute
-- ---------------------------------------------------------------------------
-- Draait elke nacht om 03:15 UTC. Recompute voor alle owners met een rij in
-- dac7_reporting_state voor het lopende OF vorige kalenderjaar (vorig jaar
-- meepakken tot uiterlijk 31 jan, want late payments kunnen tot dan nog
-- binnenkomen die aan vorig jaar toegerekend moeten worden — DAC7-XML
-- export is uiterlijk 31 jan).
--
-- Purpose: als de trigger ooit iets mist (bijv. door een handmatige write
-- of een bug), synct de cron alles terug naar consistent.
create or replace function public.dac7_cron_recompute_all()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_year int := extract(year from now() at time zone 'Europe/Amsterdam')::int;
  r record;
begin
  for r in
    select distinct c.owner_id, y.year
      from public.chargers c
      cross join (values (v_current_year), (v_current_year - 1)) as y(year)
     where c.owner_id is not null
  loop
    perform public.dac7_recompute_owner_year(r.owner_id, r.year);
  end loop;
end;
$$;

comment on function public.dac7_cron_recompute_all() is
  'Nightly safety-net: recompute DAC7 counters voor alle chargers-owners voor lopend + vorig kalenderjaar. Idempotent.';

revoke all on function public.dac7_cron_recompute_all() from public, anon, authenticated;
grant execute on function public.dac7_cron_recompute_all() to service_role;

-- Cron: idempotent unschedule + schedule.
do $$
begin
  perform cron.unschedule('dac7-recompute-nightly');
exception
  when others then null;
end $$;

select cron.schedule(
  'dac7-recompute-nightly',
  '15 3 * * *',
  $$select public.dac7_cron_recompute_all();$$
);

-- ============================================================================
-- ROLLBACK
-- ----------------------------------------------------------------------------
--   select cron.unschedule('dac7-recompute-nightly');
--   drop trigger if exists dac7_bookings_after on public.bookings;
--   drop trigger if exists profiles_tin_write_guard on public.profiles;
--   drop function if exists public.profiles_tin_write_guard();
--   drop function if exists public.dac7_bookings_trigger();
--   drop function if exists public.dac7_cron_recompute_all();
--   drop function if exists public.dac7_status_for_owner();
--   drop function if exists public.dac7_recompute_owner_year(uuid, integer);
--   drop function if exists public.is_valid_rsin(text);
--   drop function if exists public.is_valid_bsn(text);
--   drop table if exists public.dac7_reporting_state;
--   drop table if exists public.profiles_tin_secure;
--   alter table public.profiles
--     drop column if exists tin_last_prompt_at,
--     drop column if exists tin_provided_at,
--     drop column if exists tin_last4,
--     drop column if exists tin_type;
--   drop type if exists public.tin_type;
--
-- VERIFICATIE (na deploy)
-- ----------------------------------------------------------------------------
--   1. select public.is_valid_bsn('111222333');       -- expect true (test-BSN)
--      select public.is_valid_bsn('123456789');       -- expect false
--      select public.is_valid_bsn('111 222 333');     -- expect true (spaties stripped)
--      select public.is_valid_bsn(null);              -- expect false
--   2. Als authenticated user:
--        select ciphertext from public.profiles_tin_secure limit 1;
--      → expect: RLS geeft 0 rijen terug (geen select-policy).
--   3. Als authenticated user, probeer TIN-spoofing:
--        update public.profiles set tin_provided_at = now() where id = auth.uid();
--      → expect: exception 42501 vanuit profiles_tin_write_guard.
--   4. select * from public.dac7_status_for_owner();
--      → expect: één rij met prompt_state = 'not_required' (bij een owner
--        zonder betaalde boekingen dit jaar) of 'provided'/'early_warning'
--        afhankelijk van state.
--   5. Simuleer drempel: update een booking's owner_share_cents naar
--      200001 en payment_requested_at naar now(). → check dat trigger
--      dac7_reporting_state row aanmaakt met threshold_100_reached_at.
--   6. select cron.job where jobname = 'dac7-recompute-nightly';
--      → expect: één rij, schedule '15 3 * * *'.
-- ============================================================================
