class_name BioCellForms
extends RefCounted
## The shape of each lineage. A newborn is a plain ball; each step of differentiation changes the whole
## body (silhouette, size, organelles), and class mutations push the form further. Everything is drawn
## procedurally on the cell's canvas, so no two bodies are identical once the engine's look is added.

const ESFERA := &"esfera"


## Shape parameters of a form, given the expressed genes: lobes (pseudopods), their amplitude, size,
## wobble, spikes, nucleus scale and whether it keeps a tail.
static func params(form: StringName, genes: Array[StringName]) -> Dictionary:
	var p := {"lobes": 0, "lobe_amp": 0.0, "size": 0.82, "wobble": 0.035, "spikes": 0, "spike_len": 0.0, "nucleus": 0.8, "tail": false, "poly": 0, "poly_amp": 0.0, "oval": 0.0}
	match form:
		&"mieloide":
			p.merge({"lobes": 3, "lobe_amp": 0.2, "size": 1.0, "wobble": 0.05, "nucleus": 1.0}, true)
		&"linfoide":
			p.merge({"size": 0.95, "wobble": 0.03, "nucleus": 1.35}, true)
		&"macrofago":
			p.merge({"lobes": 5, "lobe_amp": 0.4, "size": 1.45, "wobble": 0.05, "nucleus": 0.9}, true)
		&"neutrofilo":
			p.merge({"size": 0.88, "wobble": 0.06, "nucleus": 0.7, "tail": true, "oval": 0.24}, true)
		&"dendritica":
			p.merge({"lobes": 7, "lobe_amp": 0.1, "size": 1.0, "wobble": 0.05, "nucleus": 0.9, "poly": 7, "poly_amp": 0.1}, true)
		&"linfocito_b":
			p.merge({"size": 1.0, "wobble": 0.012, "nucleus": 1.6}, true)
		&"t_citotoxico":
			p.merge({"size": 0.95, "wobble": 0.015, "spikes": 6, "spike_len": 0.2, "nucleus": 1.1, "poly": 6, "poly_amp": 0.11}, true)
		&"t_auxiliar":
			p.merge({"size": 1.05, "wobble": 0.045, "nucleus": 1.0, "poly": 4, "poly_amp": 0.07}, true)
		&"mastocito":  # plump and full of granules
			p.merge({"size": 1.12, "wobble": 0.035, "nucleus": 0.7}, true)
		&"eosinofilo":  # broad and a little oval
			p.merge({"size": 1.2, "wobble": 0.04, "nucleus": 1.0, "oval": 0.1}, true)
		&"celula_nk":  # sleek
			p.merge({"size": 0.92, "wobble": 0.02, "nucleus": 1.2, "oval": 0.18}, true)
		&"t_regulador":  # composed: five soft corners
			p.merge({"size": 1.0, "wobble": 0.03, "nucleus": 1.1, "poly": 5, "poly_amp": 0.05}, true)
	if genes.has(&"pseudopodes_gigantes"):
		p["lobes"] += 3
		p["lobe_amp"] += 0.18
		p["size"] *= 1.12
	if genes.has(&"plasmocito"):
		p["nucleus"] *= 1.25
		p["size"] *= 1.1
	return p


