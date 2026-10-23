"""E2: the places a cell can discover, the passages that need a gene to cross and the niches that reward a gene. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))
if "visitou" not in u["predicates"]:
    u["predicates"].append("visitou")
u["discovered"] = "visitou"
u["passages"] = [
    {"id": "sinusoide", "from": "medula", "to": "sangue", "name": "Sinusoide"},
    {"id": "veia_cava", "from": "sangue", "to": "coracao", "name": "Vênula coletora"},
    {"id": "arteria_pulmonar", "from": "coracao", "to": "pulmao", "name": "Artéria pulmonar", "gene": "citoesqueleto-elastico",
     "hint": "Os capilares do pulmão são estreitos: só passa quem tem o citoesqueleto elástico para se espremer."},
    {"id": "aorta_ascendente", "from": "coracao", "to": "aorta", "name": "Aorta ascendente"},
]
u["niches"] = [
    {"id": "nicho-estroma", "region": "medula", "name": "Bolsa do estroma", "gene": "cilios-ageis",
     "hint": "Um brilho de cílios se mexe num canto do nicho, longe da saída.",
     "text": "Você acha a bolsa do estroma: cílios minúsculos ondulam ali dentro e passam para você. (Cílios Ágeis)"},
    {"id": "bolsa-da-venula", "region": "sangue", "name": "Bolsa da vênula", "gene": "citoesqueleto-elastico",
     "hint": "Uma dobra da parede da vênula guarda uma célula que se espreme por qualquer fresta.",
     "text": "Na dobra da vênula, uma célula velha lhe empresta o segredo de se espremer: o citoesqueleto elástico. Os capilares do pulmão agora estão ao seu alcance."},
    {"id": "recesso-do-atrio", "region": "coracao", "name": "Recesso do átrio", "gene": "receptor-de-mapa", "unique": True,
     "hint": "Onde o sangue volta e demora, há um recanto que o batimento quase não alcança.",
     "text": "No recesso do átrio você sente o corpo inteiro como um mapa: o receptor de mapa é seu, e de mais ninguém."},
    {"id": "gruta-alveolar", "region": "pulmao", "name": "Gruta alveolar", "gene": "receptor-de-limpeza", "unique": True,
     "hint": "Entre os alvéolos mais fundos há uma gruta onde o ar não chega a se mover.",
     "text": "Na gruta alveolar o muco parou no tempo. Você aprende a limpar o que ninguém limpa: o receptor de limpeza."},
    {"id": "valva-aortica", "region": "aorta", "name": "Seio da valva aórtica", "gene": "flagelo-turbinado", "unique": True,
     "hint": "Atrás das válvulas, a corrente faz um redemoinho que nunca sai do lugar.",
     "text": "No seio da valva, o redemoinho lhe ensina a ser a própria correnteza: o flagelo turbinado."},
]
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(u["passages"]), "passages", len(u["niches"]), "niches")
