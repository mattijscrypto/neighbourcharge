# SEO-scan pluggoapp.nl — juli 2026

Gescand: homepage, /pioniers, /goedkoop-laden.html, /zonnepanelen-verdienen.html, /welke-laadpaal-werkt.html. Cloudflare analytics toont 153 pageviews in 3 dagen (+39%) — basis-traction aanwezig, maar er liggen grote technische en inhoudelijke kansen braak.

---

## 🔴 Kritiek — direct aanpakken

### 1. Geen sitemap.xml en geen robots.txt

Google kan de site niet efficiënt crawlen. Sitemap.xml met alle 5 pagina's aanmaken en indienen via Google Search Console. Robots.txt met `Sitemap:` verwijzing toevoegen.

```
# robots.txt (minimaal)
User-agent: *
Allow: /
Sitemap: https://pluggoapp.nl/sitemap.xml
```

**Impact:** zonder sitemap.xml indexeert Google sub-pagina's pas als er genoeg externe links naar wijzen. Die zijn er nog niet.

---

### 2. Geen schema-markup — overal

Dit is de grootste gemiste kans. Alle pagina's hebben FAQ-blokken maar er staat geen JSON-LD in de HTML. Google toont FAQ-antwoorden direct in de zoekresultaten (rich results) — dat geeft je tot 3× meer SERP-ruimte zonder extra ranking nodig.

**Toe te voegen per pagina:**

| Pagina | Schema-types |
|---|---|
| Homepage | `Organization`, `WebSite`, `FAQPage` |
| /goedkoop-laden.html | `Article`, `FAQPage` |
| /zonnepanelen-verdienen.html | `Article`, `FAQPage` |
| /welke-laadpaal-werkt.html | `Article`, `FAQPage` |
| /pioniers | `WebPage` |
| Alle sub-pagina's | `BreadcrumbList` |

