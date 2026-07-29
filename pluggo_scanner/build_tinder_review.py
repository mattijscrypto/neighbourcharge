#!/usr/bin/env python3
"""
Pluggo Scanner — Tinder review generator

Leest results.csv + foto's van een wijk en bouwt één zelfstandig HTML-bestand
waarin je per adres de 5 foto's + AI-suggestie ziet en met JA/NEE/TWIJFEL
door de lijst heen swipet. Aan het einde download je decisions.csv.

Gebruik:
    python3 build_tinder_review.py hoefkwartier
    open output_browser/hoefkwartier/review.html

Sneltoetsen in de review:
    J = ja      N = nee     T = twijfel     ← = terug
"""

import argparse
import base64
import csv
import json
import sys
from pathlib import Path

BASE = Path(__file__).parent / "output_browser"


def load_results(csv_path):
    if not csv_path.exists():
        print(f"❌ Geen results.csv gevonden op {csv_path}")
        sys.exit(1)
    with csv_path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def photo_to_b64(path):
    if not path.exists():
        return None
    return "data:image/jpeg;base64," + base64.b64encode(path.read_bytes()).decode()


def build_cards(results, photos_dir):
    """Bouw list van dicts met alle info per adres, foto's als base64."""
    cards = []
    for i, r in enumerate(results, start=1):
        if r.get("status") != "OK":
            # Adressen zonder foto's tonen we wel, met leeg fotoveld,
            # zodat je alsnog beslist. Het is jouw AVG-hygiëne.
            pass
        slug = f"{i:02d}_" + "".join(c if c.isalnum() else "_" for c in r["adres"]).strip("_")[:60]
        photos = []
        labels = (r.get("labels") or "").split(",") if r.get("labels") else []
        for lbl in labels:
            if not lbl:
                continue
            p = photos_dir / f"{slug}_{lbl}.jpg"
            b64 = photo_to_b64(p)
            if b64:
                photos.append({"label": lbl, "src": b64})
        cards.append({
            "adres": r["adres"],
            "status": r.get("status", ""),
            "ai_heeft_laadpaal": r.get("heeft_laadpaal", ""),
            "ai_confidence": r.get("confidence", ""),
            "ai_signalen": r.get("signalen", ""),
            "ai_ev_merk": r.get("ev_merk", ""),
            "ai_notitie": r.get("notitie", ""),
            "expected": r.get("expected", ""),
            "n_photos": len(photos),
            "photos": photos,
        })
    return cards


