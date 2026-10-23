class_name BioGate
extends Node2D
## The entrance of the granuloma in the bloodstream: concentric rings of fused macrophages around a dark, necrotic core.
## It shows whether the cell may go in and how to do it.

const REACH_UNITS := 3.2

var eligible := false
var hint := ""
var _player: BioCellActor
var _t := 0.0


func configure(player: BioCellActor) -> void:
	_player = player
	z_index = -2
	material = BioArt.additive()


func is_near() -> bool:
	return _player != null and _player.is_active() and _player.global_position.distance_to(global_position) <= REACH_UNITS * BioArt.UNIT


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := 1.9 * BioArt.UNIT
	var pink := Color(1.0, 0.45, 0.62)
	for ring in 3:
		var rr := r * (1.0 - ring * 0.27)
		var segs := 9 + ring * 3
		for i in segs:
			var a := i * TAU / segs + _t * (0.08 if ring % 2 == 0 else -0.08)
			draw_arc(Vector2.ZERO, rr, a, a + TAU / segs * 0.78, 6, BioArt.with_alpha(pink, 0.55 - 0.12 * ring), 6.0 - ring, true)
	var pulse := 0.5 + 0.5 * sin(_t * 1.6)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r * 0.5, Vector2.ONE * r), false, Color(0.55, 0.9, 0.25, 0.18 + 0.12 * pulse))
	draw_circle(Vector2.ZERO, r * 0.14, Color(0.1, 0.2, 0.05, 0.6))
	if is_near():
		draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 56, Color(1, 1, 1, 0.25 + 0.2 * pulse), 2.0, true)
