-- ============================================================================
-- Consolideer en repareer UPDATE-policies op public.bookings
--
-- Aanleiding: in productie zien we silent RLS-failures bij owner-update van
-- kwh_consumed. De DB had drie overlappende UPDATE-policies waarvan onduide-
-- lijk was welke domineerde, en sommige hadden een NULL with_check waardoor
-- de WITH CHECK fase impliciet faalt zodra meerdere policies actief zijn.
--
-- Deze migratie:
--   1. Drop alle bestaande UPDATE-policies op bookings (idempotent).
--   2. Maakt één heldere booker-policy:  user mag eigen booking updaten.
--   3. Maakt één heldere owner-policy:   eigenaar mag bookings op zijn palen
--      updaten (incl. kwh_consumed, payment_requested_at, bedragen).
--   Beide policies hebben expliciete USING én WITH CHECK.
--
-- Niet aangeraakt: SELECT, INSERT, DELETE policies.
-- ============================================================================

-- 1. Drop alle UPDATE-policies (we hernoemen tegelijk)
drop policy if exists "Gebruiker kan eigen boeking updaten" on public.bookings;
drop policy if exists "Owners can update bookings for their chargers" on public.bookings;
drop policy if exists "bookings owner sets kwh" on public.bookings;

-- 2. Booker mag eigen boeking updaten (status, etc.)
create policy "bookings_update_booker"
  on public.bookings
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. Owner mag bookings updaten op zijn eigen palen
create policy "bookings_update_owner"
  on public.bookings
  for update
  to authenticated
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

-- Klaar. Vanaf nu één en slechts één owner-UPDATE-policy met expliciete
-- WITH CHECK. De guard-trigger uit 0006 blijft actief en blokkeert nog steeds
-- post-payment kWh-wijzigingen.
