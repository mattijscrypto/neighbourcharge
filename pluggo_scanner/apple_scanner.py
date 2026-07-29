"""
Pluggo Scanner — Apple Look Around edition

Vervangt browser_scanner.py (Google Street View + Playwright) door:
  - MKLookAroundSnapshotter via native Swift CLI (apple_snapshot binary)
  - Verse Apple Look Around data + fijnere pano-density dan Google
  - Zelfde 3-foto geometrie (L1 + base + R1) + zelfde Ollama pipeline

Voorbereiding:
    # 1. Compileer het Swift binary (eenmalig, ~5 sec):
    cd pluggo_scanner
    swiftc apple_snapshot.swift -o apple_snapshot \\
        -framework MapKit -framework AppKit -framework CoreLocation

    # 2. Ollama draait al lokaal (zelfde als browser_scanner)
    ollama serve &  # als 't nog niet draait
    ollama pull qwen2.5vl:7b

    # 3. Python deps
    pip install requests

Gebruik:
    # Test één adres (Gibraltar 170 = ground-truth met verse wallbox in Apple)
    python3 apple_scanner.py --wijk vathorst --limit 1

    # Simple mode: 1 foto per adres (skip L1/R1 geometrie)
    python3 apple_scanner.py --wijk vathorst --limit 5 --simple

    # Volledige run
    python3 apple_scanner.py --wijk vathorst --limit 0
"""

import argparse
import base64
import csv
import json
import math
import subprocess
import time
from pathlib import Path

import requests

from test_addresses import TEST_ADDRESSES

# ─────────────────────────────────────────────────────────────
# Config

DEFAULT_WIJK = "vathorst"
DEFAULT_SAMPLE_SIZE = 5
STEP_METERS = 6              # Apple heeft veel fijnere pano-density dan Google (~2-4m intervals)
FOV_W, FOV_H = 1280, 720     # snapshot resolutie
PITCH = 0.0                  # 0 = horizontaal, negatief = omhoog kijken (Look Around pitch is inverted t.o.v. Google)
OLLAMA_MODEL = "qwen2.5vl:7b"
OLLAMA_URL = "http://localhost:11434"

# Paden — wordt door setup_paths gezet
SCRIPT_DIR = Path(__file__).parent
APPLE_BIN = SCRIPT_DIR / "apple_snapshot"
OUTPUT_DIR = None
PHOTOS_DIR = None
CSV_PATH = None

def setup_paths(wijk):
    global OUTPUT_DIR, PHOTOS_DIR, CSV_PATH
    OUTPUT_DIR = SCRIPT_DIR / "output_apple" / wijk
    PHOTOS_DIR = OUTPUT_DIR / "photos"
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    CSV_PATH = OUTPUT_DIR / "results.csv"

# ─────────────────────────────────────────────────────────────
# Geodesic helpers (kopie uit browser_scanner.py — geen import om Playwright-dep te vermijden)

UA = "PluggoScanner/1.0 (contact: m.sloothovenier@gmail.com)"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

_last_nominatim = 0.0

def geocode(adres):
    """Adres → (lat, lng) via Nominatim."""
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
# OSM Overpass: nearest street bearing

_overpass_cache = {}

