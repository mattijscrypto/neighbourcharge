"""
Pluggo Scanner — Browser Bot v3 (100% lokaal, geen Google API)

Wat het doet per adres:
  1. Geocode via Nominatim (OpenStreetMap, gratis, geen key)
  2. Playwright opent google.com/maps Street View op adres-locatie
  3. Leest actuele pano-coords terug uit URL (Google snapt naar dichtstbijzijnde pano)
  4. Berekent heading naar huis, laadt pano met camera naar huis, screenshot
  5. Stapt 2× links + 2× rechts perpendiculair op zichtlijn, per stap opnieuw richt+screenshot
  6. 5 foto's [L2, L1, base, R1, R2] → local Ollama qwen2.5vl:7b analyse

Gebruik:
    # één keer voorbereiden:
    brew install ollama
    ollama serve &
    ollama pull qwen2.5vl:7b
    pip install playwright requests
    playwright install chromium

    # dan runnen (per wijk):
    python3 browser_scanner.py --wijk hoefkwartier --limit 5
    python3 browser_scanner.py --wijk laak_noord            # alles in de lijst
"""

import argparse
import asyncio
import base64
import csv
import json
import math
import re
import time
from pathlib import Path

import requests
from playwright.async_api import async_playwright

from test_addresses import TEST_ADDRESSES

# ─────────────────────────────────────────────────────────────
# Config (defaults — overschrijfbaar via CLI)

DEFAULT_WIJK = "vathorst"
DEFAULT_SAMPLE_SIZE = 5      # None = alle adressen in TEST_ADDRESSES
STEP_METERS = 10             # meters per stap (minimum om Google's ~8-12m pano-density te overwinnen)
STEPS_PER_SIDE = 1           # 1 links + 1 rechts + base = 3 foto's
PANO_WAIT_S = 4.0            # wachttijd op tegels na navigatie
FOV = 70                     # graden gezichtshoek (kleiner = huis groter/centraler)
OLLAMA_MODEL = "qwen2.5vl:7b"
OLLAMA_URL = "http://localhost:11434"
HEADLESS = False             # False = zie de browser werken; True = sneller
DEBUG = True                 # print URL/titel + save debug-screenshot bij pano-fail

# Wordt gezet door run() op basis van --wijk
OUTPUT_DIR = None
PHOTOS_DIR = None
CSV_PATH = None

def setup_paths(wijk):
    """Zet OUTPUT_DIR / PHOTOS_DIR / CSV_PATH voor deze wijk."""
    global OUTPUT_DIR, PHOTOS_DIR, CSV_PATH
    OUTPUT_DIR = Path(__file__).parent / "output_browser" / wijk
    PHOTOS_DIR = OUTPUT_DIR / "photos"
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    CSV_PATH = OUTPUT_DIR / "results.csv"

# ─────────────────────────────────────────────────────────────
# Geocoding: Nominatim (OSM, gratis)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
UA = "PluggoScanner/1.0 (contact: m.sloothovenier@gmail.com)"

_last_nominatim = 0.0

def geocode(adres):
    """Adres → (lat, lng). Nominatim TOS: max 1 req/sec."""
    global _last_nominatim
    dt = time.time() - _last_nominatim
    if dt < 1.1:
        time.sleep(1.1 - dt)
    r = requests.get(
        NOMINATIM_URL,
        params={"q": adres, "format": "json", "limit": 1, "countrycodes": "nl"},
        headers={"User-Agent": UA},
        timeout=15,
    )
    _last_nominatim = time.time()
    r.raise_for_status()
    data = r.json()
    if not data:
        return None, None
    return float(data[0]["lat"]), float(data[0]["lon"])

# ─────────────────────────────────────────────────────────────
# Geodesic helpers

def bearing_deg(from_lat, from_lng, to_lat, to_lng):
    """Kompas-bearing (0=N, 90=E) van from → to."""
    φ1, φ2 = math.radians(from_lat), math.radians(to_lat)
    Δλ = math.radians(to_lng - from_lng)
    x = math.sin(Δλ) * math.cos(φ2)
    y = math.cos(φ1) * math.sin(φ2) - math.sin(φ1) * math.cos(φ2) * math.cos(Δλ)
    return (math.degrees(math.atan2(x, y)) + 360) % 360

