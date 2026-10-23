class_name BioOrganelles
extends RefCounted
## The visible mark of a mutation (BioGene.mark): a real kind of organelle, drawn the way it looks under a microscope and let to
## float freely inside the membrane (BioCellBody moves them, confined to the cell, never escaping). Each kind is a different
## structure from cell biology, drawn as translucent fills with bright outlines, like fluorescence microscopy:
##   mitochondria (double membrane with cristae), golgi (stack of curved cisternae budding vesicles), er (folded sheets studded
##   with ribosomes), microtubules (a bundle of wavy strands with motor dots), centriole (a barrel of nine triplets and its
##   partner), vesicles (a cluster of different-sized bubbles), vacuole (a big irregular sac with granules), crystal (a faceted
##   protein crystal), tubules (a branching tubular network), autophagosome (a double membrane wrapping cargo), droplets
##   (lipid droplets with a highlight), ribosomes (dots strung on messenger RNA), lysosome (a dense granule with a halo) and
##   peroxisome (an oval with a crystalline core).

## Relative size of each kind (to the body radius) and how long it is (as an elongation of its bounding circle).
const SCALE := {"mitochondria": 0.26, "golgi": 0.24, "er": 0.27, "microtubules": 0.3, "centriole": 0.2, "vesicles": 0.22, "vacuole": 0.24,
	"crystal": 0.18, "tubules": 0.26, "autophagosome": 0.22, "droplets": 0.2, "ribosomes": 0.22, "lysosome": 0.17, "peroxisome": 0.19}


static func size_of(kind: String, body_radius: float) -> float:
	return maxf(body_radius * float(SCALE.get(kind, 0.2)), 6.0)


static func body_radius(rim: PackedVector2Array) -> float:
	if rim.is_empty():
		return 20.0
	var total := 0.0
	for p in rim:
		total += p.length()
	return total / rim.size()


## How far from the centre the membrane is in the direction of `angle` (the organelles stay inside this).
static func rim_radius_at(rim: PackedVector2Array, angle: float) -> float:
	if rim.size() < 3:
		return 20.0
	var x := fposmod(angle, TAU) / TAU * rim.size()
	var i := int(x) % rim.size()
	return lerpf(rim[i].length(), rim[(i + 1) % rim.size()].length(), x - floorf(x))


static func _blob(c: CanvasItem, at: Vector2, r: float, rot: float, t: float, seed_shift: float, wobble: float, color: Color, fill_a: float, line_a: float, width: float = 1.6) -> void:
	var pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		var k := 1.0 + wobble * sin(a * 3.0 + t * 1.1 + seed_shift) + wobble * 0.6 * sin(a * 5.0 - t * 0.8 + seed_shift * 1.7)
		pts.append(at + Vector2.from_angle(a + rot) * r * k)
	var fill := BioArt.with_alpha(color, fill_a)
	for i in pts.size():
		c.draw_primitive(PackedVector2Array([at, pts[i], pts[(i + 1) % pts.size()]]), PackedColorArray([BioArt.with_alpha(color, fill_a * 0.4), fill, fill]), PackedVector2Array())
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, BioArt.with_alpha(color.lerp(Color.WHITE, 0.3), line_a), width, true)


static func draw_organelle(c: CanvasItem, mark: Dictionary, at: Vector2, s: float, t: float, rot: float, seed_shift: float) -> void:
	var color := Color.html(str(mark.get("color", "#ffffff")))
	var count := clampi(int(mark.get("count", 3)), 1, 9)
	var light := color.lerp(Color.WHITE, 0.45)
	match str(mark.get("kind", "")):
		"mitochondria":
			_mitochondria(c, at, s, t, rot, seed_shift, color, light)
		"golgi":
			_golgi(c, at, s, t, rot, seed_shift, color, light, clampi(count + 1, 3, 5))
		"er":
			_er(c, at, s, t, rot, seed_shift, color, light)
		"microtubules":
			_microtubules(c, at, s, t, rot, seed_shift, color, light, clampi(count, 3, 5))
		"centriole":
			_centriole(c, at, s, t, rot, color, light)
		"vesicles":
			_vesicles(c, at, s, t, rot, seed_shift, color, light, clampi(count, 3, 5))
		"vacuole":
			_vacuole(c, at, s, t, rot, seed_shift, color, light, clampi(count, 1, 4))
		"crystal":
			_crystal(c, at, s, t, rot, color, light)
		"tubules":
			_tubules(c, at, s, t, rot, seed_shift, color, light)
		"autophagosome":
			_autophagosome(c, at, s, t, rot, seed_shift, color, light)
		"droplets":
			_droplets(c, at, s, t, rot, seed_shift, color, light)
		"ribosomes":
			_ribosomes(c, at, s, t, rot, seed_shift, color, light)
		"lysosome":
			_lysosome(c, at, s, t, rot, seed_shift, color, light)
		"peroxisome":
			_peroxisome(c, at, s, t, rot, seed_shift, color, light)


