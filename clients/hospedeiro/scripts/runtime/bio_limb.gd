class_name BioLimb
extends Node2D
## A limb the body grows and reabsorbs: an elastic chain rooted inside the membrane, drawn as one tapered
## ribbon with the cell's own colours, so it reads as the membrane itself stretching out. Its shape comes from
## BioLimbStyle (form + procedural look + genes). It only draws and moves; damage is never decided here.
##
## It extends with a spring (a little overshoot, then settles), trails behind the cell's motion, undulates, and
## can sweep across an arc, follow a moving target or stay out until released.

signal reached
signal retracted

const POINTS := 18

var style: Dictionary = {}
var host: Node2D
var core := BioArt.CYAN
var edge := BioArt.DEEP_BLUE
var tint := Color(0, 0, 0, 0)  # an ability's colour (alpha 0 = none), mixed into the glow and the tip
var body_radius_px := 26.0
var length_px := 100.0
var aim := Vector2.RIGHT
var grow_time := 0.12
var hold_time := 0.2  # < 0: stays until release()
var sweep_from := 0.0
var sweep_to := 0.0
var sweep_time := 0.0
var follow: Node2D
var intensity := 1.0  # dimmed when many limbs stack, so additive light does not burn out

var _age := 0.0
var _ext := 0.0
var _ext_v := 0.0
var _retracting := false
var _reached_sent := false
var _seed := randf() * 20.0
var _pts := PackedVector2Array()
var _tip_dir := Vector2.RIGHT
var _bend := 1.0 if randf() > 0.5 else -1.0
var body: BioCellBody


static var _crowd := 0  # limbs alive right now


func _ready() -> void:
	_crowd += 1
	z_index = 9
	material = BioArt.additive()
	_pts.resize(POINTS)
	var anchor := aim * body_radius_px * 0.55
	for i in POINTS:
		_pts[i] = anchor


func _exit_tree() -> void:
	_crowd = maxi(_crowd - 1, 0)
	if body != null and is_instance_valid(body):
		body.clear_bulge(get_instance_id())


func release() -> void:
	_retracting = true


func tip_global() -> Vector2:
	return to_global(_pts[POINTS - 1])


func extension() -> float:
	return _ext


func _current_aim() -> Vector2:
	if is_instance_valid(follow):
		var to := follow.global_position - global_position
		if to.length() > 1.0:
			return to.normalized()
	if sweep_time > 0.0:
		var k := clampf(_age / sweep_time, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 2.0)
		return Vector2.from_angle(lerpf(sweep_from, sweep_to, k))
	return aim


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	_age += delta
	if hold_time >= 0.0 and _age > grow_time + hold_time:
		_retracting = true
	var dir := _current_aim()
	var length_now := length_px
	if is_instance_valid(follow):
		length_now = clampf(follow.global_position.distance_to(global_position) - body_radius_px * 0.3, 20.0, length_px)
	var ext_target := 0.0 if _retracting else 1.0
	var omega := PI / (2.0 * maxf(grow_time, 0.03)) / maxf(float(style.get("speed", 1.0)), 0.3)
	if _retracting:
		omega /= 1.3
	var zeta := 1.0 if _retracting else 0.5
	_ext_v += ((ext_target - _ext) * omega * omega - 2.0 * zeta * omega * _ext_v) * delta
	_ext += _ext_v * delta
	if _retracting and _ext < 0.04:
		retracted.emit()
		queue_free()
		return
	_ext = maxf(_ext, 0.0)
	if _ext >= 0.9 and not _reached_sent:
		_reached_sent = true
		reached.emit()
	var stiff := float(style.get("stiffness", 0.5))
	var anchor := dir * body_radius_px * 0.55
	var tip_target := dir * (body_radius_px * 0.55 + length_now * _ext)
	var perp := dir.orthogonal()
	var vel := (host as CharacterBody2D).velocity if host is CharacterBody2D else Vector2.ZERO
	var rate := lerpf(9.0, 70.0, stiff)
	var wave_amp := float(style.get("wave", 0.25)) * length_now * 0.15 * (1.0 - stiff * 0.9) * minf(_ext, 1.2)
	var speed := float(style.get("speed", 1.0))
	var bend_amp := length_now * 0.13 * (1.0 - stiff * 0.8) * minf(_ext, 1.1)
	_pts[0] = anchor
	if body != null and is_instance_valid(body):
		var root_w := float(style.get("base", 15.0)) * 1.6
		body.set_bulge(get_instance_id(), dir.angle(), clampf(_ext, 0.0, 1.0) * clampf(root_w / maxf(body_radius_px, 1.0), 0.0, 1.0) * 0.95, 0.5 + root_w / maxf(body_radius_px, 1.0) * 0.5)
	for i in range(1, POINTS):
		var f := i / float(POINTS - 1)
		var wanted := anchor.lerp(tip_target, f)
		wanted += perp * sin(_age * 7.0 * speed - f * 5.0 + _seed) * wave_amp * sin(PI * f)
		wanted += perp * _bend * bend_amp * sin(PI * f) * (1.0 - f * 0.35)  # a natural arc, not a ruler
		wanted -= vel * 0.022 * f * (1.0 - stiff)
		var r := rate * lerpf(1.25, 0.6, f * (1.0 - stiff))
		_pts[i] = _pts[i].lerp(wanted, 1.0 - exp(-r * delta))
	_tip_dir = (_pts[POINTS - 1] - _pts[POINTS - 3]).normalized() if _pts[POINTS - 1] != _pts[POINTS - 3] else dir
	# level of detail: with many limbs alive (a nova, a fight) each is redrawn every second or third frame (staggered), which is what
	# keeps a crowded fight smooth; one limb on its own is drawn every frame
	var step := 1 if _crowd <= 6 else (2 if _crowd <= 14 else 3)
	if step == 1 or (Engine.get_process_frames() + get_instance_id()) % step == 0:
		queue_redraw()


