class_name BioMarkGlyph
extends Node2D
## The sigil an ability leaves on a marked cell. Each marking ability has its own: an MHC pedestal holding the antigen
## (Apresentar Antígeno), a four-blade cross over a heartbeat trace (Sinal de Morte), an urchin of tiny antibodies
## (Opsonização) and turning aim ticks (Mapa Químico).

var kind: StringName = &""
var color := Color.WHITE
var seconds := 5.0
var radius_px := 30.0
var _age := 0.0


static func attach(target: Node2D, mark_color: Color, mark_seconds: float, mark_kind: StringName = &"") -> void:
	for child in target.get_children():
		if child is BioMarkGlyph:
			child.queue_free()
	var glyph := BioMarkGlyph.new()
	glyph.color = mark_color
	glyph.seconds = mark_seconds
	glyph.kind = mark_kind
	glyph.z_index = 12
	glyph.material = BioArt.additive()
	target.add_child(glyph)


func _process(delta: float) -> void:
	_age += delta
	if _age >= seconds:
		queue_free()
	queue_redraw()


func _c(a: float, lighten: float = 0.0) -> Color:
	return BioArt.with_alpha(color.lerp(Color.WHITE, lighten), a)


func _draw() -> void:
	var fade := clampf((seconds - _age) / 0.6, 0.0, 1.0) * clampf(_age / 0.12, 0.0, 1.0)
	match kind:
		&"mhc":
			_mhc(fade)
		&"cross":
			_cross(fade)
		&"urchin":
			_urchin(fade)
		&"aim":
			_aim(fade)
		&"sleep":
			_sleep(fade)
		&"prey":
			_prey(fade)
		_:
			_rings(fade)


## A U-shaped pedestal holding a turning triangle (the antigen), with a waving column of light rising from it.
func _mhc(fade: float) -> void:
	var base := Vector2(0, -radius_px - 6.0)
	draw_line(base + Vector2(-6, 0), base + Vector2(-6, 12), _c(0.9 * fade, 0.3), 2.0, true)
	draw_line(base + Vector2(6, 0), base + Vector2(6, 12), _c(0.9 * fade, 0.3), 2.0, true)
	draw_arc(base + Vector2(0, 12), 6.0, 0.0, PI, 10, _c(0.9 * fade, 0.3), 2.0, true)
	var spin := _age * 2.6
	var tri := PackedVector2Array()
	for i in 3:
		tri.append(base + Vector2(0, 4) + Vector2.from_angle(spin + i * TAU / 3.0) * 4.5)
	draw_primitive(tri, PackedColorArray([_c(0.9 * fade, 0.6), _c(0.9 * fade, 0.6), _c(0.9 * fade, 0.6)]), PackedVector2Array())
	var col := PackedVector2Array()
	for j in 9:
		var f := j / 8.0
		col.append(base + Vector2(sin(_age * 4.0 + f * 5.0) * 3.0, -f * 40.0))
	draw_polyline(col, _c(0.7 * fade, 0.4), 2.0, true)
	draw_circle(col[8], 2.0, _c(0.9 * fade, 0.8))


## Four blades in a cross over a heartbeat trace that quickens as the mark runs out.
func _cross(fade: float) -> void:
	var rot := PI * 0.25 * minf(_age * 2.0, 1.0) + _age * 0.25
	for i in 4:
		var a := rot + i * PI * 0.5
		var tip := Vector2.from_angle(a) * (radius_px + 4.0)
		var root := Vector2.from_angle(a) * (radius_px - 6.0)
		var side := Vector2.from_angle(a + PI * 0.5) * 2.0
		draw_primitive(PackedVector2Array([root + side, tip, root - side]), PackedColorArray([_c(0.5 * fade), _c(0.95 * fade, 0.7), _c(0.5 * fade)]), PackedVector2Array())
	var urgency := 1.0 + 2.0 * (_age / seconds)
	var ecg := PackedVector2Array()
	for j in 21:
		var x := (j - 10) * 1.0
		var ph := fmod(_age * urgency / 0.8 * 1.0 + (j - 10) * 0.02, 1.0)
		var beat := -12.0 * exp(-pow((ph - 0.3) * 18.0, 2.0)) + 4.0 * exp(-pow((ph - 0.42) * 14.0, 2.0))
		ecg.append(Vector2(x, radius_px + 12.0 + beat))
	draw_polyline(ecg, _c(0.85 * fade, 0.3), 1.8, true)


