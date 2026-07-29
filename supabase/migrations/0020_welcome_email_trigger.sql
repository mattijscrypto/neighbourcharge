-- ============================================================================
-- Pluggo — welkomstmail-trigger
--
-- Verstuurt automatisch een Pluggo-gebrande welkomstmail zodra een nieuwe
-- gebruiker zijn e-mailadres heeft bevestigd.
--
-- Waarom op auth.users UPDATE ipv INSERT?
--   Bij signup is `email_confirmed_at` NULL. De gebruiker krijgt eerst de
--   confirmation-mail (auth-template). Pas als 'ie op de bevestig-link klikt
--   flipt `email_confirmed_at` van NULL naar een timestamp. Dat is het moment
--   waarop we een warme welkom sturen — niet eerder, want dan komt 'ie in het
--   niets terecht bij mensen die niet bevestigen.
--
-- Idempotent: guard voorkomt dubbele mails.
--   OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL
--
-- Waarom staat de functie in `public` ipv `auth`?
--   Supabase beschermt het auth-schema; migrations kunnen daar geen functies
--   aanmaken (permission denied). De trigger zelf mag wél op auth.users staan,
--   dus de functie leeft in public en de trigger verwijst ernaar.
--
-- Vereisten (staan al klaar uit migratie 0004):
--   • pg_net extensie
--   • vault secret 'supabase_url'
--   • vault secret 'service_role_key'
-- ============================================================================

create extension if not exists pg_net with schema extensions;

-- Cleanup: als een eerdere poging iets heeft achtergelaten, gooi 't weg.
-- (Geen drop op auth.<functie> — daar heeft de migration-role geen rechten voor,
-- en de eerdere failed push heeft in auth niks kunnen aanmaken sowieso.)
drop trigger if exists send_welcome_email on auth.users;

-- ---------------------------------------------------------------------------
-- Trigger-functie (in public schema)
--
-- SECURITY DEFINER omdat de trigger op auth.users draait en vault.decrypted_secrets
-- niet leesbaar is voor de standaard authenticator role. De functie is owned by
-- postgres en heeft dus rechten om vault te lezen én pg_net aan te roepen.
--
-- Fires "fire and forget": pg_net.http_post is async. Als de edge function 500t,
-- signup faalt NIET — de gebruiker is al bevestigd en ingelogd, dat is het
-- belangrijkste. Welkomstmail is een nice-to-have en falen is geen showstopper.
-- ---------------------------------------------------------------------------
create or replace function public.send_welcome_email_on_confirm()
returns trigger
language plpgsql
security definer
set search_path = extensions, public, vault, pg_temp
as $$
declare
  v_url  text;
  v_key  text;
begin
  -- Alleen vuren bij de flip van NULL → timestamp
  if old.email_confirmed_at is not null then
    return new;
  end if;
  if new.email_confirmed_at is null then
    return new;
  end if;

  -- Geen email? Dan kunnen we niks sturen. Skip stilletjes.
  if new.email is null or length(trim(new.email)) = 0 then
    return new;
  end if;

  -- Vault secrets ophalen. Als ze ontbreken loggen we een notice en gaan door
  -- zonder mail te sturen — signup mag hier absoluut niet op sneuvelen.
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'supabase_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'service_role_key';

  if v_url is null or v_key is null then
    raise notice 'send_welcome_email_on_confirm: vault secrets ontbreken, welkomstmail overgeslagen (user %)', new.id;
    return new;
  end if;

  -- Async HTTP POST — resultaat wordt in net._http_response gelogd,
  -- return-value hier gooien we weg.
  perform net.http_post(
    url     := v_url || '/functions/v1/send-welcome-email',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', new.id::text,
      'email',   new.email
    )
  );

  return new;
end;
$$;

comment on function public.send_welcome_email_on_confirm() is
  'Roept send-welcome-email edge function aan zodra een gebruiker zijn e-mail bevestigt (email_confirmed_at flipt NULL → timestamp). Fire-and-forget: signup mag hier nooit op falen.';

-- ---------------------------------------------------------------------------
-- Trigger op auth.users
-- ---------------------------------------------------------------------------
create trigger send_welcome_email
  after update of email_confirmed_at on auth.users
  for each row
  execute function public.send_welcome_email_on_confirm();

-- ---------------------------------------------------------------------------
-- Handmatig testen:
--   Trigger een confirmation via de app, of forceer via SQL:
--
--   update auth.users
--   set email_confirmed_at = now()
--   where id = '<user-uuid>' and email_confirmed_at is null;
--
--   Log-check:
--   select * from net._http_response order by created desc limit 5;
--   Of Supabase Dashboard → Edge Functions → send-welcome-email → Logs.
-- ---------------------------------------------------------------------------
