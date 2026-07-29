# Lease-maatschappijen outreach — Pluggo campagne

> **Doel:** Nederlandse lease-maatschappijen benaderen om Pluggo als extra perk aan te bieden aan hun EV-lease-klanten met eigen thuis-paal. Nul integratie-lasten aan hun kant, extra service voor hun klanten, differentiatie t.o.v. concurrent-lease-maatschappijen.
>
> **Status:** NIET STARTEN vóór OCPP live is (blocker #275)
>
> **Laatst bijgewerkt:** 9 juli 2026
> **Bijgewerkt door:** Mattijs + Claude

---

## Kernboodschap

- **Voor lease-maatschappij:** een nieuwe perk in het lease-pakket zonder integratie-werk
- **Voor lease-klanten:** €30-60/maand extra terugverdienen op een paal die het merendeel van de tijd ongebruikt staat, automatisch afgehandeld inclusief DAC7
- **Voor Pluggo:** toegang tot een gericht kanaal van 25-150k EV-huishoudens per maatschappij, gratis distributie

---

## Kern-insight (Mattijs, 9 juli 2026)

**De lease-maatschappij is juridisch geen partij in de Pluggo-relatie.** De thuis-paal is eigendom van de lease-klant (niet van de lease-maatschappij), de laadsessie loopt tussen host en booker, en de lease-EV komt in de Pluggo-flow eigenlijk niet voor (die staat gewoon geparkeerd terwijl een booker met eigen auto komt laden).

Dat betekent dat we in feite alléén om **toestemming en distributie** vragen — geen partnerschap, geen contract-verplichtingen aan hun kant, geen verzekering-toezeggingen die zij moeten checken. Dit maakt de pitch een stuk lichter en de "ja" veel gemakkelijker.

**Restrisico's** (goed om te weten, niet fataal):

1. **Reputatie-risico bij lease-maatschappij.** Als zij Pluggo aanraden en er ontstaat een klantklacht, komt die klacht bij hen binnen ook al zijn ze geen partij. Voor dat argument volstaat AVB + een goede support-inbox aan Pluggo's kant.
2. **Contractclausules paal.** Zeldzaam, bij "gratis paal bij lease-contract"-perken kan er een clausule tegen commercieel gebruik zitten. Aan lease-maatschappij om intern te checken; niets wat wij moeten regelen.

**Gevolg voor verzekering-fasering:** AVB is nog steeds nuttig (aanspreekpunt-argument) maar niet strikt vereist om deze pitch te doen. Producten + Cyber + Host-protection zijn helemaal niet meer relevant voor lease-outreach — dat wordt pure Pluggo-kwestie later.

---

## Wanneer starten?

**Vóórwaarden die eerst klaar moeten zijn:**

- [ ] OCPP-integratie live en getest op fysieke paal (blocker #275)
- [ ] AVB-polis afgesloten (zie `verzekeringen/README.md`, fase 1)
- [ ] Big-bang deploy (1.3.0+14) is live én stabiel (minimaal 2 weken zonder major issues)
- [ ] Website `In de media` sectie live (#294) — bright artikel als social proof

**Waarom deze volgorde:** een lease-maatschappij die serieus wil kijken, checkt de app, de website, de reviews, én vraagt naar dekking. Elk van bovenstaande items pareert een compliance-vraag. Als een van deze ontbreekt, is de kans op "we komen erop terug" ~90%.

---

## Top-5 target-maatschappijen (in volgorde van kans)

### 1. Terberg Leasing (BEGIN HIER)

- **Waarom eerst:** kleinste van de vijf (~25k voertuigen), *independent Dutch*, geen Franse/Duitse HQ. Beslissen snel.
- **Als zij "ja" zeggen = social proof richting de vier grote spelers.**
- **Contact:** LinkedIn-search "Terberg Leasing Innovation" of direct de commercieel directeur.
- **Backup-email:** `info@terbergleasing.nl`
- **Website:** https://www.terbergleasing.nl

### 2. Ayvens (LeasePlan + ALD, gefuseerd)

- **Waarom:** grootste in NL (~150k voertuigen). Bij succes = biggest impact.
- **Waarom niet eerst:** stroperig, na de fusie zit hun organisatie in reorganisatie-modus, langere doorlooptijd.
- **Contact:** *Head of E-Mobility Netherlands* of *Innovation Manager Charging Solutions*. LinkedIn-search "Ayvens Netherlands innovation".
- **Backup-email:** `partnerships@ayvens.com` of `communicatie@ayvens.com`
- **Website:** https://www.ayvens.com

### 3. Arval (BNP Paribas)

- **Waarom:** ~50k voertuigen NL, zeer EV-focused. Hebben eigen "Arval Connect"-app waar Pluggo als plugin-service in past. Zij zoeken standaard naar externe partners.
- **Contact:** *Digital Product Manager* of *Head of Connected Services*.
- **Backup-email:** `info@arval.nl`
- **Website:** https://www.arval.nl

### 4. Athlon Car Lease (Mercedes-Benz Mobility)

- **Waarom:** ~55k voertuigen NL, sterk zakelijk. Hebben eigen "Athlon Green" duurzaamheid-programma. Reactief op wat concurrentie doet.
- **Contact:** *Manager Sustainable Mobility* of *E-Mobility Specialist*.
- **Backup-email:** `info@athlon.com`
- **Website:** https://www.athlon.com

### 5. Alphabet Nederland (BMW Group)

- **Waarom:** ~40k voertuigen, zeer premium en EV-heavy (i-serie, MINI-E). Rijders zijn early-adopters bij uitstek, hebben vaak eigen paal.
- **Contact:** *Product Manager E-Mobility* of *Head of Charging Solutions*.
- **Backup-email:** `info.nl@alphabet.com`
- **Website:** https://www.alphabet.com

### Long-list (ronde 2)

- Business Lease
- Wagenplan
- Autobinck
- Multilease
- Wittebrug Leasing / Van Mossel
- Justlease (private lease)

---

## Contactpersoon vinden op LinkedIn — stap voor stap

1. Ga naar linkedin.com/company/[bedrijfsnaam-slug] (bv. `linkedin.com/company/ayvens`)
2. Klik "People" tabblad
3. Filter op locatie "Netherlands"
4. Zoek in functietitels op keywords: **"E-Mobility", "Innovation", "Sustainable", "Charging", "Digital Product", "Head of Product"**
5. Kies de persoon die het meest logisch klopt met de rol
6. Als je Sales Navigator hebt: InMail
7. Anders: connect-verzoek met korte persoonlijke tekst (max 300 tekens) waarin je hint naar het onderwerp

Als de connect wordt geaccepteerd → stuur meteen dezelfde dag de volledige pitch (zie hieronder).

Als de connect niet wordt geaccepteerd binnen 5 werkdagen → probeer een andere persoon in hetzelfde bedrijf óf stuur de e-mail naar het backup-adres.

---

## Pitch-email — versie 3 (lichte insteek, na Mattijs's inzicht 9 juli 2026)

> **Belangrijkste verschil met versie 2:** framing is "toestemming + distributie", niet "partnerschap". Compliance-afdeling ziet dit als "vermelding in ons materiaal" i.p.v. "nieuw contract". Veel gemakkelijkere "ja".

### E-mail versie (250-350 woorden)

---

Onderwerp opties (A/B testen):

- **"Extra service voor uw EV-lease-klanten met eigen thuis-paal — voorstel voor pilot"**
- **"Uw lease-klanten kunnen €30-60/maand extra verdienen op hun thuis-paal — voorstel voor samenwerking"**
- **"Vraag: past buurtladen bij uw duurzaamheid-verhaal richting 2027?"** (variant voor sustainability-managers)

---

Beste [voornaam],

Ik ben Mattijs, mede-oprichter van Pluggo. We hebben een Nederlands platform gebouwd waarmee huishoudens hun eigen laadpaal kunnen delen met buren en voorbijgangers — een Airbnb-model voor thuisladers. Live sinds april 2026, betalingen via Stripe Connect Express, DAC7-conform.

Ik neem contact op met één simpele vraag: **mogen we bij [Ayvens/Athlon/etc.] onder de aandacht komen bij uw EV-lease-klanten?**

Achtergrond: veel van uw lease-klanten hebben zelf €1.500-2.500 in een thuis-paal geïnvesteerd die ze in de praktijk maar een klein deel van de dag zelf gebruiken. Via Pluggo kunnen zij daar €30-60/maand aan terug verdienen zonder dat het hen tijd of moeite kost — alles wordt automatisch afgehandeld inclusief de fiscale kant.

**Wat wij vragen — beperkt tot vermelding/distributie:**

- Vermelding van Pluggo in het onboarding-pakket voor nieuwe EV-lease-klanten (digitale flyer of één slide in uw delivery-kit)
- Eén mailing per jaar aan uw EV-klanten — content leveren wij aan
- Vermelding op uw "extra services" of "duurzaam rijden"-pagina met een link naar pluggoapp.nl

**Wat we uitdrukkelijk NIET vragen:**

- Geen partnerschap-contract met verplichtingen aan uw kant
- Geen data-koppeling of technische integratie
- Geen aansprakelijkheid — uw klanten sluiten zelf een gebruikersovereenkomst met Pluggo; [Ayvens/etc.] is geen partij in die overeenkomst
- Geen exclusiviteit

**Wat wij tegenover uw distributie zetten:**

- Uw lease-klanten krijgen een unieke Pluggo-code voor gratis onboarding + eerste maand fee-vrij
- Eventuele kickback per aangemelde host bespreekbaar
- Kwartaal-rapportage met opt-in cijfers hoeveel uw klanten via Pluggo verdienen — nuttig voor uw duurzaamheid-verhaal

Zou u openstaan voor 30 minuten oriëntatie om te bekijken of dit past bij uw strategie? Ik kom naar u toe of we doen het via Teams.

Vriendelijke groet,
Mattijs Sloothovenier
Mede-oprichter Pluggo
+31 [nummer]
pluggoapp.nl

---

### LinkedIn InMail versie (max 250 woorden)

---

Onderwerp: **Vraag: mogen we bij uw EV-lease-klanten onder de aandacht komen?**

Beste [voornaam],

Ik ben Mattijs van Pluggo — Nederlands P2P-platform voor het delen van thuis-laadpalen. Live sinds april 2026, DAC7-conform, betalingen via Stripe Connect.

Kort punt: uw EV-lease-klanten hebben zelf €1.500-2.500 in een thuis-paal geïnvesteerd die het merendeel van de tijd ongebruikt is. Via Pluggo kunnen zij daar €30-60/maand aan terugverdienen — automatisch afgehandeld.

**Wat ik vraag:** alleen distributie/vermelding.
- Vermelding in uw EV-lease-onboarding-pakket
- 1x per jaar mailing (content leveren wij)
- Link op uw "extra services"-pagina

**Wat ik NIET vraag:** geen partnerschap-contract, geen integratie, geen aansprakelijkheid (uw klanten sluiten zelf een gebruikersovereenkomst met ons; u bent geen partij), geen exclusiviteit.

**Wat u ervoor terugkrijgt:** uw klanten unieke code met gratis onboarding + eerste maand fee-vrij, optionele kickback per aangemelde host, kwartaal-rapportage voor uw duurzaamheid-verhaal.

30 min oriëntatie via Teams of bij u op kantoor?

Mattijs Sloothovenier
Pluggo | pluggoapp.nl

---

## Aanpassingen per verzending

- **\[voornaam\]** — invullen contactpersoon
- **\[Ayvens/Athlon/etc.\]** — invullen bedrijfsnaam
- **\[aantal\]** — invullen aantal hosts. Als het onder de 25 zit: laat het getal weg, schrijf "in pilot-fase in Nederland"
- **\[nummer\]** — invullen mobiel Mattijs
- **Als je iemand van Sustainability aanschrijft** → verwissel bullet 1 en 4 in "wat wij vragen"; zet duurzaamheid-verhaal bovenaan
- **Als je iemand van E-Mobility Product aanschrijft** → verplaats "nul integratie-lasten" naar #1 in "wat wij bieden"

---

## Als vragen komen die je moet beantwoorden

### Q: Hoe zit het met verzekering?

**A:** "Wij hebben op dit moment AVB via [Reaal/NN]. Producten-aansprakelijkheid en cyber-verzekering rondt onze broker af tegen het moment dat we operationeel-live gaan met uw klanten. Wij kunnen dat parallel doorlopen zodra we een intentieverklaring hebben getekend."

Zie `verzekeringen/README.md` voor de details. Alleen zeggen zodra AVB écht is afgesloten.

### Q: Hoe zit het met AVG en DAC7?

**A:** "Wij zijn DAC7-conform. Bij hosts die de drempel van €2.000 of 30 transacties per jaar naderen, vragen we automatisch BSN op via een aparte edge function. Die BSN wordt AES-256-GCM versleuteld opgeslagen in onze Supabase-database met strikte access controls (RLS + column-level GRANTs). Wij rapporteren jaarlijks aan de Belastingdienst. Uw klanten hoeven niets zelf te regelen. Onze privacy-policy en terms behandelen dit expliciet."

### Q: Wat gebeurt er als een lease-klant schade veroorzaakt bij een host, of andersom?

**A:** "Wij faciliteren de match, de laadsessie loopt via OCPP-gecertificeerde palen met alle safety-features van het protocol (control pilot, auto-stop). In geval van schade zit onze verzekering (Producten + host-protection) daar tussen; wij handelen dat af zonder dat de lease-maatschappij daar in getrokken hoeft te worden."

*(Alleen zeggen als host-protection écht rond is. Anders: "wij werken aan een dedicated host-protection dekking die deze scenario's afdekt, actief in gesprek met broker [naam].")*

### Q: Zijn er integratie-eisen?

**A:** "Nee. Uw klanten downloaden de app, maken een account, koppelen hun paal via OCPP (WSS URL invullen in de installateur-portal van hun paal), en het loopt. Wij hebben geen SSO nodig, geen API-koppeling naar uw systemen, geen data-uitwisseling."

### Q: Wat is jullie revenue model?

**A:** "We werken op transactie-fees: €0,03/kWh bij de booker + €0,03/kWh bij de host = €0,06/kWh voor Pluggo, plus €0,40 flat fee onder 10 kWh om micro-sessies af te dekken. Voor uw klanten betekent dit dat bij een gemiddelde sessie van 25 kWh à €0,37 zij €7,50 verdienen en Pluggo €0,75 fee inhoudt. De rest is voor de host."

### Q: Wat als een klant al bij een andere platform aangesloten is?

**A:** "Pluggo werkt naast eventuele bestaande commerciële laadproviders. Klanten kunnen bijvoorbeeld overdag een aparte laadpas gebruiken voor onderweg en 's avonds hun eigen paal delen via Pluggo. Er is geen exclusiviteit."

---

## Trigger-timeline (na OCPP live)

**Week 0 (OCPP is groen):**
- AVB-polis afsluiten (`verzekeringen/README.md` fase 1) — €30-50/maand
- LinkedIn-lijst opstellen: 1 contactpersoon per bedrijf (5 personen totaal)
- Contactpersonen benaderen met LinkedIn connect-verzoek

**Week 1:**
- Als connect geaccepteerd → pitch versturen via InMail
- Als connect niet geaccepteerd binnen 5 werkdagen → e-mail via backup-adres

**Week 2:**
- Follow-up bij niet-reactie: één beleefde reminder na 5 werkdagen
- Bij interesse van Terberg: plannen call

**Week 3-4:**
- Eerste call met eerste geïnteresseerde partij
- Bij "ja op verkennend niveau" → volgende gesprek plannen voor pilot-scope

**Week 5+:**
- Pilot-scope onderhandelen: verkopen we ze op één mailing/onboarding-slot, of full-service?
- Contract-jurist eventueel inschakelen als iemand een intentieverklaring wil tekenen

---

## Wat te doen bij weigering

Als een lease-maatschappij "nee" of "nog niet" zegt:

- **Vraag waarom** — feedback is gouden data voor de volgende
- **Vraag om terug te komen na X maanden** — planten van een zaadje voor later
- **Vraag om introductie in het netwerk** — soms kennen ze een andere collega bij een collega-maatschappij

Verlies is niet definitief; over 6-12 maanden zit de situatie anders (jullie hebben meer hosts, betere metrics, misschien Bright/FD-artikel).

---

## Update-log

- **9 juli 2026** — bestand aangemaakt. Beslissing: outreach start pas na OCPP-live + AVB. Terberg eerst, dan Ayvens/Arval/Athlon/Alphabet.