def offset_latlng(lat, lng, bearing, distance_m):
    """Verplaats punt over `distance_m` in `bearing`-richting."""
    R = 6371000.0
    δ = distance_m / R
    θ = math.radians(bearing)
    φ1, λ1 = math.radians(lat), math.radians(lng)
    φ2 = math.asin(math.sin(φ1) * math.cos(δ) + math.cos(φ1) * math.sin(δ) * math.cos(θ))
    λ2 = λ1 + math.atan2(
        math.sin(θ) * math.sin(δ) * math.cos(φ1),
        math.cos(δ) - math.sin(φ1) * math.sin(φ2),
    )
    return math.degrees(φ2), math.degrees(λ2)

def haversine_m(lat1, lng1, lat2, lng2):
    R = 6371000.0
    φ1, φ2 = math.radians(lat1), math.radians(lat2)
    dφ = math.radians(lat2 - lat1)
    dλ = math.radians(lng2 - lng1)
    a = math.sin(dφ/2)**2 + math.cos(φ1)*math.cos(φ2)*math.sin(dλ/2)**2
    return 2 * R * math.asin(math.sqrt(a))

# ─────────────────────────────────────────────────────────────
# Playwright Street View driver

# Google's officieel gedocumenteerde Street View URL API — triggert pano-mode betrouwbaar.
# https://developers.google.com/maps/documentation/urls/get-started#street-view-action
SV_URL = "https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lng}&heading={heading}&pitch=0&fov={fov}"
# Regex accepteert zowel /@lat,lng, als !3d/!4d varianten in de redirected URL.
URL_RE = re.compile(r"/@(-?[\d.]+),(-?[\d.]+),")
# Fallback voor pano-id URL: !1sPANOID
PANOID_RE = re.compile(r"!1s([A-Za-z0-9_-]{16,})")

async def dismiss_consent(page):
    """Cookie/consent banner wegklikken als 'ie verschijnt.

    Google's consent-pagina op consent.google.com heeft een iframe of aparte page.
    We proberen: button role, form-buttons (BEFORE/AFTER), en JS-fallback.
    """
    consent_texts = [
        "Alles accepteren", "Accept all", "Alles weigeren", "Reject all",
        "I agree", "Ik ga akkoord", "Accepteren", "Weigeren",
    ]
    # 1. probeer button role
    for text in consent_texts:
        try:
            btn = page.get_by_role("button", name=re.compile(text, re.I)).first
            if await btn.is_visible(timeout=1500):
                await btn.click()
                await asyncio.sleep(2.0)
                return True
        except Exception:
            continue
    # 2. Fallback: elke <button>/<form> die 'accept' of 'reject' bevat
    try:
        clicked = await page.evaluate("""() => {
          const words = ['accepteren','weigeren','accept','reject','agree','akkoord'];
          for (const b of document.querySelectorAll('button, [role=button], form input[type=submit]')) {
            const t = (b.innerText || b.value || '').toLowerCase();
            if (words.some(w => t.includes(w))) { b.click(); return t; }
          }
          return null;
        }""")
        if clicked:
            await asyncio.sleep(2.0)
            return True
    except Exception:
        pass
    return False

async def _debug_dump(page, tag):
    """Print URL/titel en save screenshot van huidige page-state."""
    if not DEBUG:
        return
    try:
        cur_url = page.url
        cur_title = await page.title()
        # tel de types van canvas / iframes / consent-clues
        canvases = await page.evaluate("""() => {
          const cs = document.querySelectorAll('canvas');
          return Array.from(cs).map(c => c.className || '(no class)');
        }""")
        has_consent = await page.evaluate("""() => {
          const t = document.body ? document.body.innerText.toLowerCase() : '';
          return t.includes('accepter') || t.includes('cookies') || t.includes('consent');
        }""")
        print(f"      [debug {tag}] url={cur_url[:120]}")
        print(f"      [debug {tag}] title={cur_title[:80]}")
        print(f"      [debug {tag}] canvases={canvases[:5]}")
        print(f"      [debug {tag}] consent_detected={has_consent}")
        # Screenshot
        dbg_dir = OUTPUT_DIR / "debug"
        dbg_dir.mkdir(exist_ok=True)
        ts = int(time.time() * 1000) % 1000000
        shot = dbg_dir / f"debug_{tag}_{ts}.png"
        await page.screenshot(path=str(shot), full_page=False)
        print(f"      [debug {tag}] screenshot → {shot.name}")
    except Exception as e:
        print(f"      [debug {tag}] fout tijdens dump: {e}")


