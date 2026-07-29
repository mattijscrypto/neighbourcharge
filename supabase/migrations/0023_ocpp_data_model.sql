-- ============================================================================
-- 0023_ocpp_data_model.sql — Data-model uitbreiding voor live laadschatting
--
-- Deze migratie voegt de velden toe die nodig zijn voor:
--   1. Realistische ETA-berekening tijdens een OCPP-laadsessie
--   2. Auto-stop bij target-SoC via RemoteStopTransaction
--   3. Weergave van laadtempo/vermogen in de app
--   4. Groene laadbalk-widget met huidige SoC-inschatting
--
-- Split over 3 tabellen:
--   - chargers.max_power_kw          — vermogen dat de paal maximaal levert
--   - profiles.vehicle_*             — voertuig-eigenschappen (model, accu, laadvermogen)
--   - bookings.target_soc_pct        — gewenste eind-SoC voor deze sessie (voor auto-stop)
--   - bookings.start_soc_pct         — huidige SoC bij start (optioneel — voor accurate ETA)
--
-- Alle velden zijn NULLABLE (behalve target_soc_pct met default) zodat bestaande
-- rijen niet breken. Missende data → app valt terug op conservatieve schattingen
-- op basis van gemeten laadtempo (kWh/uur uit MeterValues).
--
-- Idempotent: alle statements gebruiken IF NOT EXISTS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. chargers.max_power_kw — vermogen van de paal
--
-- Waarde in kW (bijv. 3.7, 7.4, 11.0, 22.0). Nullable omdat bestaande palen
-- zonder OCPP-integratie deze waarde nog niet ingevuld hebben. Wordt bij
-- paal-toevoegen/-bewerken uitgevraagd.
--
-- Wordt gebruikt om:
--   - "Verwacht laadvermogen" te tonen in de boekingsflow
--   - Sanity-check te doen op de MeterValues-delta (paal te traag = signaal)
--   - Bij ETA-berekening samen met vehicle.max_ac_kw de bottleneck te vinden:
--     effective_kw = LEAST(charger.max_power_kw, vehicle.max_ac_kw)
-- ---------------------------------------------------------------------------
alter table public.chargers
  add column if not exists max_power_kw numeric(4,1);

alter table public.chargers
  drop constraint if exists chargers_max_power_kw_range;
alter table public.chargers
  add constraint chargers_max_power_kw_range
  check (max_power_kw is null or (max_power_kw > 0 and max_power_kw <= 350));

comment on column public.chargers.max_power_kw is
  'Maximaal laadvermogen dat deze paal kan leveren (kW). Bijv. 3.7, 7.4, 11.0, 22.0. NULL = onbekend/nog niet ingevuld.';

-- ---------------------------------------------------------------------------
-- 2. profiles.vehicle_* — voertuig-eigenschappen
--
-- Één auto per profiel voor MVP. Bij multi-vehicle later: aparte
-- vehicles-tabel + profiles.default_vehicle_id.
--
-- vehicle_model              — vrije tekst (nu), later FK naar vehicles_catalog
-- vehicle_battery_capacity   — usable capacity in kWh (bijv. 77.0 voor ID.4 77kWh)
-- vehicle_max_ac_kw          — max AC-vermogen dat auto kan opnemen (11.0 default
--                              want de meeste NL-EV's hebben een 11kW on-board charger;
--                              oudere Zoe/Leaf beperkt tot 3.7-7.4)
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists vehicle_model text;

alter table public.profiles
  add column if not exists vehicle_battery_capacity_kwh numeric(5,1);

alter table public.profiles
  add column if not exists vehicle_max_ac_kw numeric(4,1);

alter table public.profiles
  drop constraint if exists profiles_vehicle_battery_capacity_range;
alter table public.profiles
  add constraint profiles_vehicle_battery_capacity_range
  check (vehicle_battery_capacity_kwh is null or
         (vehicle_battery_capacity_kwh >= 5 and vehicle_battery_capacity_kwh <= 250));

alter table public.profiles
  drop constraint if exists profiles_vehicle_max_ac_kw_range;
alter table public.profiles
  add constraint profiles_vehicle_max_ac_kw_range
  check (vehicle_max_ac_kw is null or
         (vehicle_max_ac_kw > 0 and vehicle_max_ac_kw <= 43));

comment on column public.profiles.vehicle_model is
  'Vrij tekstveld met EV-model, bijv. "Volkswagen ID.4". Wordt via preset-dropdown gevuld (task #286) maar users mogen ook custom invullen.';
comment on column public.profiles.vehicle_battery_capacity_kwh is
  'Usable batterij-capaciteit in kWh (niet gross). Gebruikt voor SoC-inschatting: current_soc_pct = start_soc_pct + (charged_kwh / capacity) * 100.';
comment on column public.profiles.vehicle_max_ac_kw is
  'Maximaal AC-laadvermogen dat de auto kan opnemen (kW). Cap voor charge rate: effective_kw = LEAST(charger.max_power_kw, this). Meestal 11.0 voor moderne NL-EV''s.';

-- ---------------------------------------------------------------------------
-- 3. bookings.target_soc_pct + start_soc_pct — SoC-targeting voor deze boeking
--
-- target_soc_pct — user's gewenste eind-SoC. Default 80% (batterij-vriendelijk,
--                  meest gangbare setting bij bewuste EV-rijders). Wordt gebruikt
--                  door de auto-stop-logic (task #289).
--
-- start_soc_pct — SoC waar de auto op staat NET VOOR laden begint. Optioneel:
--                 user kan 'm invullen in de app (via een slider "waar sta je nu
--                 op qua batterij?"). Zonder deze waarde valt de app terug op
--                 kWh-getal alleen — dan geen absolute SoC-inschatting, wel ETA.
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists target_soc_pct smallint not null default 80;

alter table public.bookings
  add column if not exists start_soc_pct smallint;

alter table public.bookings
  drop constraint if exists bookings_target_soc_pct_range;
alter table public.bookings
  add constraint bookings_target_soc_pct_range
  check (target_soc_pct >= 10 and target_soc_pct <= 100);

alter table public.bookings
  drop constraint if exists bookings_start_soc_pct_range;
alter table public.bookings
  add constraint bookings_start_soc_pct_range
  check (start_soc_pct is null or (start_soc_pct >= 0 and start_soc_pct <= 100));

alter table public.bookings
  drop constraint if exists bookings_soc_pct_order;
alter table public.bookings
  add constraint bookings_soc_pct_order
  check (start_soc_pct is null or start_soc_pct <= target_soc_pct);

comment on column public.bookings.target_soc_pct is
  'Gewenste eind-SoC voor deze laadsessie (10-100). Default 80% (batterij-vriendelijk). Trigger voor auto-stop via RemoteStopTransaction.';
comment on column public.bookings.start_soc_pct is
  'SoC waarop de auto stond bij start van de sessie (0-100). Optioneel, user vult in via slider. Nodig voor absolute SoC-inschatting; zonder deze waarde toont app alleen ETA in kWh/tijd, niet in "% vol".';

-- ---------------------------------------------------------------------------
-- 4. RLS — geen nieuwe policies nodig
--
-- profiles, bookings en chargers hebben al RLS aan met bestaande policies die
-- toegang regelen op basis van user_id/owner_id. De nieuwe kolommen erven die
-- policies automatisch.
-- ---------------------------------------------------------------------------
