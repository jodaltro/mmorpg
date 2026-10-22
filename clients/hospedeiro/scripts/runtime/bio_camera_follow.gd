class_name BioCameraFollow
extends Camera2D

var target: Node2D
var smooth_time := 0.18
var look_ahead := 0.25

var _shake := 0.0


func _ready() -> void:
	zoom = Vector2.ONE * 1.35


func set_target(follow: Node2D) -> void:
	target = follow
	if target != null:
		global_position = target.global_position


func shake(magnitude_units: float) -> void:
	_shake = maxf(_shake, magnitude_units)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var ahead := Vector2.ZERO
	var body := target as CharacterBody2D
	if body != null:
		ahead = body.velocity * look_ahead
	global_position = global_position.lerp(target.global_position + ahead, 1.0 - exp(-delta / smooth_time))
	_shake = move_toward(_shake, 0.0, delta * 1.2)
	offset = Vector2.from_angle(randf() * TAU) * _shake * BioArt.UNIT
