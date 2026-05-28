-- ============================================================================
-- Pay-after-charge: automatische betaal-reminders.
--
-- Voegt last_reminder_sent_at toe aan bookings, en plant een dagelijkse
-- pg_cron job die de `send-payment-reminders` edge function aanroept.
--
-- Reminder-logica (zie edge function): boekingen waarvoor:
--   • payment_requested_at IS NOT NULL
--   • payment_status NOT IN ('paid','refunded')
--   • payment_requested_at < now() - 24h
--   • last_reminder_sent_at IS NULL OR last_reminder_sent_at < now() - 24h
-- krijgen een herinneringsmail. Daarna last_reminder_sent_at updaten.
--
-- Idempotent: alle statements gebruiken IF NOT EXISTS / CREATE OR REPLACE.
-- ============================================================================

alter table public.bookings
  add column if not exists last_reminder_sent_at timestamptz;

comment on column public.bookings.last_reminder_sent_at is
  'Laatste keer dat de boeker een betaal-herinneringsmail kreeg. NULL = nog geen reminder gestuurd.';

create index if not exists bookings_last_reminder_sent_at_idx
  on public.bookings(last_reminder_sent_at)
  where payment_requested_at is not null;

-- ---------------------------------------------------------------------------
-- pg_cron + pg_net extensies (voor het schedulen + HTTP-call naar edge fn).
--
-- Beide zijn standaard beschikbaar op Supabase, maar moeten één keer
-- aangezet worden in Database → Extensions, of via dit script.
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- Cron-job: elke dag om 09:00 UTC (= 11:00 NL zomertijd / 10:00 wintertijd)
-- de send-payment-reminders edge function aanroepen.
--
-- Gebruikt pg_net.http_post; de Authorization header bevat de service-role
-- key. Die staat in `vault` (Supabase Dashboard → Settings → Vault) zodat
-- 'm niet hardcoded in de migratie staat. Vul de vault-secret eenmalig in:
--   supabase secrets set SERVICE_ROLE_KEY=<eyJ...>     # niet nodig
--   OF in Dashboard → SQL Editor:
--     select vault.create_secret('<service_role_jwt>', 'service_role_key');
-- en stel je project URL als secret in:
--     select vault.create_secret('https://<ref>.supabase.co', 'supabase_url');
-- ---------------------------------------------------------------------------

-- Verwijder oude job met dezelfde naam (idempotent)
do $$
declare
  jid bigint;
begin
  select jobid into jid from cron.job where jobname = 'send-payment-reminders-daily';
  if jid is not null then
    perform cron.unschedule(jid);
  end if;
end $$;

select cron.schedule(
  'send-payment-reminders-daily',
  '0 9 * * *',  -- elke dag om 09:00 UTC
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url') || '/functions/v1/send-payment-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Klaar. Test handmatig met:
--   curl -X POST https://<ref>.supabase.co/functions/v1/send-payment-reminders \
--     -H "Authorization: Bearer <service_role_key>"
