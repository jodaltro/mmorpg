"""Four more classes (E3+): the mast cell, the eosinophil, the NK cell and the regulatory T cell. Each is a tier-2 lineage with a starter
ability, three more to awaken, and a proof quest that grants one. The class mutations come from gen_mutations.py (same table as the client).
Idempotent. Run from anywhere."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def upsert(items, item):
    items[:] = [x for x in items if x["id"] != item["id"]] + [item]


CLASSES = [
    {"id": "mastocito", "name": "Mastócito", "from": "mieloide", "tags": ["combat", "metabolism"],
     "desc": "O Alarmista. O bombardeiro do corpo: uma bolsa de grânulos prestes a estourar. Atira histamina em chuva, incha o tecido inimigo e, quando o alarme soa, tudo ao redor sente.",
     "skills": [
         ("chuva-de-granulos", "Chuva de Grânulos", "comum", "Dispara um leque de grânulos de histamina que ferem de perto.", True, None),
         ("edema", "Edema", "incomum", "Lança uma poça de líquido que incha o tecido e retarda quem a atravessa.", False, None),
         ("choque-anafilatico", "Choque Anafilático", "epica", "Concentra todos os grânulos e os solta de uma vez numa onda que empurra tudo.", False, None),
         ("alarme-de-mastocito", "Alarme de Mastócito", "rara", "Todos os inimigos por perto são marcados: a defesa os vê e os fere mais.", False, ("abates", 40)),
     ], "prova": ("rubra", "nutrientes", 30, "edema", "Prova do Alarmista", "Absorva 30 nutrientes: um mastócito se enche de grânulos comendo.")},
    {"id": "eosinofilo", "name": "Eosinófilo", "from": "mieloide", "tags": ["combat", "endure"],
     "desc": "O Caça-Colossos. O especialista em gigantes: grânulos vermelhos de proteína corrosiva que derretem uma fração da vida do alvo, pequeno ou enorme. Lento para começar, devastador no fim.",
     "skills": [
         ("granulo-caustico", "Grânulo Cáustico", "comum", "Um golpe curto que derrete uma parte da vida do inimigo, seja ele fraco ou colossal.", True, None),
         ("nuvem-de-peroxidase", "Nuvem de Peroxidase", "incomum", "Solta uma nuvem corrosiva que anda sozinha atrás dos inimigos.", False, None),
         ("marca-de-ige", "Marca de IgE", "rara", "Marca um alvo com anticorpos: ele sofre muito mais dano por um tempo.", False, ("abates", 30)),
         ("proteina-basica", "Proteína Básica Maior", "epica", "Estoura os grânulos ao redor do corpo: uma explosão corrosiva de curto alcance.", False, None),
     ], "prova": ("neva", "abates", 120, "nuvem-de-peroxidase", "Prova do Caça-Colossos", "Chegue a 120 invasores destruídos: um eosinófilo se prova derretendo o que o ameaça.")},
    {"id": "celula-nk", "name": "Célula NK", "from": "linfoide", "tags": ["combat", "explore"],
     "desc": "O Assassino Natural. A caçadora que não pede licença: ataca o que não se reconhece sem precisar de marca nem de ordem, saltando de alvo em alvo numa cadeia de golpes.",
     "skills": [
         ("golpe-natural", "Golpe Natural", "comum", "Um salto curto e rápido que fere tudo o que cruza.", True, None),
         ("cadeia-letal", "Cadeia Letal", "rara", "Salta de um inimigo para o próximo, ferindo até quatro numa sequência.", False, ("esquivas", 12)),
         ("ausencia-de-mhc", "Ausência de MHC", "incomum", "Quem perdeu a identidade e já está ferido morre, sem precisar de marca.", False, None),
         ("explosao-de-interferon", "Explosão de Interferon", "epica", "Um surto de interferon: a célula corre mais e recupera energia por um tempo.", False, None),
     ], "prova": ("neva", "esquivas", 10, "cadeia-letal", "Prova da Caçadora", "Esquive 10 vezes: uma célula NK vive de chegar antes do golpe.")},
    {"id": "t-regulador", "name": "Linfócito T regulador", "from": "linfoide", "tags": ["knowledge", "endure"],
     "desc": "O Pacificador. O diplomata do corpo: não fere, apazigua. Suprime os inimigos, tira a força do que ataca e ergue muros de tolerância onde o caos começa.",
     "skills": [
         ("supressao-celular", "Supressão Celular", "comum", "Acalma um inimigo: ele golpeia com muito menos força por um tempo.", True, None),
         ("zona-de-tolerancia", "Zona de Tolerância", "incomum", "Uma região onde quem entra fica lento e enfraquecido.", False, None),
         ("muro-de-tolerancia", "Muro de Tolerância", "rara", "Ergue um arco de coágulos que os inimigos não atravessam por alguns segundos.", False, ("nutrientes", 20)),
         ("silencio-imunologico", "Silêncio Imunológico", "epica", "Todos os inimigos por perto são calados: batem com muito menos força.", False, None),
     ], "prova": ("rubra", "nutrientes", 25, "zona-de-tolerancia", "Prova do Pacificador", "Absorva 25 nutrientes: um regulador aprende a manter a calma comendo.")},
]

for c in CLASSES:
    upsert(u["lineages"], {"id": c["id"], "name": c["name"], "tier": 2, "from": c["from"], "tags": c["tags"], "desc": c["desc"]})
    for sid, name, rarity, desc, starter, learn in c["skills"]:
        skill = {"id": sid, "name": name, "rarity": rarity, "desc": desc, "class": c["id"], "tags": c["tags"]}
        if starter:
            skill["starter"] = True
        else:
            skill["offer"] = True
        if learn:
            skill["learn"] = {"all": [{"tag": {"e": "$self", "k": "lineage", "v": c["id"]}}, {"deeds": {"action": "derrotar-virus" if learn[0] == "abates" else "esquivar" if learn[0] == "esquivas" else "absorver-nutriente", "op": ">=", "v": learn[1]}}]}
        upsert(u["skills"], skill)
    giver, key, n, grant, title, objective = c["prova"]
    upsert(u["quests"], {"id": "prova-" + c["id"], "giver": giver, "rank": "C", "title": title,
        "desc": "Quem se diferencia aprende com a prática. %s espera por você." % dict((s[0], s[1]) for s in c["skills"])[grant],
        "objective": objective, "reward": "A habilidade %s e pressão evolutiva +5" % dict((s[0], s[1]) for s in c["skills"])[grant], "tags": c["tags"],
        "eligible": {"all": [{"tag": {"e": "$self", "k": "lineage", "v": c["id"]}}, {"not": {"has": {"skill": grant}}}]},
        "goal": {"num": {"e": "$self", "k": key, "op": ">=", "v": n}},
        "rewards": [{"op": "grant", "v": grant}, {"op": "adjust", "e": "$self", "k": "pressao", "d": 5}, {"op": "adjust", "e": "$self", "k": "maturidade", "d": 5}]})

# (a goal already met when the class is chosen is never offered: the cytotoxic T cell proof asked for 12 kills, which a cell has long passed by then)
for q in u["quests"]:
    if q["id"] == "prova-t-citotoxico":
        q["goal"] = {"num": {"e": "$self", "k": "abates", "op": ">=", "v": 120}}
        q["objective"] = "Chegue a 120 invasores destruídos: um T citotóxico se prova eliminando o que o corpo já marcou."

with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print("lineages:", [x["id"] for x in u["lineages"]])
