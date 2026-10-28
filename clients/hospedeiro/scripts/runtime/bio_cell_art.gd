class_name BioCellArt
extends RefCounted
## How the anonymous cells of the body are drawn: one soft membrane (a radius that breathes and bulges where the cell reaches), a gradient
## from a bright core to a darker edge, a lit rim, and what makes each kind of cell itself (the lobes of a neutrophil's nucleus, the
## pseudopods of a macrophage, the dent of a red cell, the rod of a bacterium). Every limb is a bulge of the membrane, never a part stuck
## on; colour changes are gradients inside the one cell.

const SEGMENTS := 26


## Draws worker `w` on `ci`, in the canvas of `ci`. `t` is the clock; `near` adds the inner details (far cells keep the silhouette).
static func draw(ci: CanvasItem, w: BioWorker, t: float, near: bool) -> void:
	var role := w.role
	var spec := w.spec
	var r: float = float(spec["size"]) * BioArt.UNIT * 0.95
	var core: Color = spec["core"]
	var edge: Color = spec["edge"]
	var aim := w.aim.normalized() if w.aim.length() > 0.01 else Vector2.RIGHT
	var heading := aim.angle()
	var moving := w.vel.length() > 0.2 * BioArt.UNIT
	if moving:
		heading = lerp_angle(heading, w.vel.angle(), 0.5)
	var reach := sin(w.work * PI) if w.state == &"work" else 0.0
	var lobes := _lobes(role, w, heading, reach, t)
	if role == "simbiose":
		_draw_rod(ci, w, r, core, edge, heading, t)
		return
	if role == "transporte":
		_draw_red_cell(ci, w, r, core, edge, heading, t)
		return
	var squash := Vector2(1.0, 1.0)
	if moving:
		squash = Vector2(1.0 + 0.12, 1.0 - 0.1)  # a cell on the move is a little longer along its way
	var ring := PackedVector2Array()
	for i in SEGMENTS:  # no repeated closing point: the triangulator rejects it
		var a := TAU * i / SEGMENTS
		var k := 1.0 + 0.05 * sin(a * 3.0 + t * 1.4 + w.seed_value) + 0.035 * sin(a * 5.0 - t * 1.9 + w.seed_value * 2.0)
		for l in lobes:
			var d := absf(angle_difference(a, float(l[0])))
			k += float(l[2]) * exp(-(d * d) / (2.0 * float(l[1]) * float(l[1])))
		var v := Vector2.from_angle(a) * r * maxf(k, 0.2)
		v = v.rotated(-heading) * squash
		ring.append(w.pos + v.rotated(heading))
	ci.draw_circle(w.pos, r * 1.7, BioArt.with_alpha(core, 0.045))  # a soft halo: the body is dark and the cells are its lights
	# soft outer light, then the body: layers from the dark edge to a bright core (a gradient inside the one cell), then the lit rim
	ci.draw_polyline(ring, BioArt.with_alpha(core, 0.18), 5.0, true)
	for j in 4:
		var layer := PackedVector2Array()
		var s := 1.0 - 0.22 * j
		var shift := aim * r * 0.05 * j
		for p in ring:
			layer.append(w.pos + shift + (p - w.pos) * s)
		ci.draw_colored_polygon(layer, edge.lerp(core.lightened(0.3), j / 3.0))
	ci.draw_polyline(ring, BioArt.with_alpha(core.lightened(0.5), 0.85), 1.4, true)
	ci.draw_circle(w.pos - aim.orthogonal() * r * 0.35 - aim * r * 0.1, r * 0.13, BioArt.with_alpha(Color.WHITE, 0.4))  # a glint
	if near:
		_details(ci, w, r, core, edge, heading, t)


