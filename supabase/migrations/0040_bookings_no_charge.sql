-- ============================================================================
-- 0040_bookings_no_charge.sql — bookings.no_charge kolom (task #371)
--
-- Waarom:
--   Na een boeking moet de host normaal het aantal afgenomen kWh invullen
--   ('Vul kWh in'-knop). Maar er zijn scenario's waarin GEEN lading heeft
--   plaatsgevonden:
--     - boeker kwam niet opdagen (no-show)
--     - boeker stak nooit de stekker in
--     - technische fout / paal uitgevallen aan het begin
--     - boeker besloot ter plekke toch niet te laden
--
--   Zonder deze vlag blijft de boeking permanent hangen op 'awaitingKwhInput'
--   in de Mijn Palen-lijst van de host. Dat werd al gemeld door meerdere
--   pioniers ("hoe kom ik van dat rode ballonnetje af?").
--
-- Semantiek:
--   no_charge = true  → host bevestigde dat er niks geladen is. De boeking
--                       is administratief afgerond, er komt geen betaalverzoek
--                       en de boeker krijgt een notificatie. Booking-status
--                       blijft 'confirmed' (of wat 'ie was) — we misbruiken
--                       de status-enum niet voor deze markering.
--   no_charge = false → default, normale pay-after-charge flow.
--
--   awaitingKwhInput in de app-code checkt vanaf nu ook op !no_charge, dus
--   de Vul kWh in-knop verdwijnt zodra de host op 'Geen lading' klikt.
--
-- MID-guard:
--   De app doet vóór het zetten van no_charge=true een pre-check tegen
--   charging_sessions (meter_stop_wh − meter_start_wh > drempel). Als er wél
--   geregistreerd verbruik is, wordt de flow geblokkeerd — anders zou een
--   host kunnen "vergeten" af te rekenen. Dat is UI-guard, niet DB-guard,
--   omdat we in de vroege fase nog niet elke boeking aan een MID-sessie
--   kunnen koppelen (manuele palen zonder OCPP).
--
-- Idempotent: gebruikt IF NOT EXISTS zodat re-apply veilig is.
-- ============================================================================

alter table public.bookings
  add column if not exists no_charge boolean not null default false;

comment on column public.bookings.no_charge is
  'Host markeerde de boeking als "geen lading" (no-show of geen stekker). '
  'True onderdrukt de Vul kWh in-prompt en slaat het betaalverzoek over. '
  'Boeker krijgt een notificatie. Zie migratie 0040 voor de rationale.';

-- Partial index: alleen queries die actief no_charge-boekingen zoeken,
-- profiteren hiervan. Bespaart schijfruimte t.o.v. een volle index.
create index if not exists bookings_no_charge_true_idx
  on public.bookings (charger_id, end_time)
  where no_charge = true;
