-- ============================================================================
-- 0018_iban_validation.sql — server-side NL-IBAN-validatie
--
-- Voorheen: client deed alleen structurele regex (^NL\d{2}[A-Z]{4}\d{10}$),
-- server vertrouwde blind. Een typo in de controlegetallen of een verzonnen
-- IBAN als NL00ABCD0000000000 kwam er ongezien doorheen — om pas bij de
-- eerste payout via Stripe Connect te bouncen.
--
-- Deze migratie:
--   1. is_valid_nl_iban(text) — PL/pgSQL functie met structuur + mod-97
--      checksum (ISO 13616). Spiegelt isValidNlIban() in lib/main.dart.
--   2. CHECK constraint op profiles.iban — NULL toegestaan (IBAN is optioneel
--      tot user payouts wil), niet-NULL moet geldig zijn.
--
-- NOT VALID: constraint wordt niet retroactief op bestaande rows toegepast.
-- Pre-launch heeft profiles mogelijk test-IBANs van eerdere flows; nieuwe
-- writes worden hoe dan ook gecheckt. Na opschoning kunnen we 'm valideren
-- met: alter table profiles validate constraint profiles_iban_valid;
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Validatie-functie
-- ---------------------------------------------------------------------------
create or replace function public.is_valid_nl_iban(input text)
returns boolean
language plpgsql
immutable
as $$
declare
  cleaned    text;
  rearranged text;
  numeric_str text := '';
  ch         char;
  i          int;
begin
  -- NULL = geen IBAN ingevuld; validatie zit elders (Stripe-onboarding).
  if input is null then
    return true;
  end if;

  cleaned := upper(replace(input, ' ', ''));

  -- Structurele check: NL + 2 cijfers + 4 letters + 10 cijfers = 18 tekens.
  if cleaned !~ '^NL[0-9]{2}[A-Z]{4}[0-9]{10}$' then
    return false;
  end if;

  -- ISO 13616 mod-97:
  --   • Eerste 4 tekens naar achter: ABCD0123456789NL12
  --   • Letters → 2-cijferige nummers (A=10, B=11, ... Z=35)
  --   • Resterende getal mod 97 moet 1 zijn.
  rearranged := substring(cleaned from 5) || substring(cleaned from 1 for 4);

  for i in 1..length(rearranged) loop
    ch := substring(rearranged from i for 1);
    if ch ~ '[0-9]' then
      numeric_str := numeric_str || ch;
    elsif ch ~ '[A-Z]' then
      -- A=10 → ascii('A')=65, dus -55.
      numeric_str := numeric_str || (ascii(ch) - 55)::text;
    else
      -- Onmogelijk na regex, maar defensief.
      return false;
    end if;
  end loop;

  -- numeric_str is ~24 cijfers (te groot voor bigint). NUMERIC kan dat aan.
  return (numeric_str::numeric % 97) = 1;
end;
$$;

comment on function public.is_valid_nl_iban(text) is
  'Valideert Nederlandse IBAN: structurele regex + ISO 13616 mod-97 checksum. NULL geeft true (IBAN is optioneel). Spiegelt isValidNlIban() in lib/main.dart.';

-- ---------------------------------------------------------------------------
-- 2. CHECK constraint op profiles.iban
-- ---------------------------------------------------------------------------
-- NOT VALID: bestaande rows worden niet gecheckt. Nieuwe writes wel.
-- Idempotent: drop-if-exists vóór create.
alter table public.profiles
  drop constraint if exists profiles_iban_valid;

alter table public.profiles
  add constraint profiles_iban_valid
  check (iban is null or public.is_valid_nl_iban(iban))
  not valid;

comment on constraint profiles_iban_valid on public.profiles is
  'Server-side IBAN-validatie als safety net naast client-side check in lib/main.dart. NOT VALID: bestaande pre-launch rows niet retroactief gecheckt — valideren na opschoning met: alter table profiles validate constraint profiles_iban_valid;';