## The bulges of the membrane: [angle, width (rad), height]. Each cell's own shape, plus the reach towards its work.
static func _lobes(role: String, w: BioWorker, heading: float, reach: float, t: float) -> Array:
	var out: Array = []
	var s := w.seed_value
	match role:
		"limpeza", "reciclagem":  # a macrophage: broad pseudopods that keep changing
			for i in 4:
				out.append([s + i * 1.6 + 0.4 * sin(t * 0.7 + i), 0.34, 0.26 + 0.1 * sin(t * 1.1 + i * 2.0)])
		"amparo":  # an astrocyte: processes in every direction
			for i in 6:
				out.append([TAU * i / 6.0 + s, 0.14, 0.55 + 0.08 * sin(t * 1.3 + i)])
		"vigilancia":  # a killer: a pointed front
			out.append([heading, 0.3, 0.22 + 0.2 * reach])
		"reparo":  # a platelet: a few small spikes
			for i in 5:
				out.append([TAU * i / 5.0 + s, 0.16, 0.2])
		"depuracao":  # a hepatocyte: a polygon, not a circle
			for i in 6:
				out.append([TAU * i / 6.0 + s * 0.2, 0.34, 0.1])
		"filtracao":  # a tubular cell: long along one axis
			out.append([heading, 0.5, 0.3])
			out.append([heading + PI, 0.5, 0.3])
		"defesa":
			out.append([heading, 0.4, 0.1 + 0.16 * reach])
		_:
			pass
	if reach > 0.0:  # the cell leans a bulge into what it works on
		out.append([heading, 0.36, 0.5 * reach])
	return out


static func _details(ci: CanvasItem, w: BioWorker, r: float, core: Color, edge: Color, heading: float, t: float) -> void:
	var dark := edge.darkened(0.3)
	var u := Vector2.from_angle(heading)
	var v := u.orthogonal()
	match w.role:
		"defesa":  # a multilobed nucleus, and granules
			for i in 3:
				ci.draw_circle(w.pos + u * r * (0.28 - 0.28 * i) + v * r * 0.12 * (1 if i % 2 == 0 else -1), r * 0.22, BioArt.with_alpha(dark, 0.9))
			for i in 5:
				ci.draw_circle(w.pos + Vector2.from_angle(w.seed_value + i * 1.3) * r * 0.55, r * 0.05, BioArt.with_alpha(core.lightened(0.5), 0.7))
		"limpeza", "reciclagem":  # a bean-shaped nucleus pushed aside and vacuoles with what it ate
			ci.draw_circle(w.pos - u * r * 0.15, r * 0.3, BioArt.with_alpha(dark, 0.85))
			for i in 3:
				var at := w.pos + Vector2.from_angle(w.seed_value * 2.0 + i * 2.1 + 0.3 * sin(t + i)) * r * 0.5
				ci.draw_circle(at, r * 0.14, BioArt.with_alpha(core.lightened(0.45), 0.65))
				ci.draw_arc(at, r * 0.14, 0.0, TAU, 12, BioArt.with_alpha(dark, 0.6), 1.0, true)
		"vigilancia":  # a big nucleus and red granules
			ci.draw_circle(w.pos, r * 0.34, BioArt.with_alpha(dark, 0.9))
			for i in 6:
				ci.draw_circle(w.pos + Vector2.from_angle(w.seed_value + i * 1.05) * r * 0.58, r * 0.07, BioArt.with_alpha(Color(1.0, 0.35, 0.3), 0.85))
		"reparo":  # platelet granules
			for i in 3:
				ci.draw_circle(w.pos + Vector2.from_angle(w.seed_value + i * 2.1) * r * 0.3, r * 0.13, BioArt.with_alpha(dark, 0.8))
		"amparo":  # a round nucleus and the thin ends of its processes
			ci.draw_circle(w.pos, r * 0.2, BioArt.with_alpha(dark, 0.85))
		"depuracao":  # two nuclei and glycogen granules
			ci.draw_circle(w.pos + v * r * 0.18, r * 0.2, BioArt.with_alpha(dark, 0.85))
			ci.draw_circle(w.pos - v * r * 0.2 + u * r * 0.1, r * 0.17, BioArt.with_alpha(dark, 0.8))
			for i in 6:
				ci.draw_circle(w.pos + Vector2.from_angle(w.seed_value * 3.0 + i * 1.0) * r * 0.6, r * 0.05, BioArt.with_alpha(Color(1.0, 0.9, 0.5), 0.7))
		"filtracao":  # a nucleus and the brush border of the tubule
			ci.draw_circle(w.pos, r * 0.22, BioArt.with_alpha(dark, 0.85))
			for i in 7:
				var a := heading + PI * 0.5 + (i - 3) * 0.2
				ci.draw_line(w.pos + Vector2.from_angle(a) * r * 0.85, w.pos + Vector2.from_angle(a) * r * 1.1, BioArt.with_alpha(core.lightened(0.4), 0.6), 1.0, true)
		"memoria":  # almost all nucleus
			ci.draw_circle(w.pos, r * 0.58, BioArt.with_alpha(dark, 0.78))
			ci.draw_circle(w.pos + u * r * 0.1, r * 0.2, BioArt.with_alpha(dark.lightened(0.2), 0.6))
		_:
			ci.draw_circle(w.pos, r * 0.26, BioArt.with_alpha(dark, 0.8))


