class_name BioFlagellum
extends Node2D
## Locomotion tail that is also the lash weapon. The root always stays on the cell's rear; a lash bends the
## whole tail around the body as a curve and is blended in/out of the resting chain so it never detaches.

const LASH_SECONDS := 0.24
const LASH_LAG_DEGREES := 50.0
const TRAIL_SECONDS := 0.25

var segments := 26
var segment_length_units := 0.12
var anchor_radius_units := 0.3
var width_px := 17.0
var color := BioArt.CYAN
var root_color := BioArt.DEEP_BLUE  # matches the membrane edge so the tail reads as part of the body
var body_radius_px := 26.0

var _points := PackedVector2Array()  # resting chain (follow-the-leader physics)
var _rendered := PackedVector2Array()
var _left := PackedVector2Array()
var _right := PackedVector2Array()
var _tail_dir := Vector2.LEFT
var _whip := 0.0
var _initialised := false

var _lash_t := -1.0
var _lash_angle := 0.0
var _lash_half := 0.0
var _lash_length := 0.0
var _lash_sign := 1.0
var _lash_weight := 0.0
var _prev_sweep := 0.0
var _trail: Array = []  # [position, age] pairs of the tail tip


func configure(anchor_radius: float, segment_length: float, width: float, tint: Color, z: int) -> void:
	anchor_radius_units = anchor_radius
	segment_length_units = segment_length
	width_px = width
	color = tint
	z_index = z


func whip(strength: float) -> void:
	_whip = maxf(_whip, strength)


## Tail attack: the tail sweeps across the attack arc, alternating side each time.
func lash(aim: Vector2, reach_units: float, half_angle_degrees: float) -> void:
	_lash_t = 0.0
	_lash_angle = aim.angle()
	_lash_half = deg_to_rad(half_angle_degrees)
	_lash_length = (reach_units + 0.35) * BioArt.UNIT
	_lash_sign = -_lash_sign
	_prev_sweep = _lash_angle - _lash_sign * _lash_half


func is_lashing() -> bool:
	return _lash_t >= 0.0


## Direction from the cell centre towards where the tail leaves the body.
func tail_direction() -> Vector2:
	return _tail_dir


func left_edge() -> PackedVector2Array:
	return _left


func right_edge() -> PackedVector2Array:
	return _right


func half_width_px(k: float) -> float:
	return lerpf(width_px * (1.0 + 0.5 * _lash_weight), 1.0, pow(k, 0.7)) * 0.5


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	material = BioArt.additive()
	process_priority = -1  # run before the body so its outline uses this frame's tail
	_points.resize(segments)
	_rendered.resize(segments)
	_left.resize(segments)
	_right.resize(segments)


func _process(delta: float) -> void:
	var host := get_parent() as CharacterBody2D
	if host == null:
		return
	var v := host.velocity
	var speed_units := v.length() / BioArt.UNIT
	if speed_units > 0.3:
		var blended := _tail_dir.lerp(-v.normalized(), 1.0 - exp(-6.0 * delta))
		_tail_dir = blended.normalized() if blended.length() > 0.01 else -v.normalized()
	var seg := segment_length_units * BioArt.UNIT
	var anchor := host.global_position + _tail_dir * anchor_radius_units * BioArt.UNIT
	if not _initialised:
		for i in segments:
			_points[i] = anchor + _tail_dir * seg * i
		_initialised = true
	_points[0] = anchor
	for i in range(1, segments):
		var d := _points[i] - _points[i - 1]
		if d.length_squared() < 1e-6:
			d = _tail_dir
		_points[i] = _points[i - 1] + d.normalized() * seg

	_whip = move_toward(_whip, 0.0, delta * 2.5)
	var amplitude := (0.12 + speed_units * 0.02 + _whip * 0.35) * BioArt.UNIT
	var frequency := 5.0 + speed_units * 0.8
	var perp := Vector2(-_tail_dir.y, _tail_dir.x)
	var t := Time.get_ticks_msec() * 0.001
	for i in segments:
		var k := i / float(segments - 1)
		var envelope := 0.25 + 0.75 * k  # already bends near the root, so it grows out of the body
		var wave := sin(t * frequency - k * 5.5) + 0.35 * sin(t * 0.9 + k * 2.0)
		_rendered[i] = _points[i] + perp * wave * amplitude * envelope

	_age_trail(delta)
	_lash_weight = 0.0
	if _lash_t >= 0.0:
		_apply_lash(host, anchor, delta)
	_compute_edges()
	queue_redraw()


