# Mollie Connect refactor — implementatieplan

*Laatst bijgewerkt: 21 mei 2026*

## Context

Pluggo gebruikt momenteel de standaard Mollie Payments API met één merchant-account (Pluggo BV). Alle betalingen komen op Pluggo's balans binnen; uitbetalingen aan paaleigenaren zouden separaat via SEPA gaan. Deze constructie houdt geld voor derden aan en valt daarmee onder Wft-vergunningsplicht (PSD2 art. 4 lid 3) — niet wenselijk pre-launch.

Oplossing: migreren naar **Mollie Connect for Partners**. Elke paaleigenaar wordt een Mollie sub-merchant met eigen KYC en eigen settlement-IBAN. Pluggo blijft alleen "platform" en heeft daarmee geen vergunning nodig. Pluggo's commissie wordt geïnd als `applicationFee` per betaling.

Bijkomende vereiste: omdat paaleigenaren juridisch de verkoper worden, moet Pluggo een **facturatie-engine** bouwen die per laadsessie de juiste documenten genereert (self-billing onder art. 35e Wet OB), en kwartaaloverzichten voor de BTW-aangifte van ondernemers-paaleigenaren.

**Deadline**: live vóór 7 juli 2026 (booking go-live), met buffer voor migratie van bestaande test-payments.

## Beslispunten

### Reeds besloten (21 mei 2026)
- **KOR voor Pluggo BV**: Pluggo zit al in de KOR via bestaande KvK-inschrijving. Geen BTW op application fees. Sjablonen en boekhouding daarop ingericht.
- **Bemiddelings-vrijstelling art. 11.1.i**: niet relevant — KOR levert al hetzelfde effect zonder de juridische onzekerheid.
- **Realtime drempel-waarschuwingen voor paaleigenaren**: uit scope. Particulieren halen geen €20k laadpaal-omzet; bedrijfs-paaleigenaren weten zelf wanneer ze de drempel naderen.

### Nog open (input nodig van jurist, kleinere scope dan gedacht)
1. **Self-billing constructie art. 35e Wet OB**: bevestigen dat clausule in ToS voldoende is om Pluggo te machtigen facturen namens paaleigenaren op te maken. Quick juridisch advies (~€300-€500), niet per se een full fintech-consult.
2. **Wft-positie**: 30-min telefonische bevestiging door fintech-advocaat dat Connect-constructie Pluggo definitief buiten vergunningsplicht houdt. Verzekering tegen verkeerde aanname; ~€250-€500.
3. **v1 scope: alleen particulier-paaleigenaar?** 95%+ van paaleigenaren is particulier voor launch. Voorstel: bouw v1 alleen voor particulier (`business_type = particulier`), voeg `kor_freelancer` + `vat_liable` flows toe in v1.1 zodra eerste BTW-plichtige paaleigenaar zich aanmeldt. Versimpelt invoice-engine drastisch.

## Fase-overzicht en geschatte werktijd

| Fase | Onderwerp | Geschat | Blokkeert |
|---|---|---|---|
| 0 | Mollie KYC + partnercontract (Pluggo zelf) | wachten op Mollie | alles |
| 1 | OAuth app registreren bij Mollie | 0,5 dag | fase 3 |
| 2 | Database-migratie (BTW-velden + invoice-velden) | 0,5 dag | fase 3,4,5 |
| 3 | Edge function refactor: `create-payment` voor Connect | 3 dagen | fase 5 |
| 4 | Paaleigenaar onboarding-flow in Flutter app | 4 dagen | live-gang |
| 5 | Invoice-engine (PDF generator + e-mail) | 4 dagen | live-gang |
| 6 | Kwartaaloverzicht-engine + cron | 2 dagen | post-launch ok |
| 7 | Privacy + ToS updates voor Connect-constructie | 0,5 dag | live-gang |
| 8 | Migratie test-data + €1,79 balans | 0,5 dag | live-gang |
| 9 | Smoke test end-to-end met testaccount | 1 dag | live-gang |

**Totaal**: ~16 werkdagen, exclusief wachttijd op Mollie KYC en advocaten. Realistische doorlooptijd 3-4 weken bij parallelle werkstromen.

---

## Fase 0 — Mollie account setup

