"""Removes the cosmetic spores (the style only reaches the projectile and the physical effects now), gives every trajectory a reward
that matches how hard it is to land, and extends the same risk and reward to every other ability family through the trait "foco".
One-off edits; run from anywhere."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b, count=1):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, count), encoding="utf-8", newline="")


# ---- A. no more spores
sub("scripts/runtime/bio_ability_runner.gd", """	if effect_style != &"" and BioFx.root != null:  # the cast itself carries the cell's flavour: a flare, shards, a cloud, sparks or blobs
		BioPfx.burst(BioFx.root, origin + aim * 0.6 * BioArt.UNIT, color, 48, 300.0, 0.7, 22.0, aim, 85.0)
		BioPfx.ring_burst(BioFx.root, origin, color, 1.3 * BioArt.UNIT, 36, 0.6, 16.0)
""", "")
fx = "scripts/runtime/bio_fx.gd"
sub(fx, """	color = BioEffectSignature.tint(color, BioPfx.style)  # every spark of this cell carries its flavour
	count = maxi(1, roundi(count * BioPfx.density))
	speed_units *= BioPfx.tempo
	life *= BioPfx.linger
""", "")
pf = "scripts/runtime/bio_pfx.gd"
p = base / pf
s = p.read_text(encoding="utf-8", newline="")
nl = "\r\n" if "\r\n" in s else "\n"
s = s.replace("\r\n", "\n")
s = s.replace("	_shape(p, color)\n", "")
s = s.replace("	emitted += 1\n	if style != &\"\":\n		emitted_styled += 1\n", "")
s = s.replace("	p.amount = maxi(1, roundi(amount * density))\n	p.lifetime = life * linger\n", "	p.amount = amount\n	p.lifetime = life\n")
a = s.index("## The feel Jev designed for this cell's effects")
b = s.index("## An explosion of glowing motes.")
s = s[:a] + s[b:]
s = s.replace("	var pace := tempo * float({&\"nevoa\": 0.55, &\"eletrico\": 1.7, &\"cristal\": 1.2, &\"chama\": 0.9}.get(style, 1.0))\n	p.initial_velocity_min = speed * 0.4 * pace\n	p.initial_velocity_max = speed * pace\n", "	p.initial_velocity_min = speed * 0.4\n	p.initial_velocity_max = speed\n")
a = s.index("## Each style changes what the particles are")
s = s[:a].rstrip("\n") + "\n"
p.write_text(s.replace("\n", nl), encoding="utf-8", newline="")

w = "scripts/runtime/bio_world.gd"
sub(w, "	BioPfx.style = abilities.effect_style\n", "")
sub(w, """	var feel := BioDesign.feel(design_traits)
	BioPfx.density = feel["density"]
	BioPfx.linger = feel["trail"]
	BioPfx.tempo = feel["tempo"]
""", "	player.combatant.focus = BioAbilityFocus.params(design_traits)\n")
dbg = "scripts/runtime/bio_design_debug.gd"
p = base / dbg
s = p.read_text(encoding="utf-8", newline="")
nl = "\r\n" if "\r\n" in s else "\n"
s = s.replace("\r\n", "\n")
import re
s = re.sub(r'\tlines\.append\("partículas:[^\n]*\n', '\tlines.append("foco das outras habilidades: %s" % BioAbilityFocus.describe(_world.design_traits))\n', s)
s = re.sub(r'\tlines\.append\("emitidas nesta sessão:[^\n]*\n', '', s)
p.write_text(s.replace("\n", nl), encoding="utf-8", newline="")

# ---- B. trajectory table
pj = "scripts/domain/bio_projectile_design.gd"
sub(pj, 'const TRAJECTORIES := ["reta", "ondulada", "espiral", "arco", "teleguiada"]\n', '''const TRAJECTORIES := ["reta", "ondulada", "espiral", "arco", "teleguiada"]

## How hard each path is to land, paid for in what it gives back. `odds` is the share of shots that find a moving enemy (measured on
## the physics in test_projectile.gd, rounded); the multipliers are chosen so damage x odds is about the same for every path:
## the hunter that never misses hits softly; the straight needle is hard to land and hits hard, fast and far.
const PATHS := {
	"reta": {"damage": 1.6, "speed": 1.25, "range": 1.15, "odds": 0.55},
	"ondulada": {"damage": 1.25, "speed": 1.0, "range": 1.0, "odds": 0.7},  # also sweeps the sides of its path
	"espiral": {"damage": 1.15, "speed": 0.95, "range": 1.0, "odds": 0.75},  # a wide tube in front of the cell
	"arco": {"damage": 1.3, "speed": 1.0, "range": 1.2, "odds": 0.65},  # bends around the enemy in front and flies further
	"teleguiada": {"damage": 1.0, "speed": 0.85, "range": 1.0, "odds": 0.9},  # hunts, never misses much
}
''')
sub(pj, '''	var tempo := float(TEMPO.get(str(traits.get("ritmo", "")), 1.0))
	return {
		"path": path if TRAJECTORIES.has(path) else "",
		"radius_units": float(c["radius"]),
		"speed": float(c["speed"]) * tempo,
		"range": float(c["range"]),
		"damage": float(c["damage"]) * float(imp["direct"]),''', '''	var tempo := float(TEMPO.get(str(traits.get("ritmo", "")), 1.0))
	var pa: Dictionary = PATHS.get(path, {"damage": 1.0, "speed": 1.0, "range": 1.0})
	return {
		"path": path if TRAJECTORIES.has(path) else "",
		"radius_units": float(c["radius"]),
		"speed": float(c["speed"]) * tempo * float(pa["speed"]),
		"range": float(c["range"]) * float(pa["range"]),
		"damage": float(c["damage"]) * float(imp["direct"]) * float(pa["damage"]),''')

# ---- C. foco for every other family
combat = "scripts/runtime/bio_combatant.gd"
sub(combat, "var effect_style: StringName = &\"\"\n", "var effect_style: StringName = &\"\"\nvar focus := {}  # BioAbilityFocus.params: the risk and reward of every non-projectile ability\n")
sub(combat, "	var styled := attacker.effect_style", "	if BioAbilityFocus.applies_to(hit_def.id) and not attacker._chaining:\n		factor *= float(attacker.focus.get(\"damage\", 1.0))\n	var styled := attacker.effect_style")
sub("scripts/runtime/bio_ability_runner.gd", "	var kind: String = a[\"kind\"]\n", "	var kind: String = a[\"kind\"]\n	a = BioAbilityFocus.apply(a, _host.combatant.focus)  # the cell's focus: a wide weak reach or a narrow strong one\n")
print("ok")
