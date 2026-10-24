"""The abilities of the six older classes, redone (seven stay: each one is the workhorse that carries one family of the designs Jev makes for
a cell: devour, nova, zone, dash, cone, projectile and thrust). Idempotent: the skills these classes had before are dropped, the new ones
written, and the proof quests grant the right second ability. Run from anywhere."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))

KEEP = {"engolir", "onda-de-pseudopodes", "rede-de-dna", "explosao-neutrofilica", "dendritos-em-chicote", "anticorpo-y", "perforina"}
OLD = ["macrofago", "neutrofilo", "dendritica", "linfocito-b", "t-citotoxico", "t-auxiliar"]


def learn(cls, action, n):
    return {"all": [{"tag": {"e": "$self", "k": "lineage", "v": cls}}, {"deeds": {"action": action, "op": ">=", "v": n}}]}


# class -> list of (id, name, rarity, desc, mode, learn deed)   mode: starter | offer | learn
NEW = {
    "macrofago": [
        ("contragolpe", "Contragolpe", "rara", "A membrana endurece: quem bate nela paga o golpe de volta, fica atordoado, e o macrófago se cura com o que aguenta.", "learn", ("estilo-chicote", 30)),
        ("polarizacao", "Polarização M1/M2", "epica", "O macrófago muda de forma: M1 bate forte e queima o que fere, M2 bate fraco, aguenta mais e se cura sozinho.", "offer", None),
    ],
    "neutrofilo": [
        ("diapedese", "Diapedese", "rara", "O neutrófilo se afina e atravessa os corpos no caminho, mais rápido, ferindo quem cruza.", "learn", ("estilo-impulso", 20)),
        ("surto-oxidativo", "Surto Oxidativo", "epica", "Tudo corre o dobro, as recargas também; o neutrófilo queima a própria membrana por isso.", "offer", None),
    ],
    "dendritica": [
        ("varredura", "Varredura", "comum", "Um feixe de luz que sai da célula e segue a mira devagar, queimando o que cruza.", "starter", None),
        ("maturacao", "Maturação", "rara", "A célula amadurece: as próximas habilidades não custam nada e batem mais forte.", "learn", ("absorver-nutriente", 25)),
        ("passagem-linfatica", "Passagem Linfática", "epica", "Abre duas portas no tecido, uma na mira e outra sob a célula: quem entra numa sai na outra.", "offer", None),
    ],
    "linfocito-b": [
        ("complemento", "Complemento", "incomum", "Marca o inimigo com complemento: no terceiro golpe, de quem for, ele estoura.", "offer", None),
        ("memoria-imunologica", "Memória Imunológica", "rara", "Repete de graça, e um pouco mais fraca, a última habilidade que a célula usou.", "learn", ("estilo-toxina", 25)),
        ("fabrica-de-plasmocito", "Fábrica de Plasmócito", "epica", "A célula vira uma fábrica parada, que atira anticorpos sem parar no que estiver mais perto.", "offer", None),
    ],
    "t-citotoxico": [
        ("salto-letal", "Salto Letal", "incomum", "Salta por cima da multidão, sem que nada a pare, e cai com um golpe no chão.", "offer", None),
        ("sinapse-letal", "Sinapse Letal", "rara", "Segura um inimigo à frente, sem que ele aja, apertando mais a cada instante; se ainda estiver quase morto no fim, é terminado.", "learn", ("derrotar-virus", 18)),
        ("lise-em-massa", "Lise em Massa", "epica", "Fere todos os inimigos da sala e sentencia os quase mortos: quanto mais mortes recentes, mais perto da morte vale a sentença.", "offer", None),
    ],
    "t-auxiliar": [
        ("febre-contagiosa", "Febre Contagiosa", "comum", "Dá febre a um inimigo: ele queima e passa a febre ao vizinho mais próximo, uma vez atrás da outra.", "starter", None),
        ("chamado-aos-auxiliares", "Chamado aos Auxiliares", "incomum", "Chama células auxiliares que correm atrás dos inimigos e os mordem por um tempo.", "offer", None),
        ("segunda-chance", "Segunda Chance", "rara", "Por um tempo, o golpe que mataria a célula a deixa viva, com parte da membrana de volta.", "learn", ("absorver-nutriente", 20)),
        ("transfusao", "Transfusão", "epica", "Troca o que sobra pelo que falta: membrana por energia, ou energia por membrana.", "offer", None),
    ],
}
TAGS = {c: next(s["tags"] for s in u["skills"] if s.get("class") == c) for c in OLD}

u["skills"] = [s for s in u["skills"] if s.get("class") not in OLD or s["id"] in KEEP]
for cls, items in NEW.items():
    for sid, name, rarity, desc, mode, deed in items:
        s = {"id": sid, "name": name, "rarity": rarity, "desc": desc, "class": cls, "tags": TAGS[cls]}
        if mode == "starter":
            s["starter"] = True
        else:
            s["offer"] = True
        if mode == "learn":
            s["learn"] = learn(cls, deed[0], deed[1])
        u["skills"] = [x for x in u["skills"] if x["id"] != sid] + [s]
# dendritic cells now start with the sweep, and the whips come with the proof; the B cell starts with the Y antibody (kept)
for s in u["skills"]:
    if s["id"] == "dendritos-em-chicote":
        s.pop("starter", None)
        s["offer"] = True

GRANTS = {"prova-linfocito-b": ("complemento", "Complemento"), "prova-t-citotoxico": ("salto-letal", "Salto Letal"), "prova-t-auxiliar": ("chamado-aos-auxiliares", "Chamado aos Auxiliares")}
for q in u["quests"]:
    if q["id"] in GRANTS:
        sid, name = GRANTS[q["id"]]
        for r in q["rewards"]:
            if r.get("op") == "grant":
                r["v"] = sid
        q["desc"] = "Quem se diferencia aprende com a prática. %s espera por você." % name
        q["reward"] = "A habilidade %s e pressão evolutiva +5" % name
        if "eligible" in q:
            q["eligible"] = json.loads(json.dumps(q["eligible"]).replace("golpe-litico", sid).replace("salva-de-anticorpos", sid).replace("canto-de-citocinas", sid))

with open(p, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(u, ensure_ascii=False, indent=1))
print({c: [s["id"] for s in u["skills"] if s.get("class") == c] for c in OLD})