async def load_pano(page, lat, lng, heading, wait_s=None):
    """
    Navigeer naar Street View op (lat, lng) met camera-heading.
    Google snapt naar dichtstbijzijnde pano.
    Return: (actual_lat, actual_lng) van pano na snap, of (None, None).
    """
    url = SV_URL.format(lat=lat, lng=lng, heading=round(heading, 2), fov=FOV)
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
    except Exception as e:
        if DEBUG:
            print(f"      [debug] goto() faalde: {type(e).__name__}: {str(e)[:100]}")
        return None, None

    # Consent check na navigatie (Google redirect vaak eerst naar consent.google.com)
    if "consent" in page.url.lower():
        if DEBUG:
            print(f"      [debug] redirect naar consent-pagina, probeer af te handelen")
        await dismiss_consent(page)
        await asyncio.sleep(2.0)

    # De URL API-redirect naar het echte /@lat,lng,3a,... pad kost een tel extra.
    # Wacht tot URL het pano-formaat heeft (3a = Street View mode marker in URL).
    for _ in range(20):  # tot 10 sec (20 × 0.5s)
        if "3a," in page.url or "!1e1" in page.url or "cbll" in page.url:
            break
        await asyncio.sleep(0.5)

    # Wacht op ELK canvas — Google's obfuscated class-names veranderen constant.
    # De URL zelf ("3a," marker) is de betrouwbare check dat we in Street View zitten.
    try:
        await page.wait_for_selector("canvas", timeout=10000)
    except Exception:
        if DEBUG:
            await _debug_dump(page, "no_canvas")
        return None, None

    # Bevestig via URL dat we in Street View mode zijn.
    if not ("3a," in page.url or "!1e1" in page.url):
        if DEBUG:
            print(f"      [debug] geen Street View mode in URL: {page.url[:200]}")
            await _debug_dump(page, "no_sv_mode")
        return None, None

    await asyncio.sleep(wait_s if wait_s is not None else PANO_WAIT_S)
    # Actuele URL uitlezen (Google update deze met echte pano-locatie)
    m = URL_RE.search(page.url)
    if not m:
        if DEBUG:
            print(f"      [debug] URL_RE match faalde op: {page.url[:200]}")
            await _debug_dump(page, "no_url_match")
        return None, None
    return float(m.group(1)), float(m.group(2))

async def screenshot_pano(page):
    """Screenshot van de grootste zichtbare canvas (= Street View pano).

    Google verandert canvas-class-namen naar geobfusceerde strings. De Street
    View canvas is altijd verreweg de grootste (meestal full viewport).
    """
    # Vind de grootste canvas via bounding box.
    biggest_idx = await page.evaluate("""() => {
      const cs = Array.from(document.querySelectorAll('canvas'));
      let best = -1, bestArea = 0;
      cs.forEach((c, i) => {
        const r = c.getBoundingClientRect();
        const area = r.width * r.height;
        if (area > bestArea) { bestArea = area; best = i; }
      });
      return best;
    }""")
    if biggest_idx is not None and biggest_idx >= 0:
        try:
            loc = page.locator("canvas").nth(biggest_idx)
            return await loc.screenshot(type="jpeg", quality=88)
        except Exception:
            pass
    # Fallback: full viewport screenshot
    return await page.screenshot(type="jpeg", quality=88)