def get_street_geometry(lat, lng, radius_m=30):
    """
    Vind de dichtstbijzijnde highway-way, return (bearing, closest_point_on_street).

    - bearing = richting van de straat (0-360, tweezijdig ambigu, we kiezen willekeurig)
    - closest_point = (lat, lng) van het projectie-punt op de straat vanaf (lat, lng)

    Return (None, None) bij falen.
    """
    key = (round(lat, 6), round(lng, 6))
    if key in _overpass_cache:
        return _overpass_cache[key]

    q = f"""[out:json][timeout:10];
(way(around:{radius_m},{lat},{lng})["highway"~"^(residential|living_street|unclassified|tertiary|secondary|primary|service)$"];);
out geom;"""
    try:
        r = requests.post(OVERPASS_URL, data=q, headers={"User-Agent": UA}, timeout=20)
        r.raise_for_status()
        ways = r.json().get("elements", [])
    except Exception as e:
        print(f"      [overpass] fout: {type(e).__name__}: {str(e)[:80]}")
        _overpass_cache[key] = (None, None)
        return None, None

    if not ways:
        _overpass_cache[key] = (None, None)
        return None, None

    # Vind kortste segment-punt afstand
    best = None  # (dist_m, seg_a, seg_b, closest_lat, closest_lng)
    for way in ways:
        geom = way.get("geometry", [])
        for i in range(len(geom) - 1):
            a = (geom[i]["lat"], geom[i]["lon"])
            b = (geom[i+1]["lat"], geom[i+1]["lon"])
            cp_lat, cp_lng = _project_on_segment(lat, lng, a, b)
            d = haversine_m(lat, lng, cp_lat, cp_lng)
            if best is None or d < best[0]:
                best = (d, a, b, cp_lat, cp_lng)

    if best is None:
        _overpass_cache[key] = (None, None)
        return None, None

    _, a, b, cp_lat, cp_lng = best
    street_bearing = bearing_deg(a[0], a[1], b[0], b[1])
    result = (street_bearing, (cp_lat, cp_lng))
    _overpass_cache[key] = result
    return result

def _project_on_segment(plat, plng, a, b):
    """
    Kleine helper: projecteer punt (plat, plng) op segment a→b in vlakke benadering.
    Voor kleine afstanden (<100m) is een equirectangular projectie nauwkeurig genoeg.
    """
    lat0 = math.radians((a[0] + b[0]) / 2)
    # Zet lat/lng om naar meters t.o.v. a
    def to_xy(la, ln):
        x = math.radians(ln - a[1]) * math.cos(lat0) * 6371000.0
        y = math.radians(la - a[0]) * 6371000.0
        return x, y
    ax, ay = 0.0, 0.0
    bx, by = to_xy(b[0], b[1])
    px, py = to_xy(plat, plng)
    dx, dy = bx - ax, by - ay
    L2 = dx*dx + dy*dy
    if L2 < 1e-6:
        return a
    t = ((px - ax) * dx + (py - ay) * dy) / L2
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    # Zet terug naar lat/lng
    dlat = cy / 6371000.0
    dlng = cx / (6371000.0 * math.cos(lat0))
    return a[0] + math.degrees(dlat), a[1] + math.degrees(dlng)

# ─────────────────────────────────────────────────────────────
# Swift snapshotter driver

