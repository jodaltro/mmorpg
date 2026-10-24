class_name BioMarkGlyph
extends Node2D
## The sigil an ability leaves on a cell: the Z's of a sleeper (Anergia), a hunter's reticle (Predar), the pores of complement (Complemento).

var kind: StringName = &""
var color := Color.WHITE
var seconds := 5.0
var radius_px := 30.0
var _age := 0.0
var _peak := 0


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
		&"sleep":
			_sleep(fade)
		&"prey":
			_prey(fade)
		&"complement":
			_complement(fade)
		_:
			_rings(fade)


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


## Pores of the membrane attack complex, one for every blow still to come; each blow that lands closes one of them with a flash.
func _complement(fade: float) -> void:
	var host := get_parent() as BioCellActor
	var left := host.combatant.complement_hits() if host != null else 0
	_peak = maxi(_peak, left)
	for k in _peak:
		var a := -PI * 0.5 + (k - (_peak - 1) * 0.5) * 0.7
		var at := Vector2.from_angle(a) * (radius_px + 10.0)
		var open := k < left
		draw_arc(at, 6.0, 0.0, TAU, 14, _c((0.95 if open else 0.3) * fade, 0.5 if open else 0.0), 2.2, true)
		if open:
			draw_circle(at, 2.2, _c(0.9 * fade, 0.8))


func _rings(fade: float) -> void:
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - _age / 0.25)
	var r := radius_px * pop
	for i in 3:
		var a := _age * 1.6 + i * TAU / 3.0
		draw_arc(Vector2.ZERO, r, a, a + TAU / 3.0 * 0.6, 14, _c(0.85 * fade), 2.4, true)
