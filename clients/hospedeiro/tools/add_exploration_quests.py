"""E2 (part 3): diapedesis as a key to the aorta (macrophage, neutrophil or the elastic cytoskeleton) and one exploration quest per
niche, offered while the advisor's route points the player to it. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))

for ps in u["passages"]:
    if ps["id"] == "aorta_ascendente":
        ps["gene"] = "citoesqueleto-elastico"
        ps["lineages"] = ["macrofago", "neutrofilo"]
        ps["hint"] = "A parede da aorta é espessa: passam os que atravessam a parede por ofício (macrófago e neutrófilo, a diapedese) ou os que se espremem com o citoesqueleto elástico."

u["quests"] = [q for q in u["quests"] if not q["id"].startswith("rastro-")]
for n in u["niches"]:
    u["quests"].append({
        "id": "rastro-" + n["id"],
        "giver": "estroma",
        "rank": "F",
        "title": "Rastro: " + n["name"],
        "desc": "Osteia segue um fio químico que leva a um recanto do corpo que você ainda não viu.",
        "objective": "Siga o rastro químico até " + n["name"] + " e entre.",
        "reward": "Pressão evolutiva +2 e a gratidão de Osteia",
        "tags": ["explore"],
        "eligible": {"all": [
            {"tag": {"e": "$self", "k": "rota", "v": n["id"]}},
            {"deeds": {"action": "nicho:" + n["id"], "op": "<", "v": 1}},
        ]},
        "goal": {"deeds": {"action": "nicho:" + n["id"], "op": ">=", "v": 1}},
        "rewards": [
            {"op": "adjust", "e": "$self", "k": "pressao", "d": 2},
            {"op": "relate", "e": "estroma", "to": "$self", "d": 1, "min": -10, "max": 10},
            {"op": "adjust", "e": "$self", "k": "maturidade", "d": 2},
        ],
    })
with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("quests:", len(u["quests"]))
