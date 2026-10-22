class_name BioAmbientMotes
extends Node2D
## Drifting plankton-like specks and huge faint blobs that give the dark water depth.

var _motes: Array[Sprite2D] = []
var _anchors: Array[Vector2] = []
var _phases: Array[float] = []


func count() -> int:
	return _motes.size()


func build(specks: int, blobs: int, radius_units: float, rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var palette := [BioArt.CYAN, BioArt.DEEP_BLUE, BioArt.MAGENTA, BioArt.JADE]
	for i in specks + blobs:
		var is_blob := i >= specks
		var color: Color = palette[rng.randi() % palette.size()]
		var sprite: Sprite2D
		if is_blob:
			sprite = BioArt.make_glow(BioArt.with_alpha(color, 0.05 + rng.randf() * 0.05), 8.0 + rng.randf() * 10.0, -20)
		else:
			sprite = BioArt.make_glow(BioArt.with_alpha(color, 0.25 + rng.randf() * 0.4), 0.08 + rng.randf() * 0.18, -10)
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius_units * 1.15 * BioArt.UNIT
		var anchor := Vector2.from_angle(angle) * dist
		sprite.position = anchor
		add_child(sprite)
		_motes.append(sprite)
		_anchors.append(anchor)
		_phases.append(rng.randf() * 20.0)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var drift := 0.8 * BioArt.UNIT
	for i in _motes.size():
		var p := _phases[i]
		_motes[i].position = _anchors[i] + Vector2(sin(t * 0.2 + p), cos(t * 0.17 + p * 1.3)) * drift
