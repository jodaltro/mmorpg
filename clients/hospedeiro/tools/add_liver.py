"""E3 (liver): the region, its passage, spots, niche, vitals, the glycogen/toxin rules, the two verbs, quests and codex. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def upsert(items, item):
    items[:] = [x for x in items if x["id"] != item["id"]] + [item]


upsert(u["entities"], {"id": "figado", "kind": "tecido", "name": "Fígado", "num": {"glicogenio": 30, "toxina": 20}})
upsert(u["passages"], {"id": "arteria_hepatica", "from": "aorta", "to": "figado", "name": "Artéria hepática"})
upsert(u["spots"], {"id": "sinusoide-hepatico", "region": "figado", "name": "Sinusoide hepático, onde o sangue devagar encontra os hepatócitos", "near": ["veia-central"]})
upsert(u["spots"], {"id": "veia-central", "region": "figado", "name": "Veia central, a saída do fígado", "near": ["sinusoide-hepatico"]})
upsert(u["niches"], {"id": "cripta-de-kupffer", "region": "figado", "name": "Cripta de Kupffer", "gene": "peroxissomos", "unique": True,
    "hint": "Entre os cordões de hepatócitos há uma cripta onde um macrófago antigo nunca parou de limpar.",
    "text": "Na cripta, uma célula de Kupffer lhe empresta o ofício de quebrar o que envenena: os peroxissomos. Daqui em diante a toxina do fígado lhe dá energia, não dano."})
upsert(u["vitals"], {"id": "glicogenio", "label": "Glicogênio (fígado)", "e": "figado", "k": "glicogenio", "min": 0, "max": 100, "low": 10, "high": 90})
upsert(u["vitals"], {"id": "toxina", "label": "Toxinas (fígado)", "e": "figado", "k": "toxina", "min": 0, "max": 100, "low": 0, "high": 70})

in_liver = {"in": {"e": "$self", "region": "figado"}}
upsert(u["actions"], {"id": "guardar-glicogenio", "title": "Guardar glicogênio", "by": ["adapter"], "requires": in_liver, "tags": ["metabolism"],
    "effects": [{"op": "adjust", "e": "figado", "k": "glicogenio", "d": 4, "max": 100},
                {"op": "adjust", "e": "$self", "k": "maturidade", "d": 1}]})
upsert(u["actions"], {"id": "filtrar-toxina", "title": "Filtrar toxina", "by": ["adapter"], "requires": in_liver, "tags": ["metabolism", "endure"],
    "effects": [{"op": "adjust", "e": "figado", "k": "toxina", "d": -4, "min": 0},
                {"op": "adjust", "e": "$self", "k": "maturidade", "d": 1},
                {"op": "adjust", "e": "$self", "k": "pressao", "d": 1}]})

upsert(u["rules"], {"id": "figado-guarda", "every": 4, "when": {"all": [{"num": {"e": "sangue", "k": "glicose", "op": ">=", "v": 70}}, {"num": {"e": "figado", "k": "glicogenio", "op": "<", "v": 100}}]},
    "effects": [{"op": "adjust", "e": "figado", "k": "glicogenio", "d": 6, "max": 100}, {"op": "adjust", "e": "sangue", "k": "glicose", "d": -5, "min": 0}]})
upsert(u["rules"], {"id": "figado-libera", "every": 4, "when": {"all": [{"num": {"e": "sangue", "k": "glicose", "op": "<", "v": 48}}, {"num": {"e": "figado", "k": "glicogenio", "op": ">=", "v": 6}}]},
    "effects": [{"op": "adjust", "e": "figado", "k": "glicogenio", "d": -6, "min": 0}, {"op": "adjust", "e": "sangue", "k": "glicose", "d": 8, "max": 100},
                {"op": "emit", "event": "figado-libera", "public": True, "text": "O fígado solta glicogênio no sangue: a glicose volta a subir."}]})
upsert(u["rules"], {"id": "toxina-sobe", "every": 5, "when": {"num": {"e": "figado", "k": "toxina", "op": "<", "v": 100}},
    "effects": [{"op": "adjust", "e": "figado", "k": "toxina", "d": 2, "max": 100}]})
upsert(u["rules"], {"id": "figado-sobrecarregado", "every": 6, "when": {"num": {"e": "figado", "k": "toxina", "op": ">=", "v": 80}},
    "effects": [{"op": "adjust", "e": "corpo", "k": "inflamacao", "d": 3, "max": 100},
                {"op": "emit", "event": "figado-sobrecarregado", "public": True, "text": "O fígado se sobrecarrega de toxinas e o corpo inflama."}]})

visited = {"fact": {"p": "visitou", "s": "$self", "o": "figado", "private": True}}
for q in (
    {"id": "guardar-a-reserva", "title": "Guardar a reserva", "objective": "No fígado, absorva 8 nutrientes: o glicogênio guardado sustenta o corpo quando a glicose cai.",
     "reward": "Pressão evolutiva +3", "desc": "Osteia explica: o que o sangue não gasta, o fígado guarda.", "action": "guardar-glicogenio", "n": 8},
    {"id": "figado-limpo", "title": "Fígado limpo", "objective": "Filtre 8 toxinas nos sinusoides, antes que o corpo inflame.",
     "reward": "Pressão evolutiva +3", "desc": "Osteia teme o que o fígado acumula: toxina demais vira inflamação.", "action": "filtrar-toxina", "n": 8},
):
    upsert(u["quests"], {"id": q["id"], "giver": "estroma", "rank": "E", "title": q["title"], "desc": q["desc"], "objective": q["objective"], "reward": q["reward"],
        "tags": ["metabolism", "explore"],
        "eligible": {"all": [visited, {"deeds": {"action": q["action"], "op": "<", "v": q["n"]}}]},
        "goal": {"deeds": {"action": q["action"], "op": ">=", "v": q["n"]}},
        "rewards": [{"op": "adjust", "e": "$self", "k": "pressao", "d": 3}, {"op": "adjust", "e": "$self", "k": "maturidade", "d": 3},
                    {"op": "relate", "e": "estroma", "to": "$self", "d": 1, "min": -10, "max": 10}]})
upsert(u["quests"], u["quests"].pop(next(i for i, x in enumerate(u["quests"]) if x["id"] == "figado-limpo")))  # keep order stable

upsert(u["codex"], {"id": "cx-figado", "kind": "regiao", "title": "O fígado", "when": visited,
    "text": "O maior órgão interno é uma usina química: seus sinusoides deixam o sangue passar devagar entre cordões de hepatócitos, que guardam açúcar, quebram toxinas e fabricam proteínas."})
upsert(u["codex"], {"id": "cx-glicogenio", "kind": "fisiologia", "title": "Glicogênio", "when": {"deeds": {"action": "guardar-glicogenio", "op": ">=", "v": 1}},
    "text": "Depois da refeição, a insulina manda o fígado guardar glicose como glicogênio; com o jejum, ele a devolve ao sangue. É o reservatório que mantém o açúcar estável."})
upsert(u["codex"], {"id": "cx-kupffer", "kind": "segredo", "title": "Células de Kupffer", "when": {"deeds": {"action": "nicho:cripta-de-kupffer", "op": ">=", "v": 1}},
    "text": "Os macrófagos residentes do fígado ficam dentro dos sinusoides e limpam bactérias e restos que vêm do intestino. Seus peroxissomos quebram toxinas."})

with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("ok")
