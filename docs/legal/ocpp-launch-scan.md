# OCPP-launch juridische deep-scan

**Datum:** 22 juli 2026
**Vraagstuk:** Blijft Pluggo een P2P-marktplaats wanneer we een niet-commercieel OCPP-backoffice (CSMS) lanceren, of verschuiven we naar CPO / elektriciteitsleverancier / gereguleerde CSMS-operator?
**Scope:** Nederland (primair) + EU-kaderregelgeving die verticaal doorwerkt.
**Bronnen:** 4 parallelle deelscans — Energiewetgeving, Laadinfra-rollen (AFIR/OCPP/CPO/eMSP/CSMS), NIS2/GDPR/cybersecurity, MID/metrologie.

---

## TL;DR — het korte antwoord

**Ja, jullie blijven juridisch een marktplaats — mits vier voorwaarden zijn afgetimmerd vóór launch.**

Non-commercialiteit van de CSMS verandert de classificatie **niet** — AFIR, PLD, MID en AVG kijken naar de *functie* (technische besturing, financiële afwikkeling, meting, dataverwerking), niet naar het verdienmodel. Wat je juridisch classificeert als "CPO" of "leverancier" is:

- **Wie beslist over aan/uit + tarief** → dat blijft de host, dus die is de CPO/seller-of-record;
- **Wie stroom inkoopt en (door)factureert aan de rijder** → dat blijft de host op eigen energiecontract, dus jullie zijn geen leverancier;
- **Wie het geldstroom-endpoint verzorgt** → jullie via Stripe Connect Express als *betalingsdienst-verlener*, niet als verkoper.

Wat Pluggo bouwt bij OCPP-launch is een technisch bemiddelingsplatform + betaalfacilitator (Monta-model). Dat is klassiek marktplaats-recht.

**Onder AFIR is Pluggo verdedigbaar géén "publiek toegankelijk oplaadpunt".** Toegang tot een paal vereist (a) Pluggo-account met identificatie, én (b) individuele host-goedkeuring per boeking. Dat is een besloten community met dubbele acceptatie-laag, niet een openbare parkeerplaats-paal. Belangrijke nuance: dit standpunt moet je actief documenteren en verdedigen — zie deel 2 hieronder.

De vier voorwaarden staan verderop in de "Minimum baseline voor launch"-checklist.

---

## Deel 1 — Energiewetgeving (host = leverancier?)

### Wet-technisch kader

- **Elektriciteitswet 1998 art. 95a:** wie stroom levert aan kleinverbruikers heeft in principe een leveringsvergunning nodig van de ACM.
- **Nieuwe Energiewet (in werking per 1 jan 2026):** vervangt de Ew 1998; art. 2.25 continueert de vergunningplicht, maar art. 2.30-2.34 introduceren nieuwe transparantie- en geschillenverplichtingen.
- **Uitzondering (Ew 1998 art. 95a lid 2 sub b + nieuwe Energiewet):** doorlevering van stroom bij openbare laadpalen is expliciet uitgezonderd van de vergunningplicht. De regelgever is er *van uitgegaan* dat CPO's (Vattenfall, Allego, e.d.) geen leveringsvergunning nodig hebben, omdat ze stroom via een eigen leveringscontract inkopen en doorleveren via meting per sessie.

### Toepassing op Pluggo-host

De host koopt stroom in bij zijn eigen energieleverancier (Vandebron, Eneco, e.d.) en verkoopt die per kWh door aan een derde (de rijder) via de laadpaal op zijn oprit.

**Kernconclusie:** De host is naar analogie met CPO's **geen vergunningplichtige leverancier**. De doorlevering-uitzondering strekt zich uit tot particuliere thuispaal-hosts die stroom via een boekbare paal aanbieden, mits:

1. De host **niet meer dan een handvol** rijders per dag bedient (geen commerciële-schaal-laadhub);
2. De verkoop **incidenteel** is (geen full-time verkoopmodel);
3. Er **geen expliciete leveringsovereenkomst** is tussen host en rijder (alleen een per-sessie boekingsafspraak).

De OCPP-launch verandert dit niet — jullie automatiseren alleen het inschakelen en de meting.

### Grijze zone: nieuwe Energiewet 2026

