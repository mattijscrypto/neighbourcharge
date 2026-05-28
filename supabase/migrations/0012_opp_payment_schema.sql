-- ============================================================================
-- 0012_opp_payment_schema.sql — OPP (Online Payment Platform) integratie
--
-- Voegt velden toe voor migratie van Mollie Payments → Online Payment Platform.
-- Mollie-kolommen blijven tijdelijk staan voor parallelle run (12-26 juni 2026).
-- In 0013 worden de obsolete Mollie-kolommen + payouts tabel verwijderd.
--
-- Idempotent: gebruikt IF NOT EXISTS / DROP POLICY IF EXISTS overal.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enums voor BTW-status en business type
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'business_type') then
    create type public.business_type as enum (
      'particulier',   -- geen KvK
      'eenmanszaak',   -- ZZP met KvK
      'bv',            -- besloten vennootschap
      'overig'         -- VvE, stichting, etc.
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'vat_status') then
    create type public.vat_status as enum (
      'none',          -- particulier, geen BTW-administratie
      'kor',           -- KOR-ondernemer, vrijgesteld onder €20k
      'btw_plichtig'   -- BTW-plichtige ondernemer, draagt zelf BTW af
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'opp_compliance_status') then
    create type public.opp_compliance_status as enum (
      'unverified',    -- net aangemaakt, KYC nog niet afgerond
      'review',        -- compliance team OPP beoordeelt
      'verified',      -- mag betalingen ontvangen + uitbetaald worden
      'rejected'       -- afgewezen door OPP compliance
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'invoice_type') then
    create type public.invoice_type as enum (
      'self_billing_owner',  -- Pluggo factureert namens paaleigenaar (art. 35e Wet OB)
      'platform_fee_pluggo'  -- Pluggo's eigen platform-fee aan paaleigenaar
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. profiles uitbreidingen — OPP merchant + BTW-administratie
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists business_type           public.business_type,
  add column if not exists vat_status              public.vat_status,
  add column if not exists kvk_number              text,
  add column if not exists vat_number              text,
  add column if not exists opp_merchant_uid        text unique,
  add column if not exists opp_compliance_level    smallint default 0,  -- 100 / 200 / 400
  add column if not exists opp_compliance_status   public.opp_compliance_status default 'unverified',
  add column if not exists opp_can_receive_payments boolean default false,
  add column if not exists opp_can_receive_payouts  boolean default false,
  add column if not exists opp_bank_account_uid    text,
  add column if not exists opp_bank_account_status text,
  add column if not exists opp_contact_uid         text,
  add column if not exists opp_onboarding_started_at timestamptz,
  add column if not exists opp_onboarding_completed_at timestamptz,
  add column if not exists invoice_counter         integer not null default 0,
  add column if not exists ytd_revenue_cents       bigint  not null default 0;

comment on column public.profiles.business_type is
  'Status uit BTW-vragenlijst: bepaalt KYC-flow + factuurtemplate.';
comment on column public.profiles.vat_status is
  'BTW-status: bepaalt of we 21% over stroom-omzet moeten berekenen voor self-billing factuur.';
comment on column public.profiles.opp_merchant_uid is
  'Unieke merchant ID bij OPP. Vereist voor het ontvangen van betalingen.';
comment on column public.profiles.opp_compliance_level is
  '100=created, 200=Low KYC (bankaccount verified), 400=High KYC (iDIN verified)';
comment on column public.profiles.invoice_counter is
  'Volgnummer voor zelfgenereerde facturen. Per profiel om identifiers per ondernemer uniek te houden.';

create index if not exists profiles_opp_merchant_uid_idx
  on public.profiles(opp_merchant_uid)
  where opp_merchant_uid is not null;

create index if not exists profiles_opp_compliance_status_idx
  on public.profiles(opp_compliance_status)
  where opp_merchant_uid is not null;

-- ---------------------------------------------------------------------------
-- 3. bookings uitbreidingen — BTW-velden voor self-billing
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists owner_vat_amount_cents    integer,  -- 21% over owner_share (alleen bij btw_plichtig)
  add column if not exists platform_fee_vat_cents    integer;  -- 21% over Pluggo's €0,06/kWh (Pluggo KOR → meestal 0)

comment on column public.bookings.owner_vat_amount_cents is
  'BTW-bedrag in self-billing factuur voor paaleigenaar. Alleen ingevuld als profiles.vat_status = btw_plichtig.';
comment on column public.bookings.platform_fee_vat_cents is
  'BTW-bedrag op Pluggo platform-fee. Onder KOR (huidige status Pluggo BV) = 0.';

-- ---------------------------------------------------------------------------
-- 4. payments uitbreidingen — OPP transaction velden
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists opp_transaction_uid text unique,
  add column if not exists opp_merchant_uid    text,        -- snapshot van paaleigenaar's OPP merchant
  add column if not exists platform_fee_cents  integer,     -- wat Pluggo afhoudt (€0,06/kWh + evt. €0,40 small-session)
  add column if not exists owner_payout_cents  integer,     -- wat paaleigenaar krijgt (incl. of excl. BTW)
  add column if not exists opp_status          text,        -- created/pending/completed/failed/cancelled/expired
  add column if not exists opp_completed_at    timestamptz,
  add column if not exists psp_provider        text default 'mollie';  -- 'mollie' of 'opp' tijdens parallel run

comment on column public.payments.psp_provider is
  'Welke PSP deze betaling heeft verwerkt. Tijdens cutover-periode: nieuwe betalingen = opp, oude historie = mollie.';

create index if not exists payments_opp_transaction_uid_idx
  on public.payments(opp_transaction_uid)
  where opp_transaction_uid is not null;

create index if not exists payments_psp_provider_idx
  on public.payments(psp_provider);

-- ---------------------------------------------------------------------------
-- 5. invoices tabel — self-billing facturen + Pluggo platform-fee facturen
-- ---------------------------------------------------------------------------
create table if not exists public.invoices (
  id                     uuid primary key default gen_random_uuid(),
  booking_id             uuid references public.bookings(id) on delete restrict,
  payment_id             uuid references public.payments(id) on delete restrict,
  invoice_type           public.invoice_type not null,
  invoice_number         text not null unique,
  recipient_profile_id   uuid not null references public.profiles(id),
  issuer_profile_id      uuid references public.profiles(id),  -- null = Pluggo BV (geen profile)
  subtotal_cents         integer not null,
  vat_amount_cents       integer not null default 0,
  total_cents            integer not null,
  vat_rate               numeric(4,2) not null default 0.00,
  vat_clause             text,  -- 'art 25 Wet OB (KOR)' / 'art 35e Wet OB (self-billing)' / null
  pdf_storage_path       text,  -- pad in Supabase Storage bucket 'invoices'
  issued_at              timestamptz not null default now(),
  sent_at                timestamptz,
  created_at             timestamptz not null default now()
);

create index if not exists invoices_booking_id_idx        on public.invoices(booking_id);
create index if not exists invoices_payment_id_idx        on public.invoices(payment_id);
create index if not exists invoices_recipient_id_idx      on public.invoices(recipient_profile_id);
create index if not exists invoices_invoice_type_idx      on public.invoices(invoice_type);
create index if not exists invoices_issued_at_idx         on public.invoices(issued_at desc);

comment on table public.invoices is
  'Alle facturen: zowel zelf-gegenereerde Pluggo platform-fee facturen als self-billing facturen die Pluggo namens de paaleigenaar uitschrijft (art. 35e Wet OB).';

-- ---------------------------------------------------------------------------
-- 6. Row Level Security — invoices
-- ---------------------------------------------------------------------------
alter table public.invoices enable row level security;

-- ontvanger mag zijn eigen facturen zien
drop policy if exists "invoices selectable by recipient" on public.invoices;
create policy "invoices selectable by recipient" on public.invoices
  for select to authenticated using (recipient_profile_id = auth.uid());

-- Insert/Update gaat alleen via service_role (edge functions) — geen policy nodig

-- ---------------------------------------------------------------------------
-- 7. Helper view: onboarding-overzicht voor admin + Flutter app
-- ---------------------------------------------------------------------------
create or replace view public.opp_onboarding_overview as
  select
    p.id                              as profile_id,
    p.full_name,
    -- email staat in auth.users, niet in public.profiles
    (select u.email from auth.users u where u.id = p.id) as email,
    p.business_type,
    p.vat_status,
    p.opp_merchant_uid,
    p.opp_compliance_level,
    p.opp_compliance_status,
    p.opp_can_receive_payments,
    p.opp_can_receive_payouts,
    p.opp_bank_account_status,
    p.opp_onboarding_started_at,
    p.opp_onboarding_completed_at,
    case
      when p.opp_merchant_uid is null then 'not_started'
      when p.opp_compliance_status = 'verified' and p.opp_can_receive_payouts then 'complete'
      when p.opp_compliance_status = 'rejected' then 'rejected'
      when p.opp_bank_account_status is null then 'need_bank'
      when p.opp_bank_account_status in ('new','pending') then 'bank_review'
      when p.opp_compliance_level < 400 and p.ytd_revenue_cents > 150000 then 'need_idin'
      else 'in_progress'
    end as overall_status
  from public.profiles p
  where p.opp_merchant_uid is not null
     or exists (select 1 from public.chargers c where c.owner_id = p.id);

comment on view public.opp_onboarding_overview is
  'Per-paaleigenaar overzicht van OPP onboarding-voortgang. Gebruikt door Flutter app voor statusbanner + admin dashboard.';

-- ---------------------------------------------------------------------------
-- 8. Helper view: openstaande facturen om te versturen (cron-job target)
-- ---------------------------------------------------------------------------
create or replace view public.pending_invoice_emails as
  select
    i.id,
    i.invoice_type,
    i.invoice_number,
    i.recipient_profile_id,
    -- email staat in auth.users, niet in public.profiles
    (select u.email from auth.users u where u.id = i.recipient_profile_id) as email,
    p.full_name,
    i.pdf_storage_path,
    i.issued_at
  from public.invoices i
  join public.profiles p on p.id = i.recipient_profile_id
  where i.sent_at is null
    and i.pdf_storage_path is not null
  order by i.issued_at asc;

-- ---------------------------------------------------------------------------
-- 9. Migratie-helper: invoice_number generator
--    Format: P-{owner_short}-{YYYY}-{counter:04d} voor self-billing
--            PLUGGO-{YYYY}-{global_counter:06d} voor platform-fee facturen
-- ---------------------------------------------------------------------------
create or replace function public.next_invoice_number(
  p_profile_id uuid,
  p_invoice_type public.invoice_type
)
returns text
language plpgsql
security definer
as $$
declare
  v_counter integer;
  v_year integer := extract(year from now())::integer;
  v_short text;
begin
  if p_invoice_type = 'self_billing_owner' then
    update public.profiles
       set invoice_counter = invoice_counter + 1
     where id = p_profile_id
    returning invoice_counter, left(replace(coalesce(full_name,'XXX'), ' ', ''), 4) into v_counter, v_short;
    return format('P-%s-%s-%s', upper(v_short), v_year, lpad(v_counter::text, 4, '0'));
  else
    -- platform_fee_pluggo: globaal nummerschema
    select count(*) + 1 into v_counter
      from public.invoices
     where invoice_type = 'platform_fee_pluggo'
       and extract(year from issued_at) = v_year;
    return format('PLUGGO-%s-%s', v_year, lpad(v_counter::text, 6, '0'));
  end if;
end;
$$;

comment on function public.next_invoice_number is
  'Genereert het volgende factuurnummer per paaleigenaar (self-billing) of globaal (Pluggo platform-fee). Wordt aangeroepen door generate-self-billing-invoice edge function.';

-- ---------------------------------------------------------------------------
-- 10. Cleanup-hint voor 0013 (NIET nu uitvoeren)
-- ---------------------------------------------------------------------------
-- In 0013_drop_mollie_legacy.sql na succesvolle OPP cutover (na 26 juni 2026):
--   alter table public.payments drop column mollie_payment_id;
--   alter table public.payments drop column checkout_url;
--   drop table public.payouts cascade;
--   drop view public.pending_payouts;
--
-- Tot die tijd blijven die kolommen behouden voor backward-compat tijdens parallelle run.

-- Klaar. Verifieer in Supabase Dashboard:
--  1. profiles bevat business_type, vat_status, opp_merchant_uid en peer kolommen
--  2. payments bevat opp_transaction_uid + psp_provider
--  3. invoices tabel zichtbaar met RLS aan
--  4. view opp_onboarding_overview retourneert lege set bij eerste run