**Doel**: Pluggo's eigen Mollie partner-account is geverifieerd, partnercontract is getekend, app is geregistreerd in Mollie's dashboard.

### Stappen

1. **Verstrek informatie** (gele warning op dashboard wegwerken)
   - KvK uittreksel Pluggo BV
   - UBO-verklaring
   - ID-bewijs Mattijs
   - Pluggo settlement IBAN (zakelijke rekening waar application fees binnenkomen)
   - Bedrijfsadres + website

2. **Onderteken partnercontract** — lees voorwaarden door, let op:
   - Maandelijkse minima of opstartkosten
   - Tarieven voor application fees (per Connect transactie)
   - Aansprakelijkheidsclausules richting sub-merchants

3. **Registreer een OAuth app**
   - Naam: "Pluggo"
   - Redirect URI: `https://<pluggo-domain>/mollie/oauth/callback` of `pluggo://mollie-oauth-callback` voor mobile redirect
   - Scopes: `onboarding.read`, `payments.read`, `payments.write`, `profiles.read`, `organizations.read`
   - Noteer `client_id` + `client_secret` → toevoegen aan Supabase secrets (`MOLLIE_OAUTH_CLIENT_ID`, `MOLLIE_OAUTH_CLIENT_SECRET`)

**Acceptatiecriterium**: Pluggo's Mollie dashboard toont status "ready" voor het partner-account; OAuth credentials zijn opgeslagen in Supabase Vault.

---

## Fase 1 — Database-migratie

**Bestand**: nieuwe migratie `supabase/migrations/0002_mollie_connect_schema.sql`

### Wijzigingen aan bestaande tabellen

```sql
-- profiles: BTW/ondernemer-status + Mollie OAuth tokens
alter table public.profiles
  add column if not exists business_type text
    check (business_type in ('particulier', 'kor_freelancer', 'vat_liable'))
    default 'particulier',
  add column if not exists kvk_number text,
  add column if not exists vat_number text,
  add column if not exists mollie_organization_id text,        -- Mollie sub-merchant ID na onboarding
  add column if not exists mollie_access_token text,            -- versleuteld via supabase vault
  add column if not exists mollie_refresh_token text,           -- versleuteld via supabase vault
  add column if not exists mollie_onboarding_status text
    check (mollie_onboarding_status in ('not_started', 'needs_data', 'in_review', 'completed', 'rejected'))
    default 'not_started',
  add column if not exists mollie_can_receive_payments boolean default false,
  add column if not exists mollie_can_receive_settlements boolean default false,
  add column if not exists invoice_counter integer default 0,   -- per-user doorlopende factuurnummering
  add column if not exists ytd_revenue_cents integer default 0; -- YTD omzet voor KOR-monitoring

-- bookings: BTW-uitsplitsing op niveau van de boeking
alter table public.bookings
  add column if not exists owner_vat_amount_cents integer default 0,  -- BTW die paaleigenaar moet afdragen
  add column if not exists platform_fee_vat_cents integer default 0;  -- BTW op Pluggo's application fee (0 bij KOR)

-- payments: koppeling naar gegenereerde factuur + Mollie Connect velden
alter table public.payments
  add column if not exists application_fee_cents integer,        -- = service_fee_cents in nieuwe model
  add column if not exists mollie_organization_id text,           -- welke sub-merchant heeft betaald
  add column if not exists invoice_id uuid references public.invoices(id),
  add column if not exists receipt_url text;                      -- ontvangstbewijs booker
```

### Nieuwe tabellen