func _compute_edges() -> void:
	for i in segments:
		var tangent := (_rendered[mini(i + 1, segments - 1)] - _rendered[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half := half_width_px(i / float(segments - 1))
		_left[i] = _rendered[i] + normal * half
		_right[i] = _rendered[i] - normal * half


## Blends a cubic curve (rear root -> around the flank -> swept tip) over the resting chain.
func _apply_lash(host: CharacterBody2D, anchor: Vector2, delta: float) -> void:
	_lash_t += delta / LASH_SECONDS
	if _lash_t >= 1.0:
		_lash_t = -1.0
		return
	var t := _lash_t
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var sweep := _lash_angle + _lash_sign * lerpf(-_lash_half, _lash_half, eased)
	var lag := deg_to_rad(LASH_LAG_DEGREES) * (1.0 - t)
	var base := host.global_position
	var sweep_dir := Vector2.from_angle(sweep)
	var side := signf(_tail_dir.cross(sweep_dir))
	if side == 0.0:
		side = _lash_sign
	var flank := Vector2(-_tail_dir.y, _tail_dir.x) * side
	var p0 := anchor
	var p1 := anchor + flank * _lash_length * 0.75 + _tail_dir * _lash_length * 0.1
	var p2 := base + Vector2.from_angle(sweep - _lash_sign * lag) * _lash_length * 0.85
	var p3 := base + sweep_dir * _lash_length
	_lash_weight = minf(1.0, minf(t / 0.2, (1.0 - t) / 0.3))
	_lash_weight = _lash_weight * _lash_weight * (3.0 - 2.0 * _lash_weight)
	for i in segments:
		var k := i / float(segments - 1)
		var curve := _cubic(p0, p1, p2, p3, k)
		_rendered[i] = _rendered[i].lerp(curve, _lash_weight)
	# Sub-sample the tip along the arc so the trail stays curved even on slow frames.
	var reach := _lash_length * 0.95
	for step in range(1, 11):
		var a := lerpf(_prev_sweep, sweep, step / 10.0)
		_trail.append([base + Vector2.from_angle(a) * reach, 0.0])
	_prev_sweep = sweep


static func _cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, k: float) -> Vector2:
	var u := 1.0 - k
	return a * (u * u * u) + b * (3.0 * u * u * k) + c * (3.0 * u * k * k) + d * (k * k * k)


func _age_trail(delta: float) -> void:
	for entry in _trail:
		entry[1] += delta
	while not _trail.is_empty() and _trail[0][1] > TRAIL_SECONDS:
		_trail.pop_front()


func _draw() -> void:
	if not _initialised:
		return
	for i in range(1, _trail.size()):
		var a := 1.0 - float(_trail[i][1]) / TRAIL_SECONDS
		draw_line(_trail[i - 1][0], _trail[i][0], BioArt.with_alpha(Color.WHITE.lerp(color, 0.4), 0.8 * a), 3.5 * a + 1.0, true)
	var host := get_parent() as Node2D
	var bright := color.lerp(Color.WHITE, 0.45 * _lash_weight)
	var shades := PackedColorArray()
	var spine := PackedColorArray()
	for i in segments:
		var k := i / float(segments - 1)
		# Invisible inside the body (the membrane already fills it), fading in as it leaves the cell.
		var dist := _rendered[i].distance_to(host.global_position)
		var fill_in := smoothstep(body_radius_px * 1.5, body_radius_px * 1.9, dist)  # the body fills the neck itself
		var spine_in := smoothstep(body_radius_px * 0.8, body_radius_px * 1.5, dist)
		var tint := root_color.lerp(bright, smoothstep(0.1, 1.0, k))
		var alpha := 0.32 * (1.0 - k * (0.6 - 0.3 * _lash_weight))
		shades.append(BioArt.with_alpha(tint, alpha * fill_in))
		spine.append(BioArt.with_alpha(tint.lerp(Color.WHITE, 0.5), 0.6 * (1.0 - k * 0.7) * spine_in))
	# Triangle strip drawn as raw primitives: no triangulation, so tight curves cannot make it fail.
	for i in segments - 1:
		var colors_a := PackedColorArray([shades[i], shades[i + 1], shades[i + 1]])
		var colors_b := PackedColorArray([shades[i], shades[i + 1], shades[i]])
		draw_primitive(PackedVector2Array([_left[i], _left[i + 1], _right[i + 1]]), colors_a, PackedVector2Array())
		draw_primitive(PackedVector2Array([_left[i], _right[i + 1], _right[i]]), colors_b, PackedVector2Array())
	draw_polyline_colors(_rendered, spine, 2.0, true)
