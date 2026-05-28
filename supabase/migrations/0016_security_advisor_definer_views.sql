-- ============================================================================
-- 0016_security_advisor_definer_views.sql — fix de 4 CRITICAL Security
-- Advisor errors die zichtbaar werden in de Supabase dashboard (25 mei 2026).
--
-- ERRORS
-- ----------------------------------------------------------------------------
--   1. Security Definer View — public.chargers_public
--   2. Security Definer View — public.pending_payouts
--   3. Security Definer View — public.outstanding_payment_requests
--   4. RLS Disabled in Public — public.stripe_webhook_events
--
-- ALGEMENE STRATEGIE
-- ----------------------------------------------------------------------------
-- Views in public schema draaien standaard met de rechten van de view-owner
-- (postgres superuser), wat RLS op de onderliggende tabellen omzeilt. De
-- Supabase advisor flagt dit als ERROR. Fix: WITH (security_invoker = true)
-- toevoegen, zodat de view onder de rechten van de caller draait en RLS dus
-- wel wordt afgedwongen.
--
-- Voor admin/cron-views die nooit door de Flutter-app aangeroepen worden
-- (pending_payouts, outstanding_payment_requests) doen we extra: REVOKE
-- toegang van anon/authenticated en GRANT enkel aan service_role.
--
-- Voor chargers_public (wel door Flutter map gebruikt) moeten we ervoor
-- zorgen dat de RLS-policies op chargers ook werken voor de "anyone met
-- de fuzzy lens" use-case — anders breekt de publieke kaart.
--
-- Idempotent: drops + create or replace + revoke/grant zijn safe om
-- opnieuw uit te voeren.
-- ============================================================================

