"""Pacing: how fast the body evolves. Everything that gates growth scales together (PACE x the first values), so a mutation takes
about three times the kills it used to, and the first class about three times the maturity. Idempotent; PACE is the only knob."""
import json
from pathlib import Path

PACE = 3
BASE = {"threshold": 10, "tiers": [14, 40], "granuloma": 14, "cordoes-hepaticos": 16}

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
