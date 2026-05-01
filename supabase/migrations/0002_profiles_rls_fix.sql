-- ============================================================================
-- Fix: profiles RLS toestaan dat een ingelogde gebruiker zijn eigen rij
-- INSERT en UPDATE.
--
-- Achtergrond: bij het opslaan van een IBAN doet de app een upsert. Voor
-- accounts die vóór de handle_new_user-trigger zijn aangemaakt bestaat er
-- nog geen rij in profiles, dus de upsert valt terug op INSERT — en die
-- werd geblokkeerd door RLS.
--
-- Idempotent: gebruikt drop policy if exists + create policy. Mag
-- meerdere keren gedraaid worden.
-- ============================================================================

alter table public.profiles enable row level security;

-- SELECT: iedereen mag zijn eigen profiel zien (en in de toekomst ook
-- andere profielen voor naam-weergave bij reviews/boekingen).
drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own" on public.profiles
  for select to authenticated using (true);

-- INSERT: alleen je eigen rij (id moet matchen met auth.uid())
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
  for insert to authenticated with check (id = auth.uid());

-- UPDATE: alleen je eigen rij
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
