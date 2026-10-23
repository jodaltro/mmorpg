class_name BioMarkGlyph
extends Node2D
## A turning sigil over a marked cell: two counter-rotating broken rings and four notches, fading as the mark runs out.

var color := Color.WHITE
var seconds := 5.0
var radius_px := 38.0
var _age := 0.0


static func attach(target: Node2D, mark_color: Color, mark_seconds: float) -> void:
	for child in target.get_children():
		if child is BioMarkGlyph:
			child.queue_free()
	var glyph := BioMarkGlyph.new()
	glyph.color = mark_color
	glyph.seconds = mark_seconds
	glyph.z_index = 12
	glyph.material = BioArt.additive()
	target.add_child(glyph)


func _process(delta: float) -> void:
	_age += delta
	if _age >= seconds:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((seconds - _age) / 0.6, 0.0, 1.0) * clampf(_age / 0.12, 0.0, 1.0)
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - _age / 0.25)
	var r := radius_px * pop
	for i in 3:
		var a := _age * 1.6 + i * TAU / 3.0
		draw_arc(Vector2.ZERO, r, a, a + TAU / 3.0 * 0.6, 14, BioArt.with_alpha(color, 0.85 * fade), 2.4, true)
	for i in 3:
		var a := -_age * 2.4 + i * TAU / 3.0
		draw_arc(Vector2.ZERO, r * 0.72, a, a + TAU / 3.0 * 0.45, 12, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.7 * fade), 1.6, true)
	for i in 4:
		var d := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
		draw_line(d * r * 1.05, d * r * 1.3, BioArt.with_alpha(color, 0.9 * fade), 2.2, true)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2.0), false, BioArt.with_alpha(color, 0.12 * fade))
