class_name BioCargoSite
extends Node2D
## The place in the tissue where a crisis needs what the player carries: the breach of the skin, a starving neuron, an inflamed
## alveolus. It is part of the organ and shows the crisis healing (`healed`, from the engine's numbers): the breach closes and fibrin
## threads cross it, the neuron lights up, the alveolus clears. A delivery makes it pulse. Presentation only.

var def := ""
var shape: StringName = &"cell"
var title := ""
var cargo := ""
var tint := Color.WHITE
var healed := 0.0  # 0 as bad as the crisis got, 1 calm
var waiting := false  # the player carries a load for it: it calls
var _shown := 0.0  # eases towards healed
var _pulse := 0.0
var _t := 0.0


func configure(p_def: String, at: Vector2) -> void:
	def = p_def
	var c := BioCargoRules.of(p_def)
	shape = c.get("site_shape", &"cell")
	title = str(c.get("site", ""))
	cargo = str(c.get("cargo", ""))
	tint = c.get("cargo_color", Color.WHITE)
	global_position = at
	z_index = -1


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 1.6)
	_shown = move_toward(_shown, healed, delta * 0.25)
	queue_redraw()


func _draw() -> void:
	var u := BioArt.UNIT
	var h := _shown
	var sick := Color(0.85, 0.2, 0.25)
	var well := tint.lerp(Color.WHITE, 0.25)
	var body := sick.lerp(well, h)
	draw_circle(Vector2.ZERO, u * (3.2 + 0.6 * _pulse), BioArt.with_alpha(body, 0.06 + 0.1 * _pulse))  # its light in the tissue
	match shape:
		&"breach":
			_draw_breach(u, h, body)
		&"neuron":
			_draw_neuron(u, h, body)
		&"alveolus":
			_draw_alveolus(u, h, body)
		&"niche":
			_draw_ring_of(u, h, body, 7, 0.55)
		&"colony":
			_draw_ring_of(u, h, body, 9, 0.35)
		&"mass":
			_draw_mass(u, h, body)
		&"tubule":
			_draw_tubule(u, h, body)
		_:
			_draw_cell(u, h, body)
	if waiting:  # the player brings a load: the place calls for it
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		draw_arc(Vector2.ZERO, u * (2.6 + 0.4 * k), 0.0, TAU, 40, BioArt.with_alpha(tint, 0.85), 2.5, true)
	var font := ThemeDB.fallback_font
	var line := title if not waiting else "%s · entregue aqui" % title
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var at := Vector2(-w * 0.5, -u * 3.2)
	draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.01, 0.02, 0.05, 0.95))
	draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BioArt.with_alpha(well, 0.95))


## A torn membrane: two ragged lips around a dark gap that narrows as it heals, fibrin threads across it.
func _draw_breach(u: float, h: float, body: Color) -> void:
	var gap := lerpf(1.1, 0.12, h) * u
	for side in [-1.0, 1.0]:
		var lip := PackedVector2Array()
		for i in 13:
			var x := lerpf(-2.4, 2.4, i / 12.0) * u
			var ragged := sin(i * 2.3 + side) * 0.18 * u * (1.0 - h)
			var open := gap * (1.0 - pow(absf(x) / (2.4 * u), 2.0))
			lip.append(Vector2(x, side * (open + ragged)))
		draw_polyline(lip, BioArt.with_alpha(body, 0.9), 5.0, true)
		draw_polyline(lip, BioArt.with_alpha(body.lightened(0.4), 0.7), 1.5, true)
	var dark := PackedVector2Array()
	for i in 13:
		var x := lerpf(-2.3, 2.3, i / 12.0) * u
		dark.append(Vector2(x, -gap * 0.9 * (1.0 - pow(absf(x) / (2.3 * u), 2.0))))
	for i in range(12, -1, -1):
		var x := lerpf(-2.3, 2.3, i / 12.0) * u
		dark.append(Vector2(x, gap * 0.9 * (1.0 - pow(absf(x) / (2.3 * u), 2.0)) + 0.5))
	draw_colored_polygon(dark, Color(0.05, 0.0, 0.02, 0.85))
	for i in int(1 + h * 9.0):  # fibrin threads, more as it closes
		var x := lerpf(-1.9, 1.9, fposmod(i * 0.37, 1.0)) * u
		draw_line(Vector2(x - 0.2 * u, -gap - 3.0), Vector2(x + 0.2 * u, gap + 3.0), BioArt.with_alpha(tint, 0.75), 1.4, true)


