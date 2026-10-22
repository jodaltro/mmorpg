class_name BioFxLife
extends Node2D

enum Kind { MOTE, ARC, RING }

var kind: int = Kind.MOTE
var color := Color.WHITE
var life := 0.5
var velocity := Vector2.ZERO
var size_px := 10.0
var points := PackedVector2Array()
var start_scale := 1.0
var end_scale := 1.0
var _age := 0.0


func _ready() -> void:
	material = BioArt.additive()
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	var t := _age / life
	if t >= 1.0:
		queue_free()
		return
	position += velocity * delta
	velocity *= maxf(0.0, 1.0 - 3.0 * delta)
	scale = Vector2.ONE * lerpf(start_scale, end_scale, t)
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var c := BioArt.with_alpha(color, color.a * (1.0 - t) * (1.0 - t))
	match kind:
		Kind.MOTE:
			draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -size_px * 0.5, Vector2.ONE * size_px), false, c)
		Kind.ARC:
			draw_polyline(points, BioArt.with_alpha(c.lerp(Color.WHITE, 0.4), c.a), 9.0, true)
		Kind.RING:
			draw_polyline(points, c, 3.0, true)
