-- ============================================================================
-- Mollie payment integration — Fase 1 schema
--
-- Dit script kun je copy-pasten in Supabase Dashboard → SQL Editor → Run.
-- Het is idempotent: alle CREATE / ALTER statements gebruiken IF NOT EXISTS,
-- dus je kunt 't meerdere keren draaien zonder fouten.
--
-- Wat dit toevoegt:
--   • profiles.iban (voor uitbetalingen aan eigenaren)
--   • bookings: payment_status + bedrags-velden
--   • payments tabel (Mollie betalingen)
--   • refunds tabel (terugbetalingen)
--   • payouts tabel (uitbetalingen aan eigenaren)
--   • RLS policies zodat gebruikers alleen hun eigen data zien
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. IBAN-veld op profiles voor uitbetalingen aan eigenaren
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists iban text;

comment on column public.profiles.iban is
  'IBAN waarop de eigenaar zijn 95%-aandeel uitbetaald krijgt. Verplicht voor wie een paal aanbiedt.';

-- ---------------------------------------------------------------------------
-- 2. Enum voor betaalstatus
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type public.payment_status as enum (
      'unpaid',             -- nieuwe boeking, checkout nog niet gestart
      'pending',            -- Mollie checkout aangemaakt, wachten op afronding
      'paid',               -- succesvol betaald
      'failed',             -- mislukt of verlopen
      'refunded',           -- volledig terugbetaald
      'partially_refunded'  -- deels terugbetaald
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Bookings uitbreiden met betaalvelden
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists payment_status public.payment_status not null default 'unpaid',
  add column if not exists total_amount_cents integer,    -- Wat de boeker betaalt (incl. 5% fee)
  add column if not exists service_fee_cents integer,     -- Pluggo's deel (5%)
  add column if not exists owner_share_cents integer;     -- Eigenaar's deel (95%)

create index if not exists bookings_payment_status_idx
  on public.bookings(payment_status);

-- ---------------------------------------------------------------------------
-- 4. payments tabel — één rij per Mollie-betaalpoging
-- ---------------------------------------------------------------------------
create table if not exists public.payments (
  id                   uuid primary key default gen_random_uuid(),
  booking_id           uuid not null references public.bookings(id) on delete cascade,
  mollie_payment_id    text unique,
  amount_cents         integer not null,
  service_fee_cents    integer not null,
  owner_share_cents    integer not null,
  currency             text not null default 'EUR',
  status               public.payment_status not null default 'pending',
  checkout_url         text,
  paid_at              timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists payments_booking_id_idx        on public.payments(booking_id);
create index if not exists payments_mollie_payment_id_idx on public.payments(mollie_payment_id);
create index if not exists payments_status_idx            on public.payments(status);

-- ---------------------------------------------------------------------------
-- 5. refunds tabel — terugbetalingen
-- ---------------------------------------------------------------------------
create table if not exists public.refunds (
  id                uuid primary key default gen_random_uuid(),
  payment_id        uuid not null references public.payments(id) on delete cascade,
  mollie_refund_id  text unique,
  amount_cents      integer not null,
  reason            text not null,                      -- 'cancellation_24h' | 'owner_cancelled' | 'problem_reported' | 'manual'
  status            text not null default 'pending',    -- 'pending' | 'processed' | 'failed'
  created_at        timestamptz not null default now()
);

create index if not exists refunds_payment_id_idx on public.refunds(payment_id);

-- ---------------------------------------------------------------------------
-- 6. payouts tabel — uitbetalingen aan eigenaren
-- ---------------------------------------------------------------------------
create table if not exists public.payouts (
  id              uuid primary key default gen_random_uuid(),
  payment_id      uuid not null references public.payments(id) on delete cascade,
  owner_id        uuid not null references auth.users(id) on delete cascade,
  amount_cents    integer not null,
  iban            text not null,                        -- snapshot op moment van uitbetaling
  status          text not null default 'scheduled',    -- 'scheduled' | 'processing' | 'paid' | 'failed'
  scheduled_for   timestamptz not null default (now() + interval '7 days'),
  paid_at         timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists payouts_owner_id_idx on public.payouts(owner_id);
create index if not exists payouts_status_idx   on public.payouts(status);

-- ---------------------------------------------------------------------------
-- 7. updated_at-trigger (hergebruik bestaande functie of maak 'm aan)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. Row Level Security
-- ---------------------------------------------------------------------------

-- payments: zichtbaar voor boeker EN eigenaar van de geboekte paal.
-- Insert/update gaat alleen via service_role (edge functions).
alter table public.payments enable row level security;

drop policy if exists "payments selectable by participants" on public.payments;
create policy "payments selectable by participants" on public.payments
  for select to authenticated using (
    exists (
      select 1 from public.bookings b
      where b.id = payments.booking_id
        and (
          b.user_id = auth.uid()
          or exists (
            select 1 from public.chargers c
            where c.id = b.charger_id and c.owner_id = auth.uid()
          )
        )
    )
  );

-- refunds: zelfde logica als payments
alter table public.refunds enable row level security;

drop policy if exists "refunds selectable by participants" on public.refunds;
create policy "refunds selectable by participants" on public.refunds
  for select to authenticated using (
    exists (
      select 1 from public.payments p
      join public.bookings b on b.id = p.booking_id
      where p.id = refunds.payment_id
        and (
          b.user_id = auth.uid()
          or exists (
            select 1 from public.chargers c
            where c.id = b.charger_id and c.owner_id = auth.uid()
          )
        )
    )
  );

-- payouts: alleen de eigenaar mag zijn eigen uitbetalingen zien
alter table public.payouts enable row level security;

drop policy if exists "payouts selectable by owner" on public.payouts;
create policy "payouts selectable by owner" on public.payouts
  for select to authenticated using (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 9. Helper view: openstaande uitbetalingen (handig voor admin-dashboard)
-- ---------------------------------------------------------------------------
create or replace view public.pending_payouts as
  select
    p.id,
    p.owner_id,
    pr.full_name as owner_name,
    p.amount_cents,
    p.iban,
    p.scheduled_for,
    p.created_at,
    p.status
  from public.payouts p
  left join public.profiles pr on pr.id = p.owner_id
  where p.status in ('scheduled', 'processing')
  order by p.scheduled_for asc;

-- Klaar. Controleer in de Supabase Dashboard → Table Editor of payments,
-- refunds en payouts zichtbaar zijn, en of profiles.iban erbij staat.
