-- ============================================================================
-- 0015_security_advisor_auth_users_views.sql — fix CRITICAL Supabase
-- Security Advisor finding "auth_users_exposed" (25 mei 2026).
--
-- ACHTERGROND
-- ----------------------------------------------------------------------------
-- Drie views in het public schema selecteerden `email` direct uit auth.users:
--
--   1. public.stripe_onboarding_overview  (0013_stripe_payment_schema.sql)
--   2. public.opp_onboarding_overview     (0012_opp_payment_schema.sql)
--   3. public.pending_invoice_emails      (0012_opp_payment_schema.sql)
--
-- Views in public draaien standaard met de rechten van de view-owner
-- (postgres-superuser), wat RLS op auth.users effectief omzeilt. Default
-- grants in Supabase op public-views gaan naar anon + authenticated, dus
-- iedereen met de publieke anon key (die in onze Flutter-app gecompileerd
-- zit en dus reverse-engineerbaar is) kon alle user-emails ophalen.
--
-- BESLUIT
-- ----------------------------------------------------------------------------
-- • De twee OPP-views droppen — dead code na de OPP→Stripe refactor
--   (task #176). Niet meer in gebruik door Flutter app of Edge Functions.
-- • stripe_onboarding_overview behouden maar afdichten:
--     – recreëren met `WITH (security_invoker = true)` zodat RLS per
--       caller wordt geëvalueerd (Postgres 15+, ondersteund door Supabase).
--     – REVOKE op anon, authenticated en public.
--     – GRANT SELECT alleen aan service_role (Edge Functions / admin debugging).
--
-- Geen impact op Flutter app: grep bevestigt dat lib/main.dart deze view
-- nergens query't. Stond enkel in STRIPE_DEPLOYMENT.md als "queryable for
-- admin verification" — admin kan dat alsnog via service_role of dashboard.
--
-- Idempotent: drop is `if exists`, view-recreate is `create or replace`,
-- revoke/grant zijn ook idempotent.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Drop dead OPP-views
-- ---------------------------------------------------------------------------
drop view if exists public.opp_onboarding_overview;
drop view if exists public.pending_invoice_emails;

-- ---------------------------------------------------------------------------
-- 2. Recreate stripe_onboarding_overview met security_invoker
--
-- Definitie identiek aan 0013 r.132-160; alleen WITH-clause toegevoegd.
-- ---------------------------------------------------------------------------
create or replace view public.stripe_onboarding_overview
  with (security_invoker = true) as
  select
    p.id                              as profile_id,
    p.full_name,
    -- email staat in auth.users, niet in public.profiles.
    -- Met security_invoker=true wordt deze SELECT geëvalueerd onder de
    -- rechten van de caller. auth.users heeft RLS waardoor een caller
    -- alleen zijn eigen rij ziet — voor andere users komt NULL terug,
    -- niet hun email. Voor service_role (Edge Functions) gelden geen
    -- RLS-restricties, dus die ziet alles zoals voorheen.
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
  'Per-paaleigenaar overzicht van Stripe Connect onboarding-voortgang. '
  'security_invoker=true sinds 0015; alleen toegankelijk via service_role. '
  'Anon en authenticated rollen hebben geen GRANT meer.';

-- ---------------------------------------------------------------------------
-- 3. Lock down grants — REVOKE op anon/authenticated/public, GRANT alleen
--    aan service_role. Idempotent.
-- ---------------------------------------------------------------------------
revoke all on public.stripe_onboarding_overview from public;
revoke all on public.stripe_onboarding_overview from anon;
revoke all on public.stripe_onboarding_overview from authenticated;
grant select on public.stripe_onboarding_overview to service_role;

-- ---------------------------------------------------------------------------
-- 4. Sanity check — log de fix in een migrations-log indien gewenst.
--    (Geen aparte tabel hiervoor; comment volstaat als audit-trail.)
-- ---------------------------------------------------------------------------

-- ============================================================================
-- ROLLBACK (manueel — copy/paste in psql)
-- ----------------------------------------------------------------------------
-- 1. opp_onboarding_overview en pending_invoice_emails terughalen door 0012
--    relevante regels opnieuw uit te voeren (zie 0012_opp_payment_schema.sql
--    r.170-220).
-- 2. stripe_onboarding_overview terug naar default:
--      create or replace view public.stripe_onboarding_overview as <0013 def>;
--      grant select on public.stripe_onboarding_overview to anon, authenticated;
--
-- ⚠️ Doe rollback alléén als de OPP-views echt nog ergens nodig blijken.
--    Standaard pad: deze migratie blijft staan, OPP-code is definitief gedrop.
-- ============================================================================
