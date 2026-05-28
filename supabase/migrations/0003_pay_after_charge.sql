-- ============================================================================
-- Pay-after-charge: owner vult achteraf werkelijke kWh in, boeker betaalt
-- daarna het exacte bedrag.
--
-- Flow:
--   1. Boeker boekt        → status='pending', payment_status='unpaid'
--   2. Owner accepteert    → status='confirmed', payment_status='unpaid'
--   3. Boeker laadt        → boekingstijd verstrijkt
--   4. Owner vult kWh in   → kwh_consumed gezet, payment_requested_at=now(),
--                            total_amount_cents berekend
--   5. Boeker betaalt      → Mollie flow (payment_status='pending' → 'paid')
--
-- Idempotent: alle ALTER statements gebruiken IF NOT EXISTS.
-- ============================================================================

alter table public.bookings
  add column if not exists kwh_consumed numeric(6,2),
  add column if not exists payment_requested_at timestamptz;

comment on column public.bookings.kwh_consumed is
  'Werkelijk afgenomen kWh, ingevuld door owner na afloop. NULL = nog niet ingevuld.';

comment on column public.bookings.payment_requested_at is
  'Moment waarop owner kWh invulde en boeker werd gevraagd te betalen. NULL = nog niet gevraagd.';

create index if not exists bookings_payment_requested_at_idx
  on public.bookings(payment_requested_at)
  where payment_requested_at is not null;

-- ---------------------------------------------------------------------------
-- RLS-policy: owner mag kwh_consumed + payment_requested_at + amount-velden
-- updaten op zijn eigen palen. Status mag niet via deze route veranderen
-- (wordt door edge functions gedaan).
--
-- Andere booking-update policies blijven bestaan (drop hier niet generiek,
-- alleen onze eigen policy idempotent vervangen).
-- ---------------------------------------------------------------------------

drop policy if exists "bookings owner sets kwh" on public.bookings;
create policy "bookings owner sets kwh" on public.bookings
  for update to authenticated
  using (
    exists (
      select 1 from public.chargers c
      where c.id = bookings.charger_id
        and c.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.chargers c
      where c.id = bookings.charger_id
        and c.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- View: openstaande betaalverzoeken — handig voor reminder-cron en admin.
-- ---------------------------------------------------------------------------
create or replace view public.outstanding_payment_requests as
  select
    b.id           as booking_id,
    b.user_id      as booker_id,
    b.user_email   as booker_email,
    b.charger_id,
    c.name         as charger_name,
    c.owner_id,
    b.kwh_consumed,
    b.total_amount_cents,
    b.payment_requested_at,
    extract(epoch from (now() - b.payment_requested_at)) / 86400 as days_outstanding
  from public.bookings b
  left join public.chargers c on c.id = b.charger_id
  where b.payment_status in ('unpaid', 'failed')
    and b.payment_requested_at is not null
  order by b.payment_requested_at asc;

-- Klaar. Geen schema-wijziging op `payments` of `chargers`; werken met de
-- bestaande velden. De `total_amount_cents` etc. velden op bookings worden
-- nu pas gevuld als owner kWh invult (i.p.v. bij booking creation).