## A neuron: a soma and its dendrites, dark and flickering when starved, alight when fed.
func _draw_neuron(u: float, h: float, body: Color) -> void:
	var flicker := 1.0 if h > 0.6 else 0.6 + 0.4 * absf(sin(_t * (9.0 - 6.0 * h)))
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := PackedVector2Array([Vector2.ZERO])
		var dir := Vector2.from_angle(a)
		for k in range(1, 6):
			p.append(dir * u * 0.55 * k + dir.orthogonal() * sin(k * 1.7 + i) * u * 0.18)
		draw_polyline(p, BioArt.with_alpha(body, 0.75 * flicker), 2.2 - 0.3 * (i % 3), true)
	draw_circle(Vector2.ZERO, u * 0.85, BioArt.with_alpha(body.darkened(0.3), 0.95))
	draw_circle(Vector2.ZERO, u * 0.6, BioArt.with_alpha(body, 0.9 * flicker))
	draw_circle(Vector2.ZERO, u * 0.25, BioArt.with_alpha(Color.WHITE, 0.3 + 0.6 * h))


## An alveolus: a sac, filled red when inflamed, clear and breathing when healed.
func _draw_alveolus(u: float, h: float, body: Color) -> void:
	var breath := 1.0 + 0.06 * sin(_t * 1.3) * h
	var ring := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		ring.append(Vector2.from_angle(a) * u * 1.9 * breath * (1.0 + 0.06 * sin(a * 5.0 + _t)))
	draw_colored_polygon(ring, BioArt.with_alpha(Color(0.7, 0.1, 0.15).lerp(Color(0.2, 0.45, 0.7), h), 0.55))
	ring.append(ring[0])
	draw_polyline(ring, BioArt.with_alpha(body, 0.9), 3.0, true)
	for i in int((1.0 - h) * 8.0):  # what clogs it
		draw_circle(Vector2.from_angle(i * 2.4) * u * 0.9 * fposmod(i * 0.61, 1.0), u * 0.18, Color(1.0, 0.85, 0.4, 0.7))


## A ring of small things that fill up as the place heals (stem cells in their niche, a flora's colony).
func _draw_ring_of(u: float, h: float, body: Color, count: int, size: float) -> void:
	draw_arc(Vector2.ZERO, u * 1.7, 0.0, TAU, 40, BioArt.with_alpha(body, 0.6), 3.0, true)
	var full := int(round(h * count))
	for i in count:
		var p := Vector2.from_angle(TAU * i / count + _t * 0.15) * u * 1.7
		var on := i < full
		draw_circle(p, u * size, BioArt.with_alpha(body if on else Color(0.25, 0.25, 0.3), 0.9 if on else 0.5))
		if on:
			draw_circle(p, u * size * 0.45, BioArt.with_alpha(Color.WHITE, 0.45))


## A tumour mass: dark and lumpy, shrinking as it is beaten.
func _draw_mass(u: float, h: float, body: Color) -> void:
	var r := lerpf(2.0, 0.7, h) * u
	var ring := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		ring.append(Vector2.from_angle(a) * r * (1.0 + 0.22 * sin(a * 4.0 + 1.3) + 0.08 * sin(_t * 2.0 + a * 3.0)))
	draw_colored_polygon(ring, Color(0.35, 0.08, 0.2, 0.9))
	ring.append(ring[0])
	draw_polyline(ring, BioArt.with_alpha(body, 0.85), 2.5, true)


## A tubule: a tube of the nephron with crystals clogging it, fewer as it clears.
func _draw_tubule(u: float, h: float, body: Color) -> void:
	for side in [-1.0, 1.0]:
		var wall := PackedVector2Array()
		for i in 11:
			var x := lerpf(-2.5, 2.5, i / 10.0) * u
			wall.append(Vector2(x, side * (0.7 * u + sin(i * 0.9) * 0.08 * u)))
		draw_polyline(wall, BioArt.with_alpha(body, 0.9), 4.0, true)
	for i in int((1.0 - h) * 7.0):
		var at := Vector2(lerpf(-2.0, 2.0, fposmod(i * 0.43, 1.0)) * u, sin(i * 1.9) * 0.3 * u)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -0.3 * u), at + Vector2(0.22 * u, 0), at + Vector2(0, 0.3 * u), at + Vector2(-0.22 * u, 0)]), Color(0.85, 1.0, 0.95, 0.85))


## A cell of the organ: swollen and dull when overloaded, bright and calm when relieved.
func _draw_cell(u: float, h: float, body: Color) -> void:
	var swell := lerpf(1.35, 1.0, h)
	var ring := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + 0.2
		ring.append(Vector2.from_angle(a) * u * 1.6 * swell * (1.0 + 0.04 * sin(_t * 1.5 + i)))
	draw_colored_polygon(ring, BioArt.with_alpha(body.darkened(0.35), 0.85))
	ring.append(ring[0])
	draw_polyline(ring, BioArt.with_alpha(body, 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, u * 0.5, BioArt.with_alpha(body.lightened(0.2), 0.8))
