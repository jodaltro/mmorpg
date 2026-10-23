class_name BioNiche
extends Node2D
## A hidden pocket of the body. It is only a faint shimmer until the cell comes near, and reaching it hands over its gene
## (the engine decides; this only tells it the cell arrived).

signal reached(id: String)

const SHIMMER_UNITS := 15.0
const REACH_UNITS := 2.6

var niche_id := ""
var player: BioCellActor
var _t := 0.0
var _done := false


func configure(id: String, who: BioCellActor) -> void:
	niche_id = id
	player = who
	z_index = -3
	material = BioArt.additive()


func _process(delta: float) -> void:
	_t += delta
	if _done or player == null or not player.is_active():
		return
	if player.global_position.distance_to(global_position) <= REACH_UNITS * BioArt.UNIT:
		_done = true
		reached.emit(niche_id)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var d := player.global_position.distance_to(global_position) / BioArt.UNIT
	var near := clampf(1.0 - d / SHIMMER_UNITS, 0.0, 1.0)
	if near <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var base := Color(0.65, 1.0, 0.8)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -2.2 * BioArt.UNIT, Vector2.ONE * 4.4 * BioArt.UNIT), false, BioArt.with_alpha(base, (0.08 + 0.12 * pulse) * near))
	for i in 3:
		var a := _t * 0.5 + i * TAU / 3.0
		draw_circle(Vector2.from_angle(a) * (0.9 + 0.25 * pulse) * BioArt.UNIT, 3.0 + 3.0 * near, BioArt.with_alpha(base, 0.35 + 0.4 * near))
	draw_arc(Vector2.ZERO, 0.55 * BioArt.UNIT * (1.0 + 0.2 * pulse), 0.0, TAU, 32, BioArt.with_alpha(base, 0.5 * near), 2.0, true)
