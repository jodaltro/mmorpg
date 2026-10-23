"""E3 (liver dungeon): Os Cordões Hepáticos, five rooms inside the liver with modifiers tied to the liver's own state. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def upsert(items, item):
    items[:] = [x for x in items if x["id"] != item["id"]] + [item]


upsert(u["skills"], {"id": "selo-do-figado", "name": "Selo do Fígado", "desc": "Você limpou os cordões hepáticos uma vez: seu corpo guarda a lembrança do que se acumula no fígado.", "rarity": "rara"})
upsert(u["skills"], {"id": "primeiro-filtro", "name": "Primeiro Filtro", "desc": "Foi a primeira célula a limpar os Cordões Hepáticos. O corpo inteiro lembra.", "rarity": "epica"})

num = lambda e, k, op, v: {"num": {"e": e, "k": k, "op": op, "v": v}}
upsert(u["dungeons"], {
    "id": "cordoes-hepaticos",
    "name": "Os Cordões Hepáticos",
    "desc": "Entre os cordões de hepatócitos, uma lesão crônica se fechou: células estreladas fizeram cicatriz, hepatócitos adoeceram e gordura e toxina se acumulam ao redor de um nódulo duro. Se ninguém entrar, o fígado perde a função.",
    "region": "figado",
    "eligible": num("$self", "maturidade", ">=", 16),
    "rooms": [
        {"id": "sinusoides-vigiados", "name": "Os sinusoides vigiados", "desc": "Células estreladas patrulham o sangue lento: pequenas, rápidas e frágeis.", "kind": "guard"},
        {"id": "cordao-de-hepatocitos", "name": "O cordão de hepatócitos", "desc": "Hepatócitos inchados e doentes, lentos e resistentes, com estreladas por perto.", "kind": "wall"},
        {"id": "faixa-de-fibrose", "name": "A faixa de fibrose", "desc": "Gotas de gordura e hepatócitos presos numa cicatriz que não cede.", "kind": "wall"},
        {"id": "foco-toxico", "name": "O foco tóxico", "desc": "Toxina concentrada: emissores que aceleram quem está perto.", "kind": "core"},
        {"id": "nodulo", "name": "O nódulo cirrótico", "desc": "O tecido duro que o fígado tentou fazer para se proteger e que agora o sufoca.", "kind": "boss"},
    ],
    "modifiers": [
        {"id": "bile-acida", "name": "Bile ácida", "desc": "A bile transborda: a vida escorre mais depressa.", "tags": ["endure", "metabolism"]},
        {"id": "fibrose-ativa", "name": "Fibrose ativa", "desc": "O núcleo e o nódulo cospem estreladas enquanto você demora.", "tags": ["combat", "endure"]},
        {"id": "toxinas-altas", "name": "Toxinas altas", "desc": "O fígado está sobrecarregado: os inimigos andam mais depressa.", "tags": ["combat", "explore"], "eligible": num("figado", "toxina", ">=", 60)},
        {"id": "glicogenio-cheio", "name": "Glicogênio cheio", "desc": "As reservas estão fartas: o ATP volta mais depressa.", "tags": ["metabolism", "explore"], "eligible": num("figado", "glicogenio", ">=", 60)},
        {"id": "kupffer-aliadas", "name": "Kupffer aliadas", "desc": "Macrófagos do fígado enfraquecem os inimigos antes de você chegar.", "tags": ["knowledge", "explore"], "eligible": num("figado", "toxina", "<", 40)},
    ],
    "rewards": [
        {"op": "adjust", "e": "$self", "k": "pressao", "d": 10},
        {"op": "adjust", "e": "$self", "k": "maturidade", "d": 6},
        {"op": "adjust", "e": "figado", "k": "toxina", "d": -35, "min": 0},
        {"op": "adjust", "e": "figado", "k": "glicogenio", "d": 20, "max": 100},
        {"op": "adjust", "e": "corpo", "k": "inflamacao", "d": -10, "min": 0},
        {"op": "grant", "v": "selo-do-figado"},
        {"op": "emit", "event": "cordoes-limpos", "text": "Os cordões hepáticos foram limpos: o fígado respira, a toxina cai."},
    ],
    "firstClear": [{"op": "grant", "v": "primeiro-filtro"}],
    "firstText": "foi a primeira a limpar os Cordões Hepáticos.",
    "retry": 6,
})
with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("dungeons:", [d["id"] for d in u["dungeons"]])