async def aim_at_house(page, pano_lat, pano_lng, house_lat, house_lng):
    """Herlaad huidige pano met camera-heading gericht op huis; return foto-bytes."""
    heading = bearing_deg(pano_lat, pano_lng, house_lat, house_lng)
    actual_lat, actual_lng = await load_pano(page, pano_lat, pano_lng, heading, wait_s=3.0)
    if actual_lat is None:
        return None, None, None
    photo = await screenshot_pano(page)
    return photo, actual_lat, actual_lng

async def capture_5_photos(page, house_lat, house_lng, slug):
    """
    Loop 5 pano's rondom huis:
      [L2, L1, base, R1, R2]
    Elke pano met camera-heading berekend naar huis.
    """
    photos, labels = [], []

    # 1. Base pano — laadt op huis-coord, snapt naar dichtstbijzijnde pano
    base_lat, base_lng = await load_pano(page, house_lat, house_lng, heading=0.0)
    if base_lat is None:
        print("      geen base pano beschikbaar")
        return None
    base_photo, base_lat, base_lng = await aim_at_house(page, base_lat, base_lng, house_lat, house_lng)
    if base_photo is None:
        return None

    seen = {(round(base_lat, 6), round(base_lng, 6))}
    all_photos = {"base": (base_photo, base_lat, base_lng)}

    # 2. Links loop — bij kleine STEP_METERS (2m) kan Google naar dezelfde pano
    #    snappen. Dat is prima: we behouden dan effectief dezelfde locatie maar
    #    met een licht andere heading, wat nog steeds nuttige variatie geeft.
    prev_lat, prev_lng = base_lat, base_lng
    for step in range(1, STEPS_PER_SIDE + 1):
        heading = bearing_deg(prev_lat, prev_lng, house_lat, house_lng)
        # perpendiculair naar links = heading - 90
        left_bearing = (heading - 90) % 360
        tgt_lat, tgt_lng = offset_latlng(prev_lat, prev_lng, left_bearing, STEP_METERS)
        actual_lat, actual_lng = await load_pano(page, tgt_lat, tgt_lng, heading=0.0)
        if actual_lat is None:
            print(f"      L{step}: geen pano")
            break
        photo, actual_lat, actual_lng = await aim_at_house(page, actual_lat, actual_lng, house_lat, house_lng)
        if photo is None:
            break
        all_photos[f"L{step}"] = (photo, actual_lat, actual_lng)
        prev_lat, prev_lng = actual_lat, actual_lng

    # 3. Rechts loop — start weer vanaf base
    prev_lat, prev_lng = base_lat, base_lng
    for step in range(1, STEPS_PER_SIDE + 1):
        heading = bearing_deg(prev_lat, prev_lng, house_lat, house_lng)
        right_bearing = (heading + 90) % 360
        tgt_lat, tgt_lng = offset_latlng(prev_lat, prev_lng, right_bearing, STEP_METERS)
        actual_lat, actual_lng = await load_pano(page, tgt_lat, tgt_lng, heading=0.0)
        if actual_lat is None:
            print(f"      R{step}: geen pano")
            break
        photo, actual_lat, actual_lng = await aim_at_house(page, actual_lat, actual_lng, house_lat, house_lng)
        if photo is None:
            break
        all_photos[f"R{step}"] = (photo, actual_lat, actual_lng)
        prev_lat, prev_lng = actual_lat, actual_lng

    # Volgorde: L2, L1, base, R1, R2 (voor zover beschikbaar)
    order = []
    for lbl in ["L2", "L1", "base", "R1", "R2"]:
        if lbl in all_photos:
            order.append(lbl)

    for lbl in order:
        photo, plat, plng = all_photos[lbl]
        path = PHOTOS_DIR / f"{slug}_{lbl}.jpg"
        path.write_bytes(photo)
        photos.append(photo)
        labels.append(lbl)

    return list(zip(labels, photos))

# ─────────────────────────────────────────────────────────────
# Local Ollama vision

