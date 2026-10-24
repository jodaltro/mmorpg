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
     "desc": "O Alarmista. O bombardeiro do corpo: uma bolsa de grânulos prestes a estourar. Semeia minas pelo caminho, cola bombas nos inimigos, faz cada morte explodir e, quando ousa, sangra a própria membrana numa explosão enorme.",
     "skills": [
         ("granulos-latentes", "Grânulos Latentes", "comum", "Por alguns segundos a célula solta um grânulo atrás de si a cada passo. Cada um arma, explode quando um inimigo chega perto e faz explodir os vizinhos.", True, None),
         ("histamina-instavel", "Histamina Instável", "incomum", "Cola uma bomba no inimigo: ela explode depois de um pavio, e cada bomba a mais no mesmo alvo aumenta a explosão.", False, None),
         ("cascata-de-degranulacao", "Cascata de Degranulação", "rara", "Por um tempo, tudo o que a célula mata explode em grânulos que ferem os vizinhos, e quem morre da explosão também explode.", False, ("abates", 40)),
         ("anafilaxia", "Anafilaxia", "epica", "A célula sangra a própria membrana numa onda que cresce; aperte de novo para soltá-la. Quanto mais vida gasta, maior e mais forte o estouro.", False, None),
     ], "prova": ("rubra", "nutrientes", 30, "histamina-instavel", "Prova do Alarmista", "Absorva 30 nutrientes: um mastócito se enche de grânulos comendo.")},
    {"id": "eosinofilo", "name": "Eosinófilo", "from": "mieloide", "tags": ["combat", "endure"],
     "desc": "O Caça-Colossos. O especialista em gigantes: prende-se ao que é grande e o corrói por dentro, congela um monstro em cristal para guardar os golpes, cresce a cada morte e, enrolado numa bola, quica pela sala.",
     "skills": [
         ("adesao", "Adesão", "comum", "Prende-se a um inimigo com uma corda de grânulos: ele é puxado e perde uma fração da própria vida a cada segundo. O colosso paga mais que o miúdo.", True, None),
         ("cristal-de-charcot", "Cristal de Charcot-Leyden", "incomum", "Prende o inimigo em cristal: ele fica parado e nada o fere. Os golpes ficam guardados e saem todos de uma vez, em explosão, quando o cristal quebra.", False, None),
         ("hipertrofia", "Hipertrofia", "rara", "A cada morte a célula cresce, bate mais forte e se cura um pouco. Acaba quando o tempo passa.", False, ("abates", 30)),
         ("rolagem", "Rolagem", "epica", "A célula vira uma bola protegida e veloz: quica nas paredes e nos inimigos, ferindo cada um. O mouse a guia.", False, None),
     ], "prova": ("neva", "abates", 120, "cristal-de-charcot", "Prova do Caça-Colossos", "Chegue a 120 invasores destruídos: um eosinófilo se prova guardando o que o ameaça.")},
    {"id": "celula-nk", "name": "Célula NK", "from": "linfoide", "tags": ["combat", "explore"],
     "desc": "O Assassino Natural. A caçadora que não pede licença: aparece atrás da presa, caça um alvo por vez e recupera forças a cada golpe, some da vista dos inimigos e volta no tempo para onde estava.",
     "skills": [
         ("passo-sem-identidade", "Passo Sem Identidade", "comum", "Aparece atrás do alvo e o golpeia nas costas, com muito mais força. Sem alvo ao alcance, é só um salto curto.", True, None),
         ("predar", "Predar", "incomum", "Escolhe uma presa. Cada golpe nela devolve recarga e energia às outras habilidades; matá-la devolve todas.", False, None),
         ("camuflagem-de-mhc", "Camuflagem de MHC", "rara", "A célula some da vista dos inimigos: eles a perdem. O primeiro golpe de dentro da sombra é muito mais forte.", False, ("esquivas", 12)),
         ("ancora-de-vigilancia", "Âncora de Vigilância", "epica", "Fixa uma âncora com a vida de agora. Pouco depois a célula é puxada de volta a ela em linha reta, ferindo quem estiver no caminho e recuperando parte do que perdeu.", False, None),
     ], "prova": ("neva", "esquivas", 10, "predar", "Prova da Caçadora", "Esquive 10 vezes: uma célula NK vive de chegar antes do golpe.")},
    {"id": "t-regulador", "name": "Linfócito T regulador", "from": "linfoide", "tags": ["knowledge", "endure"],
     "desc": "O Pacificador. O diplomata do corpo: não fere, apazigua. Faz inimigos dormirem, une-os pela dor, lança um isco que os distrai e abre um ponto de tolerância que puxa a sala inteira para o mesmo lugar.",
     "skills": [
         ("anergia", "Anergia", "comum", "O inimigo adormece e só acorda ao ser ferido, e o golpe que o acorda bate mais forte. Os grandes dormem mais leve.", True, None),
         ("sinapse-imunologica", "Sinapse Imunológica", "incomum", "Une até três inimigos: o que um sofre, os outros sofrem em parte.", False, None),
         ("autoantigeno", "Autoantígeno", "rara", "Lança um isco de si mesma: os inimigos próximos o atacam em vez de você, até ele cair ou o tempo acabar.", False, ("nutrientes", 20)),
         ("singularidade-de-tolerancia", "Singularidade de Tolerância", "epica", "Abre um ponto que puxa os inimigos para o centro; quando colapsa, quem ficou no meio leva o golpe.", False, None),
     ], "prova": ("rubra", "nutrientes", 25, "sinapse-imunologica", "Prova do Pacificador", "Absorva 25 nutrientes: um regulador aprende a manter a calma comendo.")},
]

# (the abilities were redesigned: the skills a class had before are dropped, and the new ones written in their place)
for c in CLASSES:
    u["skills"] = [x for x in u["skills"] if x.get("class") != c["id"]]

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
