-- ============================================================================
-- 0033_chargers_public_ocpp_visibility.sql — Task #308
--
-- CONTEXT
-- ----------------------------------------------------------------------------
-- De publieke kaart in de Flutter-app onderscheidt vanaf de "grote OCPP-
-- onboarding build" twee soorten palen:
--
--   • Smart  — paal is aan het Pluggo CSMS gekoppeld (ocpp_charger_id != null),
--              de booker kan de laadsessie via de app starten/stoppen.
--   • Manueel — traditionele paal zonder OCPP-koppeling, boeker en eigenaar
--              regelen aan/uit fysiek zoals voorheen.
--
-- Voor die visuele differentiatie op de kaart (custom marker + filter-chip)
-- moet iedere ingelogde/anon user PER PAAL kunnen zien of hij smart is,
-- ZONDER de row-level toegang tot `chargers` uit te breiden.
--
-- De publieke view `chargers_public` (0010, 0016) toont bewust alleen fuzzy
-- lat/lng en publieke velden. `ocpp_charger_id` was column-level al
-- toegankelijk voor anon/authenticated (0030 safe cols), maar zat NIET in
-- de view — dus de map-query (`from('chargers_public').select()`) kreeg 'm
-- niet en de client kon de smart-vlag niet afleiden.
--
-- DESIGN
-- ----------------------------------------------------------------------------
-- Simpelste oplossing: `c.ocpp_charger_id` toevoegen aan de select-list van
-- `chargers_public`. Het is een niet-gevoelige identifier — het feit dat een
-- paal aan een CSMS hangt is juist marketing voor de eigenaar ("app-control!")
-- en informatief voor de boeker. Het RemoteStart/Stop-endpoint zelf zit
-- achter een owner/booker-check in de Edge Function, dus lekken van de ID
-- geeft geen aanvalsoppervlak.
--
-- ROW-LEVEL BLIJFT ONVERANDERD
-- ----------------------------------------------------------------------------
-- Zelfde security_invoker=true, zelfde chargers_select_for_public_view
-- policy. Alleen kolom-samenstelling van de view breidt uit.
--
-- FLUTTER-KANT (bijbehorende main.dart wijziging)
-- ----------------------------------------------------------------------------
--   • Charger.fromMap leest map['ocpp_charger_id'] al sinds task #293 —
--     die code hoeft niet aangepast. Zodra de kolom in de view zit rolt de
--     waarde vanzelf door naar de UI.
--   • _HomeScreenState._visibleMarkers vertakt vanaf nu op charger.ocppChargerId
--     om smart vs manueel markers te renderen (task #308).
--
-- IDEMPOTENT: create or replace view. Meerdere keren draaien is veilig.
-- ============================================================================

create or replace view public.chargers_public
  with (security_invoker = true) as
select
  c.id,
  c.name,
  c.address,
  c.lat_public as lat,
  c.lng_public as lng,
  c.price,
  c.type,
  c.available,
  c.solar,
  c.description,
  c.instructions,
  c.owner_id,
  c.owner_email,
  c.photo_urls,
  c.cable_included,
  c.access_type,
  c.created_at,
  jsonb_build_object('is_pioneer', coalesce(p.is_pioneer, false)) as owner_profile,
  -- NIEUW (0033): expose ocpp_charger_id zodat de publieke kaart smart-vs-
  -- manueel palen visueel kan onderscheiden. Zie header voor rationale.
  --
  -- STAAT ACHTERAAN (belangrijk!): CREATE OR REPLACE VIEW mag geen bestaande
  -- kolommen hernoemen/herordenen (Postgres error 42P16). Nieuwe kolommen
  -- moeten dus altijd aan het EIND worden toegevoegd, ná owner_profile.
  c.ocpp_charger_id
from public.chargers c
left join public.profiles p on p.id = c.owner_id;

comment on view public.chargers_public is
  'Publieke view van chargers met fuzzy locatie. security_invoker=true sinds 0016. Sinds 0033 bevat de view ook ocpp_charger_id zodat de kaart smart (CSMS-gekoppelde) van manueel-bedienbare palen kan onderscheiden. GRANT naar anon/authenticated blijft staan.';

grant select on public.chargers_public to anon, authenticated;

-- ============================================================================
-- ROLLBACK
-- ----------------------------------------------------------------------------
--   Recreate de view zonder `c.ocpp_charger_id` in de select-list (kopieer
--   uit 0016_security_advisor_definer_views.sql).
--
-- VERIFICATIE (na deploy)
-- ----------------------------------------------------------------------------
--   1. Als anon of authenticated:
--        select id, ocpp_charger_id from chargers_public limit 5;
--      → verwacht: rijen met ocpp_charger_id gevuld voor smart palen, null
--        voor manueel.
--   2. Flutter kaart-render: smart palen krijgen bliksem-marker, manueel
--        palen outlined marker, solar behoudt sun-icoon (met bliksem-badge
--        als ook smart). Filter-chips [Alle] [Smart] [Manueel] werken.
-- ============================================================================
