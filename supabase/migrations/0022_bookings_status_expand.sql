-- ============================================================================
-- 0022_bookings_status_expand.sql — bookings.status: cancelled + rejected toevoegen
--
-- Bug: Flutter-app kon boekingen niet weigeren of annuleren. De update naar
-- status='rejected' (owner-weigert-inkomende-boeking) of status='cancelled'
-- (boeker-annuleert-bevestigde-boeking) faalde met:
--
--   PostgrestException(message: new row for relation "bookings" violates
--   check constraint "bookings_status_check", code: 23514)
--
-- Root cause: de check-constraint stond alleen ('pending', 'confirmed',
-- 'completed') toe. De app-code (lib/main.dart regel 14085 en 10137) probeerde
-- 'rejected' resp. 'cancelled' te zetten, en werd door Postgres geweigerd.
--
-- Fix: constraint droppen en opnieuw aanmaken met alle 5 statussen.
--
-- Semantisch onderscheid (belangrijk voor toekomstige refund/analytics-logica):
--   - pending    : boeking aangevraagd, wacht op accept/reject door eigenaar
--   - confirmed  : eigenaar accepteerde, sessie kan starten
--   - completed  : sessie afgerond en (indien van toepassing) betaald
--   - rejected   : eigenaar wees af VOOR acceptatie
--   - cancelled  : boeker OF eigenaar annuleerde NA acceptatie
--
-- Deze migratie is idempotent (drop IF EXISTS + add).
-- ============================================================================

alter table public.bookings drop constraint if exists bookings_status_check;

alter table public.bookings add constraint bookings_status_check
  check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'rejected'));

comment on constraint bookings_status_check on public.bookings is
  'Allowed booking lifecycle states. See migration 0022 for semantic definitions of each.';