HTML_TEMPLATE = """<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<title>Pluggo review — {wijk}</title>
<style>
  * {{ box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
         margin: 0; background: #F1F3F4; color: #212121; }}
  header {{ background: #1B5E20; color: #fff; padding: 14px 20px; display: flex;
            justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }}
  header h1 {{ font-size: 20px; margin: 0; }}
  header .progress {{ font-variant-numeric: tabular-nums; font-weight: 600; }}
  .bar {{ height: 4px; background: #A5D6A7; }}
  .bar-fill {{ height: 100%; background: #FFEB3B; transition: width .2s; }}
  main {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}
  .card {{ background: #fff; border-radius: 14px; box-shadow: 0 4px 20px rgba(0,0,0,.08); overflow: hidden; }}
  .adres {{ padding: 20px 24px 10px; font-size: 26px; font-weight: 700; }}
  .meta {{ padding: 0 24px 12px; font-size: 14px; color: #616161; }}
  .ai-box {{ margin: 0 24px 16px; padding: 12px 14px; border-radius: 10px; background: #E8F5E9;
             border-left: 4px solid #2E7D32; font-size: 14px; }}
  .ai-box.nee {{ background: #FFF3E0; border-left-color: #E65100; }}
  .ai-box b {{ display: inline-block; min-width: 90px; }}
  .photos {{ display: grid; grid-template-columns: repeat(5, 1fr); gap: 4px; padding: 0 4px 4px;
             background: #263238; }}
  .photos.count-4 {{ grid-template-columns: repeat(4, 1fr); }}
  .photos.count-3 {{ grid-template-columns: repeat(3, 1fr); }}
  .photos.count-2 {{ grid-template-columns: repeat(2, 1fr); }}
  .photos.count-1 {{ grid-template-columns: 1fr; }}
  .photo-wrap {{ position: relative; cursor: pointer; }}
  .photo-wrap img {{ width: 100%; height: 200px; object-fit: cover; display: block; }}
  .photo-wrap .lbl {{ position: absolute; top: 4px; left: 4px; background: rgba(0,0,0,.6);
                       color: #fff; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: 600; }}
  .no-photos {{ padding: 40px 24px; background: #FFEBEE; color: #C62828; font-weight: 600; text-align: center; }}
  .buttons {{ display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; padding: 16px 24px 24px; }}
  .btn {{ padding: 20px; font-size: 20px; font-weight: 800; border: none; border-radius: 12px;
          cursor: pointer; color: #fff; transition: transform .1s; }}
  .btn:active {{ transform: scale(.97); }}
  .btn-ja {{ background: #2E7D32; }}
  .btn-twijfel {{ background: #F9A825; }}
  .btn-nee {{ background: #C62828; }}
  .btn small {{ display: block; opacity: .8; font-weight: 500; font-size: 12px; margin-top: 4px; }}
  .toolbar {{ display: flex; gap: 8px; justify-content: space-between; margin-top: 16px; }}
  .btn-mini {{ background: #37474F; color: #fff; padding: 10px 16px; border: none; border-radius: 8px;
               cursor: pointer; font-size: 14px; }}
  .btn-mini.warn {{ background: #E65100; }}
  .btn-mini.success {{ background: #1B5E20; }}
  .done {{ text-align: center; padding: 60px 20px; }}
  .done h2 {{ font-size: 32px; margin-bottom: 20px; }}
  .lightbox {{ position: fixed; inset: 0; background: rgba(0,0,0,.9); display: none;
               align-items: center; justify-content: center; z-index: 200; padding: 20px; cursor: pointer; }}
  .lightbox img {{ max-width: 100%; max-height: 100%; object-fit: contain; }}
  .lightbox.on {{ display: flex; }}
</style>
</head>
<body>
<header>
  <h1>Pluggo review — {wijk}</h1>
  <div class="progress"><span id="idx">1</span>/<span id="total">{total}</span> · <span id="counts"></span></div>
</header>
<div class="bar"><div class="bar-fill" id="bar" style="width:0%"></div></div>
<main id="app"></main>
<div class="lightbox" id="lightbox" onclick="closeLb()"><img id="lbimg" alt=""></div>

<script>
const WIJK = {wijk_json};
const CARDS = {cards_json};
const STORAGE_KEY = "pluggo_review_" + WIJK;

let state = {{ i: 0, decisions: {{}} }};

// Load saved state from localStorage
try {{
  const saved = localStorage.getItem(STORAGE_KEY);
  if (saved) state = JSON.parse(saved);
}} catch(e) {{}}

function save() {{
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}}

function counts() {{
  const d = Object.values(state.decisions);
  const ja = d.filter(x => x === "ja").length;
  const nee = d.filter(x => x === "nee").length;
  const twijfel = d.filter(x => x === "twijfel").length;
  return {{ja, nee, twijfel}};
}}

function render() {{
  const app = document.getElementById("app");
  const total = CARDS.length;
  const i = state.i;
  document.getElementById("idx").textContent = Math.min(i + 1, total);
  document.getElementById("total").textContent = total;
  document.getElementById("bar").style.width = (i / total * 100) + "%";
  const c = counts();
  document.getElementById("counts").textContent = `✅${{c.ja}} ⚠️${{c.twijfel}} ❌${{c.nee}}`;

  if (i >= total) {{
    app.innerHTML = `
      <div class="card done">
        <h2>Klaar! 🎉</h2>
        <p>${{c.ja}} × ja · ${{c.twijfel}} × twijfel · ${{c.nee}} × nee</p>
        <div class="toolbar" style="justify-content:center">
          <button class="btn-mini success" onclick="download()">📥 Download decisions.csv</button>
          <button class="btn-mini" onclick="prev()">← Terug</button>
          <button class="btn-mini warn" onclick="reset()">🗑 Reset alles</button>
        </div>
      </div>`;
    return;
  }}

  const card = CARDS[i];
  const already = state.decisions[card.adres];
  const aiSays = card.ai_heeft_laadpaal;
  const aiClass = (aiSays === "True" || aiSays === "true") ? "" : "nee";
  const conf = card.ai_confidence ? (parseFloat(card.ai_confidence) * 100).toFixed(0) + "%" : "?";
  const photoCount = card.photos.length;

  let photosHtml = "";
  if (photoCount === 0) {{
    photosHtml = `<div class="no-photos">Geen foto's beschikbaar (status: ${{card.status}})</div>`;
  }} else {{
    const photoItems = card.photos.map(p =>
      `<div class="photo-wrap" onclick="openLb('${{p.src}}')">
         <img src="${{p.src}}" alt="${{p.label}}">
         <span class="lbl">${{p.label}}</span>
       </div>`
    ).join("");
    photosHtml = `<div class="photos count-${{photoCount}}">${{photoItems}}</div>`;
  }}

  app.innerHTML = `
    <div class="card">
      <div class="adres">${{card.adres}}</div>
      <div class="meta">
        Foto's: ${{photoCount}}
        ${{card.expected ? '· Ground truth: ' + card.expected : ''}}
        ${{already ? '· <b style="color:#2E7D32">Al beoordeeld: ' + already + '</b>' : ''}}
      </div>
      <div class="ai-box ${{aiClass}}">
        <div><b>AI zegt:</b> ${{aiSays || '?'}} (${{conf}})</div>
        <div><b>Signalen:</b> ${{card.ai_signalen || '—'}}</div>
        <div><b>EV merk:</b> ${{card.ai_ev_merk || '—'}}</div>
        <div><b>Notitie:</b> ${{card.ai_notitie || '—'}}</div>
      </div>
      ${{photosHtml}}
      <div class="buttons">
        <button class="btn btn-nee" onclick="decide('nee')">❌ NEE<small>N</small></button>
        <button class="btn btn-twijfel" onclick="decide('twijfel')">⚠️ TWIJFEL<small>T</small></button>
        <button class="btn btn-ja" onclick="decide('ja')">✅ JA<small>J</small></button>
      </div>
      <div class="toolbar" style="padding:0 24px 20px">
        <button class="btn-mini" onclick="prev()">← Terug</button>
        <button class="btn-mini" onclick="skip()">Skip →</button>
        <button class="btn-mini success" onclick="download()">📥 Download CSV</button>
      </div>
    </div>`;
}}

function decide(v) {{
  const card = CARDS[state.i];
  state.decisions[card.adres] = v;
  state.i++;
  save();
  render();
}}

function prev() {{
  if (state.i > 0) state.i--;
  render();
}}

function skip() {{
  state.i = Math.min(state.i + 1, CARDS.length);
  save();
  render();
}}

function reset() {{
  if (!confirm("Alle beslissingen wissen?")) return;
  state = {{i: 0, decisions: {{}}}};
  save();
  render();
}}

function openLb(src) {{
  document.getElementById("lbimg").src = src;
  document.getElementById("lightbox").classList.add("on");
}}
function closeLb() {{
  document.getElementById("lightbox").classList.remove("on");
}}

function download() {{
  const rows = [["adres", "review_decision", "ai_heeft_laadpaal", "ai_confidence", "ai_notitie"]];
  for (const card of CARDS) {{
    const d = state.decisions[card.adres] || "";
    rows.push([card.adres, d, card.ai_heeft_laadpaal, card.ai_confidence, card.ai_notitie]);
  }}
  const csv = rows.map(r =>
    r.map(cell => {{
      const s = String(cell ?? "");
      return /[",\\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    }}).join(",")
  ).join("\\n");
  const blob = new Blob([csv], {{type: "text/csv;charset=utf-8"}});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "decisions_" + WIJK + ".csv";
  a.click();
  URL.revokeObjectURL(url);
}}

document.addEventListener("keydown", e => {{
  if (document.getElementById("lightbox").classList.contains("on")) {{
    closeLb();
    return;
  }}
  if (state.i >= CARDS.length) return;
  if (e.key === "j" || e.key === "J") decide("ja");
  else if (e.key === "n" || e.key === "N") decide("nee");
  else if (e.key === "t" || e.key === "T") decide("twijfel");
  else if (e.key === "ArrowLeft") prev();
  else if (e.key === "ArrowRight") skip();
}});

render();
</script>
</body>
</html>
"""


