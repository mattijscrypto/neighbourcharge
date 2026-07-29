"""Print welke Gemini-modellen jouw API key mag gebruiken."""
import os
import requests
from dotenv import load_dotenv

load_dotenv()
key = os.getenv("GEMINI_API_KEY")

r = requests.get(
    "https://generativelanguage.googleapis.com/v1beta/models",
    headers={"x-goog-api-key": key},
    timeout=15,
)
data = r.json()

if "models" not in data:
    print("Error response:")
    print(data)
    raise SystemExit(1)

print(f"Totaal {len(data['models'])} modellen. Filter op flash + generateContent:\n")
for m in data["models"]:
    name = m["name"]
    if "flash" not in name.lower():
        continue
    if "generateContent" not in m.get("supportedGenerationMethods", []):
        continue
    print(f"  {name}")
    print(f"     display: {m.get('displayName')}")
    print(f"     version: {m.get('version')}")
    print()
