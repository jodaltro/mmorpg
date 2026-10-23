class_name BioNucleusShapes
extends RefCounted
## The nucleus, in the shape of its class: a round soft one for the newborn, a bean for the myeloid line, a big kidney for
## the macrophage, a chain of lobes for the neutrophil, a flower for the dendritic cell, a huge round one with a bright
## nucleolus for the B cell, a compact hexagon for the cytotoxic T cell and a four-leaf clover for the helper T cell.
## At full ascension the nucleus becomes the head, so the head of a humanoid cell has the shape of its class.


## Radius multiplier of the outline at angle `a` (local, before rotation) for a form.
static func radius_at(form: StringName, a: float, t: float) -> float:
	var breath := 1.0 + 0.03 * sin(t * 2.0 + a * 2.0)
	match form:
		&"mieloide":  # a bean: one side indented
			return (1.0 - 0.3 * exp(-pow(angle_difference(a, PI * 0.5) / 0.6, 2.0))) * 1.05 * breath
		&"macrofago":  # a large kidney, deeper notch
			return (1.0 - 0.5 * exp(-pow(angle_difference(a, PI * 0.5) / 0.55, 2.0))) * 1.12 * breath
		&"dendritica":  # an irregular flower
			return (1.0 + 0.26 * cos(5.0 * a + sin(t * 0.7) * 0.3) + 0.06 * cos(3.0 * a)) * 0.9 * breath
		&"linfocito_b":  # huge and perfectly round
			return 1.18 * breath
		&"t_citotoxico":  # a compact hexagon
			var sector := fposmod(a, TAU / 6.0) - TAU / 12.0
			return 0.98 * cos(TAU / 12.0) / cos(sector) * breath
		&"t_auxiliar":  # a four-leaf clover
			return (1.0 + 0.34 * absf(cos(2.0 * a))) * 0.88 * breath
		&"estrela":  # a five-pointed star
			return (0.62 + 0.5 * pow(absf(cos(2.5 * a)), 1.6)) * breath
		&"linfoide":
			return (1.0 + 0.1 * cos(2.0 * a)) * 1.08 * breath
		_:
			return breath


static func draw(c: CanvasItem, form: StringName, pos: Vector2, rn: float, rot: float, t: float, core: Color, edge: Color, lobes: int = 3) -> void:
	if form == &"neutrofilo":
		_lobes(c, pos, rn, t, core, edge, lobes)
		return
	var n := 36
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(pos + Vector2.from_angle(a + rot) * rn * radius_at(form, a, t))
	var fill := BioArt.with_alpha(core.lerp(Color.WHITE, 0.1), 0.26)
	for i in n:
		c.draw_primitive(PackedVector2Array([pos, pts[i], pts[(i + 1) % n]]), PackedColorArray([BioArt.with_alpha(core, 0.34), fill, fill]), PackedVector2Array())
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.55), 0.9), 2.4, true)
	match form:
		&"linfocito_b":  # the nucleolus, bright and off-centre
			c.draw_circle(pos + Vector2.from_angle(rot + 0.7) * rn * 0.35, rn * 0.2, BioArt.with_alpha(Color.WHITE, 0.85))
			c.draw_arc(pos, rn * 0.62, rot, rot + TAU * 0.7, 24, BioArt.with_alpha(core.lerp(Color.WHITE, 0.5), 0.6), 2.0, true)
		&"t_citotoxico":  # dense: a hot point inside
			c.draw_circle(pos, rn * 0.26, BioArt.with_alpha(Color(1.0, 0.8, 0.8), 0.9))
			c.draw_arc(pos, rn * 0.55, rot, rot + TAU, 6, BioArt.with_alpha(BioArt.CRIMSON, 0.7), 2.0, true)
		&"t_auxiliar":  # a quiet glow in the middle of the clover
			c.draw_circle(pos, rn * 0.3, BioArt.with_alpha(Color(1.0, 0.95, 0.7), 0.8))
		&"dendritica":
			for k in 5:
				c.draw_circle(pos + Vector2.from_angle(rot + k * TAU / 5.0 + t * 0.1) * rn * 0.5, rn * 0.09, BioArt.with_alpha(Color.WHITE, 0.7))
		&"macrofago", &"mieloide":
			c.draw_circle(pos + Vector2.from_angle(rot - 0.5) * rn * 0.25, rn * 0.14, BioArt.with_alpha(Color.WHITE, 0.6))
		_:
			c.draw_circle(pos, rn * 0.22, BioArt.with_alpha(Color.WHITE, 0.6))


## The neutrophil's nucleus: three round lobes joined by thin threads.
static func _lobes(c: CanvasItem, pos: Vector2, rn: float, t: float, core: Color, edge: Color, count: int) -> void:
	var centres: Array[Vector2] = []
	var size := 0.5 if count <= 3 else 0.36
	for k in count:
		var a := t * 0.35 + k * TAU / count
		centres.append(pos + Vector2.from_angle(a) * rn * (0.62 if count <= 3 else 0.7))
	for k in count:
		c.draw_line(centres[k], centres[(k + 1) % count], BioArt.with_alpha(edge.lerp(Color.WHITE, 0.3), 0.5), 2.4, true)
	for k in count:
		c.draw_circle(centres[k], rn * size, BioArt.with_alpha(core, 0.26))
		c.draw_arc(centres[k], rn * size, 0.0, TAU, 20, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.45), 0.85), 2.0, true)
		c.draw_circle(centres[k], rn * 0.12, BioArt.with_alpha(Color.WHITE, 0.6))


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