def build(wijk):
    wijk_dir = BASE / wijk
    if not wijk_dir.exists():
        print(f"❌ Wijk '{wijk}' bestaat niet in {BASE}")
        sys.exit(1)

    csv_path = wijk_dir / "results.csv"
    photos_dir = wijk_dir / "photos"
    results = load_results(csv_path)
    print(f"→ {len(results)} adressen uit {csv_path.name}")
    print(f"→ Foto's uit {photos_dir}")

    cards = build_cards(results, photos_dir)
    total_photos = sum(c["n_photos"] for c in cards)
    print(f"→ {total_photos} foto's ingebed als base64")

    html = HTML_TEMPLATE.format(
        wijk=wijk,
        total=len(cards),
        wijk_json=json.dumps(wijk),
        cards_json=json.dumps(cards),
    )
    out = wijk_dir / "review.html"
    out.write_text(html, encoding="utf-8")
    size_mb = out.stat().st_size / 1024 / 1024
    print(f"✅ {out}  ({size_mb:.1f} MB)")
    print(f"\nOpen met:\n    open {out}\n")


def parse_args():
    p = argparse.ArgumentParser(description="Bouw tinder-review HTML voor een wijk")
    p.add_argument("wijk", help="Wijk-naam (moet bestaan in output_browser/)")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    build(args.wijk)
