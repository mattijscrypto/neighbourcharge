-- ============================================================================
-- 0030_chargers_column_grants.sql — Task #241 (volledige #188-fix).
--
-- CONTEXT
-- ----------------------------------------------------------------------------
-- Sinds 0016 heeft public.chargers RLS aan met twee policies:
--
--   • chargers_owner_all              (FOR ALL, owner_id = auth.uid())
--   • chargers_select_for_public_view (FOR SELECT, USING true)
--
-- De tweede policy is er om de publieke kaart via `chargers_public`
-- (security_invoker = true) te laten werken voor anon + authenticated.
-- Bijkomend gevolg: elke ingelogde user kan óók DIRECT `chargers` querien
-- met `.select('lat, lng')` en zo de exacte huisadres-coördinaten van
-- iedere paal ophalen. `chargers_public` doet dat expres NIET (die geeft
-- alleen `lat_public / lng_public` fuzzy uit) — maar de policy laat de
-- directe query toe.
--
-- Task #188 was bedoeld om dit column-level dicht te zetten maar heeft
-- nooit een migratie gehad. #241 rondt het af.
--
-- DESIGN
-- ----------------------------------------------------------------------------
-- Twee bewegingen:
--
-- 1. SECURITY DEFINER helper `public.my_chargers()` die SETOF chargers
--    teruggeeft voor de ingelogde owner. Draait als postgres, dus
--    column-level REVOKEs raken 'm niet — de owner ziet altijd álle
--    kolommen van z'n eigen palen (incl. `lat, lng`).
--
-- 2. Column-level GRANT op public.chargers:
--    • REVOKE SELECT (all cols) FROM anon, authenticated
--    • GRANT SELECT (safe cols) TO anon, authenticated
--
--    Safe cols = alles wat `chargers_public` view al exposeert +
--    `max_power_kw` en `ocpp_charger_id` (feature-cols die ook via de
--    map/detail zichtbaar mogen zijn). Alleen `lat` en `lng` — de echte
--    huisadres-coords — blijven exclusief voor owner via my_chargers().
--
-- ROW-LEVEL BLIJFT ONVERANDERD
-- ----------------------------------------------------------------------------
-- We laten `chargers_select_for_public_view` (USING true) staan zodat
-- `chargers_public` blijft werken via security_invoker. De column-level
-- GRANT bepaalt WELKE kolommen zichtbaar zijn — de row-level policy
-- bepaalt WELKE rijen. Beide samen = defense in depth.
--
-- INSERT / UPDATE / DELETE
-- ----------------------------------------------------------------------------
-- Buiten scope. Die worden via `chargers_owner_all` (FOR ALL) geregeld
-- op row-niveau (owner_id = auth.uid()). Column-level INSERT/UPDATE zou
-- ook kunnen maar is nu niet nodig — er is geen kolom die een owner niet
-- mag beschrijven op z'n eigen rij.
--
-- FLUTTER-KANT (bijbehorende main.dart refactor)
-- ----------------------------------------------------------------------------
--   • MyChargersScreen._load (r9985)  → `.rpc('my_chargers')` i.p.v.
--     `.from('chargers').select().eq('owner_id', ...)`. Anders krijg je
--     alleen `lat_public/lng_public` in plaats van de echte lat/lng.
--   • AddChargerScreen insert-refetch → idem.
--   • Overige `.from('chargers').select('<safe col>')` sites blijven werken.
--
-- IDEMPOTENT: create or replace + revoke/grant if not exists guards waar
-- mogelijk. Deze migratie kan meerdere keren gedraaid worden zonder side
-- effects.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. SECURITY DEFINER helper voor de owner-view.
-- ---------------------------------------------------------------------------
create or replace function public.my_chargers()
returns setof public.chargers
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  -- Guard: anonieme aanroep krijgt niets. auth.uid() is null buiten
  -- een user-session (bijv. service_role of unauthenticated). Zonder
  -- deze guard zou `owner_id = null` altijd false geven en dus 0 rows
  -- returnen — technisch al veilig, maar deze early-return is explicieter.
  if auth.uid() is null then
    return;
  end if;

  return query
    select *
      from public.chargers
     where owner_id = auth.uid()
     order by created_at desc;
end;
$$;

comment on function public.my_chargers() is
  'SECURITY DEFINER wrapper. Retourneert alle chargers-kolommen (incl. exacte lat/lng) voor de ingelogde owner. Bedoeld als vervanging van .from(''chargers'').select().eq(''owner_id'', auth.uid()) nu column-level SELECT op chargers is dichtgezet voor authenticated (0030). Zie ook task #241.';

-- Anonymous users hebben hier niks te zoeken.
revoke all on function public.my_chargers() from public;
revoke all on function public.my_chargers() from anon;
grant execute on function public.my_chargers() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Column-level GRANTs op public.chargers.
-- ---------------------------------------------------------------------------
-- Eerst álle bestaande table-wide SELECT-grants intrekken (default van
-- Supabase kent SELECT toe aan anon+authenticated bij CREATE TABLE).
revoke select on public.chargers from anon;
revoke select on public.chargers from authenticated;
revoke select on public.chargers from public;

-- Vervolgens per kolom expliciet SELECT toekennen voor de safe subset.
-- Missende kolommen (lat, lng, en toekomstige OCPP-secrets) blijven
-- alleen bereikbaar via `my_chargers()` (owner-only) of via service_role
-- (Edge Functions).
grant select (
  id,
  owner_id,
  owner_email,
  name,
  address,
  lat_public,
  lng_public,
  price,
  type,
  available,
  solar,
  description,
  instructions,
  photo_urls,
  cable_included,
  access_type,
  created_at,
  max_power_kw,
  ocpp_charger_id
) on public.chargers to anon, authenticated;

-- INSERT/UPDATE/DELETE grants: laten staan zoals ze zijn (Supabase-default).
-- De row-level policy `chargers_owner_all` (WITH CHECK owner_id = auth.uid())
-- voorkomt dat een user rijen van een ander wijzigt of aanmaakt met een
-- andere owner_id dan zichzelf. Column-level UPDATE-restrictions zijn niet
-- nodig: er is geen kolom die een owner niet mag beschrijven op z'n eigen rij.

-- ============================================================================
-- ROLLBACK
-- ----------------------------------------------------------------------------
--   grant select on public.chargers to anon, authenticated;
--   drop function if exists public.my_chargers();
--
-- VERIFICATIE (na deploy)
-- ----------------------------------------------------------------------------
--   1. Publieke kaart laadt (anon + authenticated) — verwacht fuzzy coords.
--   2. Mijn palen scherm laadt — verwacht exacte coords + volle detail.
--   3. Als authenticated:
--        select lat, lng from chargers where owner_id != auth.uid() limit 1;
--      → verwacht: "permission denied for column lat".
--   4. Als authenticated:
--        select * from my_chargers();
--      → verwacht: alleen eigen rijen, incl. lat/lng.
-- ============================================================================
