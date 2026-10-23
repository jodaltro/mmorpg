"""Makes the dungeons procedural: each keeps its opening room and its boss, and the rooms between them are drawn per run from a pool
(their number, which ones and in what order come from the seed of the run). Idempotent. Run from the repo root."""
import json

PATH = "universes/hospedeiro/universe.json"

POOLS = {
    "granuloma": {
        "depth": [3, 4],
        "extra": [
            {"id": "emboscada-de-neutrofilos", "name": "A emboscada", "kind": "ambush",
             "desc": "A parede se abre e a guarda cai de todos os lados, de uma vez."},
            {"id": "camara-de-pilares", "name": "A câmara de pilares", "kind": "pillars",
             "desc": "Colunas de fibrina escondem bacilos que cospem ácido de longe."},
            {"id": "ninho-de-bacilos", "name": "O ninho de bacilos", "kind": "nest",
             "desc": "Uma colônia que não para de gerar bacilos enquanto estiver de pé."},
            {"id": "poca-necrotica", "name": "A poça necrótica", "kind": "hazard",
             "desc": "O chão é tecido morto: as poças queimam a membrana de quem pisa."},
        ],
    },
    "cordoes-hepaticos": {
        "depth": [3, 4],
        "extra": [
            {"id": "veias-em-emboscada", "name": "As veias em emboscada", "kind": "ambush",
             "desc": "As células estreladas saem das paredes do sinusoide, todas juntas."},
            {"id": "trabeculas", "name": "As trabéculas", "kind": "pillars",
             "desc": "Placas de hepatócitos formam um labirinto; esporos de bile atiram de trás delas."},
            {"id": "cisto-hidatidico", "name": "O cisto", "kind": "nest",
             "desc": "Um cisto que gera célula estrelada atrás de célula estrelada até ser rompido."},
            {"id": "bile-derramada", "name": "A bile derramada", "kind": "hazard",
             "desc": "Poças de bile pelo chão queimam a membrana; plasmódios se escondem entre elas."},
        ],
    },
}

with open(PATH, encoding="utf-8", newline="") as f:
    u = json.loads(f.read())

for d in u["dungeons"]:
    spec = POOLS.get(d["id"])
    if spec is None or "pool" in d:
        continue
    rooms = d["rooms"]
    d["pool"] = rooms[1:-1] + spec["extra"]
    d["rooms"] = [rooms[0], rooms[-1]]
    d["depth"] = spec["depth"]

with open(PATH, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
    f.write("\n")
print("ok")
