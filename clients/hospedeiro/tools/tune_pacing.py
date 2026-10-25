"""Pacing: growth gates scale from the original baseline by PACE.
PACE 12 is four times the previous cadence (3). Idempotent; rewards are tuned separately."""
import json
from pathlib import Path

PACE = 12
BASE = {"threshold": 10, "tiers": [14, 40], "granuloma": 14, "cordoes-hepaticos": 16,
        "centro-germinativo": 18, "criptas-profundas": 20, "nefrons": 22}

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))
u["evolution"]["threshold"] = BASE["threshold"] * PACE
u["differentiation"]["tiers"] = [t * PACE for t in BASE["tiers"]]
for d in u["dungeons"]:
    if d["id"] in BASE:
        d["eligible"]["num"]["v"] = BASE[d["id"]] * PACE
with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("pace", PACE, u["evolution"]["threshold"], u["differentiation"]["tiers"], [d["eligible"]["num"]["v"] for d in u["dungeons"]])
