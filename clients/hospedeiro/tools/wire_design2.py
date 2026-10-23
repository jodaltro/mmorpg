"""Design part 2 (client): the composed nucleus and the feel of the effects (density, trail, rhythm). One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


def append(rel, text):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    p.write_text(s.rstrip("\r\n") + nl + text.replace("\n", nl), encoding="utf-8", newline="")


# BioDesign tables
append("scripts/domain/bio_design.gd", '''

const LOBES := {"l3": 3, "l4": 4, "l5": 5, "l6": 6, "l7": 7, "l8": 8}
const CUTS := ["liso", "entalhe", "serrilhado"]
const NUCLEOLI := ["nenhum", "brilhante", "anel", "constelacao"]
const DENSITY := {"rala": 0.6, "media": 1.0, "densa": 1.6}
const TRAIL := {"curto": 0.7, "medio": 1.0, "longo": 1.5}
const TEMPO := {"lento": 0.75, "firme": 1.0, "veloz": 1.35}


## Particle multipliers {density, trail, tempo} for the traits Jev designed (1.0 each when none).
static func feel(traits: Dictionary) -> Dictionary:
	return {
		"density": float(DENSITY.get(str(traits.get("densidade", "")), 1.0)),
		"trail": float(TRAIL.get(str(traits.get("rastro", "")), 1.0)),
		"tempo": float(TEMPO.get(str(traits.get("ritmo", "")), 1.0)),
	}
''')

# particles: every effect goes through _base and burst
pf = "scripts/runtime/bio_pfx.gd"
sub(pf, "static func burst(parent: Node,", "## The feel Jev designed for this cell's effects: how many particles, how long they linger, how fast they go.\nstatic var density := 1.0\nstatic var trail := 1.0\nstatic var tempo := 1.0\n\n\nstatic func burst(parent: Node,")
sub(pf, "	var p := _base(parent, pos, color, amount, life, size_px)\n	p.one_shot = true\n	p.explosiveness = 1.0\n	p.direction = direction\n	p.spread = spread_deg\n	p.initial_velocity_min = speed * 0.4\n	p.initial_velocity_max = speed\n",
    "	var p := _base(parent, pos, color, amount, life, size_px)\n	p.one_shot = true\n	p.explosiveness = 1.0\n	p.direction = direction\n	p.spread = spread_deg\n	p.initial_velocity_min = speed * 0.4 * tempo\n	p.initial_velocity_max = speed * tempo\n")

# nucleus composed from parts
append("scripts/runtime/bio_nucleus_shapes.gd", '''

## A nucleus built from parts (see BioDesign): its lobes, how its outline is cut and the nucleolus inside.
static func radius_composite(a: float, t: float, lobes: int, cut: String) -> float:
	var r := 1.0 + 0.2 * cos(lobes * a + t * 0.2)
	match cut:
		"entalhe":
			r *= 1.0 - 0.4 * exp(-pow(angle_difference(a, PI * 0.5) / 0.55, 2.0))
		"serrilhado":
			r += 0.07 * cos(lobes * 4.0 * a)
	return r * (1.0 + 0.03 * sin(t * 2.0 + a * 2.0)) * 0.95


static func draw_composite(c: CanvasItem, pos: Vector2, rn: float, rot: float, t: float, core: Color, edge: Color, lobes: int, cut: String, nucleolus: String) -> void:
	var n := 48
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(pos + Vector2.from_angle(a + rot) * rn * radius_composite(a, t, lobes, cut))
	var fill := BioArt.with_alpha(core.lerp(Color.WHITE, 0.1), 0.26)
	for i in n:
		c.draw_primitive(PackedVector2Array([pos, pts[i], pts[(i + 1) % n]]), PackedColorArray([BioArt.with_alpha(core, 0.34), fill, fill]), PackedVector2Array())
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.55), 0.9), 2.4, true)
	match nucleolus:
		"brilhante":
			c.draw_circle(pos + Vector2.from_angle(rot + 0.7) * rn * 0.32, rn * 0.2, BioArt.with_alpha(Color.WHITE, 0.85))
		"anel":
			c.draw_arc(pos, rn * 0.5, 0.0, TAU, 28, BioArt.with_alpha(core.lerp(Color.WHITE, 0.5), 0.8), 2.2, true)
		"constelacao":
			var stars := PackedVector2Array()
			for k in 5:
				stars.append(pos + Vector2.from_angle(rot + k * 1.9 + t * 0.1) * rn * (0.3 + 0.12 * (k % 2)))
			for k in 5:
				c.draw_line(stars[k], stars[(k + 1) % 5], BioArt.with_alpha(Color.WHITE, 0.4), 1.2, true)
				c.draw_circle(stars[k], 2.2, BioArt.with_alpha(Color.WHITE, 0.9))
''')
cb = "scripts/runtime/bio_cell_body.gd"
sub(cb, "	BioNucleusShapes.draw(self, BioDesign.nucleus_form(str(traits.get(\"nucleo\", \"\")), form), _nuc_pos, _nuc_r, _nuc_rot, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, 6 if genes.has(&\"nucleo_multilobulado\") else 3)",
    "	if str(traits.get(\"nucleo\", \"\")) == \"composto\":\n		BioNucleusShapes.draw_composite(self, _nuc_pos, _nuc_r, _nuc_rot, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, int(BioDesign.LOBES.get(str(traits.get(\"lobulacao\", \"\")), 5)), str(traits.get(\"recorte\", \"liso\")), str(traits.get(\"nucleolo\", \"nenhum\")))\n	else:\n		BioNucleusShapes.draw(self, BioDesign.nucleus_form(str(traits.get(\"nucleo\", \"\")), form), _nuc_pos, _nuc_r, _nuc_rot, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, 6 if genes.has(&\"nucleo_multilobulado\") else 3)")
# world: apply the feel
w = "scripts/runtime/bio_world.gd"
sub(w, "		abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n", "		abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n		var feel := BioDesign.feel(design_traits)\n		BioPfx.density = feel[\"density\"]\n		BioPfx.trail = feel[\"trail\"]\n		BioPfx.tempo = feel[\"tempo\"]\n")
print("ok")
