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
         o("estrela", "Estrela", "A five-pointed star: sharp, radiant, a little cruel.", ferocidade=3, misterio=1),
         o("composto", "Composto", "A nucleus built from parts: its lobes, its cut and its nucleolus are designed separately, so it is one of a kind.", misterio=1)]},
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
    # Composed nucleus: the advisor builds a nucleus from parts instead of picking a preset (the three below override "nucleo").
    {"id": "lobulacao", "name": "Lobulação do núcleo", "question": "how many lobes the nucleus has when it is built from parts: few lobes are calm, many are restless",
     "options": [o("l3", "Três lóbulos", "A soft triangle of lobes.", misterio=1), o("l4", "Quatro lóbulos", "A balanced cross of lobes.", robustez=1),
                 o("l5", "Cinco lóbulos", "A five-petalled nucleus.", sociabilidade=2), o("l6", "Seis lóbulos", "A six-lobed rosette.", metabolismo=1),
                 o("l7", "Sete lóbulos", "A restless seven-lobed nucleus.", agilidade=2), o("l8", "Oito lóbulos", "A crowded, bustling ring of lobes.", ferocidade=1, agilidade=1)]},
    {"id": "recorte", "name": "Recorte do núcleo", "question": "how the outline of the composed nucleus is cut",
     "options": [o("liso", "Liso", "A clean, unbroken outline.", robustez=1), o("entalhe", "Entalhe", "A deep notch on one side, like a bean or a kidney.", metabolismo=2),
                 o("serrilhado", "Serrilhado", "A finely serrated outline.", ferocidade=2)]},
    {"id": "nucleolo", "name": "Nucléolo", "question": "the bright mark inside the nucleus, the signature of this cell",
     "options": [o("nenhum", "Nenhum", "A plain nucleus.", robustez=1), o("brilhante", "Brilhante", "One bright off-centre point.", misterio=2),
                 o("anel", "Anel", "A ring around the middle.", sociabilidade=2), o("constelacao", "Constelação", "Five points joined by thin lines.", misterio=3, agilidade=1)]},
    # How fast the cell's projectiles fly, and the focus of every other ability (risk and reward).
    {"id": "ritmo", "name": "Ritmo dos efeitos", "question": "how fast this cell's projectiles fly",
     "options": [o("lento", "Lento", "Slow, heavy projectiles: easy to see coming, easy to land.", robustez=2, misterio=1), o("firme", "Firme", "Projectiles at a steady speed.", sociabilidade=1),
                 o("veloz", "Veloz", "Quick projectiles that are hard to avoid.", agilidade=3, ferocidade=1)]},
    {"id": "foco", "name": "Foco das habilidades", "question": "the focus of this cell's non-projectile abilities (cones, thrusts, novas, dashes, zones): wide ones reach more and are easy to land but hit softly and short; precise ones are narrow, long and hit hard",
     "options": [o("amplo", "Amplo", "A wide, short, forgiving reach with softer hits.", sociabilidade=2, metabolismo=1),
                 o("medio", "Médio", "A balanced reach.", robustez=1),
                 o("preciso", "Preciso", "A narrow, long reach that hits hard when it lands.", ferocidade=2, agilidade=1, misterio=1)]},
    # The shot itself (it changes what a projectile does, not only how it looks).
    {"id": "trajetoria", "name": "Trajetória do projétil", "question": "how this cell's projectiles fly: this changes where they can hit, so choose what suits how this person fights",
     "options": [o("reta", "Reta", "A straight, fast, honest line (no homing): precise and easy to dodge for a patient enemy.", ferocidade=2, robustez=1),
                 o("ondulada", "Ondulada", "A snaking wave: harder to dodge, covers the sides of its path.", agilidade=2, sociabilidade=1),
                 o("espiral", "Espiral", "A corkscrew around its line: sweeps a wide tube in front of the cell.", misterio=2, metabolismo=1),
                 o("arco", "Arco", "A curving arc that bends round obstacles and around enemies who stand in front.", agilidade=1, misterio=1),
                 o("teleguiada", "Teleguiada", "Hunts the nearest enemy with a strong turn: never misses, but is slower to arrive.", sociabilidade=2, misterio=1)]},
    {"id": "calibre", "name": "Calibre do projétil", "question": "how big the projectile is: small ones are fast, long-range and hard to land; big ones are slow, forgiving and cover more space",
     "options": [o("fino", "Fino", "A thin, fast needle with long range and a little more damage, but a tiny hit area.", agilidade=2, ferocidade=1),
                 o("medio", "Médio", "An average projectile.", robustez=1, sociabilidade=1),
                 o("grosso", "Grosso", "A big, slow ball with a wide hit area and a little less damage.", robustez=2, metabolismo=1)]},
    {"id": "impacto", "name": "Impacto do projétil", "question": "what the projectile does when it arrives; each option trades some direct damage for its own reach",
     "options": [o("simples", "Simples", "Hits one enemy for full damage and is spent.", ferocidade=1),
                 o("perfurante", "Perfurante", "Goes through up to three enemies, a little weaker each time.", ferocidade=2, agilidade=1),
                 o("explosivo", "Explosivo", "Bursts on arrival: everyone near the impact takes a share of the damage.", metabolismo=2, ferocidade=1),
                 o("fragmenta", "Fragmenta", "Breaks into three fragments that fly on and hit whoever is behind.", misterio=2, sociabilidade=1),
                 o("grudento", "Grudento", "Sticks to its target and keeps hurting it for a few seconds.", robustez=1, metabolismo=2)]},
    # How each family of abilities behaves (every mode trades some direct damage for what it buys).
    {"id": "modo_cone", "name": "Comportamento dos cones", "question": "how this cell's cone abilities (whips, sweeps) behave: standard, closing on victims or lashing twice",
     "options": [o("padrao", "Padrão", "The cone sweeps once.", robustez=1),
                 o("fecha", "Fecha", "The cone closes: victims are dragged toward the cell, with slightly less damage.", sociabilidade=2, metabolismo=1),
                 o("chicoteia", "Chicoteia", "The whips come back: a second lash a beat later, each lash a bit softer.", ferocidade=2, agilidade=1)]},
    {"id": "modo_nova", "name": "Comportamento das ondas", "question": "how this cell's nova abilities (radial bursts) behave: one blast, three pulses or a repelling blast",
     "options": [o("padrao", "Padrão", "A single radial blast.", robustez=1),
                 o("pulsos", "Pulsos", "Three weaker beats instead of one: hits things that move in and out.", agilidade=2, misterio=1),
                 o("repele", "Repele", "The blast throws every enemy away from the cell, with a little less damage.", robustez=2, sociabilidade=1)]},
    {"id": "modo_estocada", "name": "Comportamento das estocadas", "question": "how this cell's thrusts (piercing lances) behave: a plain thrust or a harpoon that reels the victim in",
     "options": [o("padrao", "Padrão", "A plain thrust.", ferocidade=1),
                 o("arpao", "Arpão", "The thrust harpoons the victim and drags it to the cell, with a little less damage.", metabolismo=1, misterio=2)]},
    {"id": "modo_investida", "name": "Comportamento das investidas", "question": "how this cell's dash attacks behave: one strike at the end, or a second strike a beat later",
     "options": [o("padrao", "Padrão", "One strike at the end of the dash.", agilidade=1),
                 o("dupla", "Dupla", "A second strike lands a beat later, each strike a bit softer.", ferocidade=2, agilidade=2)]},
    {"id": "modo_zona", "name": "Comportamento das zonas", "question": "how this cell's zone abilities (acid puddles, nets, clouds) behave: fixed in place or wandering towards the nearest enemy",
     "options": [o("padrao", "Padrão", "The zone stays where it was cast.", robustez=2),
                 o("migra", "Migra", "The zone wanders slowly towards the nearest enemy; smaller and a bit weaker.", agilidade=1, misterio=2)]},
    {"id": "modo_devorar", "name": "Comportamento do devorar", "question": "how this cell's devouring bite behaves: a plain bite or a suction that pulls prey in",
     "options": [o("padrao", "Padrão", "A plain bite.", metabolismo=1),
                 o("suga", "Suga", "The bite sucks prey toward the cell first, with a little less damage.", metabolismo=2, sociabilidade=1)]},
]
u["appearance"]["traits"] = traits
p.write_text(json.dumps(u, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(traits), "traits")
