-- ============================================================================
-- bypass_emails — dynamische date-gate bypass-lijst
--
-- Vóór de officiële launchdatum (zie [bookingsGoLiveAt] in main.dart, nu
-- 7 juli 2026) zijn alle boekingen vergrendeld. Sommige accounts mogen wél
-- boeken: Apple-reviewer, Google-reviewer, founders, en pre-launch testers
-- die we uitnodigen voor Mollie test-checkouts en smoke-tests.
--
-- Voorheen stond die lijst hardcoded in main.dart, wat betekent: elke nieuwe
-- tester = nieuwe .aab + nieuwe Play Store rollout = ~30 min werk + wachttijd.
-- Door 'm naar de DB te halen kan ik in Supabase Studio binnen 5 seconden
-- iemand toevoegen, en bij de eerstvolgende app-start (of na uit/inloggen)
-- valt de date-gate voor ze weg.
--
-- We slaan op email-niveau op (niet user_id) omdat we mensen willen kunnen
-- toevoegen vóórdat ze überhaupt een account hebben aangemaakt — zo kunnen
-- ze gewoon signupen en meteen door de gate heen.
--
-- Beheer: Supabase Studio → Table editor → bypass_emails → Insert row.
-- Voer de email in lowercase in (Supabase Auth normaliseert sowieso naar
-- lowercase, dus dat sluit aan).
--
-- Na de launch op [bookingsGoLiveAt] heeft deze tabel geen effect meer
-- (de date-gate is dan überhaupt niet meer actief). We kunnen 'm dan
-- behouden voor toekomstige feature-flags of leegmaken — geen haast.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabel
-- ---------------------------------------------------------------------------
create table if not exists public.bypass_emails (
  email     text primary key,
  added_at  timestamptz not null default now(),
  note      text
);

comment on table public.bypass_emails is
  'Email-adressen die de pre-launch date-gate mogen omzeilen. Beheerd via Supabase Studio. Email moet lowercase zijn (Supabase Auth normaliseert sowieso).';

comment on column public.bypass_emails.note is
  'Vrijetekstveld om bij te houden waarom iemand op de lijst staat (bijv. "Mollie test, mei 2026" of "Tjeerd, zwager Mattijs").';

-- ---------------------------------------------------------------------------
-- 2. RLS — user mag alleen z'n eigen rij zien
-- ---------------------------------------------------------------------------
-- We willen niet dat ingelogde users de hele tester-lijst kunnen zien
-- (dat is een privacy/security smell). Daarom: select-policy filtert op
-- de email uit de JWT van de huidige user. Iedereen ziet alleen z'n eigen
-- rij (of geen rij als 'ie er niet op staat).
--
-- Insert/update/delete: geen policies = geblokkeerd voor authenticated.
-- Service_role (Studio, edge functions) omzeilt RLS sowieso, dus daarvandaan
-- kunnen we wel schrijven.
alter table public.bypass_emails enable row level security;

drop policy if exists "bypass_emails_select_own" on public.bypass_emails;
create policy "bypass_emails_select_own"
  on public.bypass_emails
  for select
  to authenticated
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));

-- ---------------------------------------------------------------------------
-- 3. Pre-populate met huidige pre-launch testers
-- ---------------------------------------------------------------------------
-- Eerst toegevoegd in main.dart bypassEmails-lijst op 19 mei 2026, nu
-- verhuisd naar DB. Idempotent — kan veilig opnieuw gedraaid worden.
insert into public.bypass_emails (email, note) values
  ('13artjan@gmail.com',     'Pre-launch tester (Mollie test), 19 mei 2026'),
  ('merelsloot88@gmail.com', 'Pre-launch tester (Mollie test), 19 mei 2026'),
  ('mscholman84@gmail.com',  'Pre-launch tester (Mollie test), 19 mei 2026'),
  ('tjeerdsloot@gmail.com',  'Pre-launch tester (Mollie test), 19 mei 2026')
on conflict (email) do nothing;
