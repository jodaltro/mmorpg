"""Guaranteed permanent genes alongside existing rewards. Idempotent, no random loot claims."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
path = ROOT / "universes/hospedeiro/universe.json"
u = json.loads(path.read_text(encoding="utf-8"))
quests = {
    "primeiro-mergulho": "nucleo-reativo", "caca-no-capilar": "vesicula-toxica", "conter-infeccao": "flagelo-calejado",
    "prova-macrofago": "fagossomo-profundo", "prova-neutrofilo": "degranulacao-toxica",
    "prova-dendritica": "dendritos-sensores", "prova-linfocito-b": "anticorpos-em-y",
    "prova-t-citotoxico": "granzima-b", "prova-t-auxiliar": "interleucina-2",
    "prova-mastocito": "degranulacao-explosiva", "prova-eosinofilo": "peroxidase-concentrada",
    "prova-celula-nk": "memoria-de-presa", "prova-t-regulador": "interleucina-10",
}
dungeons = {"granuloma": "espinhos-de-quitina", "cordoes-hepaticos": "mitocondria-avida",
            "centro-germinativo": "citoesqueleto-elastico", "criptas-profundas": "enzima-voraz", "nefrons": "peroxissomos"}
genes = {g["id"]: g for g in u["mutations"]}
proof_actions = {
    "macrofago": ("absorver-nutriente", "nutrientes"), "neutrofilo": ("esquivar", "esquivas"),
    "dendritica": ("absorver-nutriente", "nutrientes"), "linfocito-b": ("estilo-toxina", "disparos"),
    "t-citotoxico": ("derrotar-virus", "abates"), "t-auxiliar": ("absorver-nutriente", "nutrientes"),
    "mastocito": ("absorver-nutriente", "nutrientes"), "eosinofilo": ("derrotar-virus", "abates"),
    "celula-nk": ("esquivar", "esquivas"), "t-regulador": ("absorver-nutriente", "nutrientes"),
}
def replace_counter(node, old, new):
    if isinstance(node, dict):
        if "num" in node and node["num"].get("e") == "$self" and node["num"].get("k") == old:
            node["num"]["k"] = new
        for value in node.values():
            replace_counter(value, old, new)
    elif isinstance(node, list):
        for value in node:
            replace_counter(value, old, new)

for lineage, (action, stat) in proof_actions.items():
    counter = "prova-" + lineage + "-feitos"
    quest = next(q for q in u["quests"] if q["id"] == "prova-" + lineage)
    replace_counter(quest, stat, counter)
    if not quest["objective"].startswith("Após a diferenciação, "):
        quest["objective"] = "Após a diferenciação, " + quest["objective"][0].lower() + quest["objective"][1:]
    effects = next(a for a in u["actions"] if a["id"] == action)["effects"]
    effects[:] = [e for e in effects if e.get("k") != counter]
    effects.append({"op":"adjust", "e":"$self", "k":counter, "d":1,
                    "if":{"tag":{"e":"$self", "k":"lineage", "v":lineage}}})

for collection, rewards in [(u["quests"], quests), (u["dungeons"], dungeons)]:
    for entry in collection:
        gene = rewards.get(entry["id"])
        if not gene:
            continue
        effects = entry.setdefault("rewards", [])
        effects[:] = [e for e in effects if e.get("op") != "acquire-gene"]
        effects.append({"op": "acquire-gene", "e": "$self", "v": gene})
        if "reward" in entry:
            entry["reward"] = entry["reward"].split(" · Gene permanente:")[0] + " · Gene permanente: " + genes[gene]["name"] + " (Corpo → Genes)"
        else:
            entry["desc"] = entry["desc"].split("\nRecompensa permanente:")[0] + "\nRecompensa permanente: " + genes[gene]["name"] + ". " + genes[gene]["desc"]
path.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("permanent gene rewards:", len(quests), "quests,", len(dungeons), "dungeons")
