"""
Pluggo Scanner — POC v2

Wijzigingen t.o.v. v1:
- Adres → lat/lng via Geocoding API (i.p.v. handmatige coords)
- Street View metadata: radius=100m zodat "iets minder precies" ook werkt
- Gemini retry-logic met exponential backoff bij 429
- 2 sec delay tussen adressen

Gebruik:
    python3 poc.py
"""

import os
import csv
import json
import math
import base64
import time
from pathlib import Path
from urllib.parse import urlencode

import requests
from dotenv import load_dotenv

from test_addresses import TEST_ADDRESSES

# ─────────────────────────────────────────────────────────────────────────────
# Setup

load_dotenv()

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GOOGLE_MAPS_API_KEY or not GEMINI_API_KEY:
    raise RuntimeError("Set GOOGLE_MAPS_API_KEY and GEMINI_API_KEY in .env")

OUTPUT_DIR = Path(__file__).parent / "output"
PHOTOS_DIR = OUTPUT_DIR / "photos"
PHOTOS_DIR.mkdir(parents=True, exist_ok=True)

CSV_PATH = OUTPUT_DIR / "results.csv"

# ─────────────────────────────────────────────────────────────────────────────
# Google APIs

GEOCODE = "https://maps.googleapis.com/maps/api/geocode/json"
STREETVIEW_META = "https://maps.googleapis.com/maps/api/streetview/metadata"
STREETVIEW_IMG = "https://maps.googleapis.com/maps/api/streetview"

def geocode_address(adres):
    """Adres (string) → (lat, lng) via Geocoding API. Gratis binnen quota."""
    params = {"address": adres, "region": "nl", "key": GOOGLE_MAPS_API_KEY}
    r = requests.get(GEOCODE, params=params, timeout=10)
    r.raise_for_status()
    data = r.json()
    if data.get("status") != "OK" or not data.get("results"):
        return None, None
    loc = data["results"][0]["geometry"]["location"]
    return loc["lat"], loc["lng"]

def streetview_metadata(lat, lng, radius=100):
    """Check of Street View bestaat binnen radius meter. Gratis call."""
    params = {
        "location": f"{lat},{lng}",
        "radius": radius,
        "source": "outdoor",
        "key": GOOGLE_MAPS_API_KEY,
    }
    r = requests.get(STREETVIEW_META, params=params, timeout=10)
    r.raise_for_status()
    return r.json()

def streetview_photo(lat, lng, size="640x640", heading=None, fov=90):
    """Haal Street View-foto op. $0.007/foto, gratis binnen $200/maand quota."""
    params = {
        "location": f"{lat},{lng}",
        "size": size,
        "fov": fov,
        "pitch": 0,
        "radius": 100,
        "return_error_code": "true",
        "source": "outdoor",
        "key": GOOGLE_MAPS_API_KEY,
    }
    if heading is not None:
        params["heading"] = round(heading, 2)
    url = f"{STREETVIEW_IMG}?{urlencode(params)}"
    r = requests.get(url, timeout=15)
    r.raise_for_status()
    return r.content

def bearing_deg(from_lat, from_lng, to_lat, to_lng):
    """Kompas-bearing (0=N, 90=E) van from-punt naar to-punt."""
    φ1, φ2 = math.radians(from_lat), math.radians(to_lat)
    Δλ = math.radians(to_lng - from_lng)
    x = math.sin(Δλ) * math.cos(φ2)
    y = math.cos(φ1) * math.sin(φ2) - math.sin(φ1) * math.cos(φ2) * math.cos(Δλ)
    return (math.degrees(math.atan2(x, y)) + 360) % 360

# ─────────────────────────────────────────────────────────────────────────────
# Gemini

# Tier 1 (prepay). "flash-latest" is rolling alias — Google update dit automatisch
# naar het huidige productie-flash-model (nu vermoedelijk 3.5-flash, 05-2026).
GEMINI_MODEL = "gemini-flash-latest"
GEMINI_ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/"
    f"models/{GEMINI_MODEL}:generateContent"
)

