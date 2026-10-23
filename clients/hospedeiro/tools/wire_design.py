"""Wires the traits Jev designs (nucleus, membrane, organelles, glow, effect flavour) into the cell body, the abilities and the world.
One-off edits; run from anywhere."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


# --- limbs: every limb of an effect carries the cell's signature
lm = "scripts/runtime/bio_limbs.gd"
sub(lm, "func reach(dir: Vector2, length_units: float, grow: float = 0.12, hold: float = 0.2, opts: Dictionary = {}) -> BioLimb:\n	return _spawn(dir, length_units, grow / maxf(float(style()[\"speed\"]), 0.3), hold, opts)",
    "var signature: StringName = &\"\"  # the flavour Jev designed for this cell's effects (BioEffectSignature)\n\n\nfunc reach(dir: Vector2, length_units: float, grow: float = 0.12, hold: float = 0.2, opts: Dictionary = {}) -> BioLimb:\n	return _spawn(dir, length_units, grow / maxf(float(style()[\"speed\"]), 0.3), hold, BioEffectSignature.sign_options(opts, signature))")
sub(lm, "	var o := opts.duplicate()\n	o[\"follow\"] = target\n", "	var o := BioEffectSignature.sign_options(opts, signature)\n	o[\"follow\"] = target\n")

# --- abilities: the tint of everything an ability draws
ar = "scripts/runtime/bio_ability_runner.gd"
sub(ar, "var _limbs: BioLimbs\n", "var _limbs: BioLimbs\nvar effect_style: StringName = &\"\"  # trait \"efeito\" designed by Jev\n")
sub(ar, "	var color: Color = a[\"color\"]\n	match kind:", "	var color: Color = BioEffectSignature.tint(a[\"color\"], effect_style)\n	_limbs.signature = effect_style\n	match kind:")

# --- nucleus: new shapes and the override
ns = "scripts/runtime/bio_nucleus_shapes.gd"
sub(ns, "		&\"linfoide\":\n", "		&\"estrela\":  # a five-pointed star\n			return (0.62 + 0.5 * pow(absf(cos(2.5 * a)), 1.6)) * breath\n		&\"linfoide\":\n")

# --- body: traits
cb = "scripts/runtime/bio_cell_body.gd"
sub(cb, "var look_target := {}\n", "var look_target := {}\nvar traits := {}  # the signature Jev designed (nucleo, membrana, organelas, brilho): see BioDesign\n")
sub(cb, "## Back to the plain newborn look (a restarted world).\nfunc clear_look() -> void:\n", "## The traits Jev designed for this cell. They only change how the body is drawn.\nfunc set_traits(designed: Dictionary) -> void:\n	traits = designed.duplicate()\n	queue_redraw()\n\n\n## Back to the plain newborn look (a restarted world).\nfunc clear_look() -> void:\n	traits = {}\n")
sub(cb, "	var edge_now := _edge_now()\n	var core_now := _core_now()\n	var r_px := radius_units * BioArt.UNIT * _size_mul * _size_now\n",
    "	var edge_now := _edge_now()\n	var core_now := _core_now()\n	var glow := BioDesign.glow(str(traits.get(\"brilho\", \"\")))\n	if glow.a > 0.0:\n		core_now = core_now.lerp(glow, 0.55)\n		edge_now = edge_now.lerp(glow, 0.35)\n	var r_px := radius_units * BioArt.UNIT * _size_mul * _size_now\n")
sub(cb, "	BioNucleusShapes.draw(self, form, _nuc_pos,", "	_draw_membrane_trait(closed, edge_now, Time.get_ticks_msec() * 0.001 + _seed)\n	BioNucleusShapes.draw(self, BioDesign.nucleus_form(str(traits.get(\"nucleo\", \"\")), form), _nuc_pos,")
sub(cb, "	_draw_genes(edge_now, core_now)\n	BioCellForms.draw(", "	_draw_genes(edge_now, core_now)\n	_draw_organelle_trait(radius_units * BioArt.UNIT * _size_mul * _size_now, Time.get_ticks_msec() * 0.001 + _seed, core_now)\n	BioCellForms.draw(")
sub(cb, "## Marks that come from the procedural body, not from a gene:", """## The membrane texture Jev chose: ripples, spines, beads, a second wall (smooth leaves it plain).
func _draw_membrane_trait(closed: PackedVector2Array, edge_now: Color, t: float) -> void:
	var style := str(traits.get("membrana", ""))
	if style == "" or style == "lisa" or closed.size() < 8:
		return
	var n := closed.size() - 1
	var col := BioArt.with_alpha(edge_now.lerp(Color.WHITE, 0.4), 0.85)
	match style:
		"ondulada":
			var wave := PackedVector2Array()
			for i in n + 1:
				var p := closed[i % n]
				wave.append(p + p.normalized() * (4.0 + 3.0 * sin(i * 0.9 + t * 2.4)))
			draw_polyline(wave, BioArt.with_alpha(col, 0.55), 2.0, true)
		"espinhosa":
			for k in 16:
				var p2 := closed[(k * n / 16) % n]
				draw_line(p2, p2 + p2.normalized() * (9.0 + 3.0 * sin(t * 3.0 + k)), col, 2.2, true)
		"contas":
			for k in 26:
				draw_circle(closed[(k * n / 26) % n] * 1.04, 2.6, col)
		"dupla":
			var outer := PackedVector2Array()
			for p3 in closed:
				outer.append(p3 * 1.13)
			draw_polyline(outer, BioArt.with_alpha(col, 0.6), 2.0, true)


