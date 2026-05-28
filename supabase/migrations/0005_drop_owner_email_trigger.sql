-- ============================================================================
-- Drop de Postgres trigger die owner-new-booking mails stuurde.
--
-- Reden: alle email-verzending gaat nu via de centrale `send-email` edge
-- function. De Flutter app roept die ook al aan voor de owner-mail
-- (functie `_sendNewRequestEmailToOwner`), dus de trigger is dubbelop
-- en zou tot dubbele mails leiden.
--
-- De trigger gebruikte ook nog `onboarding@resend.dev` als sender — werkt
-- alleen naar de Resend-account-eigenaar zelf, dus is in de praktijk al
-- broken voor productie. Vervangen door de edge function die `noreply@pluggoapp.nl`
-- gebruikt (na domein-verificatie in Resend).
--
-- Idempotent: gebruikt IF EXISTS / DROP IF EXISTS.
-- ============================================================================

-- Trigger op bookings tabel verwijderen
drop trigger if exists on_booking_insert_notify on public.bookings;

-- Trigger function ook verwijderen (geen andere triggers gebruiken 'm)
drop function if exists public.notify_owner_new_booking();

-- get_resend_api_key() helper kan blijven staan — eventueel later nog
-- bruikbaar voor andere triggers. Geen kwaad als 'ie ongebruikt is.

-- Klaar. Owner-new-booking mails komen nu via:
--   Flutter (_sendNewRequestEmailToOwner)
--     → supabase.functions.invoke('send-email', ...)
--     → Resend API met noreply@pluggoapp.nl