```sql
-- invoices: één rij per gegenereerde factuur (zowel booker-ontvangstbewijs als paaleigenaar-application-fee-factuur)
create table public.invoices (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references auth.users(id),
  booking_id          uuid references public.bookings(id),
  payment_id          uuid references public.payments(id),
  invoice_type        text not null check (invoice_type in (
    'booker_receipt',         -- ontvangstbewijs voor de booker (kan zonder BTW als particuliere verkoper)
    'platform_fee',           -- Pluggo's application fee factuur aan paaleigenaar
    'quarterly_summary'       -- kwartaaloverzicht voor paaleigenaar's BTW-aangifte
  )),
  invoice_number      text not null,                   -- bv "P-2026-00042" of "F-2026-0007"
  pdf_url             text not null,                   -- Supabase Storage URL
  total_cents         integer not null,
  vat_cents           integer not null default 0,
  vat_rate_bp         integer not null default 0,      -- BTW-tarief in basis points (2100 = 21%)
  issued_at           timestamptz not null default now(),
  recipient_email     text,
  email_sent_at       timestamptz,
  created_at          timestamptz not null default now()
);

create index invoices_owner_id_idx     on public.invoices(owner_id);
create index invoices_booking_id_idx   on public.invoices(booking_id);
create index invoices_invoice_type_idx on public.invoices(invoice_type);
create unique index invoices_number_unique on public.invoices(owner_id, invoice_number);

-- quarterly_statements: kwartaaloverzichten voor paaleigenaren
create table public.quarterly_statements (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references auth.users(id),
  year                integer not null,
  quarter             integer not null check (quarter between 1 and 4),
  total_revenue_cents integer not null,
  total_vat_cents     integer not null,
  pdf_url             text not null,
  generated_at        timestamptz not null default now(),
  email_sent_at       timestamptz
);

create unique index quarterly_statements_period on public.quarterly_statements(owner_id, year, quarter);
```

### RLS-aanvullingen

- `invoices`: zichtbaar voor `owner_id = auth.uid()` voor select.
- `quarterly_statements`: zichtbaar voor `owner_id = auth.uid()` voor select.
- Inserts gaan alleen via service-role (edge functions).

### `payouts` tabel — wat doen we hiermee?

Bij Connect betaalt Mollie zelf uit aan de paaleigenaar's Mollie balance, en die kan zelf uitbetalen naar IBAN. Onze `payouts` tabel werd in fase 1 gebouwd om Pluggo's eigen uitbetalingsproces te tracken — die functionaliteit vervalt. **Voorstel**: tabel laten staan voor historische data van de test-fase, geen nieuwe rijen meer schrijven, en deprecation-comment toevoegen.

**Acceptatiecriterium**: migratie draait schoon in een lege Supabase staging-omgeving. Bestaande `payments` rows krijgen geen non-null waarde voor `application_fee_cents` (kunnen we via backfill doen op basis van bestaande `service_fee_cents`).

---

## Fase 2 — `create-payment` edge function refactor

**Bestand**: `supabase/functions/create-payment/index.ts`

### Wat verandert

In de huidige flow doet de edge function:
```
POST https://api.mollie.com/v2/payments
Authorization: Bearer <PLUGGO_MOLLIE_API_KEY>
```

In de Connect flow wordt het:
```
POST https://api.mollie.com/v2/payments
Authorization: Bearer <PAALEIGENAAR_ACCESS_TOKEN>      # OAuth token van de specifieke sub-merchant
body: {
  amount: { currency: "EUR", value: "4.20" },
  description: "Pluggo boeking — <chargername>",
  redirectUrl: ...,
  webhookUrl: ...,
  metadata: { booking_id, user_id, charger_id },
  applicationFee: {
    amount: { currency: "EUR", value: "0.70" },        # Pluggo's commissie + small-session fee
    description: "Pluggo platformfee"
  }
}
```

### Logica-wijzigingen

1. **Token-ophalen**: voor elke betaling de paaleigenaar's `mollie_access_token` uit `profiles` halen. Token-refresh-logica toevoegen (Mollie OAuth tokens hebben een expiration; bij 401 → refresh via `MOLLIE_OAUTH_CLIENT_ID/SECRET` → opnieuw proberen).

2. **Pre-flight check**: vóór payment-creatie verifiëren dat de paaleigenaar's `mollie_can_receive_payments = true`. Anders → 409 met instructie "paaleigenaar moet eerst onboarding afronden".

3. **Application fee berekenen**: identiek aan huidige `serviceFeeCents`, dus `kWh × €0,06 + (kWh < 10 ? €0,40 : 0)`. Plus BTW als Pluggo niet in KOR zit.

4. **Webhook URL** blijft hetzelfde (`<supabaseUrl>/functions/v1/mollie-webhook`), maar de webhook payload bevat nu `_links.organization` met de sub-merchant ID — die moeten we koppelen aan de juiste paaleigenaar.