-- ===========================================================================
-- 1. chargers_public  →  security_invoker = true
-- ===========================================================================
-- Definitie identiek aan 0010 r.113-135; alleen WITH-clause + RLS policies
-- op chargers om de invoker-flow te ondersteunen.
--
-- TRADE-OFF EXPLICIET BENOEMD:
-- De policy "chargers_select_for_public_view" hieronder is permissief
-- (USING true) zodat de view voor anon en authenticated werkt. Dit betekent
-- dat een gebruiker met de anon key technisch ook chargers DIRECT kan
-- bevragen (en dan exacte lat/lng zou krijgen). Dat is de status quo —
-- de huidige situatie zonder RLS was even open. Een verdere lockdown via
-- column-level GRANTs (alleen safe columns naar anon/authenticated) is
-- een follow-up taak (#188) — vereist Flutter-aanpassing voor owner/booker-
-- paden die wel de exact lat/lng nodig hebben.
-- ===========================================================================

-- Zorg dat RLS aanstaat op chargers (idempotent — geen effect als al aan)
alter table public.chargers enable row level security;

-- Policy 1: owner heeft volledige toegang op zijn eigen palen
drop policy if exists "chargers_owner_all" on public.chargers;
create policy "chargers_owner_all" on public.chargers
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Policy 2: een booker met een confirmed (of past confirmed) booking mag
-- de exacte rij zien — nodig voor het detailscherm na booking-bevestiging.
drop policy if exists "chargers_select_confirmed_booker" on public.chargers;
create policy "chargers_select_confirmed_booker" on public.chargers
  for select
  to authenticated
  using (
    exists (
      select 1 from public.bookings b
      where b.charger_id = chargers.id
        and b.user_id = auth.uid()
        and b.status = 'confirmed'
    )
  );

-- Policy 3: anyone (anon + authenticated) mag SELECTen — nodig zodat
-- chargers_public via security_invoker werkt voor de publieke kaart.
-- Zie TRADE-OFF hierboven: dit opent ook directe SELECT op chargers.
-- Mitigatie via column-level GRANT is follow-up.
drop policy if exists "chargers_select_for_public_view" on public.chargers;
create policy "chargers_select_for_public_view" on public.chargers
  for select
  to anon, authenticated
  using (true);

-- Recreate chargers_public met security_invoker = true (definitie identiek)
create or replace view public.chargers_public
  with (security_invoker = true) as
select
  c.id,
  c.name,
  c.address,
  c.lat_public as lat,
  c.lng_public as lng,
  c.price,
  c.type,
  c.available,
  c.solar,
  c.description,
  c.instructions,
  c.owner_id,
  c.owner_email,
  c.photo_urls,
  c.cable_included,
  c.access_type,
  c.created_at,
  jsonb_build_object('is_pioneer', coalesce(p.is_pioneer, false)) as owner_profile
from public.chargers c
left join public.profiles p on p.id = c.owner_id;

comment on view public.chargers_public is
  'Publieke view van chargers met fuzzy locatie. security_invoker=true sinds 0016 zodat RLS op chargers per-caller wordt afgedwongen i.p.v. via de view-owner (postgres). GRANT naar anon/authenticated blijft staan — de view zelf is bedoeld als publieke lens.';

grant select on public.chargers_public to anon, authenticated;

-- ===========================================================================
-- 2. pending_payouts  →  security_invoker = true + lockdown
-- ===========================================================================
-- Admin-debugging view uit 0001. Niet gebruikt door Flutter app of Edge
-- Functions (grep bevestigd). Veilig om alleen service_role-toegang te
-- geven.
-- ===========================================================================
create or replace view public.pending_payouts
  with (security_invoker = true) as
  select
    p.id,
    p.owner_id,
    pr.full_name as owner_name,
    p.amount_cents,
    p.iban,
    p.scheduled_for,
    p.created_at,
    p.status
  from public.payouts p
  left join public.profiles pr on pr.id = p.owner_id
  where p.status in ('scheduled', 'processing')
  order by p.scheduled_for asc;

comment on view public.pending_payouts is
  'Admin view van openstaande uitbetalingen. security_invoker=true + alleen service_role sinds 0016. Anon en authenticated hebben geen GRANT meer.';

revoke all on public.pending_payouts from public;
revoke all on public.pending_payouts from anon;
revoke all on public.pending_payouts from authenticated;
grant select on public.pending_payouts to service_role;

-- ===========================================================================
-- 3. outstanding_payment_requests  →  security_invoker = true + lockdown
-- ===========================================================================
-- Cron + admin view uit 0003. Niet gebruikt door Flutter app of Edge
-- Functions (grep bevestigd — wordt in code-comments genoemd maar nergens
-- in queries). Veilig om naar service_role te beperken.
-- ===========================================================================
create or replace view public.outstanding_payment_requests
  with (security_invoker = true) as
  select
    b.id           as booking_id,
    b.user_id      as booker_id,
    b.user_email   as booker_email,
    b.charger_id,
    c.name         as charger_name,
    c.owner_id,
    b.kwh_consumed,
    b.total_amount_cents,
    b.payment_requested_at,
    extract(epoch from (now() - b.payment_requested_at)) / 86400 as days_outstanding
  from public.bookings b
  left join public.chargers c on c.id = b.charger_id
  where b.payment_status in ('unpaid', 'failed')
    and b.payment_requested_at is not null
  order by b.payment_requested_at asc;

comment on view public.outstanding_payment_requests is
  'Cron + admin view van openstaande betaalverzoeken. security_invoker=true + alleen service_role sinds 0016.';

revoke all on public.outstanding_payment_requests from public;
revoke all on public.outstanding_payment_requests from anon;
revoke all on public.outstanding_payment_requests from authenticated;
grant select on public.outstanding_payment_requests to service_role;

-- ===========================================================================
-- 4. stripe_webhook_events  →  enable RLS, no policies (service_role only)
-- ===========================================================================
-- Webhook audit-log / idempotency-tabel. Alleen Edge Functions (via
-- service_role) schrijven en lezen hier. Geen Flutter access nodig.
-- service_role bypasst RLS standaard, dus geen policies nodig — RLS aan
-- met zero policies = niemand anders krijgt toegang.
-- ===========================================================================
alter table public.stripe_webhook_events enable row level security;

-- Expliciete REVOKE als dubbele veiligheidsmaatregel (default Supabase
-- GRANTs op nieuwe tabellen gaan naar anon/authenticated).
revoke all on public.stripe_webhook_events from public;
revoke all on public.stripe_webhook_events from anon;
revoke all on public.stripe_webhook_events from authenticated;
grant all on public.stripe_webhook_events to service_role;

comment on table public.stripe_webhook_events is
  'Audit-log + idempotency-guard voor Stripe webhooks. RLS aan sinds 0016; alleen service_role toegang.';

-- ============================================================================
-- ROLLBACK / VERIFICATIE
-- ----------------------------------------------------------------------------
-- Na deploy:
--   1. Supabase Dashboard → Security Advisor → "Rerun linter"
--   2. Verwacht: alle 4 errors weg
--   3. Smoke-test:
--      • Publieke kaart laden in app (logged out + logged in) — chargers
--        moeten zichtbaar zijn met fuzzy locatie
--      • Owner kan zijn eigen paal bewerken
--      • Confirmed booker ziet exacte locatie op detailscherm
--   4. Als de map breekt voor anon: check chargers RLS policies hierboven.
--
-- Follow-up (task #188): column-level GRANT op chargers zodat anon/authenticated
-- alleen de safe columns (id, name, address, lat_public, lng_public, price,
-- type, available, solar, description, owner_id, photo_urls, cable_included,
-- access_type, created_at) kunnen SELECTen. lat/lng/instructions/owner_email
-- worden dan ook via directe REST-query afgeschermd.
-- ============================================================================
