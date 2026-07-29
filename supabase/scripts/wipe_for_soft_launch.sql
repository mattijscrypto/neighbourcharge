-- ============================================================
-- WIPE-script — Pluggo soft-launch 22 juni 2026
-- ============================================================
--
-- Doel: alle test-data verwijderen, schema/RLS/policies/edge-functions
-- ongemoeid laten. Daarna is de DB schoon voor publieke launch.
--
-- BEHOUDEN:
--   - schema, indexes, RLS-policies, triggers, functions, edge functions
--   - storage buckets (alleen objects worden geleegd)
--   - bypass_emails (Apple/Google review-accounts blijven werken)
--   - migrations history
--   - Supabase secrets / API keys / project config
--
-- WIPED:
--   - alle auth.users (geen account behouden — bevestigd 22 juni 2026)
--   - alle profiles
--   - alle chargers (geen palen behouden — bevestigd)
--   - alle bookings + reviews + booker_reviews + payments
--   - alle messages + conversations
--   - alle availability_slots
--   - alle user_devices (push-tokens)
--   - alle payouts / refunds / invoices
--   - alle stripe_webhook_events (test-events)
--   - storage objects in 'avatars' en 'chargers' buckets
--
-- HOE TE RUNNEN:
--   1. Open Supabase Studio → SQL Editor
--   2. Selecteer het juiste PRODUCTION project (DUBBEL CHECKEN)
--   3. Plak deze hele file
--   4. Run als service_role (standaard in SQL editor)
--   5. Lees onderaan de count-output — alles moet 0 zijn
--
-- ⚠️  STRIPE CONNECT ACCOUNTS:
--   Stripe Connect accounts (test-eigenaren) blijven bestaan in Stripe zelf.
--   Als je in LIVE mode bent zijn die niet aangemaakt (test mode only).
--   Check via dashboard.stripe.com/connect/accounts of er live-mode
--   accounts staan die opgeschoond moeten worden.
--
-- ⚠️  NIET TERUG TE DRAAIEN.
--   Maak een backup vóór je runt (Supabase → Database → Backups).
-- ============================================================

BEGIN;

-- ---------- VEILIGHEIDSCHECK ----------
-- Tel huidige rijen vóór wipe — uitkomst loggen voordat we deleten.
DO $$
DECLARE
  v_users int;
  v_profiles int;
  v_chargers int;
  v_bookings int;
BEGIN
  SELECT count(*) INTO v_users FROM auth.users;
  SELECT count(*) INTO v_profiles FROM public.profiles;
  SELECT count(*) INTO v_chargers FROM public.chargers;
  SELECT count(*) INTO v_bookings FROM public.bookings;
  RAISE NOTICE 'PRE-WIPE COUNTS — users:% profiles:% chargers:% bookings:%',
    v_users, v_profiles, v_chargers, v_bookings;
END $$;

-- ---------- 1. CHILDREN VAN BOOKINGS ----------
DELETE FROM public.booker_reviews;
DELETE FROM public.reviews;
DELETE FROM public.payments;
DELETE FROM public.payouts;
DELETE FROM public.refunds;
DELETE FROM public.invoices;

-- ---------- 2. STRIPE WEBHOOK LOG ----------
DELETE FROM public.stripe_webhook_events;

-- ---------- 3. CHAT ----------
DELETE FROM public.messages;
DELETE FROM public.conversations;

-- ---------- 4. PUSH TOKENS ----------
DELETE FROM public.user_devices;

-- ---------- 5. BOOKINGS + AVAILABILITY ----------
DELETE FROM public.availability_slots;
DELETE FROM public.bookings;

-- ---------- 6. CHARGERS ----------
DELETE FROM public.chargers;

-- ---------- 7. PROFILES ----------
DELETE FROM public.profiles;

-- ---------- 8. STORAGE OBJECTS ----------
-- Verwijder alle foto's uit avatars + chargers buckets.
DELETE FROM storage.objects WHERE bucket_id = 'avatars';
DELETE FROM storage.objects WHERE bucket_id = 'chargers';

-- ---------- 9. AUTH USERS (LAATSTE) ----------
-- bypass_emails blijft ongemoeid; die tabel bevat alleen e-mail-strings,
-- geen FK naar auth.users.
DELETE FROM auth.users;

-- ---------- POST-WIPE CHECK ----------
DO $$
DECLARE
  v_users int;
  v_profiles int;
  v_chargers int;
  v_bookings int;
  v_storage int;
BEGIN
  SELECT count(*) INTO v_users FROM auth.users;
  SELECT count(*) INTO v_profiles FROM public.profiles;
  SELECT count(*) INTO v_chargers FROM public.chargers;
  SELECT count(*) INTO v_bookings FROM public.bookings;
  SELECT count(*) INTO v_storage FROM storage.objects WHERE bucket_id IN ('avatars','chargers');
  RAISE NOTICE 'POST-WIPE COUNTS — users:% profiles:% chargers:% bookings:% storage:%',
    v_users, v_profiles, v_chargers, v_bookings, v_storage;
  IF v_users > 0 OR v_profiles > 0 OR v_chargers > 0 OR v_bookings > 0 OR v_storage > 0 THEN
    RAISE EXCEPTION 'Wipe incompleet — er staan nog rijen. ROLLBACK door exception.';
  END IF;
END $$;

COMMIT;

-- ============================================================
-- KLAAR. Verifieer in Supabase Studio:
--   - Authentication → Users: 0
--   - Table Editor → profiles / chargers / bookings: 0 rijen
--   - Storage → avatars + chargers buckets: 0 objects
-- ============================================================