## Tiny Y-shaped antibodies landing one by one around the cell until it looks like a sea urchin.
func _urchin(fade: float) -> void:
	var count := mini(int(_age / 0.02), 12)
	for i in count:
		var a := i * TAU / 12.0 + sin(_age * 3.0 + i) * 0.08
		var base := Vector2.from_angle(a) * (radius_px - 2.0)
		var stem := base + Vector2.from_angle(a) * 6.0
		draw_line(base, stem, _c(0.85 * fade, 0.4), 1.8, true)
		draw_line(stem, stem + Vector2.from_angle(a + 0.6) * 4.0, _c(0.9 * fade, 0.5), 1.8, true)
		draw_line(stem, stem + Vector2.from_angle(a - 0.6) * 4.0, _c(0.9 * fade, 0.5), 1.8, true)


## Three aim ticks that turn around the target, a farmer's mark rather than a bullseye.
func _aim(fade: float) -> void:
	for i in 3:
		var a := _age * 1.4 + i * TAU / 3.0
		draw_line(Vector2.from_angle(a) * (radius_px + 2.0), Vector2.from_angle(a) * (radius_px + 8.0), _c(0.9 * fade, 0.4), 2.2, true)
	draw_arc(Vector2.ZERO, radius_px + 5.0, _age, _age + 1.0, 8, _c(0.5 * fade), 1.4, true)


## Three Z's that rise from the sleeper, one after the other, and a slow ring that breathes.
func _sleep(fade: float) -> void:
	var breath := 0.5 + 0.5 * sin(_age * 2.0)
	draw_arc(Vector2.ZERO, radius_px + 3.0 + 3.0 * breath, 0.0, TAU, 28, _c(0.35 * fade), 1.6, true)
	for k in 3:
		var f := fposmod(_age * 0.6 + k / 3.0, 1.0)
		var at := Vector2(radius_px * 0.5 + f * 12.0, -radius_px - f * 26.0)
		var size := 5.0 + 4.0 * f + 1.5 * k
		var c := _c((1.0 - f) * 0.9 * fade, 0.5)
		draw_line(at + Vector2(-size, -size), at + Vector2(size, -size), c, 1.8, true)
		draw_line(at + Vector2(size, -size), at + Vector2(-size, size), c, 1.8, true)
		draw_line(at + Vector2(-size, size), at + Vector2(size, size), c, 1.8, true)


## A hunter's reticle: a broken ring that closes slowly on the prey, four ticks pointing in, and a dot that does not blink.
func _prey(fade: float) -> void:
	var closing := radius_px + 14.0 - 8.0 * minf(_age * 3.0, 1.0)
	for k in 4:
		var a := -_age * 1.1 + k * TAU / 4.0
		draw_arc(Vector2.ZERO, closing, a, a + TAU / 4.0 * 0.55, 8, _c(0.9 * fade, 0.3), 2.2, true)
		var tick := Vector2.from_angle(k * TAU / 4.0 + PI * 0.25)
		draw_line(tick * (closing + 3.0), tick * (closing - 8.0), _c(0.95 * fade, 0.6), 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, _c(0.95 * fade, 0.7))


func _rings(fade: float) -> void:
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - _age / 0.25)
	var r := radius_px * pop
	for i in 3:
		var a := _age * 1.6 + i * TAU / 3.0
		draw_arc(Vector2.ZERO, r, a, a + TAU / 3.0 * 0.6, 14, _c(0.85 * fade), 2.4, true)