PROMPT = """Je bekijkt {n} Street View-foto's van HETZELFDE Nederlandse huis in nieuwbouwwijk Vathorst, Amersfoort.
De foto's zijn genomen vanaf 3 posities langs de straat, allemaal met de camera gericht op het CENTRALE doel-huis in beeld.
Volgorde: links-schuin (10m links, kijk terug-rechts op huis), recht ervoor (base, frontaal), rechts-schuin (10m rechts, kijk terug-links op huis).
Bij links/rechts foto's zie je het huis onder een hoek — perfect om zijgevel, carport en oprit te checken.

⚠️ KRITIEK: kijk ALLEEN naar het HUIS DAT IN HET MIDDEN VAN DE FOTO STAAT.
Rijtjeshuizen in Vathorst staan schouder-aan-schouder. Aan de RANDEN van de foto zie je vaak
al de buurhuizen. Een wallbox of laadpaal op de gevel van een BUURHUIS mag je NIET
toewijzen aan het doel-huis. Alleen laadinfra op de gevel/oprit/carport van het
CENTRALE huis telt.

Doel: bepaal of het CENTRALE huis in beeld THUIS KAN LADEN (auto-oplaadinfra aanwezig).

Signalen die wijzen op thuisladen — één sterk signaal is voldoende:
- STERK: wallbox aan gevel/schuur (rechthoekig wit/zwart kastje ~30cm, vaak met LED of display)
- STERK: freestanding laadpaal op oprit (~1-1.5m hoog, dun, LED-strip)
- STERK: Type 2 stopcontact op muur (rond, ~10cm, vaak met flap)
- STERK: laadkabel zichtbaar (dikke zwarte kabel van muur/paal naar auto)
- MATIG: EV geparkeerd (Tesla, ID.3/4/7, Zoe, Ioniq, Kia EV6/Niro, Polestar, Audi e-tron, BMW i, EQC/EQE, Mustang Mach-E)
- ZWAK: kabelgoot langs gevel naar oprit

Vathorst-context: dichte heggen, wallboxes vaak op zijgevel of onder carport. Kijk ALLE 5 foto's — een charger die vanaf de voorkant onzichtbaar is kan wel op de zijfoto's staan.

Negeer: straatlantaarns, verkeersborden, brievenbussen, gele nutskastjes.

Antwoord ALLEEN in geldig JSON (geen extra tekst):
{{"heeft_laadpaal": true of false, "confidence": getal 0.0-1.0, "signalen": [array van gedetecteerde signaal-strings], "ev_merk": string of null, "notitie": "max 20 woorden NL"}}"""

def ollama_analyze(photos_bytes):
    """Stuur meerdere foto's naar lokale Ollama qwen2.5vl."""
    images_b64 = [base64.b64encode(p).decode() for p in photos_bytes]
    prompt = PROMPT.format(n=len(photos_bytes))
    r = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json={
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": images_b64,
            "stream": False,
            "format": "json",
            "options": {"temperature": 0.1, "num_ctx": 8192},
        },
        timeout=600,  # tot 10 min voor 5 foto's op M1 Pro
    )
    r.raise_for_status()
    resp_text = r.json()["response"]
    return json.loads(resp_text)

# ─────────────────────────────────────────────────────────────
# Main

def slugify(s):
    return "".join(c if c.isalnum() else "_" for c in s).strip("_")[:60]

