-- ============================================================================
-- 0014_stripe_checkout_session.sql — Stripe Checkout Session ID op payments
--
-- Achtergrond: na 3 dagen debuggen van een silent hang in
-- flutter_stripe 11.5.0 PaymentSheet op iOS 26.3.1 (FlutterSceneDelegate +
-- FlutterImplicitEngineDelegate maakt het onmogelijk voor de Stripe iOS SDK
-- om de presenting view controller te vinden — sheet rendert, maar
-- onzichtbaar) pivoteren we naar **Stripe Checkout via browser-redirect**.
--
-- In plaats van een native PaymentSheet maken we een Stripe-hosted Checkout
-- Session, openen die in Safari via url_launcher, en pollen na terugkeer
-- de booking.payment_status. De webhook blijft source-of-truth.
--
-- Voor deze flow hebben we een aparte identifier nodig:
--   • stripe_checkout_session_id (cs_test_… / cs_live_…) — bekend bij creatie
--   • stripe_payment_intent_id   (pi_…)                  — pas bekend ná betaling
--
-- Bij het aanmaken van de Checkout Session weten we de PI nog niet — die
-- wordt door Stripe pas aangemaakt zodra de gebruiker een betaalmethode
-- kiest. We slaan dus eerst alleen de session-id op; de webhook vult de
-- PI-id in zodra checkout.session.completed binnenkomt.
--
-- Idempotent: gebruikt IF NOT EXISTS.
-- ============================================================================

alter table public.payments
  add column if not exists stripe_checkout_session_id text unique;

comment on column public.payments.stripe_checkout_session_id is
  'Stripe Checkout Session ID (cs_…). Bron-van-waarheid voor welke checkout-flow bij deze payment hoort. PaymentIntent ID wordt pas gevuld na checkout.session.completed webhook.';

create index if not exists payments_stripe_checkout_session_id_idx
  on public.payments(stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

-- Klaar. Verifieer in Supabase Dashboard:
--  1. payments bevat stripe_checkout_session_id (text, unique, nullable)
--  2. Index payments_stripe_checkout_session_id_idx zichtbaar onder Indexes
