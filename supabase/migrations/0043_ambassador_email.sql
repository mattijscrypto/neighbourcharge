-- ============================================================================
-- 0043_ambassador_email.sql — ambassadeurs-mail 48 uur na aanmelding
--
-- Nieuwe gebruikers krijgen 48 uur na e-mailbevestiging een losse mail
-- met een verwijzing naar de ambassadeurspagina (pluggoapp.nl/ambassadeur).
-- Dit is bewust NIET de welkomstmail — mensen moeten de app eerst even
-- gezien hebben voor we ze vragen te helpen groeien.
--
-- Wat dit doet:
--   1. Voegt ambassador_email_sent_at kolom toe aan profiles.
--   2. Plant een pg_cron job die elk uur de edge function aanroept.
--
-- Edge function: send-ambassador-email
-- De function pikt zelf kandidaten op: profiles waarvan created_at tussen
-- 48 en 72 uur geleden valt én ambassador_email_sent_at nog NULL is.
--
-- Idempotent: alle statements gebruiken IF NOT EXISTS / CREATE OR REPLACE.
-- ============================================================================

alter table public.profiles
  add column if not exists ambassador_email_sent_at timestamptz;

comment on column public.profiles.ambassador_email_sent_at is
  'Tijdstip waarop de ambassadeurs-mail is verstuurd. NULL = nog niet verstuurd. One-shot: maximaal één mail per gebruiker.';

-- Index: alleen profielen die kandidaat zijn voor de ambassadeurs-mail.
create index if not exists profiles_ambassador_email_candidates_idx
  on public.profiles(created_at)
  where ambassador_email_sent_at is null;

-- ---------------------------------------------------------------------------
-- pg_cron + pg_net extensies (al aangemaakt in 0004, maar idempotent).
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net  with schema extensions;

-- ---------------------------------------------------------------------------
-- Cron-job: elk uur send-ambassador-email aanroepen.
--
-- Vault-secrets die vooraf aangemaakt moeten zijn (eenmalig in SQL Editor):
--   select vault.create_secret('https://<ref>.supabase.co', 'supabase_url');
--   select vault.create_secret('<service_role_jwt>', 'service_role_key');
-- (waarschijnlijk al aangemaakt voor eerdere cron-jobs — hergebruik ze)
-- ---------------------------------------------------------------------------

do $$
declare
  jid bigint;
begin
  select jobid into jid from cron.job where jobname = 'send-ambassador-email-hourly';
  if jid is not null then
    perform cron.unschedule(jid);
  end if;
end $$;

select cron.schedule(
  'send-ambassador-email-hourly',
  '0 * * * *',   -- elk uur
  $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url')
               || '/functions/v1/send-ambassador-email',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- Klaar. Test handmatig:
--   curl -X POST https://<ref>.supabase.co/functions/v1/send-ambassador-email \
--     -H "Authorization: Bearer <service_role_key>"
