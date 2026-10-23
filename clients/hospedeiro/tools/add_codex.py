"""E2 part 2: the codex of the body, two secret niches that show only in a body state, and the pace of adaptation and of the rota
decision. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def visited(region):
    return {"fact": {"p": "visitou", "s": "$self", "o": region, "private": True}}


def did(action, n=1):
    return {"deeds": {"action": action, "op": ">=", "v": n}}


def fact(pred, s):
    return {"fact": {"p": pred, "s": s}}


u["exploring"] = {"adaptAfter": 30, "rotaEvery": 6}
u["codex"] = [
    {"id": "cx-medula", "kind": "regiao", "title": "A medula óssea", "when": visited("medula"),
     "text": "A medula vermelha é a fábrica do sangue: no nicho, células-tronco se dividem e dão origem às células do sangue e do sistema imune."},
    {"id": "cx-venula", "kind": "regiao", "title": "A vênula", "when": visited("sangue"),
     "text": "As vênulas recolhem o sangue dos capilares e o levam de volta ao coração. Suas paredes finas deixam as células imunes saírem para os tecidos."},
    {"id": "cx-endocardio", "kind": "regiao", "title": "O endocárdio", "when": visited("coracao"),
     "text": "Por dentro, o coração é forrado por uma camada lisa de células, o endocárdio, que deixa o sangue deslizar a cada batimento."},
    {"id": "cx-alveolos", "kind": "regiao", "title": "Os alvéolos", "when": visited("pulmao"),
     "text": "Sacos de ar de parede finíssima: o oxigênio entra no sangue e o gás carbônico sai, a poucos micrômetros de distância."},
    {"id": "cx-arteria", "kind": "regiao", "title": "A artéria", "when": visited("aorta"),
     "text": "As artérias têm parede elástica: cedem a cada batimento e devolvem a força ao sangue, empurrando-o adiante."},
    {"id": "cx-nutrientes", "kind": "corpo", "title": "Glicose e lipídios", "when": did("absorver-nutriente"),
     "text": "A glicose vira ATP, a moeda de energia da célula; os lipídios reparam a membrana. A insulina decide quanto o corpo guarda."},
    {"id": "cx-virion", "kind": "patogeno", "title": "O vírion espinhoso", "when": did("derrotar-virus"),
     "text": "Um vírus não é uma célula: é um pacote de instruções com espinhos que se prendem às células para entrar nelas e copiar a si mesmo."},
    {"id": "cx-febre", "kind": "corpo", "title": "A febre", "when": fact("febre", "sangue"),
     "text": "O corpo sobe a temperatura de propósito: o calor deixa os patógenos lentos e as defesas mais rápidas, mas cansa as células."},
    {"id": "cx-sono", "kind": "corpo", "title": "O sono", "when": fact("sono", "medula"),
     "text": "Dormindo, o corpo repara e produz: a medula se recompõe e certas coisas só acontecem em silêncio."},
    {"id": "cx-infeccao", "kind": "corpo", "title": "Infecção no pulmão", "when": fact("foco", "pulmao"),
     "text": "Bactérias nos alvéolos inflamam o pulmão; as citocinas viajam no sangue, a febre vem, e o ar passa pior até a infecção ceder."},
    {"id": "cx-segredo-venula", "kind": "segredo", "title": "A dobra da vênula", "when": did("nicho:bolsa-da-venula"),
     "text": "Quem se espreme por qualquer fresta herdou o citoesqueleto: filamentos de actina que dobram a célula sem rompê-la."},
    {"id": "cx-segredo-sonho", "kind": "segredo", "title": "O sonho da medula", "when": did("nicho:sonho-da-medula"),
     "text": "Há câmaras que só se abrem com o corpo dormindo. A memória imune de longa vida nasce em silêncio, na medula."},
    {"id": "cx-segredo-calor", "kind": "segredo", "title": "O calor dos alvéolos", "when": did("nicho:calor-do-alveolo"),
     "text": "Na febre, o interferon gama acende as defesas dos pulmões: é o sinal que diz às células vizinhas para se prepararem."},
]
have = {n["id"] for n in u["niches"]}
for n in [
    {"id": "sonho-da-medula", "region": "medula", "name": "Câmara do sono", "gene": "memoria-de-longa-vida",
     "when": fact("sono", "medula"),
     "hint": "Quando o corpo dorme, uma câmara da medula se abre; só então.",
     "text": "Com o corpo dormindo, a câmara do sono se abre e a medula lhe confia a memória de longa vida."},
    {"id": "calor-do-alveolo", "region": "pulmao", "name": "Alvéolo em brasa", "gene": "interferon-gama",
     "when": fact("febre", "sangue"),
     "hint": "Na febre, os alvéolos mais quentes brilham de outro jeito.",
     "text": "Na febre, um alvéolo em brasa lhe passa o interferon gama: o sinal que acende as defesas."},
]:
    if n["id"] not in have:
        u["niches"].append(n)
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(u["codex"]), "codex", len(u["niches"]), "niches")
