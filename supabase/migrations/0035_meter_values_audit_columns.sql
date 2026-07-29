-- ============================================================================
-- 0035_meter_values_audit_columns.sql — MeterValues audit-uitbreiding
--
-- Voegt drie kolommen toe aan charging_session_meter_values voor betere
-- fiscale/Eichrecht bewijskracht:
--
--   1. unit           — 'Wh', 'kWh', etc. Voorkomt onduidelijkheid bij audit
--                       of de bewaarde waarde daadwerkelijk in Wh is.
--   2. context        — OCPP MeterValues.sampledValue.context:
--                       'Transaction.Begin' / 'Sample.Periodic' /
--                       'Transaction.End' / 'Sample.Clock' / 'Interruption.Begin' /
--                       'Interruption.End' / 'Trigger' / 'Other'.
--                       Voor audit-trail: start- en stop-samples zijn de
--                       facturatie-relevante meetpunten, tussentijdse Sample.Periodic
--                       zijn indicatief.
--   3. signed_value   — Eichrecht/MID-signed value (indien paal 'm stuurt).
--                       Alfen Eve Mini met MID kan een signature meesturen die
--                       de meterstand cryptografisch verankert. Voor NL nu extra
--                       bewijs; voor DE-launch straks verplicht.
--
-- Alle drie zijn nullable — bestaande rijen breken niet.
-- Idempotent via IF NOT EXISTS.
-- ============================================================================

alter table public.charging_session_meter_values
  add column if not exists unit text,
  add column if not exists context text,
  add column if not exists signed_value text;

-- Partial index op context: alleen niet-null waarden worden gequeried
-- (voor "geef me alle Transaction.Begin/End samples van deze transactie").
create index if not exists meter_values_context_idx
  on public.charging_session_meter_values(transaction_id, context)
  where context is not null;

comment on column public.charging_session_meter_values.unit is
  'OCPP sampledValue.unit — meestal Wh. Als kWh binnenkomt is de opgeslagen meter_wh reeds ×1000 geconverteerd. Voor audit-transparantie.';

comment on column public.charging_session_meter_values.context is
  'OCPP MeterValues.sampledValue.context — welk type meting (Transaction.Begin/End = factuur-relevant, Sample.Periodic = indicatief tijdens sessie).';

comment on column public.charging_session_meter_values.signed_value is
  'Eichrecht/MID-signed meter value indien paal deze cryptografisch handtekent (Alfen Eve Mini MID). Extra bewijs bij geschil of DE-audit.';
