"""Adds the first dungeon (the granuloma) and its two skills to the Hospedeiro universe. Idempotent: run from the repo root."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))
u["skills"] = [k for k in u["skills"] if k["id"] not in ("selo-do-granuloma", "primeiro-selador")] + [
    {"id": "selo-do-granuloma", "name": "Selo do Granuloma", "desc": "Você fechou o granuloma uma vez: seu corpo guarda a lembrança do que há no núcleo.", "rarity": "rara"},
    {"id": "primeiro-selador", "name": "Primeiro Selador", "desc": "Foi a primeira célula a selar o Granuloma. O corpo inteiro lembra.", "rarity": "epica"},
]
u["dungeons"] = [{
    "id": "granuloma", "name": "O Granuloma",
    "desc": "Macrófagos se fecharam em anéis ao redor de um núcleo necrótico onde uma bactéria resiste. Uma guarda de linfócitos vigia por fora. Se ninguém entrar, ele pode romper.",
    "region": "sangue",
    "eligible": {"num": {"e": "$self", "k": "maturidade", "op": ">=", "v": 14}},
    "rooms": [
        {"id": "guarda-de-linfocitos", "name": "A guarda de linfócitos", "desc": "O anel de fora: linfócitos em patrulha, rápidos e frágeis.", "kind": "guard"},
        {"id": "parede-de-macrofagos", "name": "A parede de macrófagos", "desc": "Células grandes e lentas, apertadas umas nas outras.", "kind": "wall"},
        {"id": "anel-interno", "name": "O anel interno", "desc": "As células gigantes fundidas, de onde saem pseudópodes.", "kind": "wall"},
        {"id": "nucleo-necrotico", "name": "O núcleo necrótico", "desc": "Tecido morto, ar rarefeito e bactérias em quórum.", "kind": "core"},
        {"id": "bacilo", "name": "O bacilo", "desc": "A bactéria que o granuloma segurava por anos.", "kind": "boss"}],
    "modifiers": [
        {"id": "em-febre", "name": "Em febre", "desc": "O granuloma arde: tudo é mais rápido, e a vida escorre mais depressa.", "tags": ["explore", "combat"]},
        {"id": "necrose-viva", "name": "Necrose viva", "desc": "O núcleo cospe bactérias que se multiplicam enquanto você demora.", "tags": ["combat", "metabolism"]},
        {"id": "guarda-redobrada", "name": "Guarda redobrada", "desc": "O dobro de linfócitos nas duas primeiras salas, mas menos nas outras.", "tags": ["combat", "endure"]},
        {"id": "ar-rarefeito", "name": "Ar rarefeito", "desc": "Hipóxia: o ATP volta devagar. Pede paciência e metabolismo.", "tags": ["metabolism", "endure"]},
        {"id": "quorum-ativo", "name": "Quórum ativo", "desc": "Os inimigos ficam mais fortes quando estão juntos: separe-os e destrua os emissores de sinal.", "tags": ["knowledge", "explore"]}],
    "rewards": [
        {"op": "adjust", "e": "$self", "k": "pressao", "d": 10},
        {"op": "adjust", "e": "$self", "k": "maturidade", "d": 8},
        {"op": "adjust", "e": "sangue", "k": "carga", "d": -30, "min": 0},
        {"op": "grant", "v": "selo-do-granuloma"},
        {"op": "emit", "event": "granuloma-selado", "text": "O granuloma foi selado: a carga de infecção no sangue cai."}],
    "firstClear": [{"op": "grant", "v": "primeiro-selador"}],
    "firstText": "foi a primeira a selar o Granuloma.",
    "retry": 6}]
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(u["dungeons"]), "dungeon")