async def run(wijk, sample_size):
    setup_paths(wijk)
    sample = TEST_ADDRESSES if sample_size is None else TEST_ADDRESSES[:sample_size]
    total = len(sample)
    results = []

    print(f"→ Wijk: {wijk}")
    print(f"→ {total} adressen, model={OLLAMA_MODEL}, headless={HEADLESS}")
    print(f"→ Foto's: {PHOTOS_DIR}\n")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=HEADLESS)
        context = await browser.new_context(
            viewport={"width": 1280, "height": 800},
            locale="nl-NL",
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        )
        page = await context.new_page()

        # Consent bij eerste bezoek afhandelen
        await page.goto("https://www.google.com/maps", wait_until="domcontentloaded")
        if DEBUG:
            print(f"→ Na initial goto: url={page.url[:120]}")
        got_consent = await dismiss_consent(page)
        if DEBUG:
            print(f"→ dismiss_consent → {got_consent}")
        await asyncio.sleep(2)
        if DEBUG:
            print(f"→ Na consent: url={page.url[:120]}\n")

        for i, entry in enumerate(sample, start=1):
            adres = entry["adres"]
            expected = entry.get("expected_has_charger")
            slug = f"{i:02d}_{slugify(adres)}"
            print(f"[{i}/{total}] {adres}")
            try:
                lat, lng = geocode(adres)
                if lat is None:
                    print("   ⚠️  geocode mislukt")
                    results.append({
                        "adres": adres, "expected": expected, "lat": None, "lng": None,
                        "status": "GEOCODE_FAILED", "heeft_laadpaal": None,
                        "confidence": None, "signalen": None, "ev_merk": None,
                        "notitie": None, "n_photos": 0, "labels": None,
                    })
                    continue
                print(f"   📍 {lat:.6f}, {lng:.6f}")

                captured = await capture_5_photos(page, lat, lng, slug)
                if not captured:
                    print("   ⚠️  geen foto's")
                    results.append({
                        "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                        "status": "NO_STREETVIEW", "heeft_laadpaal": None,
                        "confidence": None, "signalen": None, "ev_merk": None,
                        "notitie": None, "n_photos": 0, "labels": None,
                    })
                    continue

                labels = [lbl for lbl, _ in captured]
                photos = [ph for _, ph in captured]
                print(f"   📷 {len(photos)} foto's: [{','.join(labels)}]")

                # Ollama-analyse
                print(f"   🤖 analyseren...", end=" ", flush=True)
                t0 = time.time()
                analysis = ollama_analyze(photos)
                dt = time.time() - t0
                heeft = analysis.get("heeft_laadpaal")
                conf = analysis.get("confidence")
                print(f"({dt:.0f}s)  laadpaal={heeft}, conf={conf}")
                print(f"      \"{analysis.get('notitie', '')}\"")

                results.append({
                    "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                    "status": "OK",
                    "heeft_laadpaal": heeft, "confidence": conf,
                    "signalen": ",".join(analysis.get("signalen") or []),
                    "ev_merk": analysis.get("ev_merk"),
                    "notitie": analysis.get("notitie"),
                    "n_photos": len(photos), "labels": ",".join(labels),
                })

                # Sla tussentijds op zodat crash niet alles kost
                write_csv(results)

            except Exception as e:
                print(f"   ❌ {type(e).__name__}: {str(e)[:200]}")
                results.append({
                    "adres": adres, "expected": expected, "lat": None, "lng": None,
                    "status": f"ERROR: {type(e).__name__}", "heeft_laadpaal": None,
                    "confidence": None, "signalen": None, "ev_merk": None,
                    "notitie": None, "n_photos": 0, "labels": None,
                })
                write_csv(results)

        await browser.close()

    write_csv(results)

    ok = [r for r in results if r["status"] == "OK"]
    tp = [r for r in ok if r["expected"] and r["heeft_laadpaal"]]
    print(f"\n{'─'*60}")
    print(f"Klaar. {len(ok)}/{total} succesvol.")
    if ok:
        print(f"True positive: {len(tp)}/{len(ok)} = {len(tp)/len(ok)*100:.0f}%")
    print(f"→ CSV:    {CSV_PATH}")
    print(f"→ Foto's: {PHOTOS_DIR}")

def write_csv(results):
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "adres", "expected", "lat", "lng", "status",
            "heeft_laadpaal", "confidence", "signalen", "ev_merk",
            "notitie", "n_photos", "labels",
        ])
        w.writeheader()
        w.writerows(results)

def parse_args():
    p = argparse.ArgumentParser(description="Pluggo Street View scanner (per wijk)")
    p.add_argument("--wijk", default=DEFAULT_WIJK,
                   help="Wijk-naam. Output → output_browser/<wijk>/")
    p.add_argument("--limit", type=int, default=DEFAULT_SAMPLE_SIZE,
                   help="Max aantal adressen (0 = alles)")
    return p.parse_args()

if __name__ == "__main__":
    args = parse_args()
    sample_size = None if args.limit == 0 else args.limit
    asyncio.run(run(args.wijk, sample_size))
