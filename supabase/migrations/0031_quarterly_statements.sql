-- ============================================================================
-- 0031_quarterly_statements.sql — Task #163: Kwartaaloverzicht-engine.
--
-- CONTEXT
-- ----------------------------------------------------------------------------
-- Voor BTW-plichtige paaleigenaren (profiles.vat_status = 'btw_plichtig') moet
-- Pluggo elk kwartaal een overzicht sturen met alle laadsessies + omzet + BTW
-- zodat ze hun aangifte kunnen doen. KOR-ondernemers en particulieren krijgen
-- géén kwartaaloverzicht (die vallen onder een andere flow: #162 self-billing
-- + jaarlijkse KOR-status).
--
-- SCOPE (uit task #163)
-- ----------------------------------------------------------------------------
--   ✓ pg_cron op 5e van jan / apr / jul / okt (dag na kwartaalgrens = safety
--     buffer voor late betalingen die nog binnenkomen op 1-4).
--   ✓ Per BTW-plichtige paaleigenaar: PDF met sessie-tabel + kwartaal-totalen
--     + YTD-totalen (bouwstenen in edge function generate-quarterly-statement).
--   ✓ Email via Resend (send-email edge function).
--   ✗ GEEN realtime drempel-waarschuwingen. Post-launch heeft niemand nog de
--     €20k-KOR-grens in zicht — als/wanneer dat komt lossen we het op met #263.
--
-- DEZE MIGRATIE
-- ----------------------------------------------------------------------------
-- 1. `quarterly_statements` tabel — audit-log + idempotency guard zodat we
--    nooit dubbele overzichten sturen aan dezelfde owner voor hetzelfde
--    (jaar, kwartaal).
-- 2. `quarterly_statement_targets(y, q)` SECURITY DEFINER helper die de
--    edge function aanroept om z'n werkzet te bepalen — één query, alle
--    BTW-plichtige owners met >0 paid bookings in het kwartaal, met alle
--    metadata die de PDF nodig heeft (naam, KvK, VAT-nummer, email).
-- 3. `quarterly_statement_bookings(owner, y, q)` SECURITY DEFINER helper
--    die de sessie-detailregels ophaalt (join bookings ↔ chargers) voor
--    één owner in één kwartaal. Return: JSON-array die de edge function
--    zonder verdere transformatie kan gebruiken.
-- 4. pg_cron `generate-quarterly-statements-quarterly` — 5e van jan/apr/jul/okt
--    07:00 UTC → net.http_post → generate-quarterly-statement edge function.
--    De edge function bepaalt zelf welk kwartaal (default = vorig kwartaal
--    op basis van "vandaag").
--
-- IDEMPOTENT: create table if not exists + create or replace + drop-then-schedule
-- pattern zoals in 0004 / 0028.
-- ============================================================================

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. quarterly_statements — audit + idempotency
-- ---------------------------------------------------------------------------
create table if not exists public.quarterly_statements (
  id                    uuid primary key default gen_random_uuid(),
  owner_id              uuid not null references public.profiles(id) on delete cascade,
  year                  integer not null,
  quarter               smallint not null check (quarter between 1 and 4),
  -- Snapshot van de metadata op moment van generatie (owner kan later z'n
  -- KvK/VAT-nummer wijzigen; het kwartaaloverzicht moet blijven kloppen voor
  -- Belastingdienst-doeleinden).
  full_name             text,
  kvk_number            text,
  vat_number            text,
  -- Aggregaten voor snelle lookups (bijv. admin-dashboard, drempel-checks
  -- door #263 zonder de bookings-tabel opnieuw te aggregeren).
  session_count         integer not null default 0,
  total_kwh             numeric(10,2) not null default 0,
  subtotal_cents        bigint not null default 0,  -- omzet excl. BTW (owner_share_cents som)
  vat_cents             bigint not null default 0,  -- 21% over subtotal (owner_vat_amount_cents som)
  total_cents           bigint not null default 0,  -- subtotal + vat (wat de eigenaar bruto ontving)
  -- YTD-cijfers op moment van generatie (Q1: gelijk aan kwartaal; Q4: hele jaar).
  ytd_session_count     integer not null default 0,
  ytd_total_kwh         numeric(10,2) not null default 0,
  ytd_subtotal_cents    bigint not null default 0,
  ytd_vat_cents         bigint not null default 0,
  ytd_total_cents       bigint not null default 0,
  -- Waar de PDF in Storage staat (bucket 'quarterly-statements').
  pdf_storage_path      text,
  -- Email-tracking: sent_at = null tijdens generatie, gevuld na Resend 200 OK.
  email_to              text,
  sent_at               timestamptz,
  send_error            text,
  -- Idempotency: één statement per owner per (year, quarter).
  generated_at          timestamptz not null default now(),
  unique (owner_id, year, quarter)
);

comment on table public.quarterly_statements is
  'Kwartaal-omzetoverzicht per BTW-plichtige paaleigenaar. Één rij per (owner, year, quarter). Metadata + aggregaten zijn een snapshot op generatiemoment; source-of-truth blijft bookings, deze tabel is voor audit/idempotency/lookups.';

comment on column public.quarterly_statements.subtotal_cents is
  'Som van bookings.owner_share_cents in het kwartaal (omzet van de eigenaar excl. BTW).';
comment on column public.quarterly_statements.vat_cents is
  'Som van bookings.owner_vat_amount_cents in het kwartaal (21% BTW die de eigenaar aan de Belastingdienst moet afdragen).';
comment on column public.quarterly_statements.pdf_storage_path is
  'Pad in Supabase Storage bucket ''quarterly-statements''. Signed URL wordt bij verzenden geregeld — geen publieke lees-toegang.';

create index if not exists quarterly_statements_owner_id_idx
  on public.quarterly_statements(owner_id);
create index if not exists quarterly_statements_year_quarter_idx
  on public.quarterly_statements(year desc, quarter desc);
create index if not exists quarterly_statements_sent_at_idx
  on public.quarterly_statements(sent_at)
  where sent_at is null;

-- ---------------------------------------------------------------------------
-- 2. RLS — owner mag z'n eigen overzichten zien
-- ---------------------------------------------------------------------------
alter table public.quarterly_statements enable row level security;

drop policy if exists "quarterly_statements selectable by owner" on public.quarterly_statements;
create policy "quarterly_statements selectable by owner" on public.quarterly_statements
  for select to authenticated
  using (owner_id = auth.uid());

-- Insert/Update/Delete alleen via service_role (edge function). Geen policy = deny.

-- ---------------------------------------------------------------------------
-- 3. Helper: quarterly_statement_targets(y, q)
--
-- Geeft alle BTW-plichtige paaleigenaren terug die in kwartaal q van jaar y
-- minstens één betaalde boeking hebben — met de metadata die de PDF nodig
-- heeft. SECURITY DEFINER zodat de edge function (die met service_role
-- draait) niet handmatig auth.users hoeft te bevragen.
-- ---------------------------------------------------------------------------
create or replace function public.quarterly_statement_targets(
  p_year integer,
  p_quarter smallint
)
returns table (
  owner_id     uuid,
  email        text,
  full_name    text,
  kvk_number   text,
  vat_number   text,
  vat_status   public.vat_status,
  q_from       timestamptz,
  q_to         timestamptz
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz;
  v_to   timestamptz;
begin
  if p_quarter not between 1 and 4 then
    raise exception 'quarter must be 1-4, got %', p_quarter;
  end if;

  -- Kwartaal-grenzen in Europe/Amsterdam. We slaan intern UTC op maar de
  -- fiscale-kalender werkt op NL-datums. TZ-conversie voorkomt off-by-one
  -- rond middernacht op de laatste dag van het kwartaal.
  v_from := (make_date(p_year, (p_quarter - 1) * 3 + 1, 1))::timestamp
              at time zone 'Europe/Amsterdam';
  v_to   := (v_from + interval '3 months');

  return query
    select
      p.id                                                            as owner_id,
      (select u.email from auth.users u where u.id = p.id)             as email,
      p.full_name,
      p.kvk_number,
      p.vat_number,
      p.vat_status,
      v_from                                                           as q_from,
      v_to                                                             as q_to
    from public.profiles p
    where p.vat_status = 'btw_plichtig'
      and exists (
        select 1
          from public.bookings b
          join public.chargers c on c.id = b.charger_id
         where c.owner_id = p.id
           and b.payment_status = 'paid'
           and b.payment_requested_at >= v_from
           and b.payment_requested_at <  v_to
      );
end;
$$;

comment on function public.quarterly_statement_targets is
  'Werkzet-generator voor generate-quarterly-statement edge function. Retourneert alle BTW-plichtige owners met >0 paid bookings in het opgegeven kwartaal + hun metadata (email uit auth.users).';

revoke all on function public.quarterly_statement_targets(integer, smallint) from public;
revoke all on function public.quarterly_statement_targets(integer, smallint) from anon;
revoke all on function public.quarterly_statement_targets(integer, smallint) from authenticated;
grant execute on function public.quarterly_statement_targets(integer, smallint) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Helper: quarterly_statement_bookings(owner, y, q)
--
-- Detail-regels voor de sessie-tabel in de PDF: één rij per paid booking in
-- het kwartaal, met paal-naam + kWh + omzet + BTW. Sorteert chronologisch.
-- Return-type = SETOF json zodat de edge function 'm zonder pg-type-mapping
-- kan consumeren.
-- ---------------------------------------------------------------------------
create or replace function public.quarterly_statement_bookings(
  p_owner_id uuid,
  p_year integer,
  p_quarter smallint
)
returns table (
  booking_id                uuid,
  session_date              timestamptz,
  charger_name              text,
  charger_address           text,
  kwh_consumed              numeric,
  owner_share_cents         integer,
  owner_vat_amount_cents    integer,
  booker_email              text
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz;
  v_to   timestamptz;
begin
  v_from := (make_date(p_year, (p_quarter - 1) * 3 + 1, 1))::timestamp
              at time zone 'Europe/Amsterdam';
  v_to   := (v_from + interval '3 months');

  return query
    -- N.B. `payment_requested_at` is het moment waarop de eigenaar kWh
    -- heeft ingevuld en dus feitelijk de dienst heeft "gefactureerd". Dat is
    -- fiscaal het correcte tax-point (BTW-moment) — niet het moment waarop
    -- de boeker de Stripe-checkout heeft afgerond, dat kan een dag later
    -- zijn maar hoort in hetzelfde kwartaal thuis.
    select
      b.id                                                          as booking_id,
      b.payment_requested_at                                        as session_date,
      c.name                                                        as charger_name,
      c.address                                                     as charger_address,
      b.kwh_consumed,
      b.owner_share_cents,
      b.owner_vat_amount_cents,
      b.user_email                                                  as booker_email
    from public.bookings b
    join public.chargers c on c.id = b.charger_id
    where c.owner_id = p_owner_id
      and b.payment_status = 'paid'
      and b.payment_requested_at >= v_from
      and b.payment_requested_at <  v_to
    order by b.payment_requested_at asc;
end;
$$;

comment on function public.quarterly_statement_bookings is
  'Detail-regels voor kwartaaloverzicht PDF: één rij per paid booking in het kwartaal, chronologisch. Gebruikt door generate-quarterly-statement edge function.';

revoke all on function public.quarterly_statement_bookings(uuid, integer, smallint) from public;
revoke all on function public.quarterly_statement_bookings(uuid, integer, smallint) from anon;
revoke all on function public.quarterly_statement_bookings(uuid, integer, smallint) from authenticated;
grant execute on function public.quarterly_statement_bookings(uuid, integer, smallint) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Helper: quarterly_statement_ytd(owner, y, up_to_quarter)
--
-- YTD-aggregaten voor de "totaal tot en met dit kwartaal"-blok in de PDF.
-- Zelfde filter als _bookings, maar zonder detailregels — puur som.
-- ---------------------------------------------------------------------------
create or replace function public.quarterly_statement_ytd(
  p_owner_id uuid,
  p_year integer,
  p_up_to_quarter smallint
)
returns table (
  session_count      integer,
  total_kwh          numeric,
  subtotal_cents     bigint,
  vat_cents          bigint,
  total_cents        bigint
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz;
  v_to   timestamptz;
begin
  v_from := (make_date(p_year, 1, 1))::timestamp
              at time zone 'Europe/Amsterdam';
  v_to   := (make_date(p_year, (p_up_to_quarter - 1) * 3 + 1, 1))::timestamp
              at time zone 'Europe/Amsterdam' + interval '3 months';

  return query
    select
      count(*)::integer                                              as session_count,
      coalesce(sum(b.kwh_consumed), 0)                               as total_kwh,
      coalesce(sum(b.owner_share_cents), 0)::bigint                  as subtotal_cents,
      coalesce(sum(b.owner_vat_amount_cents), 0)::bigint             as vat_cents,
      coalesce(sum(b.owner_share_cents), 0)::bigint
        + coalesce(sum(b.owner_vat_amount_cents), 0)::bigint         as total_cents
    from public.bookings b
    join public.chargers c on c.id = b.charger_id
    where c.owner_id = p_owner_id
      and b.payment_status = 'paid'
      and b.payment_requested_at >= v_from
      and b.payment_requested_at <  v_to;
end;
$$;

comment on function public.quarterly_statement_ytd is
  'YTD-aggregaten t/m een bepaald kwartaal voor kwartaaloverzicht PDF (het "tot en met"-blok).';

revoke all on function public.quarterly_statement_ytd(uuid, integer, smallint) from public;
revoke all on function public.quarterly_statement_ytd(uuid, integer, smallint) from anon;
revoke all on function public.quarterly_statement_ytd(uuid, integer, smallint) from authenticated;
grant execute on function public.quarterly_statement_ytd(uuid, integer, smallint) to service_role;

-- ---------------------------------------------------------------------------
-- 6. pg_cron — 5e van jan/apr/jul/okt om 07:00 UTC (= 08:00 NL wintertijd,
--    09:00 NL zomertijd). Waarom de 5e en niet de 1e:
--
--    a) Buffer voor late betalingen. Boekingen die op 30 dec om 23:59 zijn
--       gecompleteerd kunnen op 1 jan pas als 'paid' worden gemarkeerd door
--       Stripe webhook (of pay-after-charge boeker). We wachten 4 dagen zodat
--       het overzicht compleet is.
--    b) Fiscale deadline. Een BTW-plichtige heeft t/m de laatste dag van de
--       maand ná het kwartaal om aangifte te doen (bijv. Q1 → 30 apr). 5e
--       van de maand geeft de eigenaar 25+ dagen — meer dan genoeg.
-- ---------------------------------------------------------------------------

do $$
declare
  jid bigint;
begin
  select jobid into jid from cron.job where jobname = 'generate-quarterly-statements-quarterly';
  if jid is not null then
    perform cron.unschedule(jid);
  end if;
end $$;

select cron.schedule(
  'generate-quarterly-statements-quarterly',
  '0 7 5 1,4,7,10 *',  -- 07:00 UTC op de 5e van jan/apr/jul/okt
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url') || '/functions/v1/generate-quarterly-statement',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ---------------------------------------------------------------------------
-- 7. Storage bucket voor de gegenereerde PDFs
-- ---------------------------------------------------------------------------
-- Bucket is private: alleen service_role (edge function) mag uploaden/lezen.
-- Owners krijgen hun PDF via een 30-daagse signed URL in de mail — géén
-- publieke toegang.
--
-- Idempotent: on conflict do nothing, storage.buckets heeft PK op id.
insert into storage.buckets (id, name, public)
values ('quarterly-statements', 'quarterly-statements', false)
on conflict (id) do nothing;

-- Geen storage-policies voor authenticated/anon. Owners krijgen hun PDF
-- exclusief via de 30-daagse signed URL in de mail. Wanneer we later een
-- "kwartaaloverzichten"-scherm bouwen in de app, doen we dat via een edge
-- function die de owner authentiseert, in quarterly_statements checkt of
-- de owner het overzicht mag zien (RLS via owner_id = auth.uid()), en dan
-- een verse signed URL genereert. Op die manier hoeven we storage-level
-- policies niet te ontwerpen rond het pad-format.
--
-- Uploads/reads vanuit onze edge function draaien op service_role — die
-- bypasst RLS. Geen extra config nodig.
--
-- ============================================================================
-- ROLLBACK
-- ----------------------------------------------------------------------------
--   select cron.unschedule('generate-quarterly-statements-quarterly');
--   drop function if exists public.quarterly_statement_ytd(uuid, integer, smallint);
--   drop function if exists public.quarterly_statement_bookings(uuid, integer, smallint);
--   drop function if exists public.quarterly_statement_targets(integer, smallint);
--   drop table if exists public.quarterly_statements;
--
-- VERIFICATIE (na deploy)
-- ----------------------------------------------------------------------------
--   1. select * from cron.job where jobname = 'generate-quarterly-statements-quarterly';
--        → 1 row, next_run in de toekomst.
--   2. select * from public.quarterly_statement_targets(2026, 3::smallint);
--        → verwacht: 0 rows (nog geen BTW-plichtige owners in Q3 2026).
--        (of X rows als tussen deploy en verificatie er al btw_plichtig
--         paaleigenaren met paid bookings zijn.)
--   3. Handmatig triggeren voor smoke-test:
--        curl -X POST https://<ref>.supabase.co/functions/v1/generate-quarterly-statement \
--             -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
--             -H "Content-Type: application/json" \
--             -d '{"year": 2026, "quarter": 2, "dry_run": true}'
--        → verwacht 200 + telling van hoeveel statements zouden worden gegenereerd.
-- ============================================================================
