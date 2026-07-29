# Marktanalyse Pluggo — MID-doorlevering vs. P2P-hoofdproduct

**Datum:** 16 juli 2026
**Scope:** Nederlandse EV-thuislaadmarkt, verrekening thuisladen, MID-vereisten en concurrentie
**Doel:** Strategisch advies over (a) OCPP-implementatie en (b) MID-meter-data-doorlevering als tweede product

---

## Deel 1 — Nederlandse EV-markt: privé vs. zakelijk

### Kern-cijfers (medio 2026)

| Metriek | Waarde | Bron |
|---|---|---|
| Volledig elektrische personenauto's (BEV) NL | ~745.000 (~8,0% van totaal park) | [MobilityEnergy — april 2026](https://www.mobilityenergy.com/nl/elektrificatie/2026/04/02/aantal-volledig-elektrische-personenautos-in-nederland-nadert-700-000-autos-op-waterstof-marginaal/) |
| Nieuw-verkochte BEV's YTD 2026 | 63.037 (37% van nieuwverkoop) | [MobilityEnergy — april 2026](https://www.mobilityenergy.com/nl/elektrificatie/2026/04/02/aantal-volledig-elektrische-personenautos-in-nederland-nadert-700-000-autos-op-waterstof-marginaal/) |
| Publieke laadpunten NL | ~210.000 (eind 2025) | [Laadpunt.nl](https://www.laadpunt.nl/laadpaal-kennisbank/2026-200000-laadpunten-nederland/) |
| Private thuislaadpunten (schatting) | ~667.000 – 863.000 | [Solar Magazine](https://solarmagazine.nl/nieuws-zonne-energie/i43188/de-harde-cijfers-private-laadpunten-als-groeidiamant-thuisladen-en-werkladen-exploderen) |
| Werklaadpunten | 153.215 (2025) | [Nederland Elektrisch](https://nederlandelektrisch.nl/actueel/nieuwsoverzicht/i3278/voortgangsrapportage-nal-laadinfrastructuur-groeit-maar-netcongestie-neemt-toe) |

### Verdeling privé vs. zakelijk

De historische aanname "NL is 75-80% zakelijk" klopt niet meer voor het BEV-**park** — begin 2025 waren voor het eerst meer stekkerauto's in privé-bezit (503k) dan zakelijk (442k), waarvan 245k particuliere BEV's vs. 324k zakelijke BEV's ([CBS via Carros, mei 2025](https://www.carros.nl/artikelen/67013/in-2025-voor-het-eerst-meer-particulieren-met-stekkerauto-dan-bedrijven)).

Voor de **nieuwverkoop** is de zakelijke dominantie echter juist zeer sterk: in H1 2025 was **81,8% zakelijk vs. 18,2% privé** — een verslechtering t.o.v. 2024 (16,7% privé). De bijtellingsverhoging naar 22% (2028) en de extra werkgeversheffing per 2027 gaat dit deels bijsturen, maar op korte termijn blijft de zakelijke stroom dominant.

Van het VNA-leasepark (1,19 mln auto's, 87% van totale leasemarkt) is 22% private lease en 78% zakelijk ([VNA feiten en cijfers](https://www.vna-lease.nl/feiten-en-cijfers/autoleasemarkt-in-cijfers)). BEV-aandeel in zakelijke lease: van 36% naar bijna 43% in 2025; in private lease: stabiel rond 20%.

### Thuislaadpaal-dekking

Geen exacte splitsing gepubliceerd, maar met ~745k BEV's en ~667-863k thuislaadpunten (waarvan een deel bij bedrijven staat) is de ruwe conclusie: **de meeste BEV-huishoudens hebben een eigen paal**. Doelgroep zonder eigen paal (publieke-paal-afhankelijk): naar schatting 15-25% van het BEV-park, vooral in binnensteden en bij appartementbewoners. Dit is de core doelgroep voor P2P.

### Trendlijn nieuwverkoop privé BEV (grove indicatie)

- 2023: ~15-17% privé aandeel BEV nieuwverkoop
- 2024: 16,7% privé
- 2025 (H1): 18,2% privé
- 2026e: verwacht 20-25% door bijtellingsdruk en zakelijke elektrificatie-plateau ([BOVAG](https://www.bovag.nl/nieuws/matig-eerste-halfjaar-voor-de-verkoop-van-nieuwe-autos))

---

## Deel 2 — Concurrentietabel verrekening thuisladen

| Speler | Rol MID-meter | Fee-structuur | Lease-integratie | Volume / marktpositie |
|---|---|---|---|---|
| **Shell Recharge** (ex-NewMotion) | MID vereist in eigen paal; werkt met Alfen, Tesla, Mennekes, Ecotap, Keba, Wallbox eM4 | Automatische maandelijkse creditfactuur naar leasemaatschappij; alleen via **Advanced-abo + werkgeverslaadpas**; kWh-tarief door gebruiker ingesteld | Diep geïntegreerd met vrijwel alle grote lease (LeasePlan/Ayvens, Athlon, Alphabet, Arval); marktleider | Naar schatting >150k thuispalen NL, feitelijk de facto standaard ([Shell support](https://support.shell.nl/hc/nl/articles/30506391955089-Hoe-werkt-automatisch-vergoeden-van-stroomkosten)) |
| **Bluecurrent** | MID in eigen palen (NanoCharge, U:Move, H:Move Hidden) | Gebruiker stelt kWh-tarief incl. BTW in; werkgever betaalt +21% BTW; automatische verrekening | Partner van Arval (aparte portal `lps-info.arval.com/bluecurrent`); geaccepteerd door meeste laadpassen | Middelgroot, sterk in eigen paal + eigen back-office ([Bluecurrent help](https://help.bluecurrent.nl/knowledge/what-do-i-set-as-the-charging-rate-on-my-charge-point)) |
| **Eneco eMobility** | MID vereist; werkt met multi-brand palen via OCPP | kWh-verrekening via energieleverancier-relatie; ERE-integratie (~€0,10/kWh extra vanaf 2026) | Aparte propositie "Laadpalen voor leasemaatschappijen" — directe koppeling | Groeiend; combineert energiecontract + laden ([Eneco eMobility](https://www.eneco-emobility.com/zakelijk/voor-wie/leasemaatschappijen)) |
| **EVBox Everon** | MID in Elvi (nieuwere versies) | Historisch marktspeler | **Everon-platform sluit per 1 december 2025** — grote migratieklanten worden herverdeeld | Sterk krimpend / feitelijk uit deze markt ([Oplaadspecialist](https://www.oplaadspecialist.nl/evbox-stopt-met-everon/)) |
| **Optimile / Mobiflow** | MID vereist; multi-brand-OCPP-hub | Optimile stuurt verrekening naar werkgever, betaalt medewerker | België-focus, opereert ook NL via partners | Vooral BE, wel technische leverancier voor meerdere NL-partijen ([Optimile](https://www.optimile.eu/)) |
| **Groendus (ThuisLader)** | MID in geleverde paal, OCPP naar eigen platform | End-to-end managed door leasemaatschappij | **>5.000 installaties/jaar** voor Ayvens, Athlon, Promobility (single-source deal) | Zeer sterk in het lease-B2B-kanaal ([Groendus](https://groendus.nl/onze-oplossingen/thuislader)) |
| **Blue Corner / Blossom / Enervalis** | Data niet publiek vindbaar voor NL-thuisladen-vergoeding | — | Enervalis vooral energy-management SaaS achter derde-partij-CPO's | Beperkte directe NL-lease-aanwezigheid — niet als aparte spelers vindbaar in NL retail |
| **Vandebron thuisladen** | Werkt met werkgeverslaadpassen op Eneco-palen; geen eigen MID-paal | Energiecontract + laadpas | Losse laadpas-propositie, geen diepe lease-integratie gevonden | Klein t.o.v. Shell/Bluecurrent ([Eneco eMobility](https://www.eneco-emobility.com/thuis/kennis-en-tips/hoe-werkt-verrekenen-en-vergoeden-bij-elektrisch-laden)) |

**Kernconclusie deel 2:** De markt is geconsolideerd rond 3-4 dominante spelers (Shell Recharge, Bluecurrent, Eneco, Groendus als lease-white-label). Toegang tot lease-maatschappijen loopt via directe contracten en gecertificeerde OCPP-integraties — niet via "gewoon een laadpas aanbieden". EVBox' terugtrekking uit Everon (december 2025) opent op korte termijn een gat in de installed-base.

---

## Deel 3 — MID-certificering + OCPP praktisch

**1. Zijn tweedehands NL thuislaadpalen MID-gecertificeerd?**

Gedeeltelijk — sterk model- en jaarafhankelijk ([ERE-Centrum matrix van 71 modellen](https://erecentrum.nl/mid-meter-laadpaal/)):

- **Alfen Eve Single S-line en Pro-line** — MID sinds 2019 standaard. Wel MID.
- **Alfen Eve Mini** — alleen recente versies met "Pro" of MID-optie.
- **ABB Terra AC** — MID-versie bestaat, maar veel bestaande installaties zijn de basisvariant zonder MID.
- **Wallbox Pulsar (Plus)** — standaard **geen** MID; alleen de eM4 heeft MID.
- **Easee Home / One** — geen MID; alleen **Easee Charge Max** (nieuwer) heeft MID.
- **Zaptec Go** — geen MID; **Zaptec Go 2 (vanaf 2024)** wel MID.
- **Tesla Wall Connector** — alleen Gen3 MID-versie.

**Praktische implicatie voor Pluggo:** de geïnstalleerde P2P-hostbase zal voor een substantieel deel (schatting: 40-60%) **geen MID-conforme paal** hebben. Dat is de kernbarrière voor het MID-doorleverproduct.

**2. Kan ruwe OCPP MeterValues zonder MID-keten geaccepteerd worden voor werkgeververgoeding?**

**Nee.** Dit is de vast standpunt van de Belastingdienst ([KG:204:2024:13](https://kennisgroepen.belastingdienst.nl/publicaties/kg204202413-vergoeding-laadkosten-auto-van-de-zaak/), 4 november 2024). Onder de Metrologiewet mogen kosten alleen commercieel worden doorbelast als de meting met een gecertificeerd instrument is verricht. Een niet-gecertificeerde meting is juridisch ongeldig voor verrekening. Lease-maatschappijen weigeren om deze reden non-MID data ([De Groene Specialist](https://degroenespecialist.nl/is-een-mid-meter-verplicht-voor-zakelijk-verrekenen/)).

**3. Certificerings-eisen aan Pluggo als tussenpartij?**

Geen aparte eIDAS/vergunning voor Pluggo zelf — de eis zit in de **keten-integriteit van de meting** onder de Metrologiewet. Praktisch betekent dit:

- MID-meter in de paal (verantwoordelijkheid host / installateur).
- OCPP-transportkanaal moet meterwaarden zonder manipulatie doorleveren (signed meter values, OCPP 1.6J-Security of OCPP 2.0.1 aanbevolen).
- Contractueel: Pluggo moet met de lease-maatschappij een DPA + auditafspraak sluiten. Sommige lease-partijen eisen ISAE 3402 of vergelijkbaar bij grote volumes.

Geen wettelijke certificeringsplicht op Pluggo-niveau, wél feitelijke toelatingseisen door de lease-inkoop.

---

## Deel 4 — Fiscaal / juridisch kader thuisladen

**1. Behandeling in 2026.** Werkgevers mogen thuislaadkosten onbelast vergoeden onder de gerichte vrijstelling "intermediaire kosten" (KG:204:2024:13). De vergoeding moet **op basis van werkelijke kosten per kWh** worden vastgesteld — de Belastingdienst accepteert geen uniform bedrag over alle werknemers heen wegens variatie in energiecontracten, zonnepanelen en dynamische tarieven ([JUYST samenvatting](https://juyst.nl/belastingdienst-verduidelijkt-vergoeding-laadkosten-elektrische-auto-van-de-zaak-maatwerk-vereist-per-werknemer/)).

**2. Typische kWh-tarieven werkgeversvergoeding.** In de praktijk hanteren werkgevers/leasemaatschappijen:

- **Forfait "veilige haven"**: circa €0,23/kWh (afgeleid van CBS-referentiecijfer) — landelijk uniform, laag risico.
- **Werkelijk contract-tarief**: €0,27 – €0,32/kWh in 2026 op basis van CBS-gemiddelde variabele consumententarieven.
- **Dynamisch tarief-koppeling** (opkomend): verrekening op basis van EPEX-uurprijs op moment van sessie — technisch complex, wint terrein.

**3. Kan een lease-rijder bij een Pluggo-host laadsessie declareren?**

**Ja, in principe wel**, mits:

- De sessie kan worden gebonden aan de leaserijder-identiteit (RFID / app-login met werkgeverslaadpas of via een OCPI-koppeling).
- De MID-meter in de host-paal levert een gecertificeerde kWh-waarde.
- Het bedrag past binnen het door de werkgever geaccepteerde tarief.

De crux: **de laadsessie is dan effectief géén "thuisladen bij de werknemer" meer, maar een "openbare/semi-publieke laadsessie"** — vergelijkbaar met een sessie op een reguliere publieke paal. Voor de werkgever is dit fiscaal juist eenvoudiger (gewoon factuur van CPO), maar de vergoedingssystematiek loopt via de laadpas-provider, niet via de thuislaad-forfaitair. Pluggo moet dus of (a) laadpassen-acceptatie realiseren via een MSP-integratie (OCPI), of (b) een eigen factuurstroom naar werkgevers opzetten met MID-conformiteit.

---

## Analytische observaties — advies aan de oprichter

1. **Het gat in de markt is niet MID-doorlevering — dat is al belegd bij Shell Recharge, Bluecurrent, Eneco en Groendus, met diepe lease-contracten en installed base.** Als Pluggo hier probeert in te breken concurreren jullie op een verzadigde markt tegen partijen met 5-10× het volume en jaren aan lease-relaties. Verwacht 18-36 maanden sales-cyclus per lease-partij en marginale margins.

2. **De echte niche voor Pluggo is de doelgroep die géén eigen thuispaal heeft**: 15-25% van BEV-rijders, groeiend door de particuliere verkoopstijging (18,2%→~25% richting 2028) en door apartementbewoners in steden. Dat is exact de P2P-doelgroep en die is *nu* underserved door alle bovenstaande spelers, die allemaal alleen "eigen paal"-modellen bedienen.

3. **OCPP nu bouwen: ja, maar minimalistisch (1.6J StartTx/StopTx/MeterValues) — niet als voorbereiding op MID-doorlevering, maar als voorwaarde voor P2P billing accuracy en publieke roaming (OCPI).** Zonder OCPP kunnen jullie ook niet aan MSP's aanhaken en niet aan grid-service-programma's meedoen. Investering is beperkt (2-4 mnd dev), payoff is fundamenteel.

4. **MID-doorlevering als tweede product: dun — maar er zit één interessante hoek.** De installed-base heeft 40-60% non-MID-palen. Er is potentieel voor een "MID-retrofit + Pluggo-doorlevering"-bundel voor lease-rijders die willen upgraden. Dit is echter meer een installateur/hardware-play dan een softwareproduct. Focus is verkeerd voor een pre-seed/seed startup.

5. **Sterker alternatief tweede product: DAC7 + laadsessie-declaratie voor lease-rijders die bij Pluggo-hosts laden.** De klant die bij een host laadt met werkgeverslaadpas heeft nu geen goede route — een MID-conforme host-paal + Pluggo-factuur naar werkgever kan wél. Dit hangt aan de P2P-kern in plaats van ernaast, versterkt de netwerkeffecten (hosts met MID-paal worden waardevoller voor lease-guests) en creëert een defensibele niche die de grote spelers niet raken omdat zij op "eigen paal" gebaseerd zijn.

**Aanbeveling:** OCPP nu bouwen (goedkoop, fundamenteel). MID-doorlevering **niet** als apart product lanceren; wel MID-support in het P2P-productvlak bouwen zodat host-sessies door lease-rijders werkgeversvergoedbaar worden. Positioneer Pluggo als "de laadoplossing voor de BEV-rijder zonder eigen paal" — dat is het enige segment waar de grote 4 niet spelen, en de zakelijke variant is verdedigbaar via MID-host + OCPI-koppeling.

---

**Bronnen (chronologisch, hoofdreferenties):**

- [CBS — Meer dan 1 miljoen stekkerauto's (mei 2025)](https://www.cbs.nl/nl-nl/nieuws/2025/22/meer-dan-1-miljoen-stekkerauto-s-in-nederland)
- [Carros / CBS — Particulieren > bedrijven, mei 2025](https://www.carros.nl/artikelen/67013/in-2025-voor-het-eerst-meer-particulieren-met-stekkerauto-dan-bedrijven)
- [VNA Autoleasemarkt in cijfers 2024](https://www.vna-lease.nl/uploads/files/eeqgpbzr/autoleasemarkt-in-cijfers-2024-2.pdf)
- [MobilityEnergy (april 2026) — 745.389 BEV's](https://www.mobilityenergy.com/nl/elektrificatie/2026/04/02/aantal-volledig-elektrische-personenautos-in-nederland-nadert-700-000-autos-op-waterstof-marginaal/)
- [Solar Magazine — private laadpunten](https://solarmagazine.nl/nieuws-zonne-energie/i43188/de-harde-cijfers-private-laadpunten-als-groeidiamant-thuisladen-en-werkladen-exploderen)
- [Nederland Elektrisch — NAL Voortgangsrapportage](https://nederlandelektrisch.nl/actueel/nieuwsoverzicht/i3278/voortgangsrapportage-nal-laadinfrastructuur-groeit-maar-netcongestie-neemt-toe)
- [Belastingdienst KG:204:2024:13 (november 2024)](https://kennisgroepen.belastingdienst.nl/publicaties/kg204202413-vergoeding-laadkosten-auto-van-de-zaak/)
- [Belastingdienst KG:204:2024:14 Opladen auto van de zaak](https://kennisgroepen.belastingdienst.nl/publicaties/kg204202414-opladen-auto-van-de-zaak/)
- [De Groene Specialist — MID verplicht?](https://degroenespecialist.nl/is-een-mid-meter-verplicht-voor-zakelijk-verrekenen/)
- [ERE-Centrum matrix 71 modellen (2026)](https://erecentrum.nl/mid-meter-laadpaal/)
- [Shell Recharge automatische vergoeding](https://support.shell.nl/hc/nl/articles/30506391955089-Hoe-werkt-automatisch-vergoeden-van-stroomkosten)
- [Bluecurrent — kWh-tarief instellen](https://help.bluecurrent.nl/knowledge/what-do-i-set-as-the-charging-rate-on-my-charge-point)
- [Eneco eMobility voor leasemaatschappijen](https://www.eneco-emobility.com/zakelijk/voor-wie/leasemaatschappijen)
- [Groendus ThuisLader](https://groendus.nl/onze-oplossingen/thuislader)
- [Oplaadspecialist — EVBox stopt Everon](https://www.oplaadspecialist.nl/evbox-stopt-met-everon/)
- [Ayvens laadpaal thuis](https://www.ayvens.com/nl-nl/elektrisch-rijden/opladen/thuisladen/laadpaal-thuis/)
- [Arval x Bluecurrent portal](https://lps-info.arval.com/bluecurrent)
- [JUYST — maatwerk vergoeding laadkosten](https://juyst.nl/belastingdienst-verduidelijkt-vergoeding-laadkosten-elektrische-auto-van-de-zaak-maatwerk-vereist-per-werknemer/)

*Rapport ~1.480 woorden — waar exacte cijfers ontbraken (bv. installed-base per speler, precieze aandeel non-MID palen in tweedehandsmarkt) is dit expliciet als schatting aangeduid.*