func _width(f: float) -> float:
	var base := float(style.get("base", 15.0))
	var tip_w := float(style.get("tip_w", 12.0))
	var w := lerpf(base, tip_w, pow(f, 0.8))
	var neck := smoothstep(0.0, 1.0, maxf(0.0, 1.0 - f / 0.32))
	w *= 1.0 + 0.7 * neck * neck  # the root is a wide neck that narrows like drawn-out membrane
	return w * lerpf(0.55, 1.0, minf(_ext, 1.0))


## Per-point constants of every limb (same for all of them), computed once: the position along the limb, its root fades and the
## narrowing of the neck. They keep _draw to one cheap pass per limb.
static var _t_pow := PackedFloat32Array()
static var _t_neck := PackedFloat32Array()
static var _t_strip_fade := PackedFloat32Array()
static var _t_outline_fade := PackedFloat32Array()
static var _t_flow_root := PackedFloat32Array()
static var _t_along := _make_along()  # last: filling the others needs them declared first


static func _make_along() -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(POINTS)
	_t_pow.resize(POINTS)
	_t_neck.resize(POINTS)
	_t_strip_fade.resize(POINTS)
	_t_outline_fade.resize(POINTS)
	_t_flow_root.resize(POINTS)
	for i in POINTS:
		var x := i / float(POINTS - 1)
		f[i] = x
		_t_pow[i] = pow(x, 0.8)
		var neck := smoothstep(0.0, 1.0, maxf(0.0, 1.0 - x / 0.32))
		_t_neck[i] = 1.0 + 0.7 * neck * neck
		_t_strip_fade[i] = smoothstep(0.0, 0.3, x)
		_t_outline_fade[i] = smoothstep(0.05, 0.35, x)
		_t_flow_root[i] = smoothstep(0.0, 0.2, x)
	return f


func _draw() -> void:
	var alpha := clampf(_ext * 2.0, 0.0, 1.0) * intensity
	var glow_c := core.lerp(tint, tint.a * 0.55) if tint.a > 0.0 else core
	var base_w := float(style.get("base", 15.0))
	var tip_w := float(style.get("tip_w", 12.0))
	var grow := lerpf(0.55, 1.0, minf(_ext, 1.0))
	var thin := clampf(14.0 / maxf(base_w, 1.0), 0.3, 1.0)
	var crowd := _crowd  # level of detail: many limbs at once (a nova, a fight) draw fewer layers
	var c_glow := glow_c
	var c_mid := edge.lerp(core, 0.4)
	var c_core := core.lerp(Color.WHITE, 0.2)
	var c_flow := core.lerp(Color.WHITE, 0.35)
	var c_out := edge.lerp(Color.WHITE, 0.2)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var widths := PackedFloat32Array()
	var col_glow := PackedColorArray()
	var col_mid := PackedColorArray()
	var col_core := PackedColorArray()
	var col_flow := PackedColorArray()
	var col_out := PackedColorArray()
	left.resize(POINTS)
	right.resize(POINTS)
	widths.resize(POINTS)
	col_glow.resize(POINTS)
	col_mid.resize(POINTS)
	col_core.resize(POINTS)
	col_flow.resize(POINTS)
	col_out.resize(POINTS)
	var last := POINTS - 1
	for i in POINTS:
		var a := _pts[maxi(i - 1, 0)]
		var b := _pts[mini(i + 1, last)]
		var d := (b - a).normalized() if b != a else _tip_dir
		var w := lerpf(base_w, tip_w, _t_pow[i]) * _t_neck[i] * grow
		widths[i] = w
		var n := d.orthogonal() * (w * 0.5)
		left[i] = _pts[i] + n
		right[i] = _pts[i] - n
		var fade := _t_strip_fade[i]
		col_glow[i] = Color(c_glow.r, c_glow.g, c_glow.b, 0.07 * alpha * fade)
		col_mid[i] = Color(c_mid.r, c_mid.g, c_mid.b, 0.24 * alpha * fade)
		col_core[i] = Color(c_core.r, c_core.g, c_core.b, 0.2 * alpha * fade)
		var wave := 0.5 + 0.5 * sin(_age * 6.0 - _t_along[i] * 9.0)
		col_flow[i] = Color(c_flow.r, c_flow.g, c_flow.b, (0.34 * (1.0 - _t_along[i]) + 0.1 + 0.1 * wave) * alpha * thin * _t_flow_root[i])
		col_out[i] = Color(c_out.r, c_out.g, c_out.b, 0.8 * alpha * _t_outline_fade[i])
	_ribbon(left, right, _pts, 1.0, col_mid)
	if crowd <= 16:
		_ribbon(left, right, _pts, 0.45, col_core)
		_ribbon(left, right, _pts, 0.55, col_flow)
	draw_polyline_colors(left, col_out, 2.2, true)
	draw_polyline_colors(right, col_out, 2.2, true)
	_draw_extras(widths, alpha)
	_draw_tip(_pts[last], _tip_dir, widths[last], glow_c, alpha)