PROMPT = """Je bekijkt 1-3 Street View-foto's van HETZELFDE Nederlandse huis in een nieuwbouwwijk.
De foto's zijn genomen vanaf dezelfde straatpositie met verschillende kijkhoeken (recht, links, rechts) —
je ziet dus voorkant + zijkanten + carport/schuur van dezelfde woning.
Doel: inschatten of hier thuis geladen wordt (auto-oplaadinfra aanwezig).

Signalen die wijzen op thuisladen (elk telt mee):
1. STERK — zichtbare wallbox aan gevel/schuur/muur (rechthoekig kastje ~30cm, vaak wit/zwart, met LED of display)
2. STERK — freestanding laadpaal op oprit (~1-1.5m hoog, dun, LED-strip)
3. STERK — Type 2 stopcontact op muur (rond, ~10cm, vaak met flap)
4. STERK — laadkabel zichtbaar (dikke zwarte kabel, van muur/paal naar auto)
5. MATIG — elektrische auto geparkeerd op oprit/voor huis (Tesla, ID.3/4/7, Zoe, Ioniq, EQC/EQE, Kia EV6/Niro EV, Polestar, BMW i-serie, Q4/Q8 e-tron, iX, EX30, Mustang Mach-E). Kentekens beginnen soms met blauwe EU-strip zonder plaatje-symbool.
6. ZWAK — kabelgoot/leidingpijp langs gevel naar oprit-hoogte

Negeer: straatlantaarns, verkeersborden, brievenbussen, gele elektriciteitskasten van het net, tuinverlichting, alarmkastjes.

Belangrijk: Vathorst heeft veel dichte heggen — als een gevel afgeschermd is maar er staat een EV op de oprit, is dat zelf al een goede indicatie.

Geef antwoord in strikt JSON-formaat, geen extra tekst:
{
  "heeft_laadpaal": true | false,
  "confidence": 0.0 tot 1.0,
  "signalen": ["wallbox_gevel" | "wallbox_schuur" | "paal_oprit" | "type2_socket" | "laadkabel" | "ev_geparkeerd" | "kabelgoot"],
  "ev_merk": "Tesla" | "Zoe" | "ID.3" | ... | null,
  "notitie": "korte omschrijving in het Nederlands, max 20 woorden"
}

Regel: als er MINSTENS ÉÉN sterk signaal is → heeft_laadpaal=true. Als er alleen een EV staat zonder zichtbare paal/kabel/socket → heeft_laadpaal=true met confidence 0.5-0.7."""

def gemini_analyze_photos(photo_bytes_list, max_retries=5):
    """Stuur 1-N foto's van hetzelfde adres naar Gemini in één call."""
    parts = [{"text": PROMPT}]
    for pb in photo_bytes_list:
        b64 = base64.b64encode(pb).decode("utf-8")
        parts.append({"inline_data": {"mime_type": "image/jpeg", "data": b64}})
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"},
    }
    headers = {"x-goog-api-key": GEMINI_API_KEY, "Content-Type": "application/json"}

    delay = 4  # Tier 1: 429s zouden zeldzaam moeten zijn, korte backoff volstaat
    for attempt in range(max_retries):
        r = requests.post(GEMINI_ENDPOINT, headers=headers, json=payload, timeout=30)
        if r.status_code == 200:
            data = r.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            # Gemini plakt soms extra objecten of trailing tekst — pak eerste JSON-blok
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                # Fallback: knip vanaf eerste { tot matching }
                start = text.find("{")
                if start == -1:
                    raise
                depth = 0
                for i, c in enumerate(text[start:], start=start):
                    if c == "{": depth += 1
                    elif c == "}":
                        depth -= 1
                        if depth == 0:
                            return json.loads(text[start:i+1])
                raise
        if r.status_code in (429, 503):
            print(f"      ⏳ {r.status_code}, wacht {delay}s (poging {attempt+1}/{max_retries})...")
            time.sleep(delay)
            delay = min(delay * 2, 120)  # cap op 2 min per poging
            continue
        # Print body voor debugging bij andere errors
        print(f"      ❌ Status {r.status_code}: {r.text[:300]}")
        r.raise_for_status()

    raise RuntimeError(f"Gemini bleef 429/503 geven na {max_retries} pogingen")

# ─────────────────────────────────────────────────────────────────────────────
# Main loop

def slugify(s):
    return "".join(c if c.isalnum() else "_" for c in s).strip("_")

SAMPLE_SIZE = 25   # eerst 25 als sanity check, daarna op None voor alle 141.
DELAY_BETWEEN_ADDRESSES = 1.0   # Tier 1: 2000 RPM ruimte zat, 1s is beleefd.