## Draws the organelles and appendages of a form around the origin of the cell's canvas.
static func draw(c: CanvasItem, form: StringName, genes: Array[StringName], r: float, t: float, core: Color, edge: Color, front: Vector2, human: float = 0.0, pockets: bool = false) -> void:
	# With mutations in their pockets the body keeps a clean inside: the form's own granules and vacuoles stay out of the way.
	if human > 0.35 and form in [&"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar", &"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]:
		return  # a risen cell wears its gear (BioHumanoid) instead of the radial appendages
	match form:
		&"mieloide":
			if not pockets:
				_granules(c, r, t, 6, BioArt.JADE * 0.8, 0.45)
		&"linfoide":
			_receptors(c, r, t, 12, 7.0, core)
		&"macrofago":
			if not pockets:
				_vacuoles(c, r, t, 4 + (3 if genes.has(&"lisossomos_acidos") else 0), BioArt.TOXIN if genes.has(&"lisossomos_acidos") else edge.lightened(0.2))
		&"neutrofilo":
			if genes.has(&"rede_de_dna") and human <= 0.35 and not pockets:
				_dna_web(c, r, t, core)
		&"dendritica":
			var depth := 3 if genes.has(&"dendritos_ramificados") else 2
			var arms := 7 + (4 if genes.has(&"dendritos_ramificados") else 0)
			for i in arms:
				_dendrite(c, Vector2.from_angle(i * TAU / arms + sin(t * 0.3 + i) * 0.1) * r * 0.95, i * TAU / arms, r * 0.75, depth, t, core)
			if genes.has(&"esporos_de_antigeno"):
				_spores(c, r, t, Color(0.8, 0.6, 1.0))
		&"linfocito_b":
			var big := genes.has(&"anticorpos_em_y")
			_receptors(c, r, t, 22 if big else 11, 15.0 if big else 11.0, Color(0.95, 0.8, 1.0))
			if genes.has(&"plasmocito"):
				c.draw_arc(Vector2.ZERO, r * 1.5, 0.0, TAU, 48, BioArt.with_alpha(BioArt.MAGENTA, 0.5), 3.0, true)
		&"t_citotoxico":
			_needle(c, r, t, front, 2.0 if genes.has(&"agulha_litica") else 1.0)
			if not pockets:
				_granules(c, r, t, 11 if genes.has(&"granulos_de_perforina") else 5, BioArt.CRIMSON, 0.55)
		&"t_auxiliar":
			_rings(c, r, t, 2 + (2 if genes.has(&"halo_de_citocinas") else 0), core)
			_spores(c, r * 0.9, t, Color(1.0, 0.9, 0.5), 3 + (6 if genes.has(&"coro_de_interleucinas") else 0))
		&"mastocito":  # the cytoplasm packed with big amber granules, a few bursting out
			_granules(c, r, t, 24 if genes.has(&"granulos_de_histamina") else 16, Color(1.0, 0.62, 0.2), 0.3)
			_spores(c, r * 0.8, t, Color(1.0, 0.8, 0.4), 4 + (5 if genes.has(&"degranulacao_explosiva") else 0))
		&"eosinofilo":  # coarse red granules, and a rim of them at the membrane
			_granules(c, r, t, 14 if genes.has(&"granulos_de_proteina_basica") else 9, Color(1.0, 0.3, 0.3), 0.4)
			_granules(c, r * 1.35, t * -1.0, 6, Color(1.0, 0.55, 0.45), 0.55)
		&"celula_nk":  # a few large lytic granules and short receptors, and a streak behind
			_granules(c, r, t, 6, Color(0.6, 0.85, 1.0), 0.45)
			_receptors(c, r, t, 7, 8.0, Color(0.75, 0.9, 1.0))
		&"t_regulador":  # rings that fall inward, and a faint shell
			for k in 3:
				var phase := fmod(t * 0.2 + k / 3.0, 1.0)
				c.draw_arc(Vector2.ZERO, r * (1.9 - 0.9 * phase), 0.0, TAU, 56, BioArt.with_alpha(Color(0.5, 1.0, 0.8), 0.5 * (1.0 - phase)), 2.0, true)
			c.draw_arc(Vector2.ZERO, r * 1.25, t * 0.15, t * 0.15 + TAU * 0.8, 40, BioArt.with_alpha(Color(0.6, 1.0, 0.85), 0.35), 2.0, true)


static func _granules(c: CanvasItem, r: float, t: float, count: int, color: Color, spread: float) -> void:
	for k in count:
		var pos := Vector2.from_angle(t * 0.2 + k * 2.399) * r * (spread + 0.4 * fmod(k * 0.37, 1.0))
		c.draw_circle(pos, 2.6, BioArt.with_alpha(color, 0.85))


static func _vacuoles(c: CanvasItem, r: float, t: float, count: int, color: Color) -> void:
	for k in count:
		var pos := Vector2.from_angle(t * 0.15 + k * TAU / count) * r * 0.5
		var size := 7.0 + 3.0 * sin(t * 0.8 + k)
		c.draw_arc(pos, size, 0.0, TAU, 20, BioArt.with_alpha(color, 0.8), 2.0, true)
		c.draw_circle(pos, size * 0.45, BioArt.with_alpha(color, 0.35))


static func _multilobed_nucleus(c: CanvasItem, r: float, t: float, lobes: int) -> void:
	for k in lobes:
		var a := t * 0.5 + k * TAU / lobes
		var pos := Vector2.from_angle(a) * r * 0.22
		c.draw_circle(pos, r * (0.2 if lobes <= 3 else 0.15), BioArt.with_alpha(Color(1.0, 0.7, 0.9), 0.55))
		c.draw_circle(pos, r * 0.07, BioArt.with_alpha(Color.WHITE, 0.5))


## Thin spokes and rings of DNA around the body: the neutrophil's trap.
static func _dna_web(c: CanvasItem, r: float, t: float, color: Color) -> void:
	var spokes := 14
	for i in spokes:
		var a := i * TAU / spokes + sin(t * 0.7) * 0.05
		c.draw_line(Vector2.from_angle(a) * r, Vector2.from_angle(a) * r * 1.9, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.5), 1.4, true)
	for ring in [1.35, 1.7]:
		var pts := PackedVector2Array()
		for i in spokes + 1:
			var a := i * TAU / spokes + sin(t * 0.7) * 0.05
			pts.append(Vector2.from_angle(a) * r * (float(ring) + 0.05 * sin(t * 2.0 + i)))
		c.draw_polyline(pts, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.4), 1.2, true)