## An elongated, slightly bent bean with a double membrane and cristae folds that run in from the inner membrane.
static func _mitochondria(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 20
	for i in n:
		var a := i * TAU / n
		var bend := sin(a) * 0.0 + (1.0 - cos(a * 2.0)) * 0.12 * s
		var p := Vector2(cos(a) * s * 1.35, sin(a) * s * 0.62 + bend * sign(cos(a)) * 0.0 + cos(a) * cos(a) * s * 0.16 * (1.0 + 0.1 * sin(t + sd)))
		outer.append(at + p.rotated(rot))
		inner.append(at + (p * 0.78).rotated(rot))
	for i in n:
		c.draw_primitive(PackedVector2Array([at, outer[i], outer[(i + 1) % n]]), PackedColorArray([BioArt.with_alpha(color, 0.08), BioArt.with_alpha(color, 0.3), BioArt.with_alpha(color, 0.3)]), PackedVector2Array())
	var o := outer.duplicate()
	o.append(outer[0])
	var inn := inner.duplicate()
	inn.append(inner[0])
	c.draw_polyline(o, BioArt.with_alpha(light, 0.95), 1.8, true)
	c.draw_polyline(inn, BioArt.with_alpha(color, 0.55), 1.2, true)
	for k in 6:  # cristae: folds entering from alternate sides
		var x := lerpf(-0.95, 0.95, (k + 0.5) / 6.0) * s
		var side := 1.0 if k % 2 == 0 else -1.0
		var y0 := side * s * 0.5 + x * x / (s * 7.0)
		var fold := PackedVector2Array([at + Vector2(x, y0).rotated(rot), at + Vector2(x + s * 0.06, y0 - side * s * 0.4).rotated(rot), at + Vector2(x - s * 0.04, y0 - side * s * 0.65).rotated(rot)])
		c.draw_polyline(fold, BioArt.with_alpha(light, 0.65), 1.2, true)


## A stack of curved, tapered cisternae with small vesicles budding from the rim.
static func _golgi(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color, layers: int) -> void:
	for k in layers:
		var f := k / float(layers - 1) - 0.5
		var width := s * (1.3 - 0.35 * absf(f) * 2.0)
		var pts := PackedVector2Array()
		for i in 11:
			var u := i / 10.0 - 0.5
			var arch := (1.0 - 4.0 * u * u) * s * 0.18
			pts.append(at + Vector2(u * width * 2.0, f * s * 1.1 - arch + sin(t * 1.3 + k + sd) * s * 0.03).rotated(rot))
		c.draw_polyline(pts, BioArt.with_alpha(color, 0.3), 5.0, true)
		c.draw_polyline(pts, BioArt.with_alpha(light, 0.9), 1.6, true)
		c.draw_circle(pts[0], s * 0.07, BioArt.with_alpha(light, 0.9))
		c.draw_circle(pts[10], s * 0.07, BioArt.with_alpha(light, 0.9))
	for b in 3:  # budding vesicles drifting off the outer face
		var ph := fmod(t * 0.35 + b * 0.33 + sd, 1.0)
		var p := at + Vector2((b - 1) * s * 0.7, s * 0.75 + ph * s * 0.5).rotated(rot)
		c.draw_arc(p, s * 0.1 * (1.0 - ph * 0.3), 0.0, TAU, 8, BioArt.with_alpha(light, 0.8 * (1.0 - ph)), 1.3, true)


## Folded sheets of endoplasmic reticulum: a serpentine double line, studded with ribosome dots.
static func _er(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var folds := 4
	var pts := PackedVector2Array()
	for i in folds * 8 + 1:
		var u := i / float(folds * 8)
		var x := lerpf(-s * 1.1, s * 1.1, u)
		var y := sin(u * folds * PI) * s * 0.55 * (1.0 + 0.08 * sin(t * 0.9 + sd))
		pts.append(at + Vector2(x, y + sin(u * 11.0 + t * 1.4) * s * 0.04).rotated(rot))
	var off := PackedVector2Array()
	for i in pts.size():
		var d := ((pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()).orthogonal()
		off.append(pts[i] + d * s * 0.12)
	c.draw_polyline(pts, BioArt.with_alpha(light, 0.9), 1.5, true)
	c.draw_polyline(off, BioArt.with_alpha(color, 0.75), 1.3, true)
	for i in range(2, pts.size(), 3):
		c.draw_circle(pts[i] - (off[i] - pts[i]) * 0.7, 1.4, BioArt.with_alpha(Color.WHITE, 0.8))


## A bundle of wavy strands with dots (motors) walking along them.
static func _microtubules(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color, strands: int) -> void:
	for k in strands:
		var off := (k - (strands - 1) * 0.5) * s * 0.2
		var pts := PackedVector2Array()
		for i in 12:
			var u := i / 11.0
			pts.append(at + Vector2(lerpf(-s * 1.35, s * 1.35, u), off + sin(u * 4.5 + sd + t * 0.9 + k * 0.5) * s * 0.28).rotated(rot))
		c.draw_polyline(pts, BioArt.with_alpha(color, 0.9 - 0.12 * k), 1.8, true)
		var walker := fmod(t * 0.3 * (1.0 if k % 2 == 0 else -1.0) + k * 0.3 + sd + 8.0, 1.0)
		c.draw_circle(pts[int(walker * 11.0)], s * 0.09, BioArt.with_alpha(light, 0.95))


## A barrel of nine triplets (seen end on) with its partner standing at right angles, as in a centrosome.
static func _centriole(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, color: Color, light: Color) -> void:
	var pos := at + Vector2(-s * 0.25, -s * 0.2).rotated(rot)
	for i in 9:
		var a := i * TAU / 9.0 + t * 0.15
		var p := pos + Vector2.from_angle(a) * s * 0.48
		c.draw_line(p - Vector2.from_angle(a + PI * 0.5) * s * 0.11, p + Vector2.from_angle(a + PI * 0.5) * s * 0.11, BioArt.with_alpha(light, 0.95), 1.8, true)
		c.draw_circle(pos + Vector2.from_angle(a) * s * 0.22, 0.9, BioArt.with_alpha(color, 0.8))
	c.draw_arc(pos, s * 0.34, 0.0, TAU, 14, BioArt.with_alpha(color, 0.4), 1.0, true)
	var base := at + Vector2(s * 0.45, s * 0.55).rotated(rot)  # the partner, side on: a short striped cylinder
	var ax := Vector2.RIGHT.rotated(rot + 0.3)
	var nrm := ax.orthogonal()
	var pts := PackedVector2Array([base - ax * s * 0.55 - nrm * s * 0.28, base + ax * s * 0.55 - nrm * s * 0.28, base + ax * s * 0.55 + nrm * s * 0.28, base - ax * s * 0.55 + nrm * s * 0.28, base - ax * s * 0.55 - nrm * s * 0.28])
	c.draw_polyline(pts, BioArt.with_alpha(light, 0.9), 1.5, true)
	for k in 4:
		var f := (k + 0.5) / 4.0
		c.draw_line(base + ax * lerpf(-s * 0.55, s * 0.55, f) - nrm * s * 0.28, base + ax * lerpf(-s * 0.55, s * 0.55, f) + nrm * s * 0.28, BioArt.with_alpha(color, 0.7), 1.0, true)


## A cluster of bubbles of different sizes, each with a highlight, drifting about their common centre.
static func _vesicles(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color, count: int) -> void:
	for k in count:
		var a := sd + k * 2.2 + t * (0.25 + 0.07 * k)
		var p := at + Vector2.from_angle(a + rot) * s * (0.35 + 0.1 * sin(t * 0.8 + k)) * (0.0 if k == 0 else 1.0)
		var r := s * (0.52 - 0.07 * k)
		c.draw_circle(p, r, BioArt.with_alpha(color, 0.18))
		c.draw_arc(p, r, 0.0, TAU, 16, BioArt.with_alpha(light, 0.9), 1.5, true)
		c.draw_arc(p, r * 0.7, -2.4, -1.2, 6, BioArt.with_alpha(Color.WHITE, 0.8), 1.4, true)  # the highlight
		c.draw_circle(p + Vector2(r * 0.15, r * 0.2), r * 0.18, BioArt.with_alpha(color, 0.55))


## A large irregular sac, sparsely filled, with a few granules tumbling inside it.
static func _vacuole(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color, grains: int) -> void:
	_blob(c, at, s * 0.95, rot, t, sd, 0.13, color, 0.14, 0.95, 1.7)
	c.draw_arc(at, s * 0.7, 1.0 + t * 0.2, 2.4 + t * 0.2, 8, BioArt.with_alpha(light, 0.5), 1.2, true)
	for k in grains:
		var a := t * (0.6 + 0.2 * k) + sd + k * 1.9
		var p := at + Vector2.from_angle(a) * s * (0.2 + 0.15 * sin(t * 0.7 + k))
		c.draw_circle(p, s * (0.1 + 0.03 * (k % 2)), BioArt.with_alpha(light, 0.9))


## A faceted protein crystal: a hexagon with inner facet lines and a glint that moves across it.
static func _crystal(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, color: Color, light: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var a := i * TAU / 6.0 + rot
		pts.append(at + Vector2.from_angle(a) * s * (0.95 if i % 2 == 0 else 0.7))
	for i in 6:
		c.draw_primitive(PackedVector2Array([at, pts[i], pts[i + 1]]), PackedColorArray([BioArt.with_alpha(color, 0.25), BioArt.with_alpha(color, 0.12 + 0.1 * (i % 3)), BioArt.with_alpha(color, 0.12 + 0.1 * ((i + 1) % 3))]), PackedVector2Array())
	c.draw_polyline(pts, BioArt.with_alpha(light, 0.95), 1.7, true)
	for i in 3:
		c.draw_line(at, pts[i * 2], BioArt.with_alpha(light, 0.5), 1.0, true)
	var g := sin(t * 1.2) * 0.5 + 0.5
	c.draw_line(at + Vector2(-s * 0.4, -s * 0.4 + g * s * 0.5).rotated(rot), at + Vector2(-s * 0.1, -s * 0.7 + g * s * 0.5).rotated(rot), BioArt.with_alpha(Color.WHITE, 0.9), 1.6, true)


## A branching tubular network: three tubes joined at a node and ending in small bulbs, swaying.
static func _tubules(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var arms := [rot + 0.2, rot + 2.3, rot + 4.3]
	for k in 3:
		var a: float = arms[k] + sin(t * 0.8 + sd + k) * 0.2
		var mid := at + Vector2.from_angle(a) * s * 0.55
		var end := mid + Vector2.from_angle(a + sin(t * 1.1 + k * 2.0 + sd) * 0.6) * s * 0.55
		var pts := PackedVector2Array([at, mid, end])
		c.draw_polyline(pts, BioArt.with_alpha(color, 0.3), 5.0, true)
		c.draw_polyline(pts, BioArt.with_alpha(light, 0.9), 1.4, true)
		c.draw_circle(end, s * 0.13, BioArt.with_alpha(color, 0.35))
		c.draw_arc(end, s * 0.13, 0.0, TAU, 8, BioArt.with_alpha(light, 0.95), 1.3, true)
	c.draw_circle(at, s * 0.1, BioArt.with_alpha(light, 0.9))


## A double membrane that closes around cargo: two nested open arcs and a few dark blobs inside.
static func _autophagosome(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var gap := 0.9 + 0.5 * sin(t * 0.7 + sd)
	c.draw_arc(at, s * 0.9, rot + gap, rot + TAU - gap * 0.3, 20, BioArt.with_alpha(light, 0.95), 1.8, true)
	c.draw_arc(at, s * 0.68, rot + gap + 0.2, rot + TAU - gap * 0.3 - 0.2, 18, BioArt.with_alpha(color, 0.85), 1.4, true)
	for k in 3:
		var a := sd + k * 2.1 + t * 0.3
		var p := at + Vector2.from_angle(a) * s * 0.22
		_blob(c, p, s * 0.2, a, t, sd + k, 0.18, color, 0.35, 0.8, 1.1)


## Lipid droplets: round, glossy, with a ring and a specular highlight; a smaller one beside it.
static func _droplets(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var sizes := [0.62, 0.36, 0.26]
	for k in 3:
		var p := at + Vector2.from_angle(rot + k * 2.3 + sin(t * 0.5 + sd)) * s * (0.0 if k == 0 else 0.7)
		var r: float = s * sizes[k]
		c.draw_circle(p, r, BioArt.with_alpha(color, 0.3))
		c.draw_arc(p, r, 0.0, TAU, 16, BioArt.with_alpha(light, 0.9), 1.5, true)
		c.draw_arc(p, r * 0.6, 0.0, TAU, 12, BioArt.with_alpha(color, 0.5), 1.0, true)
		c.draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.2, BioArt.with_alpha(Color.WHITE, 0.85))


## Ribosomes: pairs of small and large subunits strung on a curved messenger RNA.
static func _ribosomes(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var u := i / 13.0
		pts.append(at + Vector2(lerpf(-s * 1.2, s * 1.2, u), sin(u * 5.0 + sd + t * 0.7) * s * 0.35).rotated(rot))
	c.draw_polyline(pts, BioArt.with_alpha(color, 0.6), 1.1, true)
	for i in range(1, 14, 2):
		c.draw_circle(pts[i], s * 0.16, BioArt.with_alpha(light, 0.9))
		c.draw_circle(pts[i] + Vector2(0, -s * 0.17).rotated(rot), s * 0.1, BioArt.with_alpha(color, 0.95))


## A dense granule with a bright halo and fine inner grains: a lysosome.
static func _lysosome(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	c.draw_texture_rect(BioArt.glow_texture(), Rect2(at - Vector2.ONE * s * 1.6, Vector2.ONE * s * 3.2), false, BioArt.with_alpha(color, 0.12))
	_blob(c, at, s * 0.8, rot, t, sd, 0.06, color, 0.5, 0.95, 1.8)
	for k in 5:
		var a := sd + k * 1.26 + t * 0.2
		c.draw_circle(at + Vector2.from_angle(a) * s * (0.2 + 0.18 * fmod(k * 0.37, 1.0)), 1.3, BioArt.with_alpha(light, 0.95))


## An oval microbody with a crystalline core (a peroxisome).
static func _peroxisome(c: CanvasItem, at: Vector2, s: float, t: float, rot: float, sd: float, color: Color, light: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := i * TAU / 18.0
		pts.append(at + Vector2(cos(a) * s * 0.95, sin(a) * s * 0.7 * (1.0 + 0.05 * sin(t + sd))).rotated(rot))
	var closed := pts.duplicate()
	closed.append(pts[0])
	for i in pts.size():
		c.draw_primitive(PackedVector2Array([at, pts[i], pts[(i + 1) % pts.size()]]), PackedColorArray([BioArt.with_alpha(color, 0.12), BioArt.with_alpha(color, 0.3), BioArt.with_alpha(color, 0.3)]), PackedVector2Array())
	c.draw_polyline(closed, BioArt.with_alpha(light, 0.95), 1.6, true)
	var core := PackedVector2Array([at + Vector2(0, -s * 0.38).rotated(rot), at + Vector2(s * 0.3, 0).rotated(rot), at + Vector2(0, s * 0.38).rotated(rot), at + Vector2(-s * 0.3, 0).rotated(rot), at + Vector2(0, -s * 0.38).rotated(rot)])
	c.draw_polyline(core, BioArt.with_alpha(Color.WHITE, 0.9), 1.4, true)
	c.draw_line(core[0], core[2], BioArt.with_alpha(light, 0.6), 1.0, true)