5. **Idempotency guard** (bug #72 fix): blijft werken; check op bestaande pending payments per booking_id blijft staan.

### Bestand: `supabase/functions/mollie-oauth-callback/index.ts` (nieuw)

OAuth callback handler. Wordt aangeroepen door Mollie na succesvolle paaleigenaar-onboarding:

1. Ontvangt `code` + `state` query parameter
2. Wisselt `code` in voor `access_token` + `refresh_token` via Mollie OAuth endpoint
3. Slaat tokens op in `profiles` (versleuteld via Supabase Vault)
4. Haalt organization details op (`/v2/organizations/me` met het verse token) → slaat `mollie_organization_id`, `business_type`, etc. op
5. Redirect terug naar app via `pluggo://mollie-oauth-success` deep link

### Bestand: `supabase/functions/mollie-webhook/index.ts` (uitbreiding)

Bestaat al voor payment-events. Toevoegen:

1. **Onboarding-status events**: Mollie stuurt webhook bij wijziging van sub-merchant onboarding status. Handler moet:
   - `profile_id` uit webhook → corresponderende user vinden
   - `mollie_onboarding_status` updaten
   - Bij `completed`: `mollie_can_receive_payments = true`, push notification "Je kunt nu paalverhuur ontvangen!"
   - Bij `rejected`: push + email naar paaleigenaar met instructie

2. **Settlement events**: Mollie betaalt periodiek uit naar paaleigenaar's IBAN. Voor onze administratie loggen we deze events in een `mollie_settlements` tabel (alleen lees-doeleinden, geen flow-impact).

**Acceptatiecriterium**: end-to-end test in Mollie's test-modus met twee test-accounts (Pluggo + een dummy paaleigenaar) waarbij een €5 betaling correct splitst: €4,30 naar paaleigenaar, €0,70 application fee naar Pluggo.

---

## Fase 3 — Paaleigenaar onboarding-flow in Flutter app

**Bestand**: `lib/main.dart` + nieuw `lib/mollie_onboarding.dart`

### User journey

```
[Profiel → "Mijn palen" → "Nieuwe paal toevoegen"]
  ↓
Heb je al een Mollie-account gekoppeld?  (= mollie_can_receive_payments check)
  ↓ Nee
  → Welkomsscherm: "Voor uitbetalingen via Mollie"
  ↓
BTW-vragenlijst (3 schermen)
  ↓
Redirect naar Mollie hosted onboarding via OAuth
  ↓
(Mollie KYC: ID, IBAN, evt. KvK voor zakelijk)
  ↓
Terug in app via deep link → success screen
  ↓
Vervolgen met paal-toevoegen
```

### BTW-vragenlijst — concept screens

**Scherm 1**: *"Hoe ga je je laadpaal gebruiken?"*
- "Als particulier — ik deel m'n paal als bijverdienste" → `business_type = particulier`
- "Via mijn bedrijf (eenmanszaak/BV)" → ga naar scherm 2

**Scherm 2** (alleen bij ondernemer): *"Hoe is je BTW-status?"*
- "Ik gebruik de KOR (kleineondernemersregeling) — onder €20.000 omzet, geen BTW" → `business_type = kor_freelancer`
- "Ik ben BTW-plichtig, ik draag 21% af" → `business_type = vat_liable` → vraag KvK + BTW-nummer

**Scherm 3**: uitleg + disclaimer

Per categorie de tekst zoals eerder besproken (particulier: geen BTW, IB-aangifte; KOR: geen BTW, jaarlijks controleren; BTW-plichtig: 21% afdragen, kwartaalaangifte).

Onderaan altijd: *"Pluggo is geen fiscaal adviseur. Raadpleeg bij twijfel een belastingadviseur of de Belastingdienst."*

### Mollie OAuth redirect

In Flutter:

```dart
final mollieOAuthUrl = Uri.https('my.mollie.com', '/oauth2/authorize', {
  'client_id': mollieClientId,
  'redirect_uri': '<supabase>/functions/v1/mollie-oauth-callback',
  'state': userId,                       // CSRF + user koppeling
  'scope': 'onboarding.read payments.read payments.write profiles.read',
  'response_type': 'code',
});

await launchUrl(mollieOAuthUrl, mode: LaunchMode.externalApplication);
```

Na callback redirect Mollie terug via `pluggo://mollie-oauth-success?user_id=<id>` → app refresht `profiles` → toont success.

### Blockers in de bestaande UI

- **"Mijn palen" → "Nieuwe paal"**: blokkeren tot `mollie_can_receive_payments = true`, anders melding "Voltooi je Mollie-koppeling eerst".
- **Bestaande palen van paaleigenaren zonder Mollie-koppeling**: bij migratie (fase 8) een banner op hun profiel "Voltooi je Mollie-koppeling vóór 7 juli, anders worden je palen tijdelijk verborgen."

### IBAN-veld op profiel

Wordt overbodig. `profiles.iban` blijft staan voor backward compat maar wordt niet meer gebruikt. Mollie houdt het IBAN nu. Taak #144 ("IBAN validatie") kunnen we sluiten als "obsolete door Connect".

**Acceptatiecriterium**: een nieuwe testgebruiker kan zonder hulp door de complete onboarding-flow heen en eindigt met `mollie_can_receive_payments = true`.

---

## Fase 4 — Invoice-engine (automatische factuurgeneratie)

**Bestanden**:
- `supabase/functions/generate-invoice/index.ts` (nieuw)
- `supabase/functions/_shared/pdf-templates/booker-receipt.ts` (nieuw)
- `supabase/functions/_shared/pdf-templates/platform-fee-invoice.ts` (nieuw)

### Trigger

In de bestaande `mollie-webhook` handler, bij payment-status = `paid`:

1. Roep `generate-invoice` aan voor de booker (ontvangstbewijs).
2. Roep `generate-invoice` aan voor de paaleigenaar (Pluggo's application fee factuur).
3. E-mail beide PDFs naar de relevante ontvanger via Resend.

### PDF-generatie

Library: **pdf-lib** (Deno-compatible, lichtgewicht, geen externe service nodig).

Alternatief overwegen: **Puppeteer/Browserless** voor HTML→PDF (rijkere layout maar zwaarder), of Mollie's eigen invoice-API (alleen voor Mollie's transactiekosten — niet voor onze use case).

### Sjablonen per `business_type` van de paaleigenaar

**Booker-receipt (particulier-paaleigenaar)**:
```
Pluggo
Ontvangstbewijs

Datum: 21 mei 2026
Sessie: <charger-naam> in <stad>
Verbruikt: 12,3 kWh × €0,30 = €3,69
Pluggo platformfee: €0,40
Totaal betaald: €4,09

Verkoper: <paaleigenaar-naam> (particulier)
Betaalmethode: iDEAL via Mollie
Betalingsreferentie: <mollie_payment_id>

Geen omzetbelasting van toepassing (particuliere verkoop).
```

**Booker-receipt (BTW-plichtige paaleigenaar)**:
```
[zelfde header]
Verbruikt: 12,3 kWh × €0,2479 ex BTW = €3,05
21% BTW: €0,64
Pluggo platformfee: €0,40 (incl 21% BTW)
Totaal betaald: €4,09

Verkoper: <bedrijfsnaam>
KvK: <kvk>
BTW-nummer: <btw>
Factuurnummer: <invoice_number>  (zoals "P-<eigenaar-suffix>-2026-00042")
```

**Platform-fee factuur (Pluggo → paaleigenaar)** — KOR-versie (definitief):
```
Pluggo BV
Factuur platformfee

Aan: <paaleigenaar-naam>
Periode: sessie <booking_id>, datum <date>

Bemiddelingsdienst Pluggo: €0,40
Totaal: €0,40

Factuurnummer: F-2026-<doorlopend>
Pluggo BV, KvK <pluggo-kvk>

Geen omzetbelasting verschuldigd op grond van art. 25 Wet OB (KOR).
```

Geen `vat_rate_bp` of `vat_cents` op platform-fee facturen — Pluggo is KOR-vrijgesteld.

### Doorlopende factuurnummering

Per paaleigenaar een eigen reeks. Implementatie: `profiles.invoice_counter` increment in een transactie, inclusief jaar in de string. Voor Pluggo's platform-fee facturen een aparte counter (gewoon `pluggo_invoice_counter` als app-config of in een aparte tabel).

### Storage

PDFs opslaan in Supabase Storage bucket `invoices` met path `<owner_id>/<year>/<invoice_number>.pdf`. RLS: alleen owner kan lezen (en service-role natuurlijk).

### E-mail flow

Bestaande `send-email` edge function (Resend) uitbreiden met:
- Template: `booker-receipt-email` met PDF als bijlage
- Template: `platform-fee-invoice-email` voor de paaleigenaar

**Acceptatiecriterium**: bij een test-payment in Mollie test-mode worden binnen 30 sec na webhook twee PDFs gegenereerd en geëmaild — booker krijgt ontvangstbewijs, paaleigenaar krijgt platformfee-factuur.

---

## Fase 5 — Kwartaaloverzicht-engine

**Bestand**: `supabase/functions/generate-quarterly-statement/index.ts` (nieuw)

### Cron

Supabase pg_cron (of externe scheduler) op de 5e van januari/april/juli/oktober om 03:00:

```sql
select cron.schedule(
  'generate-quarterly-statements',
  '0 3 5 1,4,7,10 *',
  $$select net.http_post(
    url := 'https://<project>/functions/v1/generate-quarterly-statement',
    headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
  );$$
);
```

### Logica

Voor elke paaleigenaar met `business_type in ('kor_freelancer', 'vat_liable')` (particulieren krijgen alleen een jaaroverzicht in januari voor hun IB-aangifte):

1. Verzamel alle `bookings` met `payment_status = 'paid'` waar `chargers.owner_id = <eigenaar>` in het afgelopen kwartaal.
2. Genereer PDF met headertabel (paaleigenaar, kwartaal, BTW-positie) + per-sessie regels (datum, kWh, omzet ex BTW, BTW, omzet incl) + totalen onderaan.
3. Update `profiles.ytd_revenue_cents` (reset 1 januari).
4. Email naar paaleigenaar.

**v1-scope notitie**: omdat we starten met alleen particulier-paaleigenaren (zie beslispunten), is deze fase post-launch werk. Eerst v1 live, kwartaaloverzichten bouwen wanneer de eerste KOR-/BTW-plichtige paaleigenaar zich aanmeldt.

**Acceptatiecriterium**: handmatige trigger van de cron job genereert correcte PDF voor een test-paaleigenaar met meerdere boekingen in een kwartaal.

---

## Fase 6 — Privacy + ToS updates voor Connect-constructie

**Bestanden**: `docs/privacy.html`, `docs/terms.html`

### Privacy.html — substantiële herziening (niet alleen aanvulling zoals eerder geschat)

In het Connect-model is Pluggo niet meer de verwerker van betaal/IBAN-data — die data zit bij Mollie als verwerkingsverantwoordelijke van de paaleigenaar. Aanpassingen:

- **Sectie 2** (gegevens die wij verzamelen): IBAN/betaaldata UIT, vervangen door "type bedrijf, KvK-nummer en BTW-nummer (indien van toepassing) — alleen om correcte facturen te genereren". `mollie_organization_id` benoemen als ID-data.
- **Sectie 5** (verwerkers): Mollie verschuift naar "derde partij waarmee de paaleigenaar een eigen verwerkersrelatie heeft". FCM/push notifications toevoegen (was al een gat).
- **Sectie 6** (bewaartermijnen): factuurdata 7 jaar (Belastingdienst-verplichting), `mollie_access_token` zolang account actief is, daarna direct verwijderen.
- **Datum** bijwerken naar live-go-datum.

### Terms.html — self-billing-clausule + KOR-disclaimer

Nieuwe paragraaf toevoegen:

> *Door je laadpaal beschikbaar te stellen via Pluggo machtig je Pluggo om namens jou facturen op te maken voor de stroom die je verkoopt aan boekers (self-billing op grond van art. 35e Wet OB). Pluggo zorgt voor doorlopende factuurnummering en correcte BTW-verwerking volgens de status die je in je profiel hebt aangegeven. Je blijft zelf verantwoordelijk voor het juist opgeven van je BTW-status en voor je eigen belastingaangiftes (inkomstenbelasting, BTW indien van toepassing). Pluggo is geen fiscaal adviseur.*

### Heracceptatie

Bestaande testers van de huidige app-versie hebben geen EV en worden geen actieve gebruikers (zoals eerder bevestigd). Nieuwe gebruikers post-launch zien de bijgewerkte versie automatisch bij signup. Geen aparte heracceptatie-flow nodig.

**Acceptatiecriterium**: jurist heeft self-billing-clausule en privacy.html sectie 5 goedgekeurd.

---

## Fase 7 — Migratie test-data + €1,79 balans

### Wat te doen met bestaande payments

In de huidige `payments` tabel staan eventuele test-payments uit de fase-2 implementatie. Aanpak:

1. Run query: `select * from payments where status = 'paid'` — hoeveel echte payments zijn er?
2. Voor elk: handmatig afhandelen — paaleigenaar's deel uitbetalen via SEPA vanuit Pluggo's Mollie balans (die €1,79).
3. Markeren `payments.status = 'paid_legacy'` zodat ze niet in nieuwe rapportages opduiken.

### €1,79 op Mollie balans

Dit is restwaarde uit de single-merchant fase. Twee opties:
- Houd het op de balans en gebruik als startsaldo voor application fees.
- Uitbetalen aan Pluggo's zakelijke rekening voor 7 juli, dan met schone leitje starten.

Voorkeur: schone start, uitbetalen voor go-live.

### Cutover-datum

Voorstel: vrijdag 26 juni 2026 (10 dagen voor launch). Op die datum:
- Run database-migratie 0002
- Deploy nieuwe edge functions
- Stuur bestaande testers (paaleigenaren) een email "Pluggo gaat live op 7 juli — voltooi je Mollie-koppeling deze week"
- Bestaande palen blijven zichtbaar maar boekingen kunnen pas na Mollie-koppeling

**Acceptatiecriterium**: cutover-checklist afgewerkt, geen openstaande `payments` met status `pending`.

---

## Fase 8 — End-to-end smoke test

**Doel**: één volledige boekingsflow doorlopen met live-mode Mollie Connect, twee test-accounts.

### Scenario

1. Maak nieuwe account "Test Paaleigenaar" → doorloop BTW-vragenlijst als particulier → start Mollie OAuth → voltooi KYC met testdata → terug in app → voeg paal toe.
2. Maak nieuwe account "Test Booker" → boek 5 kWh sessie bij Test Paaleigenaar.
3. Test Paaleigenaar accepteert → laadsessie → vult kWh in → stuurt betaalverzoek.
4. Test Booker betaalt via iDEAL test-modus.
5. Verifieer:
   - Webhook ontvangen
   - Payment-status → `paid`
   - Booker-ontvangstbewijs PDF gegenereerd en gemaild
   - Platform-fee factuur PDF gegenereerd en gemaild naar paaleigenaar
   - €0,40 application fee op Pluggo's balans
   - €1,40 op Test Paaleigenaar's Mollie balans
   - `ytd_revenue_cents` correct opgehoogd

**Acceptatiecriterium**: alle 9 verificatie-punten in groen. Pas dan productie-livegang.

---

## Open juridische vragen (kleinere scope dan eerst geschat)

1. Self-billing onder art 35e Wet OB — clausule in ToS voldoende?
2. Wft-confirmation: Pluggo definitief buiten vergunningsplicht door Connect?
3. Bewaartermijn `mollie_access_token` na deactiveren account — AVG-compliant?

Punt 1+2 kunnen in een gecombineerd 30-min telefonisch advies. Punt 3 kan ook via een AVG-advocaat of zelfs als interne policy, geen externe input strikt nodig.

## Volgende stap

**Mattijs (nu)**:
- Voltooi fase 0 (Mollie KYC + partnercontract) — bezig
- Plan 30-min telefonisch consult met fintech-advocaat voor self-billing + Wft (kleinere scope dan oorspronkelijk geschat)

**Claude (zodra OAuth credentials beschikbaar)**:
- Fase 1 (DB-migratie 0002) — kan parallel beginnen, v1 schema beperken tot `business_type = particulier`
- Fase 2 (`create-payment` refactor) — wacht op OAuth credentials
- Fase 3 (Flutter onboarding) — kan UI-stub al beginnen
- Fase 4 (invoice-engine) — alleen particulier-template voor v1, KOR-versie van platform-fee factuur

**Pluggo's businessmodel staat of valt met deze refactor — geen shortcuts, maar wel gerichte scope.**
