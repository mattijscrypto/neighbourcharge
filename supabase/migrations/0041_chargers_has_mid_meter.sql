-- Migration 0041 — has_mid_meter op chargers (task #372 / #338a)
--
-- MID = Meetinstrumenten Richtlijn. Een MID-gecertificeerde meter in de paal
-- levert juridisch geldige kWh-standen — vereist voor een officiële ERE-aanvraag.
-- Zonder MID kunnen we alleen een schatting tonen.
--
-- De waarde wordt gezet in de koppelwizard (stap 4, na succesvolle verbinding).
-- Default false — veilige kant: we claimen geen MID-certificering tenzij de
-- eigenaar dit expliciet bevestigt.

alter table public.chargers
  add column if not exists has_mid_meter boolean not null default false;

comment on column public.chargers.has_mid_meter is
  'True als de eigenaar heeft bevestigd dat zijn paal een MID-gecertificeerde '
  'energiemeter heeft. Vereist voor ERE-aanvraag en officiële kWh-rapportages. '
  'Gezet via de OCPP-koppelwizard na succesvolle BootNotification.';
