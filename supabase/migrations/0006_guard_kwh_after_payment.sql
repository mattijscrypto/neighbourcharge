-- ============================================================================
-- Guard: blokkeer wijzigingen aan bookings.kwh_consumed zodra er een Mollie
-- betaling in flight is (pending) of voltooid (paid).
--
-- Aanleiding (bug #67-gerelateerd): in productie data zien we boekingen waar
-- `kwh_consumed` ná de betaling is veranderd. Concreet:
--   - Boeker betaalt €2,59 via Mollie voor 7,4 kWh
--   - Owner opent "Vul kWh in" opnieuw, vult 25 kWh in → DB heeft nu kwh=25
--   - UI toont voortaan 25 × prijs als "totaal", maar boeker betaalde €2,59
--   - Klanten verwarring + mogelijk financieel scheef
--
-- De Flutter app heeft sinds bug #65 een client-side pre-check
-- (`_enterKwhForBooking` in lib/main.dart, lijn ~10616). Die werkt voor
-- normale flow, maar:
--   • beschermt niet tegen race conditions
--   • beschermt niet tegen oudere app-versies
--   • beschermt niet tegen directe DB-calls (bv. via Supabase REST)
--
-- Server-side trigger is single source of truth.
--
-- Refunds / admin-correcties: een superuser of service_role kan dit alsnog
-- omzeilen door eerst payment_status terug te zetten naar 'unpaid', óf door
-- de trigger tijdelijk te disablen. Voor de toekomst (#55 Refunds + payouts)
-- bouwen we een aparte admin-functie als dat patroon vaker voorkomt.
--
-- Idempotent: gebruikt CREATE OR REPLACE + DROP IF EXISTS.
-- ============================================================================

create or replace function public.guard_kwh_consumed_after_payment()
returns trigger
language plpgsql
as $$
begin
  -- Alleen relevant als kwh_consumed daadwerkelijk wijzigt (IS DISTINCT FROM
  -- vangt ook null→waarde en waarde→null netjes af).
  if new.kwh_consumed is distinct from old.kwh_consumed then
    if old.payment_status in ('pending', 'paid') then
      raise exception
        'Kan kWh niet meer wijzigen — er is al een betaling (% status) voor deze boeking. Neem contact op met support voor een correctie of terugstorting.',
        old.payment_status
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_kwh_consumed_after_payment on public.bookings;

create trigger trg_guard_kwh_consumed_after_payment
before update on public.bookings
for each row
execute function public.guard_kwh_consumed_after_payment();

-- Klaar. Vanaf nu geeft elke poging om kwh_consumed te wijzigen op een
-- pending/paid booking een Postgres exception. De Flutter catch (e) bij
-- _enterKwhForBooking toont 'm in een SnackBar.