static var _ribbon_indices := _make_ribbon_indices()


static func _make_ribbon_indices() -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in POINTS - 1:
		idx.append_array(PackedInt32Array([2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2]))
	return idx


## A ribbon between the two edges as ONE draw command: vertices on both sides of the spine with a colour each, and the triangles
## between them (a draw call per quad made limbs the most expensive thing in a fight).
func _ribbon(left: PackedVector2Array, right: PackedVector2Array, spine: PackedVector2Array, width_scale: float, colors_along: PackedColorArray) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(2 * POINTS)
	cols.resize(2 * POINTS)
	for i in POINTS:
		pts[2 * i] = spine[i] + (left[i] - spine[i]) * width_scale
		pts[2 * i + 1] = spine[i] + (right[i] - spine[i]) * width_scale
		cols[2 * i] = colors_along[i]
		cols[2 * i + 1] = colors_along[i]
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _ribbon_indices, pts, cols)


func _at(f: float) -> Vector2:
	var x := f * (POINTS - 1)
	var i := clampi(floori(x), 0, POINTS - 2)
	return _pts[i].lerp(_pts[i + 1], x - i)


func _normal_at(f: float) -> Vector2:
	var a := _at(maxf(f - 0.04, 0.0))
	var b := _at(minf(f + 0.04, 1.0))
	return (b - a).normalized().orthogonal() if a != b else _tip_dir.orthogonal()


func _draw_extras(widths: PackedFloat32Array, alpha: float) -> void:
	var barbs := int(style.get("barbs", 0))
	var bumps := int(style.get("bumps", 0))
	var branches := int(style.get("branches", 0))
	var spike_c := BioArt.with_alpha(edge.lerp(Color.WHITE, 0.35), 0.6 * alpha)
	for k in barbs:  # barbs along the shaft, leaning towards the tip, alternating sides
		var f := 0.18 + 0.7 * (k + 0.5) / float(barbs)
		var p := _at(f)
		var n := _normal_at(f) * (1.0 if k % 2 == 0 else -1.0)
		var w := widths[roundi(f * (POINTS - 1))] * 0.5
		var from := p + n * w
		var to := from + n * (7.0 + 5.0 * f) + _tip_dir * 8.0
		draw_line(from, to, BioArt.with_alpha(core, 0.2 * alpha), 4.0, true)
		draw_line(from, to, spike_c, 1.8, true)
		draw_circle(to, 1.5, BioArt.with_alpha(Color.WHITE, 0.6 * alpha))
	for k in bumps:  # granules of stored energy swelling the shaft
		var f := 0.22 + 0.6 * (k + 0.5) / float(bumps)
		var p := _at(f)
		var r := widths[roundi(f * (POINTS - 1))] * (0.42 + 0.1 * sin(_age * 3.0 + k))
		draw_circle(p, r, BioArt.with_alpha(BioArt.AMBER.lerp(core, 0.35), 0.35 * alpha))
		draw_circle(p, r * 0.45, BioArt.with_alpha(Color.WHITE, 0.4 * alpha))
	for k in branches:  # side twigs, the more sociable the body, the more of them
		var f := 0.3 + 0.5 * (k + 0.5) / float(branches)
		var p := _at(f)
		var side := 1.0 if k % 2 == 0 else -1.0
		var dir := _tip_dir.rotated(side * (0.7 + 0.15 * sin(_age * 2.5 + k)))
		var length := length_px * 0.2 * minf(_ext, 1.0)
		var mid := p + dir * length * 0.55 + dir.orthogonal() * sin(_age * 5.0 + k) * 3.0
		var end := p + dir * length
		draw_polyline(PackedVector2Array([p, mid, end]), BioArt.with_alpha(core.lerp(Color.WHITE, 0.2), 0.55 * alpha), 1.8, true)
		draw_circle(end, 2.0, BioArt.with_alpha(Color.WHITE, 0.6 * alpha))
	if bool(style.get("motes", false)):  # shed light drifting along it
		for k in 5:
			var f := fmod(_age * 0.7 + k * 0.2, 1.0)
			var p := _at(f) + _normal_at(f) * sin(_age * 3.0 + k * 2.0) * 9.0
			draw_texture_rect(BioArt.glow_texture(), Rect2(p - Vector2.ONE * 7.0, Vector2.ONE * 14.0), false, BioArt.with_alpha(core.lerp(Color(1.0, 0.95, 0.6), 0.5), 0.75 * alpha * (1.0 - f * 0.5)))