def swift_snapshot(query_lat, query_lng, heading, out_path, pitch=PITCH, w=FOV_W, h=FOV_H, timeout=30):
    """
    Roep het Swift binary aan. Return: (success: bool, error_msg: str|None).
    """
    if not APPLE_BIN.exists():
        return False, f"binary ontbreekt: {APPLE_BIN} — draai eerst: swiftc apple_snapshot.swift -o apple_snapshot -framework MapKit -framework AppKit -framework CoreLocation"

    cmd = [
        str(APPLE_BIN),
        f"{query_lat:.7f}",
        f"{query_lng:.7f}",
        f"{heading:.2f}",
        f"{pitch:.2f}",
        str(w),
        str(h),
        str(out_path),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return False, "timeout"

    if proc.returncode == 0:
        return True, None

    err = (proc.stderr.decode(errors="replace") or "").strip() or f"exit_code={proc.returncode}"
    return False, err

# ─────────────────────────────────────────────────────────────
# Foto-capture: 3 shots met OSM street bearing, of 1 shot in simple mode

def capture_photos(house_lat, house_lng, slug, simple=False):
    """
    Return: lijst van (label, path, bytes) tuples, of None bij totale mislukking.

    Simple mode: 1 foto op query = house_coord, heading = auto (Apple's default).
    Full mode:   3 foto's (L1, base, R1) met street bearing van Overpass.
    """
    photos = []

    if simple:
        out = PHOTOS_DIR / f"{slug}_base.jpg"
        # Heading 0 = camera kijkt naar noord vanaf de pano. Niet ideaal maar
        # geeft ons in ieder geval een snapshot om te zien of Apple wél wat teruggeeft.
        # Voor "point at house": query iets weg van huis + bereken heading terug.
        # Simple probeert eerst een small-offset trick:
        probe_query_lat, probe_query_lng = offset_latlng(house_lat, house_lng, 0.0, 4.0)  # 4m noord
        heading = bearing_deg(probe_query_lat, probe_query_lng, house_lat, house_lng)
        ok, err = swift_snapshot(probe_query_lat, probe_query_lng, heading, out)
        if not ok:
            print(f"      base: {err}")
            return None
        photos.append(("base", out, out.read_bytes()))
        return photos

    # Full mode: probeer Overpass voor street bearing
    street = get_street_geometry(house_lat, house_lng, radius_m=30)
    street_bearing, cp = street

    if street_bearing is None:
        print(f"      [warn] geen straat gevonden — fallback naar simple mode")
        return capture_photos(house_lat, house_lng, slug, simple=True)

    cp_lat, cp_lng = cp  # closest point op straat t.o.v. het huis
    print(f"      🗺️  straat-bearing {street_bearing:.0f}°, closest street point {cp_lat:.6f},{cp_lng:.6f}")

    # Geometrie:
    # - base_query = closest street point (pano zit meestal precies daar)
    # - L1_query  = cp verschoven -STEP_METERS langs straat
    # - R1_query  = cp verschoven +STEP_METERS langs straat
    # Voor elke: heading = bearing(query → house)
    plan = [
        ("L1",   offset_latlng(cp_lat, cp_lng, (street_bearing + 180) % 360, STEP_METERS)),
        ("base", (cp_lat, cp_lng)),
        ("R1",   offset_latlng(cp_lat, cp_lng, street_bearing % 360, STEP_METERS)),
    ]

    for label, (q_lat, q_lng) in plan:
        heading = bearing_deg(q_lat, q_lng, house_lat, house_lng)
        out = PHOTOS_DIR / f"{slug}_{label}.jpg"
        ok, err = swift_snapshot(q_lat, q_lng, heading, out)
        if not ok:
            print(f"      {label}: {err}")
            continue
        photos.append((label, out, out.read_bytes()))

    if not photos:
        return None
    return photos

# ─────────────────────────────────────────────────────────────
# Ollama vision — zelfde als browser_scanner, iets aangescherpt

PROMPT_MULTI = """Je bekijkt {n} Apple Look Around foto's van HETZELFDE Nederlandse huis in nieuwbouwwijk Vathorst, Amersfoort.
De foto's zijn genomen vanaf {n} posities langs de straat, allemaal met de camera gericht op het CENTRALE doel-huis.
Volgorde: links-schuin (kijk terug-rechts op huis), recht ervoor (base, frontaal), rechts-schuin (kijk terug-links op huis).
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
- STERK: LAADKABEL zichtbaar — dikke zwarte/gele/oranje kabel van muur/paal naar auto,
  vaak liggend op de oprit of hangend langs de auto. LET GOED OP: een kabel is een
  onmiskenbaar signaal dat het huis thuis laadt, ook al zie je de wallbox zelf niet
  duidelijk (die kan verscholen zitten).
- MATIG: EV geparkeerd (Tesla, ID.3/4/7, Zoe, Ioniq, Kia EV6/Niro, Polestar, Audi e-tron, BMW i, EQC/EQE, Mustang Mach-E)
- ZWAK: kabelgoot langs gevel naar oprit

Vathorst-context: dichte heggen, wallboxes vaak op zijgevel of onder carport. Kijk ALLE foto's — een charger die vanaf de voorkant onzichtbaar is kan wel op de zijfoto's staan.

Negeer: straatlantaarns, verkeersborden, brievenbussen, gele nutskastjes.

Antwoord ALLEEN in geldig JSON (geen extra tekst):
{{"heeft_laadpaal": true of false, "confidence": getal 0.0-1.0, "signalen": [array van gedetecteerde signaal-strings], "ev_merk": string of null, "notitie": "max 20 woorden NL"}}"""

def ollama_analyze(photos_bytes):
    """Stuur foto's naar lokale Ollama qwen2.5vl."""
    images_b64 = [base64.b64encode(p).decode() for p in photos_bytes]
    prompt = PROMPT_MULTI.format(n=len(photos_bytes))
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
        timeout=600,
    )
    r.raise_for_status()
    return json.loads(r.json()["response"])

