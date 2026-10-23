"""Adds the heart, the lung and the aorta (and their places) to the Hospedeiro universe. Idempotent; run from the repository root."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))
new_regions = [
    {"id": "coracao", "kind": "tecido", "name": "Coração", "num": {"pulso": 70, "pressao": 50}},
    {"id": "pulmao", "kind": "tecido", "name": "Pulmão", "num": {"oxigenio": 80, "carga": 0}},
    {"id": "aorta", "kind": "tecido", "name": "Aorta e artérias", "num": {"pressao": 60, "carga": 0}},
]
new_spots = [
    {"id": "atrio", "region": "coracao", "name": "Átrio, onde o sangue volta", "near": ["valvula"]},
    {"id": "valvula", "region": "coracao", "name": "Válvula, que abre e fecha no ritmo", "near": ["atrio"]},
    {"id": "alveolos", "region": "pulmao", "name": "Alvéolos, onde o ar encontra o sangue", "near": ["bronquiolo"]},
    {"id": "bronquiolo", "region": "pulmao", "name": "Bronquíolo, a entrada do ar", "near": ["alveolos"]},
    {"id": "arco", "region": "aorta", "name": "Arco da aorta", "near": ["braquiocefalica"]},
    {"id": "braquiocefalica", "region": "aorta", "name": "Braquiocefálica, a saída para o corpo", "near": ["arco"]},
]
have = {e["id"] for e in u["entities"]}
for r in new_regions:
    if r["id"] not in have:
        u["entities"].append(r)
have_spots = {s["id"] for s in u["spots"]}
for s in new_spots:
    if s["id"] not in have_spots:
        u["spots"].append(s)
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(u["entities"]), "entities", len(u["spots"]), "spots")
