"""Adds the traits Jev designs for each cell (nucleus, membrane, organelles, glow, flavour of the ability effects) to the Hospedeiro
universe. Each option is something the Godot client knows how to draw. Idempotent."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[3] / "universes/hospedeiro/universe.json"
u = json.loads(p.read_text(encoding="utf-8"))


def o(id, name, desc, **aff):
    return {"id": id, "name": name, "desc": desc, "affinity": aff}


traits = [
    {"id": "nucleo", "name": "Núcleo", "question": "the shape of the nucleus, the heart of the cell, visible through the membrane",
     "options": [
         o("feijao", "Feijão", "A bean: one side indented, the nucleus of a restless wanderer.", agilidade=2, metabolismo=1),
         o("rim", "Rim", "A big kidney with a deep notch: a devourer's nucleus.", metabolismo=3, robustez=1),
         o("flor", "Flor", "An irregular flower with petals: a nucleus that listens and talks.", sociabilidade=3, misterio=1),
         o("esfera", "Esfera", "A huge perfect sphere: calm, dense, full of memory.", misterio=2, robustez=2),
         o("hexagono", "Hexágono", "A compact hexagon: disciplined and exact.", ferocidade=2, robustez=1),
         o("trevo", "Trevo", "A four-leaf clover: a nucleus that coordinates others.", sociabilidade=2, misterio=2),
         o("lobulos", "Lóbulos", "A chain of lobes: made to squeeze through anything.", agilidade=3),
         o("estrela", "Estrela", "A five-pointed star: sharp, radiant, a little cruel.", ferocidade=3, misterio=1)]},
    {"id": "membrana", "name": "Membrana", "question": "the texture of the outer membrane, the skin this cell shows the world",
     "options": [
         o("lisa", "Lisa", "A smooth, glossy membrane: nothing to catch on.", agilidade=2),
         o("ondulada", "Ondulada", "A rippling membrane that breathes and flows.", metabolismo=2, sociabilidade=1),
         o("espinhosa", "Espinhosa", "A ring of short spines: it warns before it strikes.", ferocidade=3),
         o("contas", "Contas", "A string of tiny beads along the edge: receptors on display.", misterio=2, sociabilidade=1),
         o("dupla", "Dupla", "Two membranes, one inside the other: layered and guarded.", robustez=3)]},
    {"id": "organelas", "name": "Organelas", "question": "which organelles dominate the inside of the cell and show through the membrane",
     "options": [
         o("mitocondrias", "Mitocôndrias", "Many bright mitochondria: energy to spare.", metabolismo=3),
         o("lisossomos", "Lisossomos", "Green acid sacs: a cell that digests what it finds.", ferocidade=2, metabolismo=1),
         o("vesiculas", "Vesículas", "Pale vesicles drifting about: messages and cargo.", sociabilidade=3),
         o("tubulos", "Túbulos", "A web of fine tubules: a cell that senses and builds paths.", agilidade=2, misterio=2),
         o("vacuolos", "Vacúolos", "Large clear vacuoles: storage, patience, endurance.", robustez=3),
         o("granulos", "Grânulos", "Dense dark granules: loaded, waiting to be released.", ferocidade=3)]},
    {"id": "brilho", "name": "Brilho", "question": "the colour of the cell's glow, how it looks in the dark of the body",
     "options": [
         o("ambar", "Âmbar", "A warm amber glow.", metabolismo=2, robustez=1),
         o("jade", "Jade", "A cool jade glow.", agilidade=1, sociabilidade=1),
         o("magenta", "Magenta", "A bright magenta glow.", misterio=2, ferocidade=1),
         o("ciano", "Ciano", "A clean cyan glow.", agilidade=2),
         o("carmim", "Carmim", "A deep crimson glow.", ferocidade=3),
         o("violeta", "Violeta", "A violet glow, deep and strange.", misterio=3)]},
    {"id": "efeito", "name": "Efeito das habilidades", "question": "the flavour of every ability this cell uses: how its effects look and move",
     "options": [
         o("chama", "Chama", "Abilities burn: warm tints, flaring, quick-fading sparks.", ferocidade=3),
         o("cristal", "Cristal", "Abilities crystallise: sharp, cold, glittering fragments.", robustez=2, misterio=1),
         o("nevoa", "Névoa", "Abilities billow: soft, drifting clouds with long tails.", sociabilidade=2, misterio=2),
         o("eletrico", "Elétrico", "Abilities crackle: jagged, instant, branching arcs.", agilidade=3),
         o("organico", "Orgânico", "Abilities grow: wet, pulsing, budding forms.", metabolismo=3)]},
]
u["appearance"]["traits"] = traits
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(traits), "traits")