Voorbeeld FAQPage JSON-LD voor homepage (één blok in `<head>` of vlak voor `</body>`):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Wat verdien ik als ik mijn paal deel?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Dat bepaal je zelf — jij stelt je prijs per kWh in. Bij een paar laadsessies per week is €100 tot €200 per maand realistisch."
      }
    }
    // ... meer Q&A's
  ]
}
</script>
```

**Impact:** rich results in Google → hogere CTR zonder hogere positie nodig.

---

### 3. Title-tags te lang op twee pagina's

Google knipt titels af na ~60 tekens. Twee pagina's overschrijden dit:

| Pagina | Huidige titel (tekens) | Probleem |
|---|---|---|
| goedkoop-laden.html | "Goedkoop elektrisch laden in de buurt — vaak de helft van publiek laden \| Pluggo" (82) | Afgekapt in SERP |
| welke-laadpaal-werkt.html | "Werkt mijn laadpaal op Pluggo? Check in 3 vragen + merk-instructies \| Pluggo" (77) | Afgekapt in SERP |

**Suggesties:**
- → `Goedkoop elektrisch laden bij de buren | Pluggo` (47)
- → `Werkt mijn laadpaal op Pluggo? Check in 3 vragen` (49)

---

## 🟠 Hoge prioriteit — pak dit aan na de kritieke punten

### 4. Stad-specifieke landingspagina's ontbreken

`/goedkoop-laden.html` heeft al secties over Amsterdam, Rotterdam, Utrecht en Den Haag, maar dit zijn slechts anker-links op één pagina. Google kan ze niet afzonderlijk ranken voor lokale zoekopdrachten.

**Potentieel zoekvolume (schatting, NL):**
- "goedkoop elektrisch laden Amsterdam" — 200–500 zoekacties/maand
- "laadpaal huren Amsterdam" — 100–300/maand
- "elektrisch laden Rotterdam" — 100–300/maand
- idem voor Utrecht, Den Haag

**Actie:** vier aparte pagina's aanmaken:
```
/goedkoop-laden-amsterdam.html
/goedkoop-laden-rotterdam.html
/goedkoop-laden-utrecht.html
/goedkoop-laden-den-haag.html
```

Elk met 600–800 woorden stad-specifieke tekst (prijs-context, wijken, paaldruk) en interne links naar hoofdpagina's. Vanuit `/goedkoop-laden.html` intern linken naar de stadsversies.

**Impact:** lokale zoekintentie afvangen is laaghangend fruit — de concurrentie voor stad-specifieke EV-laden-termen is gering.

---

### 5. Missende landingspagina: "laadpaal verhuren"

De host-kant van het platform (paal aanbieden) heeft geen eigen landingspagina buiten de homepage. "Laadpaal verhuren" en varianten zijn echter actief gezocht door potentiële hosts.

**Aan te maken:** `/laadpaal-verhuren.html`

Focus-keywords: laadpaal verhuren, privélaadpaal verhuren, laadpunt verhuren aan buren, geld verdienen met laadpaal, laadpaal beschikbaar stellen.

Koppel intern aan: zonnepanelen-verdienen.html, welke-laadpaal-werkt.html, pioniers.

---

### 6. Dezelfde OG-afbeelding op alle pagina's

Alle 5 pagina's gebruiken `og-image.jpg`. Als iemand `/goedkoop-laden.html` deelt op LinkedIn of WhatsApp, ziet de ontvanger dezelfde generieke Pluggo-afbeelding als bij elke andere pagina.

**Actie:** per pagina een unieke OG-afbeelding maken (1200×630px):
- Goedkoop-laden: vergelijkingstabel met prijzen
- Zonnepanelen: €0,05 vs €0,30/kWh illustratie
- Welke-laadpaal: merklogolijst (Wallbox, Alfen, Easee etc.)
- Pioniers: Pionier-badge visueel

**Impact:** hogere CTR vanuit sociale media en messaging-apps.

---

### 7. Interne navigatie op homepage linkt niet naar sub-pagina's

De header-nav op de homepage heeft: Wat is Pluggo | Hoe werkt het | Slim laden | Oprichter | FAQ | Doe mee. Geen enkele link naar `/goedkoop-laden.html`, `/zonnepanelen-verdienen.html` of `/welke-laadpaal-werkt.html`.

Deze sub-pagina's krijgen zo minder interne "link juice" vanuit de sterkste pagina op de site.

**Actie:** voeg een "Gidsen" dropdown toe in de navigatie, of footer-links met ankertekst die de keyword bevatten.

---

## 🟡 Middellange termijn

### 8. Inconsistente URL-structuur

| Type | Voorbeeld |
|---|---|
| Geen extensie | `/pioniers` |
| Met .html | `/goedkoop-laden.html` |
| Met .html | `/privacy.html` |

Niet dramatisch, maar bij het aanmaken van nieuwe pagina's: kies één stijl en houd die aan. Voorkeur: schone URLs zonder extensie (`/goedkoop-laden`, `/welke-laadpaal-werkt`). Redirect de .html-versies daarna met 301.

---

### 9. Missende keyword-pagina's met zoekpotentieel

| Zoekterm | Geschatte zoekintentie | Aanbevolen pagina |
|---|---|---|
| "elektrisch rijden zonder eigen oprit" | Hoog (rijder-doelgroep) | `/laden-zonder-oprit.html` |
| "peer to peer laden Nederland" | Groeiend | Sectie op homepage |
| "buurtladen" | Eigen begrip, positioneer als merk | Consistent gebruiken in alle content |
| "saldering 2027 zonnepanelen" | Hoog, tijdgebonden | Al in zonnepanelen-pagina — uitbreiden |
| "Wallbox Auto-Lock uitschakelen" | Specifiek, hoge intent | Al in welke-laadpaal, maar aparte H2 opsplitsen |
| "Alfen Plug & Charge instellen" | Specifiek, hoge intent | Idem |

---

### 10. H1 op homepage kan scherper

Huidige H1: `"Laadpaal delen. Het laadnet van de buurt zelf."`

Dit is two zinnen, splits over een harde punt. Google kijkt naar de H1 voor keyword-relevantie. "Laadpaal delen" staat er goed in, maar "P2P laadnetwerk" of "buurt" zit er niet sterk in.

**Alternatief:** `"Laadpaal delen met je buurt — peer-to-peer laden via Pluggo"` of keep poëtisch maar zet de SEO-versie in de H1 en de slagzin in een sub-heading.

---

### 11. Geen `lang="nl"` gevonden in de web-app layout

`/src/app/layout.tsx` in de Next.js codebase heeft nog `lang="en"` (oud NeighbourCharge-skelet). Als die app ooit live gaat (bijv. charger-landingspagina's), zal Google de pagina's als Engelstalig indexeren.

**Actie:** `lang="en"` → `lang="nl"` in `layout.tsx`. Ook de metadata aanpassen van "NeighbourCharge" / "Share EV charging points with your community" naar Pluggo-copy.

---

## ✅ Wat al goed zit

- Canonical tags aanwezig op alle pagina's
- Meta descriptions aanwezig en goed gevuld
- Twitter Card en Open Graph aanwezig
- `og:locale: nl_NL` (homepage)
- Alt-tekst op de oprichter-foto
- Uitstekende interne linking tussen content-pagina's ("Verder lezen")
- Structured long-form content op alle gids-pagina's (goed voor E-E-A-T)
- Byline + datum op gids-pagina's (`Door Ra'ka Cazander · Bijgewerkt: 3 juli 2026`) — goed voor E-E-A-T
- Page load time 459ms — acceptabel
- CLS groen

---

## Prioriteitslijst samengevat

| Prio | Actie | Effort | Impact |
|---|---|---|---|
| 1 | sitemap.xml + robots.txt aanmaken | Klein | Hoog |
| 2 | FAQPage JSON-LD op alle pagina's | Middel | Zeer hoog |
| 3 | Title tags inkorten (2 pagina's) | Klein | Middel |
| 4 | Stad-landingspagina's (4×) | Groot | Hoog |
| 5 | /laadpaal-verhuren.html aanmaken | Middel | Hoog |
| 6 | Unieke OG-afbeeldingen per pagina | Middel | Middel |
| 7 | Interne nav → sub-pagina's | Klein | Middel |
| 8 | URL-structuur consistentie | Middel | Laag |
| 9 | /laden-zonder-oprit.html | Middel | Middel |
| 10 | lang="nl" in Next.js layout | Klein | Middel |

---

*Scan uitgevoerd: 24 juli 2026 · pluggoapp.nl*