## A red cell: a biconcave disc, darker at the rim, paler in the dent, turning as it rides the current.
static func _draw_red_cell(ci: CanvasItem, w: BioWorker, r: float, core: Color, edge: Color, heading: float, t: float) -> void:
	var flat := 0.62 + 0.38 * absf(cos(t * 0.8 + w.seed_value))  # it tumbles in the flow
	var ring := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		ring.append(w.pos + Vector2(cos(a) * r, sin(a) * r * flat).rotated(heading))
	ci.draw_colored_polygon(ring, edge)
	var mid := PackedVector2Array()
	for p in ring:
		mid.append(w.pos + (p - w.pos) * 0.72)
	ci.draw_colored_polygon(mid, edge.lerp(core, 0.6))
	ci.draw_polyline(ring, BioArt.with_alpha(core.lightened(0.4), 0.8), 1.2, true)
	var dent := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		dent.append(w.pos + Vector2(cos(a) * r * 0.42, sin(a) * r * 0.42 * flat).rotated(heading))
	ci.draw_colored_polygon(dent, BioArt.with_alpha(core.lightened(0.45), 0.5))


## A bacterium of the flora: a rod with a shimmering flagellum, bent a little as it swims.
static func _draw_rod(ci: CanvasItem, w: BioWorker, r: float, core: Color, edge: Color, heading: float, t: float) -> void:
	var u := Vector2.from_angle(heading)
	var v := u.orthogonal()
	var half := r * 1.15
	var pts := PackedVector2Array()
	for i in 13:
		var f := float(i) / 12.0
		var x := lerpf(-half, half, f)
		var bend := sin(t * 3.0 + w.seed_value + f * 3.0) * r * 0.12
		var width := r * 0.62 * pow(sin(f * PI), 0.5)
		pts.append(w.pos + u * x + v * (bend + width))
	for i in range(1, 12):  # the two tips are already in the first pass
		var f := 1.0 - float(i) / 12.0
		var x := lerpf(-half, half, f)
		var bend := sin(t * 3.0 + w.seed_value + f * 3.0) * r * 0.12
		var width := r * 0.62 * pow(sin(f * PI), 0.5)
		pts.append(w.pos + u * x + v * (bend - width))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(edge.lerp(core, clampf(1.0 - absf((p - w.pos).dot(v)) / (r * 0.8), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	ci.draw_polyline(pts, BioArt.with_alpha(core.lightened(0.5), 0.75), 1.0, true)
	var tail := PackedVector2Array()
	for i in 8:
		var f := float(i) / 7.0
		tail.append(w.pos - u * (half + f * r * 1.6) + v * sin(t * 6.0 + f * 5.0 + w.seed_value) * r * 0.25 * f)
	ci.draw_polyline(tail, BioArt.with_alpha(core, 0.6), 1.0, true)