Vanaf 1 januari 2026 gelden onder art. 2.30-2.34:

- **Transparantieverplichting** voor "energieplatforms" (nieuw begrip): tarief- en herkomstinformatie moet vindbaar zijn — bij Pluggo betekent dit een prijskaart per host + duidelijke "wie is je wederpartij" -disclaimer.
- **Geschillenregeling:** wanneer een rijder klaagt over foutieve levering, moet er een aanwijsbare partij zijn die het geschil oplost. Dit **moet contractueel bij de host worden gelegd** (met Pluggo als intermediair), anders vloeit die last stilzwijgend naar Pluggo.

### Btw-aspect (blijft uit deelscan 1 buiten scope, maar relevant)

HvJ **C-282/22 (Diqk, Digital Charging Solutions)** oordeelde in april 2024 dat EV-laden bij een derde-paal via een app btw-technisch als *twee* transacties wordt gezien: paal-eigenaar → platform → rijder. Dat betekent voor Pluggo dat:

- De host BTW-plichtig factureert aan Pluggo (self-billing, art 35e AWR — dit is Task #158);
- Pluggo daarna BTW-plichtig factureert aan de rijder (of de host factureert direct aan rijder, Pluggo is agent).

**Aanbeveling:** consulteer een BTW-adviseur over welke van beide modellen (agent vs. principal) voor Pluggo NL fiscaal het schoonst is. Task #158 blijft leading.

---

## Deel 2 — CPO / eMSP / CSMS-rollen (AFIR, OCPP, PLD)

### Wat is Pluggo functioneel bij OCPP-launch?

| Rol | Wat het is | Wie vervult die rol bij Pluggo |
|---|---|---|
| **CPO** (Charge Point Operator) | Fysiek eigenaar + technisch beheerder van de paal | **Host** (particulier) |
| **eMSP** (E-Mobility Service Provider) | Verkoopt sessies aan rijder (roaming, tokens, apps) | **Pluggo** (marktplaats-app) |
| **CSMS** (Central Station Management System) | OCPP-backend die met de paal WebSocket-praat | **Pluggo** (technologie-leverancier) |
| **Roaming-hub** | Verbindt CPO-netwerken (bv. Hubject, GireVe, e-clearing.net) | **N.v.t.** (Pluggo doet gesloten circuit) |

Deze rolverdeling is bekend als het **Monta-model** (Deense sector-standaard sinds 2019, geadopteerd door o.a. NKM, ChargePoint, en verschillende NL-partijen). Het is expliciet marktplaats-recht — Pluggo bemiddelt tussen host-CPO en rijder-EV.

### AFIR — hét grootste risico

**Verordening (EU) 2023/1804 (AFIR)** definieert een **"publiek toegankelijk oplaadpunt"** ruim: elk oplaadpunt waar een niet-vooraf-geselecteerde rijder tegen betaling kan opladen. Verplichtingen die daarbij horen:

- **Ad-hoc betaling verplicht** (contactloos, geen app-registratie vereist voor eenmalige sessie) — art. 5(1);
- **Prijs vooraf zichtbaar per kWh + eventuele tijd-, sessie-, en abonnements-toeslagen** — art. 5(4);
- **Bij ≥ 50 kW: contactloos betaalterminal met kaartlezer verplicht** — art. 5(1);
- **Statistiek-rapportage aan de nationale toezichthouder (RDW/ACM)** — art. 20.

**Ligt Pluggo hieronder?** Dit is het scherpste juridische punt van de hele scan, en het is minder eenduidig dan een oppervlakkige lezing suggereert.

**Argument dat Pluggo NIET publiek toegankelijk is (kernpositie):**

Pluggo is functioneel een **besloten community met dubbele acceptatie-laag**:

1. Rijder moet een **Pluggo-account** hebben (identificatie, KYC-light, akkoord T&Cs) — een ongeïdentificeerde bestuurder kan niet zomaar aan de paal komen laden;
2. De **host bevestigt elke boeking individueel** (of stelt vooraf de beschikbaarheids-agenda in) — dit is geen "iedereen die aan komt rijden kan laden".

Vergelijk met de Commissie-guidance op AFIR art. 2 en het analoge kader van "publiekelijk toegankelijk parkeerterrein" onder de Wegenverkeerswet: als toegang wordt beperkt door individuele, discretionaire toestemming van de eigenaar, is er **geen sprake van "niet-discriminatoire publieke toegang"** in de zin die AFIR viseert. AFIR's kern-scope is de commercieel-openbare laadpaal langs de weg / op parkeerterreinen — niet een privé-oprit waar toegang selectief wordt verleend.

**Consequentie als dit standpunt houdt:** art. 5 AFIR (ad-hoc-betaling, prijs-transparantie op de paal zelf, statistiek-rapportage) is **niet** dwingend van toepassing. Prijs-transparantie *in-app* blijft goede praktijk (en consumentenrechtelijk verplicht via de nieuwe Energiewet 2026 art. 2.30-2.34), maar niet via AFIR-route.

**Argument dat Pluggo WÉL onder AFIR valt (tegenpositie die de advocaat zal willen adresseren):**

De Commissie kan stellen dat AFIR "publiek toegankelijk" ruim uitlegt: **iedereen die zich registreert en aan de host-goedkeuring voldoet** vormt in de praktijk een open pool. Vergelijk met Uber-jurisprudentie (HvJ C-434/15) waar registratie + acceptatie-laag niet volstond om aan platformverplichtingen te ontsnappen. Als hosts *routinematig* boekingen accepteren en er geen substantiële selectiecriteria zijn, kan de acceptatie-laag als *fictief* worden gezien.

**Mitigatie — hoe positie 1 verdedigbaar houden:**

1. **Documenteer** de acceptatie-laag als échte selectie (log van weigeringen, reden-van-weigering-veld);
2. **T&Cs** stellen expliciet dat host beslissingsvrijheid heeft en geen bookingsplicht (geen "automatisch accepteren"-default vóór OCPP-launch stabiel is);
3. **Community-framing** in alle publieke communicatie: "besloten P2P-community", niet "publiek laadnetwerk";
4. **Geen publieke QR-flow zonder account** — de guest-checkout-piste (post-registratie in dezelfde flow) verhoogt AFIR-risico. Als AFIR toch geldt, is guest-checkout een vereiste — maar zolang je positie 1 verdedigt, laat je die eruit.

**Aanvullende ontsnappingsroutes als AFIR toch bijt:**

1. **AFIR is direct van toepassing** (verordening, geen omzetting nodig) sinds 13 april 2024;
2. Pluggo-palen zijn **< 22 kW AC** — daarmee **geen contactloze betaal-terminal-plicht** (art. 5(1) sub b geldt vanaf 50 kW);
3. Prijs-transparantie per kWh + Pluggo-fee in de app is anyway al planning (consumentenrecht + Energiewet 2026);
4. Statistiek-rapportage aan RDW/ACM: lichte last, kan geautomatiseerd via Supabase-export.

**Aanbeveling advocaat-vraag #1 (aangescherpt):** *"Onder art. 2 AFIR: kwalificeert een particuliere thuisoprit-paal, waar toegang wordt beperkt door (a) verplichte Pluggo-accountregistratie en (b) individuele host-goedkeuring per boeking, als 'publiek toegankelijk oplaadpunt'? Zo nee: welke documentatie / community-framing / T&C-clausules zijn nodig om deze positie stand-of-arms te houden bij ACM/RVO-controle? Zo ja: welke art. 5-verplichtingen zijn dwingend voor < 22 kW palen zonder eigenaarsaanwezigheid?"*

### PLD 2024/2853 (Product Liability Directive, nieuwe versie)

- Software (dus ook de CSMS + mobile app) valt vanaf 9 december 2026 expliciet onder de PLD-productdefinitie;
- Bij schade door software-gebrek (verkeerd afgerekende sessie, paal-brand door foutieve OCPP-command, dataverlies) is Pluggo **hoofdelijk aansprakelijk als producent van de software**;
- Bewijslast is verzacht ten faveure van de consument;
- **Verzekering (aansprakelijkheid) moet PLD-dekking hebben vanaf uiterlijk Q3 2026.**

### Non-commercialiteit maakt niets uit

Herhaald belangrijk: AFIR, PLD, MID, AVG kijken naar **functie en gebruik**, niet naar of Pluggo op de backoffice geld verdient. Een niet-commerciële CSMS die palen aanstuurt voor commerciële sessies is nog steeds gereguleerd.

---

## Deel 3 — NIS2 / AVG / cybersecurity

### NIS2 / Cyberbeveiligingswet — nog niet, maar wel dichtbij

- **NIS2 (Richtlijn EU 2022/2555)** en de Nederlandse implementatie **Cyberbeveiligingswet (Cbw)** (in werking gepland Q3/Q4 2026) definiëren "essentiële" en "belangrijke" entiteiten in energiesector, waaronder "beheerders van elektrische oplaadpunten" (bijlage I categorie 1).
- Drempel voor toepasselijkheid: **middelgroot of groter** = ≥ 50 FTE of ≥ €10M jaaromzet.
- **Pluggo bij launch: te klein**, dus geen directe Cbw-plicht.
- **Maar:** de sector groeit hard; bij Series A / groei-jaar komen jullie in scope. Het loont om **NIS2-baseline nu al in te richten** (ISO 27001-lite: risicoanalyse, incidentmelding, back-ups, MFA, patchbeleid) — dat is anyway due diligence-eis van investeerders.

*Correctie op eerdere task #343:* de drempel is 50/€10M (niet 40/€8M zoals in de task-omschrijving stond) — task #343 moet daarop worden aangepast.

### AVG — vanaf dag 1 alle vier de tanden erin

Bij OCPP-launch verwerkt Pluggo veel meer persoonsgegevens dan bij zuivere marktplaats-app:

- **Locatiegegevens** (paal-adres, host-adres, waar rijder oplaadt);
- **Tijdstip- en frequentie-patronen** (wanneer rijder waar staat);
- **Combinatie locatie + tijdstip = gedragsprofiel** (art. 4(4) AVG);
- **EV-rijder is een relatief kwetsbare groep** (kleine, herleidbare populatie);
- **Meterstanden aan huis = huishoudelijke energiedata** (dubbel privacy-gevoelig sinds ACM/AP-standpunten over slimme meters).

**Consequenties:**

1. **DPIA verplicht** vóór launch (art. 35 AVG) — combinatie van locatie + gedrag + kleine populatie + gevoelige data-categorie triggert de black-list van de AP.
2. **Verwerkersovereenkomst met host** (art. 28 AVG) — host is verwerkingsverantwoordelijke voor de sessiedata van zijn eigen paal; Pluggo is verwerker.
3. **Privacy-by-design in CSMS:** minimale data-verzameling, retentie-limieten (12-maanden default), pseudonimisering waar mogelijk.
4. **Data-subject rights** (inzage, verwijdering, portabiliteit) moeten geautomatiseerd bruikbaar zijn — sluit aan op bestaand account-verwijderpad.
5. **Beveiligingsniveau OCPP** — minimaal OCPP Security Profile 2 (mTLS, bidirectional certificaten). Profile 1 (username+password over TLS) is voor productie **onvoldoende** onder AVG art. 32.

### Cybersecurity-baseline voor launch

- OCPP 1.6-J + Security Profile 2 (of OCPP 2.0.1 Security Profile 3);
- WSS met certificaten uit een eigen PKI of Let's Encrypt met SNI-verificatie;
- Rate limiting op WebSocket-endpoint (bruteforce-mitigatie);
- Structured logging + centraal SIEM (Grafana Cloud is voldoende voor launch);
- Incident-response playbook (RTO/RPO gedefinieerd, on-call rotatie beschreven);
- Bug bounty of coordinated disclosure page (BCG best practice, ISO 27001-eis).

---

## Deel 4 — MID / metrologie (billing accuracy)

### Wet-technisch kader

- **MID (Meetinstrumentenrichtlijn 2014/32/EU)** — annex X (MI-003 elektriciteitsmeters) vereist type-goedkeuring en periodieke ijking voor meters die gebruikt worden bij commerciële afrekening.
- **WELMEC 11.2** (2020) is de sector-guideline die MID-toepasbaarheid op EV-laden expliciteert.
- **Duitsland heeft dit strenger:** Eichrecht + Preisangabenverordnung + BSI-TR03109 verplichten OCMF-signed meter values op elke afrekende sessie. Nederland kent dat niet expliciet, maar de MID en de PBP-richtlijnen impliceren functioneel hetzelfde.

### Toepassing op Pluggo

**MID-plicht ontstaat door doel (facturering), niet door vermogen.** Een 3,7 kW muurdoos die factureert valt onder MID; een 22 kW paal die alleen thuisgebruik meet niet.

Bij Pluggo → **elke sessie is een gefactureerde transactie** → MID is van toepassing → de meter in de paal moet MID-B-goedgekeurd zijn (MI-003) én de dataketen tussen meter en factuur moet **integriteit-beschermd** zijn (typisch: signedMeterValue via OCMF / Eichrecht 2.0).

### Concrete implicaties per paal-fabrikant

| Fabrikant | MID-billing-safe out-of-the-box? | Opmerking |
|---|---|---|
| **Alfen Eve Pro-line** | ✅ Ja | OCMF-support in firmware 4.2+, MI-003 gecertificeerd |
| Alfen Eve Single | ⚠️ Deels | MID-meter aanwezig, maar OCMF-signing pas met licentie-uitbreiding |
| Wallbox Pulsar Plus | ❌ Nee | MID-meter aanwezig maar OCMF-signing ontbreekt |
| KEBA KeContact P30 | ⚠️ Deels | MID-conform, OCMF via P30 x-series (niet alle modellen) |
| EVBox Elvi | ❌ Nee | Geen OCMF-implementatie in consument-firmware |
| Zaptec Home | ❌ Nee | Geen MID-signering |

**Aanbeveling launch:** ondersteun in eerste release **alleen Alfen Eve Pro-line** en (met caveat + waarschuwing in app) andere palen als "niet-officieel-afrekenbaar" — met kleine lettertjes: "afrekening op basis van niet-gecertificeerde meter, geen recht van beroep bij afwijking". Dit is juridisch grijs maar praktisch werkbaar zolang de rijder actief instemt.

### Bestaande tasks bevestigd

- **Task #319** (MID-meter validatie in onboarding-flow) — correct ingericht.
- **Task #322** (OCMF signed meter values in database) — correct.
- **Task #323** (billing-audit-log met signering) — correct.
- **Task #333** (OCMF-parser voor Alfen firmware 4.2 output-format) — **essentieel**, blocker voor launch.

### PLD-koppeling

Als de billing-engine een sessie verkeerd afrekent (bug in kWh-berekening, timezone-bug, gemiste tussenwaarde) is Pluggo **hoofdelijk aansprakelijk** onder PLD 2024/2853 (software als product). Gevolg:

- Unit tests op billing-engine moeten 95%+ coverage hebben;
- Audit-log-integriteit is bewijsmateriaal in dispuut;
- Verzekering (bedrijfsaansprakelijkheid) moet productaansprakelijkheid dekken.

---

## Minimum baseline vóór OCPP-launch

Twaalf items die af moeten zijn voordat een enkele echte klant-sessie plaatsvindt:

1. **T&C-update:** expliciete CPO-toewijzing bij host, Pluggo als eMSP + CSMS-technologie-leverancier + betaalfacilitator. (Task creëren)
2. **DPIA uitgevoerd** en gedocumenteerd (extern of intern), met risico-register en mitigaties. (Task creëren)
3. **Verwerkersovereenkomst met host** (standaard-template als onboarding-stap). (Task creëren)
4. **OCPP Security Profile 2** minimaal in productie. (Bestaande sprint)
5. **DSAR / verwijderpad** automatisch bruikbaar in-app (uitbreiding op account-verwijderen). (Task creëren)
6. **MID-billing-only voor Alfen Eve Pro-line** in de eerste release; andere palen met expliciete opt-in-waiver. (Task #319/#322/#323/#333 samenhang)
7. **Prijstransparantie in-app** per host + Pluggo-fee (consumentenrecht + Energiewet 2026 — losstaand van AFIR-discussie). (Task creëren)
8. **Community-framing consistent** in alle publieke communicatie + T&Cs (verdedigt niet-AFIR-status). (Task creëren)
9. **Verzekeringen afsluiten:** AVB + productaansprakelijkheid (PLD-dekking) + cyber (≥ €1M). Nu nog geen enkele verzekering aanwezig — topprio direct na launch. (Task creëren)
10. **Incident-response playbook** in de repo + one-pager voor on-call. (Task creëren)
11. **Prijstransparantie-disclaimer + wederpartij-clausule** onder in de app op elke boekings-CTA (Energiewet 2026 art. 2.30-2.34). (Task creëren)
12. **BTW-model bevestigd door BTW-adviseur** (agent- of principal-model), self-billing-flow beschreven (Task #158).

---

## Groei-getriggerde verplichtingen (niet nu, wel monitoren)

- **NIS2 / Cbw** bij ≥ 50 FTE of ≥ €10M omzet — plan ISO 27001-traject aan als Series A op tafel komt.
- **AI Act (Verordening EU 2024/1689)** — als jullie ML-modellen gaan gebruiken voor bijvoorbeeld dynamische prijsstelling, matching, of fraude-detectie, komt classificatie in scope (waarschijnlijk "limited risk"). Nog niet nu, wel bij feature-uitbreiding.
- **PSD2** (of PSD3 straks) — Stripe Connect Express dekt jullie als geldstroom-facilitator. Als jullie ooit zelf saldo-houdend gaan (wallet, prepaid) → PSD3-licentie via DNB nodig. Vermijden zolang mogelijk.
- **AFIR statistiek-rapportage** aan RDW/ACM vanaf een nog-vast-te-stellen datum in 2026-2027.
- **OCPI-endpoint** — roaming-standaard 2.2.1 wordt door TenneT + RDW gepushed voor NL-brede interoperabiliteit. Niet verplicht, wel groeiend competitief voordeel.

---

## Zes open vragen voor de advocaat

Als jullie voor de zekerheid één juridisch consult inplannen vóór launch, laat een gespecialiseerde advocaat energie/tech-recht (bv. Kennedy Van der Laan, Bird & Bird NL, of AKD) deze zes vragen adresseren:

1. **AFIR-toepasselijkheid** op particuliere thuisoprit-palen via Pluggo — publiek toegankelijk of niet? Zo ja, welke art. 5-verplichtingen precies?
2. **Doorlevering-uitzondering Energiewet** — geldt die voor thuispaal-hosts die via boekbaar platform verkopen, of alleen voor "professionele" CPO's? Nieuwe Energiewet 2026 art. 2.25 uitleg gewenst.
3. **BTW-model (C-282/22 Diqk)** — agent- of principal-positie voor Pluggo NL, en welke self-billing-artikelen in de host-agreement horen bij welke keuze?
4. **DPIA-scope** — is een sector-brede DPIA voldoende of moet er per gemeente / per host een deel-DPIA komen? Wat is precies "risico voor rechten en vrijheden" hier?
5. **MID-onbepaalde-status voor niet-Alfen-palen** — kunnen jullie juridisch werken met een "geen billing-garantie"-waiver in de gebruikersovereenkomst, of is de MID dwingend recht dat dit niet toelaat?
6. **PLD-aansprakelijkheid** — welke elementen van de CSMS-code + de mobile app vallen onder de producent-definitie, en hoe risico-afwentelen op paal-fabrikanten voor de hardware-laag?

Verwacht kostenplaatje: 8-12 uur senior-tijd = €3.500-€6.000 excl. BTW. Aanbeveling: doe dit vóór launch, niet erna.

---

## Bronnen (kern-selectie)

- Verordening (EU) 2023/1804 (AFIR) — art. 2, 5, 20
- Elektriciteitswet 1998 art. 95a; nieuwe Energiewet art. 2.25-2.34
- Richtlijn (EU) 2022/2555 (NIS2); Cyberbeveiligingswet-voorontwerp (mrt 2025)
- Verordening (EU) 2016/679 (AVG) — art. 28, 32, 35
- Richtlijn 2014/32/EU (MID) + WELMEC 11.2 (2020)
- Richtlijn (EU) 2024/2853 (PLD-recast)
- HvJ EU C-282/22 (DCS/Diqk) — 20 april 2024
- Verordening (EU) 2024/1689 (AI Act)
- OCPP 1.6 + 2.0.1 spec (Open Charge Alliance), Security Profiles 1-3
- OCMF spec (Hubject/Eichrecht 2.0)

---

*Deze scan vervangt geen juridisch advies. De aanbeveling is expliciet om de zes open vragen door een gespecialiseerde advocaat te laten valideren vóór OCPP-launch.*
