# Lease-rijders als bookers + MSP/Roaming

> **Vraag:** kan een lease-rijder onderweg opladen bij een Pluggo-paal, of zit die vast aan een laadpas van de lease-maatschappij?
>
> **Kort antwoord:** technisch ja, praktisch grotendeels nee — behalve privé-lease. Voor zakelijke lease is een MSP-roaming-integratie nodig om echt te ontgrendelen.
>
> **Laatst bijgewerkt:** 9 juli 2026

---

## De situatie in het Nederlandse lease-landschap

De meeste zakelijke lease-EV-rijders krijgen bij hun contract een **laadpas** mee, vaak van een van deze drie:

- **Shell Recharge** (voorheen NewMotion) — verreweg de grootste, standaard bij Ayvens/Athlon
- **Athlon Charge Pass**
- **Alphabet Charge / Alphabet Recharge**
- **Arval Charge Pass** (via Shell Recharge backend)
- **Terberg Charge**

Die pas is aan het **laadpas-netwerk** gekoppeld: de klant zwaait de pas voor de paal, betaalt de sessie via de pas, en de kosten worden **automatisch doorbelast** aan de werkgever (of via bruteringen aan de rijder afgetrokken).

Alle grote publieke laadpaal-netwerken (Allego, Vattenfall, Fastned, EVBox, etc.) zijn via het **roaming-systeem** aan elkaar gekoppeld via:

- **Hubject OICP** (grootste roaming-hub in Europa)
- **e-Clearing.Net** (open-standard concurrent)
- **GIREVE** (Frans, ook actief in NL)

Als een netwerk aangesloten is op zo'n roaming-hub, dan werkt élke laadpas van élke MSP daar. Dát is waarom een Shell Recharge-pas op een Allego-paal werkt zonder dat de klant iets hoeft in te stellen.

---

## Waar Pluggo (nog) niet in zit

Pluggo is momenteel **NIET aangesloten** op Hubject / e-Clearing.Net / GIREVE. Dat betekent:

- Een zakelijke lease-rijder die met zijn Shell Recharge-pas bij een Pluggo-paal komt → **werkt niet**. De paal herkent de pas niet.
- Betaling via Pluggo-app kan wel — maar dan moet de rijder de kosten voorschieten en achteraf declareren bij de werkgever. Die declaratie-frictie is voor veel zakelijke rijders de reden om Pluggo links te laten liggen.

---

## Wie kan wél als booker bij Pluggo laden?

Grofweg drie groepen:

### 1. Privé-lease-rijders (~30-35% van totale lease-markt)

Deze mensen betalen zelf hun laadkosten. Zij hebben géén declaratie-flow met een werkgever. Voor hen is Pluggo interessant omdat:

- Ze de kosten toch al zelf moeten dragen
- Pluggo vaak goedkoper is dan publieke laders (€0.30-0.45/kWh vs €0.55-0.85/kWh publiek)
- Ze bewust op zoek zijn naar betaalbare oplaad-opties

**Deze groep is 100% adresseerbaar via de bestaande Pluggo-flow.**

### 2. Zakelijke lease-rijders die BEWUST voor Pluggo kiezen (kleine minderheid)

Sommige zakelijke rijders willen wél Pluggo gebruiken, bijvoorbeeld:

- Rijders die "duurzaam consumeren" belangrijk vinden en de P2P-verhaal aanspreekt
- Rijders met een werkgever die alle laadkosten vergoedt op basis van bonnen (dan is Pluggo simpelweg een goedkopere bon)
- Rijders die op een specifieke locatie willen laden waar géén publieke lader in de buurt is

**Frictie:** ze moeten de sessie zelf voorschieten en handmatig declareren.

### 3. Lease-rijders die thuis-laden op eigen laadpaal én die paal delen als host

Dit is de **primaire kans**. De lease-rijder is zowel host (verhuurt eigen thuis-paal) als soms booker (laadt onderweg elders). Deze categorie is precies waar de lease-outreach-campagne op mikt: **hosts, niet bookers**.

Zie `../lease_outreach/README.md` voor details.

---

## Wat zou een MSP-roaming-integratie doen?

Als Pluggo aansluit op Hubject OICP (of e-Clearing.Net):

**Voor Pluggo-hosts:**

- Hun paal wordt zichtbaar in álle grote laad-apps (Shell Recharge, ANWB Laden, Chargemap, Plugsurfing, etc.)
- Booker-volume schaalt fors — potentieel 5-10x meer sessies per paal
- Host krijgt automatische betaling, precies zoals nu

**Voor Pluggo als platform:**

- Wordt zichtbaar voor de ~55% van de EV-markt die op lease rijdt (~275k van 500k EV's)
- Krijgt substantieel meer transactievolume
- Kan een premium fee vragen (roaming-transacties leveren typisch 15-25% marge op)

**De catch:**

- Aansluiting op Hubject kost geld (~€2k-5k eenmalig + fee per transactie)
- Vereist OCPP CSMS met OICP-adapter (extra ontwikkeling: 2-4 weken)
- Vereist B2B-contract met minimaal 1 MSP als "issuer" (de partij die de kaarten uitgeeft)
- Roaming-transacties hebben hogere kosten waardoor je marge dunner wordt (~€0.02-0.04/kWh naar MSP + €0.01-0.02/kWh naar Hubject)

---

## Beslissing voor nu

**Fase huidig (12 palen, 0 sessies, big-bang 1.3.0 nog niet live):** niet doen.

**Fase 1 (post-1.3.0, na eerste ~100 hosts + eerste lease-outreach succes):** onderzoeken.

**Fase 2 (bij ~500+ hosts of ~€25k GMV/maand):** aansluiten. Prioriteit: Hubject OICP omdat die de grootste dekking heeft in NL/DE/BE.

---

## Praktische MSP-shortlist voor eventuele Fase 2

| MSP | Positionering | Waarom relevant |
|-----|---------------|-----------------|
| **Shell Recharge** | grootste in NL, standaard bij lease | volume-multiplier #1 |
| **ANWB Laden** | consumenten-brand, hoge vertrouwens-score | betrouwbaar voor privé |
| **Plugsurfing** | pan-europees, Duitse basis | uitbreiding BE/DE later |
| **Chargemap Pass** | Frans, consumenten-app | uitbreiding FR later |

Hubject-aansluiting geeft toegang tot ALLE bovenstaande in één keer — dat is de aantrekkelijkheid.

---

## Concreet: wat betekent dit voor de lease-outreach?

De lease-outreach-campagne richt zich op **lease-rijders als HOSTS** (hun thuis-paal verhuren). Dat is bewust, want:

1. Als HOST hebben ze geen frictie met declaratie — ze ontvangen alleen maar
2. De Pluggo-flow werkt volledig zoals ontworpen (Stripe payout naar hun eigen rekening)
3. Ze halen extra rendement uit een paal die in de praktijk maar deels gebruikt wordt

De vraag "kunnen deze rijders ook als BOOKER Pluggo gebruiken?" is een secundaire vraag die pas relevant wordt als MSP-roaming rond is. Nu niet.

---

## Update-log

- **9 juli 2026** — bestand aangemaakt. Beslissing: MSP-roaming pas in fase 2 (500+ hosts / €25k GMV/mnd). Focus nu op lease-rijders als hosts, niet als bookers.
