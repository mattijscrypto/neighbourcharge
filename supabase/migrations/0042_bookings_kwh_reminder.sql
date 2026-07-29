-- ============================================================================
-- 0042_bookings_kwh_reminder.sql — kWh-reminder push voor eigenaren (#12)
--
-- Na het aflopen van een boeking moet de eigenaar de verbruikte kWh invullen
-- zodat de boeker kan betalen. Als de eigenaar dat vergeet sturen we na 2 uur
-- een push-herinnering via de `send-kwh-reminders` edge function.
--
-- Wat dit doet:
--   1. Voegt kwh_reminder_sent_at kolom toe aan bookings.
--   2. Plant een pg_cron job die elke 15 minuten de edge function aanroept.
--
-- Idempotent: alle statements gebruiken IF NOT EXISTS / CREATE OR REPLACE.
-- ============================================================================

alter table public.bookings
  add column if not exists kwh_reminder_sent_at timestamptz;

comment on column public.bookings.kwh_reminder_sent_at is
  'Tijdstip waarop de eigenaar een push-herinnering kreeg om kWh in te vullen. NULL = nog geen reminder verstuurd. One-shot: we sturen maximaal één reminder per boeking.';

-- Index: alleen boekingen die kandidaat zijn voor een reminder.
create index if not exists bookings_kwh_reminder_candidates_idx
  on public.bookings(end_time)
  where
    status = 'confirmed'
    and kwh_consumed         is null
    and payment_requested_at is null
    and kwh_reminder_sent_at is null
    and no_charge            = false;

-- ---------------------------------------------------------------------------
-- pg_cron + pg_net extensies (al aangemaakt in 0004, maar idempotent).
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- Cron-job: elke 15 minuten send-kwh-reminders aanroepen.
--
-- Vault-secrets die vooraf aangemaakt moeten zijn (eenmalig in SQL Editor):
--   select vault.create_secret('https://<ref>.supabase.co', 'supabase_url');
--   select vault.create_secret('<service_role_jwt>', 'service_role_key');
-- (deze zijn waarschijnlijk al aangemaakt voor de betaal-reminders — hergebruik ze)
-- ---------------------------------------------------------------------------

do $$
declare
  jid bigint;
begin
  select jobid into jid from cron.job where jobname = 'send-kwh-reminders-15min';
  if jid is not null then
    perform cron.unschedule(jid);
  end if;
end $$;

select cron.schedule(
  'send-kwh-reminders-15min',
  '*/15 * * * *',   -- elke 15 minuten
  $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url')
               || '/functions/v1/send-kwh-reminders',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- Klaar. Test handmatig:
--   curl -X POST https://<ref>.supabase.co/functions/v1/send-kwh-reminders \
--     -H "Authorization: Bearer <service_role_key>"