# ─────────────────────────────────────────────────────────────
# Main

def slugify(s):
    return "".join(c if c.isalnum() else "_" for c in s).strip("_")[:60]

def write_csv(results):
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "adres", "expected", "lat", "lng", "status",
            "heeft_laadpaal", "confidence", "signalen", "ev_merk",
            "notitie", "n_photos", "labels",
        ])
        w.writeheader()
        w.writerows(results)

def run(wijk, sample_size, simple):
    setup_paths(wijk)
    sample = TEST_ADDRESSES if sample_size is None else TEST_ADDRESSES[:sample_size]
    total = len(sample)
    results = []

    print(f"→ Wijk: {wijk}")
    print(f"→ {total} adressen, model={OLLAMA_MODEL}, simple={simple}")
    print(f"→ Binary: {APPLE_BIN} (bestaat: {APPLE_BIN.exists()})")
    print(f"→ Foto's: {PHOTOS_DIR}\n")

    if not APPLE_BIN.exists():
        print("❌ Swift binary bestaat nog niet. Compileer eerst:")
        print("   cd pluggo_scanner")
        print("   swiftc apple_snapshot.swift -o apple_snapshot \\")
        print("       -framework MapKit -framework AppKit -framework CoreLocation")
        return

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

            captured = capture_photos(lat, lng, slug, simple=simple)
            if not captured:
                print("   ⚠️  geen foto's")
                results.append({
                    "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                    "status": "NO_LOOKAROUND", "heeft_laadpaal": None,
                    "confidence": None, "signalen": None, "ev_merk": None,
                    "notitie": None, "n_photos": 0, "labels": None,
                })
                write_csv(results)
                continue

            labels = [lbl for lbl, _, _ in captured]
            photos = [b for _, _, b in captured]
            print(f"   📷 {len(photos)} foto's: [{','.join(labels)}]")

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

    write_csv(results)

    ok = [r for r in results if r["status"] == "OK"]
    tp = [r for r in ok if r["expected"] and r["heeft_laadpaal"]]
    print(f"\n{'─'*60}")
    print(f"Klaar. {len(ok)}/{total} succesvol.")
    if ok:
        print(f"True positive: {len(tp)}/{len(ok)} = {len(tp)/len(ok)*100:.0f}%")
    print(f"→ CSV:    {CSV_PATH}")
    print(f"→ Foto's: {PHOTOS_DIR}")

def parse_args():
    p = argparse.ArgumentParser(description="Pluggo Apple Look Around scanner")
    p.add_argument("--wijk", default=DEFAULT_WIJK,
                   help="Wijk-naam. Output → output_apple/<wijk>/")
    p.add_argument("--limit", type=int, default=DEFAULT_SAMPLE_SIZE,
                   help="Max aantal adressen (0 = alles)")
    p.add_argument("--simple", action="store_true",
                   help="1 foto per adres i.p.v. 3-foto L1/base/R1 geometrie")
    return p.parse_args()

if __name__ == "__main__":
    args = parse_args()
    sample_size = None if args.limit == 0 else args.limit
    run(args.wijk, sample_size, args.simple)