static func _dendrite(c: CanvasItem, from: Vector2, angle: float, length: float, depth: int, t: float, color: Color) -> void:
	var a := angle + sin(t * 1.2 + from.x * 0.05) * 0.25
	var to := from + Vector2.from_angle(a) * length
	c.draw_line(from, to, BioArt.with_alpha(color, 0.75), maxf(1.2, 1.2 + depth * 0.6), true)
	if depth <= 0:
		c.draw_circle(to, 2.2, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), 0.9))
		return
	_dendrite(c, to, a + 0.55, length * 0.62, depth - 1, t, color)
	_dendrite(c, to, a - 0.55, length * 0.62, depth - 1, t, color)


## Y-shaped receptors/antibodies standing on the membrane.
static func _receptors(c: CanvasItem, r: float, t: float, count: int, length: float, color: Color) -> void:
	for i in count:
		var a := i * TAU / count + t * 0.05
		var base := Vector2.from_angle(a) * r
		var stem := base + Vector2.from_angle(a) * length
		c.draw_line(base, stem, BioArt.with_alpha(color, 0.85), 1.8, true)
		for side in [-0.6, 0.6]:
			var tip := stem + Vector2.from_angle(a + float(side)) * length * 0.55
			c.draw_line(stem, tip, BioArt.with_alpha(color, 0.9), 1.8, true)
			c.draw_circle(tip, 2.0, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.95))


static func _needle(c: CanvasItem, r: float, t: float, front: Vector2, scale: float) -> void:
	var dir := front.normalized() if front.length() > 0.01 else Vector2.RIGHT
	var tip := dir * r * (1.7 + 0.15 * sin(t * 4.0)) * scale
	c.draw_line(dir * r * 0.5, tip, BioArt.with_alpha(Color(1.0, 0.85, 0.85), 0.9), 2.4, true)
	c.draw_line(dir * r * 0.5, tip, BioArt.with_alpha(BioArt.CRIMSON, 0.5), 6.0, true)
	c.draw_circle(tip, 3.0, BioArt.with_alpha(Color.WHITE, 0.95))


static func _rings(c: CanvasItem, r: float, t: float, count: int, color: Color) -> void:
	for k in count:
		var phase := fmod(t * 0.5 + k / float(count), 1.0)
		c.draw_arc(Vector2.ZERO, r * (1.1 + 0.9 * phase), 0.0, TAU, 56, BioArt.with_alpha(color.lerp(Color(1.0, 0.9, 0.5), 0.5), 0.6 * (1.0 - phase)), 2.4, true)


static func _spores(c: CanvasItem, r: float, t: float, color: Color, count: int = 10) -> void:
	for k in count:
		var life := fmod(t * 0.3 + k * 0.137, 1.0)
		var pos := Vector2.from_angle(k * 2.399 + t * 0.2) * r * (1.0 + 0.8 * life)
		c.draw_circle(pos, 2.6 * (1.0 - life) + 0.8, BioArt.with_alpha(color, 0.85 * (1.0 - life)))