## The organelles Jev chose to dominate the inside: a few of one kind drifting under the membrane.
func _draw_organelle_trait(r: float, t: float, core_now: Color) -> void:
	var kind := str(traits.get("organelas", ""))
	if kind == "":
		return
	for k in 7:
		var ang := t * (0.12 + 0.02 * k) + k * 2.399
		var pos := Vector2.from_angle(ang) * r * (0.3 + 0.38 * fmod(k * 0.37, 1.0))
		match kind:
			"mitocondrias":
				draw_set_transform(pos, ang, Vector2(1.7, 0.8))
				draw_circle(Vector2.ZERO, 4.0, BioArt.with_alpha(BioArt.AMBER, 0.75))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"lisossomos":
				draw_circle(pos, 3.6, BioArt.with_alpha(Color(0.45, 1.0, 0.45), 0.7))
			"vesiculas":
				draw_arc(pos, 4.4, 0.0, TAU, 14, BioArt.with_alpha(Color(0.85, 0.92, 1.0), 0.7), 1.8, true)
			"tubulos":
				draw_line(pos, pos + Vector2.from_angle(ang + 1.0) * 14.0, BioArt.with_alpha(core_now.lerp(Color.WHITE, 0.4), 0.7), 1.6, true)
			"vacuolos":
				draw_arc(pos, 6.5, 0.0, TAU, 16, BioArt.with_alpha(Color(0.75, 0.9, 1.0), 0.5), 2.2, true)
			"granulos":
				draw_circle(pos, 2.8, BioArt.with_alpha(Color(0.25, 0.08, 0.2), 0.9))
				draw_circle(pos, 1.4, BioArt.with_alpha(BioArt.CRIMSON, 0.9))


## Marks that come from the procedural body, not from a gene:""")

# --- world
w = "scripts/runtime/bio_world.gd"
sub(w, "func apply_engine_look(look: Dictionary) -> void:\n	var axes: Dictionary = look.get(\"axes\", {})\n	if axes.is_empty():\n		return\n	for child in player.get_children():\n		if child is BioCellBody:\n			(child as BioCellBody).set_look(axes)\n",
    "func apply_engine_look(look: Dictionary) -> void:\n	var designed: Dictionary = look.get(\"traits\", {})\n	if designed != design_traits:\n		design_traits = designed.duplicate()\n		abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n		for child in player.get_children():\n			if child is BioCellBody:\n				(child as BioCellBody).set_traits(design_traits)\n	var axes: Dictionary = look.get(\"axes\", {})\n	if axes.is_empty():\n		return\n	for child in player.get_children():\n		if child is BioCellBody:\n			(child as BioCellBody).set_look(axes)\n")
sub(w, "var exploration: BioExploration\n", "var exploration: BioExploration\nvar design_traits: Dictionary = {}  # what Jev designed for this cell (engine look traits)\n")
print("ok")
