-- ============================================================================
-- 0013_stripe_payment_schema.sql — Stripe Connect (Express) integratie
--
-- Pluggo pivoteert van OPP naar Stripe Connect (Express variant, Accounts v2).
-- Reden: snellere onboarding (in-app via flutter_stripe), bredere PSP-dekking
-- (iDEAL + cards + Bancontact + Apple/Google Pay) en lagere maandkosten
-- (€1,85/maand per actief account i.p.v. OPP partner-fees).
--
-- Deze migratie voegt Stripe-velden toe naast bestaande OPP/Mollie-kolommen.
-- Tijdens cutover-periode (juni 2026) kunnen beide payment-providers parallel
-- draaien: psp_provider='stripe' voor nieuwe paaleigenaren, ='opp' voor
-- eventuele vroeg-onboarders en ='mollie' voor historische data.
--
-- Cleanup van Mollie + OPP velden gebeurt in 0014 ná Stripe go-live (7 juli 2026).
--
-- Idempotent: gebruikt IF NOT EXISTS / DROP POLICY IF EXISTS overal.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enum voor Stripe account-status
--
-- Mapt op Stripe's `account.requirements.disabled_reason` + capability-status.
-- Vereenvoudigd tot vier states voor Pluggo UI-doeleinden.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'stripe_account_status') then
    create type public.stripe_account_status as enum (
      'pending',       -- account aangemaakt, KYC nog niet (volledig) afgerond
      'review',        -- Stripe Trust & Safety beoordeelt extra docs
      'verified',      -- charges_enabled = true, mag betalingen ontvangen
      'restricted',    -- requirements outstanding, payments geblokkeerd
      'rejected'       -- Stripe heeft account permanent geweigerd
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. profiles uitbreidingen — Stripe Connect account-velden
--
-- LET OP: business_type, vat_status, kvk_number, vat_number staan al in 0012
-- en worden hergebruikt — de BTW-vragenlijst is provider-agnostisch.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists stripe_account_id                text unique,
  add column if not exists stripe_account_status            public.stripe_account_status default 'pending',
  add column if not exists stripe_charges_enabled           boolean default false,
  add column if not exists stripe_payouts_enabled           boolean default false,
  add column if not exists stripe_details_submitted         boolean default false,
  add column if not exists stripe_disabled_reason           text,
  add column if not exists stripe_currently_due             text[],            -- requirements van Stripe
  add column if not exists stripe_onboarding_started_at     timestamptz,
  add column if not exists stripe_onboarding_completed_at   timestamptz,
  add column if not exists stripe_last_webhook_at           timestamptz;

comment on column public.profiles.stripe_account_id is
  'Stripe v2 connected account ID (acct_...). Unieke identifier voor paaleigenaar als merchant op Pluggo platform.';
comment on column public.profiles.stripe_charges_enabled is
  'Mag PaymentIntents ontvangen met transfer_data.destination = dit account. True na succesvolle KYC.';
comment on column public.profiles.stripe_payouts_enabled is
  'Stripe mag automatisch uitbetalen naar het gekoppelde IBAN. True na bank verification.';
comment on column public.profiles.stripe_currently_due is
  'Array van Stripe requirement-IDs die nog moeten worden aangeleverd. Leeg = account compleet.';

create index if not exists profiles_stripe_account_id_idx
  on public.profiles(stripe_account_id)
  where stripe_account_id is not null;

create index if not exists profiles_stripe_charges_enabled_idx
  on public.profiles(stripe_charges_enabled)
  where stripe_account_id is not null;

-- ---------------------------------------------------------------------------
-- 3. payments uitbreidingen — Stripe PaymentIntent velden
--
-- Bestaande velden uit 0012 (psp_provider, platform_fee_cents, owner_payout_cents)
-- worden hergebruikt. We voegen alleen Stripe-specifieke IDs toe.
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists stripe_payment_intent_id text unique,
  add column if not exists stripe_charge_id         text,
  add column if not exists stripe_transfer_id       text,        -- transfer naar connected account
  add column if not exists stripe_application_fee_id text,       -- Pluggo's fee-record
  add column if not exists stripe_account_id        text,        -- snapshot van paaleigenaar's stripe_account_id
  add column if not exists stripe_status            text;        -- requires_payment_method / processing / succeeded / etc.

comment on column public.payments.stripe_payment_intent_id is
  'Stripe PaymentIntent ID (pi_...). Bron-van-waarheid voor betaalstatus.';
comment on column public.payments.stripe_application_fee_id is
  'Stripe ApplicationFee ID (fee_...). Bedrag dat Pluggo automatisch ontvangt uit elke betaling.';
comment on column public.payments.stripe_status is
  'Laatst bekende status van de PaymentIntent. Wordt geupdate door stripe-webhook bij elk relevant event.';

create index if not exists payments_stripe_payment_intent_id_idx
  on public.payments(stripe_payment_intent_id)
  where stripe_payment_intent_id is not null;

create index if not exists payments_stripe_account_id_idx
  on public.payments(stripe_account_id)
  where stripe_account_id is not null;

-- ---------------------------------------------------------------------------
-- 4. stripe_webhook_events — idempotency tabel voor webhook-deduplicatie
--
-- Stripe kan een event meerdere keren leveren. We slaan elk gezien event_id
-- op zodat onze handler niet dubbel uitvoert.
-- ---------------------------------------------------------------------------
create table if not exists public.stripe_webhook_events (
  id            text primary key,             -- Stripe event ID (evt_...)
  type          text not null,                -- event-type (bv. account.updated, payment_intent.succeeded)
  api_version   text,
  received_at   timestamptz not null default now(),
  processed_at  timestamptz,
  error_message text,
  payload       jsonb                         -- volledige event payload voor debugging
);

create index if not exists stripe_webhook_events_type_idx
  on public.stripe_webhook_events(type);

create index if not exists stripe_webhook_events_received_at_idx
  on public.stripe_webhook_events(received_at desc);

comment on table public.stripe_webhook_events is
  'Audit-log + idempotency-guard voor Stripe webhooks. processed_at is null tussen ontvangst en succesvolle verwerking.';

-- ---------------------------------------------------------------------------
-- 5. Helper view: Stripe onboarding-overzicht voor Flutter app + admin
--
-- Mirror van opp_onboarding_overview uit 0012, maar dan voor Stripe.
-- ---------------------------------------------------------------------------
create or replace view public.stripe_onboarding_overview as
  select
    p.id                              as profile_id,
    p.full_name,
    -- email staat in auth.users, niet in public.profiles
    (select u.email from auth.users u where u.id = p.id) as email,
    p.business_type,
    p.vat_status,
    p.stripe_account_id,
    p.stripe_account_status,
    p.stripe_charges_enabled,
    p.stripe_payouts_enabled,
    p.stripe_details_submitted,
    p.stripe_disabled_reason,
    p.stripe_currently_due,
    p.stripe_onboarding_started_at,
    p.stripe_onboarding_completed_at,
    case
      when p.stripe_account_id is null then 'not_started'
      when p.stripe_account_status = 'rejected' then 'rejected'
      when p.stripe_account_status = 'verified' and p.stripe_charges_enabled and p.stripe_payouts_enabled then 'complete'
      when p.stripe_charges_enabled and not p.stripe_payouts_enabled then 'charges_only'
      when not p.stripe_details_submitted then 'need_kyc'
      when array_length(p.stripe_currently_due, 1) > 0 then 'requirements_due'
      else 'in_progress'
    end as overall_status
  from public.profiles p
  where p.stripe_account_id is not null
     or exists (select 1 from public.chargers c where c.owner_id = p.id);

comment on view public.stripe_onboarding_overview is
  'Per-paaleigenaar overzicht van Stripe Connect onboarding-voortgang. Gebruikt door Flutter app voor statusbanner + admin dashboard.';

-- ---------------------------------------------------------------------------
-- 6. Trigger: stripe_account_status updates -> stripe_onboarding_completed_at
--
-- Wanneer een account naar 'verified' overgaat, leg het completion-moment vast.
-- Idempotent: alleen zetten als nog leeg.
-- ---------------------------------------------------------------------------
create or replace function public.set_stripe_onboarding_completed()
returns trigger
language plpgsql
as $$
begin
  if new.stripe_account_status = 'verified'
     and (old.stripe_account_status is null or old.stripe_account_status <> 'verified')
     and new.stripe_onboarding_completed_at is null then
    new.stripe_onboarding_completed_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stripe_onboarding_completed on public.profiles;
create trigger trg_stripe_onboarding_completed
  before update on public.profiles
  for each row
  when (new.stripe_account_status is distinct from old.stripe_account_status)
  execute function public.set_stripe_onboarding_completed();

-- ---------------------------------------------------------------------------
-- 7. Cleanup-hint voor 0014 (NIET nu uitvoeren)
-- ---------------------------------------------------------------------------
-- In 0014_drop_legacy_psp.sql na succesvolle Stripe cutover (na 7 juli 2026):
--   alter table public.payments drop column mollie_payment_id;
--   alter table public.payments drop column checkout_url;
--   alter table public.payments drop column opp_transaction_uid;
--   alter table public.payments drop column opp_merchant_uid;
--   alter table public.payments drop column opp_status;
--   alter table public.payments drop column opp_completed_at;
--   alter table public.profiles drop column opp_merchant_uid;
--   alter table public.profiles drop column opp_compliance_level;
--   alter table public.profiles drop column opp_compliance_status;
--   alter table public.profiles drop column opp_can_receive_payments;
--   alter table public.profiles drop column opp_can_receive_payouts;
--   alter table public.profiles drop column opp_bank_account_uid;
--   alter table public.profiles drop column opp_bank_account_status;
--   alter table public.profiles drop column opp_contact_uid;
--   drop type public.opp_compliance_status;
--   drop view public.opp_onboarding_overview;
--   drop table public.payouts cascade;
--
-- Tot die tijd blijven die kolommen behouden voor data-integriteit en rollback-opties.

-- Klaar. Verifieer in Supabase Dashboard:
--  1. profiles bevat stripe_account_id + stripe_charges_enabled + peers
--  2. payments bevat stripe_payment_intent_id + stripe_application_fee_id
--  3. tabel stripe_webhook_events zichtbaar (initieel leeg)
--  4. view stripe_onboarding_overview retourneert lege set bij eerste run
