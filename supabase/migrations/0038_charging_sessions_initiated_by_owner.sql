-- ---------------------------------------------------------------------------
-- 0038_charging_sessions_initiated_by_owner.sql
--
-- Task #340 + #339: eigen-laden-flow (host laadt zijn eigen EV op zijn eigen
-- paal zonder boeking).
--
-- Voegt de vlag `initiated_by_owner` toe aan `charging_sessions` zodat we in
-- het host-dashboard onderscheid kunnen maken tussen:
--   • gastsessies (booker rijdt aan, betaalt via Stripe → verhuur-omzet)
--   • eigen-laden-sessies (owner laadt zijn eigen EV, géén Stripe-charge)
--
-- Waarom een aparte kolom en niet gewoon "booking_id is null"?
--   1. In principe kán een gastsessie ook zonder booking bestaan (bijvoorbeeld
--      als de CSMS een orphaned sessie krijgt van een paal die niet aan een
--      boeking hangt — dat is dan een fout-situatie, geen owner-sessie).
--   2. Een expliciete boolean laat ons per sessie zeker weten wat de intentie
--      was, ook als de booking-koppeling om onvoorziene redenen null wordt.
--   3. Postgres partial indexes op deze kolom maken de host-dashboard
--      queries snel (maand-aggregaat filtert op initiated_by_owner + status).
--
-- Filled by:
--   • CSMS: bij ontvangst van StartTransaction lookup: als de id_tag hoort
--     bij owner van de paal én er is geen bijhorende booking, zet true.
--   • remote-start-session edge function: wanneer initiated_by_owner=true in
--     de request body is gepasseerd, kan de CSMS deze vlag via een header
--     doorgezet krijgen (fase 2). Voor nu vertrouwen we op de id_tag-match.
-- ---------------------------------------------------------------------------

alter table public.charging_sessions
  add column if not exists initiated_by_owner boolean not null default false;

comment on column public.charging_sessions.initiated_by_owner is
  'true = owner laadt zijn eigen EV op zijn eigen paal (geen boeking, geen Stripe-charge). '
  'false = gastsessie of onverklaarde orphaned sessie.';

-- Partial index: host-dashboard maand-aggregaat filtert typisch op
-- (charger_id, status='completed', initiated_by_owner=<bool>, started_at >= X).
-- Kleine tabel op dit moment, maar dit voorkomt regressie later.
create index if not exists charging_sessions_owner_month_idx
  on public.charging_sessions(charger_id, started_at desc)
  where status = 'completed' and initiated_by_owner = true;

-- ---------------------------------------------------------------------------
-- RLS: de owner van de paal (via chargers.owner_id) mag zijn eigen sessies
-- lezen. Die policy is al aanwezig sinds 0021 (charging_sessions_owner_read)
-- en werkt óók voor eigen-laadsessies zonder booking — de policy filtert
-- puur op chargers.owner_id = auth.uid(), niet op booking-koppeling. Dus we
-- hoeven hier niets aan toe te voegen.
-- ---------------------------------------------------------------------------
