-- =====================================================================
-- Migratie: kabel- en toegangs-info per laadpaal
-- Datum: 2026-04-28
-- Run in Supabase SQL Editor (Project → SQL Editor → New query → Run)
-- =====================================================================

-- 1. Twee nieuwe kolommen op `chargers`.
--    Defaults zijn de meest voorkomende keuzes (paal mét kabel,
--    oprit vrij toegankelijk), zodat bestaande rijen direct geldig zijn.
ALTER TABLE chargers
  ADD COLUMN IF NOT EXISTS cable_included BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE chargers
  ADD COLUMN IF NOT EXISTS access_type TEXT NOT NULL DEFAULT 'open';

-- 2. Constraint zodat we alleen de afgesproken access_type-waarden accepteren.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chargers_access_type_check'
  ) THEN
    ALTER TABLE chargers
      ADD CONSTRAINT chargers_access_type_check
      CHECK (access_type IN ('open', 'gate_code', 'doorbell', 'key', 'other'));
  END IF;
END$$;

-- 3. (Optioneel) Comment-velden zodat de Supabase Table Editor uitleg toont.
COMMENT ON COLUMN chargers.cable_included IS
  'TRUE = kabel hangt vast aan de paal, FALSE = lader brengt zelf kabel mee.';
COMMENT ON COLUMN chargers.access_type IS
  'Hoe een lader bij de paal komt. Eén van: open, gate_code, doorbell, key, other.';