func _draw_tip(tip: Vector2, d: Vector2, w: float, glow_c: Color, alpha: float) -> void:
	var n := d.orthogonal()
	var white := BioArt.with_alpha(Color.WHITE, 0.8 * alpha)
	var hot := BioArt.with_alpha(glow_c.lerp(Color.WHITE, 0.25), 0.75 * alpha)
	var kind: StringName = style.get("tip", &"blob")
	match kind:
		&"cup":  # an open maw / scoop: two crescents facing forward
			var r := maxf(w, 20.0) * 0.8
			var ang := d.angle()
			draw_arc(tip, r, ang - 1.3, ang + 1.3, 18, hot, 5.0, true)
			draw_arc(tip, r * 0.62, ang - 1.1, ang + 1.1, 14, BioArt.with_alpha(glow_c, 0.6 * alpha), 3.0, true)
			draw_texture_rect(BioArt.glow_texture(), Rect2(tip - Vector2.ONE * r * 1.4, Vector2.ONE * r * 2.8), false, BioArt.with_alpha(glow_c, 0.18 * alpha))
		&"spear":
			var tip_point := tip + d * (18.0 + 6.0 * minf(_ext, 1.0))
			draw_primitive(PackedVector2Array([tip + n * 5.0, tip - n * 5.0, tip_point]), PackedColorArray([hot, hot, white]), PackedVector2Array())
			draw_line(tip, tip_point, white, 2.0, true)
			draw_texture_rect(BioArt.glow_texture(), Rect2(tip_point - Vector2.ONE * 16.0, Vector2.ONE * 32.0), false, BioArt.with_alpha(glow_c, 0.45 * alpha))
		&"fork":
			for side in [-1.0, 1.0]:
				var dir := d.rotated(float(side) * 0.65)
				var end := tip + dir * 13.0
				draw_line(tip, end, hot, 2.2, true)
				draw_circle(end, 2.6, white)
			draw_circle(tip, 3.0, white)
			draw_texture_rect(BioArt.glow_texture(), Rect2(tip - Vector2.ONE * 14.0, Vector2.ONE * 28.0), false, BioArt.with_alpha(glow_c, 0.28 * alpha))
		&"bulb":
			var pulse := 1.0 + 0.15 * sin(_age * 6.0)
			var r := maxf(w, 10.0) * 0.55 * pulse
			draw_texture_rect(BioArt.glow_texture(), Rect2(tip - Vector2.ONE * r * 2.6, Vector2.ONE * r * 5.2), false, BioArt.with_alpha(glow_c, 0.3 * alpha))
			draw_circle(tip, r, BioArt.with_alpha(core, 0.7 * alpha))
			draw_circle(tip, r * 0.5, white)
		&"y":  # an antibody
			var stem := tip + d * 9.0
			draw_line(tip, stem, hot, 3.0, true)
			for side in [-1.0, 1.0]:
				var arm := stem + d.rotated(float(side) * 0.62) * 11.0
				draw_line(stem, arm, hot, 3.0, true)
				draw_circle(arm, 3.0, white)
			draw_texture_rect(BioArt.glow_texture(), Rect2(stem - Vector2.ONE * 15.0, Vector2.ONE * 30.0), false, BioArt.with_alpha(glow_c, 0.28 * alpha))
		_:  # blob: a blunt pseudopod end
			var r := maxf(w, 9.0) * 0.5
			draw_texture_rect(BioArt.glow_texture(), Rect2(tip - Vector2.ONE * r * 2.4, Vector2.ONE * r * 4.8), false, BioArt.with_alpha(glow_c, 0.28 * alpha))
			draw_circle(tip, r * 0.55, hot)
