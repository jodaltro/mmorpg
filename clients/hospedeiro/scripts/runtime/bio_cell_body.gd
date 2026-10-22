class_name BioCellBody
extends Node2D
## Deformable glowing membrane: the rim breathes, stretches with velocity and can sprout spikes.

const RIM := 64
const NECK_SEGMENTS := 5  # tail segments filled by the body itself so the join has no seam

var radius_units := 0.55
var core := BioArt.CYAN
var edge := BioArt.DEEP_BLUE
var wobble := 0.06
var spikes := 0
var spike_length := 0.0
var spin := 0.5

var _seed := randf() * 10.0
var _flash := 0.0
var _telegraph := 0.0
var _smooth_velocity := Vector2.ZERO
var _nucleus: Sprite2D
var _rim := PackedVector2Array()
var _outline := PackedVector2Array()
var _neck := PackedVector2Array()
var tail: BioFlagellum  # when set, the membrane bulges where the tail leaves the cell


func configure(radius: float, core_color: Color, edge_color: Color, spike_count: int, spike_len: float, spin_speed: float, z: int) -> void:
	radius_units = radius
	core = core_color
	edge = edge_color
	spikes = spike_count
	spike_length = spike_len
	spin = spin_speed
	z_index = z


func flash() -> void:
	_flash = 1.0


func set_telegraph(amount: float) -> void:
	_telegraph = clampf(amount, 0.0, 1.0)


func _ready() -> void:
	material = BioArt.additive()
	_nucleus = BioArt.make_glow(core, 1.0, 2)
	add_child(_nucleus)
	_rim.resize(RIM)


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	var host := get_parent() as CharacterBody2D
	var v := host.velocity if host != null else Vector2.ZERO
	_smooth_velocity = _smooth_velocity.lerp(v, 1.0 - exp(-8.0 * delta))
	var t := Time.get_ticks_msec() * 0.001 + _seed
	var speed_units := _smooth_velocity.length() / BioArt.UNIT
	var dir := _smooth_velocity.normalized() if speed_units > 0.05 else Vector2.RIGHT
	var stretch := clampf(speed_units * 0.04, 0.0, 0.35)
	var breath := 1.0 + 0.04 * sin(t * 3.0) + _telegraph * 0.28
	for i in RIM:
		var a := i * TAU / RIM
		var n := Vector2.from_angle(a)
		var w := 1.0 + wobble * (sin(a * 3.0 + t * 2.1) + 0.6 * sin(a * 5.0 - t * 3.3) + 0.4 * sin(a * 2.0 + t * 1.3))
		var spike := 0.0
		if spikes > 0:
			spike = spike_length * pow(maxf(0.0, cos((a + t * spin) * spikes)), 6.0)
		var along := n.dot(dir)
		var squash := 1.0 + stretch * along * along - stretch * 0.5 * (1.0 - along * along)
		_rim[i] = n * radius_units * BioArt.UNIT * (w + spike) * squash * breath
	_neck = PackedVector2Array()
	_outline = _build_outline() if tail != null else PackedVector2Array()
	var pulse := 1.0 + 0.12 * sin(t * 2.3)
	_nucleus.scale = Vector2.ONE * (radius_units * 1.7 * pulse * (1.0 + _telegraph * 0.5) * BioArt.UNIT / 128.0)
	_nucleus.modulate = BioArt.with_alpha(_core_now().lerp(BioArt.CRIMSON, _telegraph), 0.75)
	_nucleus.position = _smooth_velocity * 0.01
	queue_redraw()


func _core_now() -> Color:
	return core.lerp(Color.WHITE, _flash * 0.8)


func _edge_now() -> Color:
	return edge.lerp(BioArt.CRIMSON, _telegraph).lerp(Color.WHITE, _flash)


func _draw() -> void:
	if _rim.size() < 3:
		return
	var edge_now := _edge_now()
	var core_now := _core_now()
	var layers := [[1.0, BioArt.with_alpha(edge_now, 0.28)], [0.7, BioArt.with_alpha(core_now, 0.16 + _telegraph * 0.2)], [0.4, BioArt.with_alpha(core_now, 0.2)]]
	for layer in layers:
		var scaled := PackedVector2Array()
		if float(layer[0]) == 1.0 and _neck.size() >= 3:
			scaled = _neck
		else:
			for p in _rim:
				scaled.append(p * float(layer[0]))
		_fill_fan(scaled, layer[1])
	var outline := _outline if _outline.size() >= 3 else _rim
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, BioArt.with_alpha(edge_now.lerp(Color.WHITE, 0.35), 0.95), 3.0, true)


## Triangle fan from the centre as raw primitives: no triangulation step that could fail on odd shapes.
func _fill_fan(points: PackedVector2Array, fill: Color) -> void:
	var colors := PackedColorArray([fill, fill, fill])
	for i in points.size():
		draw_primitive(PackedVector2Array([Vector2.ZERO, points[i], points[(i + 1) % points.size()]]), colors, PackedVector2Array())


## One silhouette: the rim where the tail leaves the cell is replaced by the tail's own edges,
## then rounded, so the tail reads as the membrane itself stretched out of the nucleus.
func _build_outline() -> PackedVector2Array:
	var left := tail.left_edge()
	var right := tail.right_edge()
	var origin := (get_parent() as Node2D).global_position
	var r_t := radius_units * BioArt.UNIT
	var j0 := -1
	for i in left.size():
		if ((left[i] + right[i]) * 0.5 - origin).length() >= r_t:
			j0 = i
			break
	if j0 < 1 or j0 + NECK_SEGMENTS >= left.size() - 2:
		return PackedVector2Array()
	var half_width := (left[j0] - right[j0]).length() * 0.5
	var step := TAU / RIM
	var cut_steps := ceili((asin(clampf(half_width / r_t, 0.0, 0.9)) + 0.05) / step)
	var centre := roundi(wrapf(tail.tail_direction().angle(), 0.0, TAU) / step) % RIM
	var out := PackedVector2Array()
	for s in range(cut_steps, RIM - cut_steps + 1):
		out.append(_rim[(centre + s) % RIM])
	var rim_count := out.size()
	for i in range(j0, right.size()):
		out.append(right[i] - origin)
	for i in range(left.size() - 1, j0 - 1, -1):
		out.append(left[i] - origin)
	# Round both junctions.
	var n := out.size()
	for pass_index in 3:
		var smoothed := out.duplicate()
		for junction in [rim_count, 0]:
			for d in range(-5, 6):
				var idx := posmod(junction + d, n)
				smoothed[idx] = (out[posmod(idx - 1, n)] + out[idx] * 2.0 + out[posmod(idx + 1, n)]) * 0.25
		out = smoothed
	_neck = out.slice(0, rim_count + NECK_SEGMENTS) + out.slice(n - NECK_SEGMENTS, n)
	return out