def run():
    results = []

    sample = TEST_ADDRESSES if SAMPLE_SIZE is None else TEST_ADDRESSES[:SAMPLE_SIZE]
    total = len(sample)

    for i, entry in enumerate(sample, start=1):
        adres = entry["adres"]
        type_ = "ground-truth-positive"
        expected = entry.get("expected_has_charger")

        slug = slugify(adres)[:60]
        photo_path = PHOTOS_DIR / f"{i:02d}_{slug}.jpg"

        print(f"\n[{i}/{total}] {adres}  ({type_})")

        try:
            # Stap 1: geocode adres → lat/lng
            lat, lng = geocode_address(adres)
            if lat is None:
                print(f"   ⚠️  Geocoden mislukt")
                results.append({
                    "adres": adres, "type": type_, "expected": expected,
                    "lat": None, "lng": None,
                    "status": "GEOCODE_FAILED",
                    "heeft_laadpaal": None, "confidence": None,
                    "signalen": None, "ev_merk": None,
                    "notitie": None, "photo": None,
                })
                continue
            print(f"   📍 {lat:.6f}, {lng:.6f}")

            # Stap 2: check Street View beschikbaar (binnen 100m)
            meta = streetview_metadata(lat, lng, radius=100)
            if meta.get("status") != "OK":
                print(f"   ⚠️  Geen Street View ({meta.get('status')})")
                results.append({
                    "adres": adres, "type": type_, "expected": expected,
                    "lat": lat, "lng": lng,
                    "status": meta.get("status"),
                    "heeft_laadpaal": None, "confidence": None,
                    "signalen": None, "ev_merk": None,
                    "notitie": None, "photo": None,
                })
                continue

            # Stap 3: haal 3 foto's op — recht + 60° links + 60° rechts
            # zodat we voorkant + zijkant/carport beide zien.
            pano_loc = meta.get("location", {})
            pano_lat, pano_lng = pano_loc.get("lat"), pano_loc.get("lng")
            base_heading = None
            if pano_lat is not None and pano_lng is not None:
                base_heading = bearing_deg(pano_lat, pano_lng, lat, lng)
                print(f"   🧭 heading {base_heading:.0f}° (camera → gevel)")

            headings = [base_heading]
            if base_heading is not None:
                headings = [(base_heading - 60) % 360, base_heading, (base_heading + 60) % 360]

            photos = []
            for idx, h in enumerate(headings):
                suffix = ["_L", "", "_R"][idx] if len(headings) == 3 else ""
                p = streetview_photo(lat, lng, heading=h, fov=100)
                p_path = PHOTOS_DIR / f"{i:02d}_{slug}{suffix}.jpg"
                p_path.write_bytes(p)
                photos.append(p)
            photo_path = PHOTOS_DIR / f"{i:02d}_{slug}.jpg"  # middenfoto voor CSV
            print(f"   📷 {len(photos)} foto's opgeslagen ({sum(len(p) for p in photos)/1024:.0f} KB totaal)")

            # Stap 4: Gemini-analyse — alle foto's in één call
            analysis = gemini_analyze_photos(photos)
            heeft = analysis.get("heeft_laadpaal")
            conf = analysis.get("confidence")
            print(f"   🤖 laadpaal={heeft}, confidence={conf}")
            print(f"      \"{analysis.get('notitie')}\"")

            results.append({
                "adres": adres, "type": type_, "expected": expected,
                "lat": lat, "lng": lng,
                "status": "OK",
                "heeft_laadpaal": heeft, "confidence": conf,
                "signalen": ",".join(analysis.get("signalen") or []),
                "ev_merk": analysis.get("ev_merk"),
                "notitie": analysis.get("notitie"),
                "photo": photo_path.name,
            })

            time.sleep(DELAY_BETWEEN_ADDRESSES)  # respecteer Gemini free-tier rate limit

        except Exception as e:
            print(f"   ❌ Fout: {e}")
            results.append({
                "adres": adres, "type": type_, "expected": expected,
                "lat": None, "lng": None,
                "status": f"ERROR: {e}",
                "heeft_laadpaal": None, "confidence": None,
                "signalen": None, "ev_merk": None,
                "notitie": None, "photo": None,
            })

    # CSV
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "adres", "type", "expected", "lat", "lng", "status",
            "heeft_laadpaal", "confidence", "signalen", "ev_merk",
            "notitie", "photo",
        ])
        w.writeheader()
        w.writerows(results)

    ok = [r for r in results if r["status"] == "OK"]
    positives = [r for r in ok if r["heeft_laadpaal"]]

    # Accuracy vs ground truth (alle verwachtingen zijn True in deze POC)
    true_positive = [r for r in ok if r["expected"] is True and r["heeft_laadpaal"] is True]
    false_negative = [r for r in ok if r["expected"] is True and r["heeft_laadpaal"] is False]

    print(f"\n{'─'*60}")
    print(f"Klaar. {len(ok)}/{total} adressen succesvol geanalyseerd.")
    print(f"Laadpaal gedetecteerd: {len(positives)}/{len(ok)}")
    print()
    print(f"Ground-truth accuracy (alle 141 hebben bevestigd een laadpaal):")
    print(f"  ✓ True positive:  {len(true_positive)}/{len(ok)} = {len(true_positive)/max(len(ok),1)*100:.0f}%")
    print(f"  ✗ False negative: {len(false_negative)}/{len(ok)} = {len(false_negative)/max(len(ok),1)*100:.0f}%")
    print()
    print(f"Doel: >85% true positive. Als lager → prompt tunen of Street View heading fixen.")
    print(f"→ Resultaten: {CSV_PATH}")
    print(f"→ Foto's:     {PHOTOS_DIR}")

if __name__ == "__main__":
    run()
