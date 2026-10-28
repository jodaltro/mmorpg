class_name BioNpcFx
extends Node2D
## The body of a named cell, drawn as ONE organic membrane. Nothing here is a limb stuck onto the cell: every claw, arm, root, spike
## and mouth is the membrane itself deformed (a lobe that grows out of the outline and goes back into it), and the colour is a gradient
## that runs through the cell, from its centre to its rim and out along each extension. Gestures are only changes of this shape:
## notice → approach → anticipate → act → contact → progress → confirmed / cancel → recover. What is not the cell (a toxin, a vesicle
## in transit, a breach, fibrin, the stem cells being fed, the telegraph of a burst, a chemical call) is drawn apart, as itself.
## The shape and tone are pure functions of the interaction state and time; nothing touches a collider or a fact.
## `lod`: 0 a pulsing dot, 1 the membrane with fewer points, 2 the full cell.

var role: Dictionary = BioNpcRoles.FALLBACK
var state: BioInteractionState
var prefs: BioVisualPrefs = BioVisualPrefs.new()
var lod := 2
var t := 0.0
var facing := Vector2.RIGHT
var target_dir := Vector2.DOWN  # towards the tissue or the thing being worked on
var radius_px := 30.0
var step_index := 0
var seed_angle := 0.0
var thanks := 0.0  # seconds left of the gesture of gratitude

const TELEGRAPH_UNITS := 3.2  # the reach of a defensive burst, shown before it happens
const POINTS_FULL := 72
const POINTS_LIGHT := 36

var velocity := Vector2.ZERO  # real movement of the cell on screen (px/s): the body stretches along it and drags behind
var _lobes := {}  # name -> {a, va (angle and its velocity), amp, vamp, w, k}: each extension is its own spring
var _lean := Vector2.ZERO  # where the whole body has moved towards the work, in px
var _lean_v := Vector2.ZERO
var _stretch := 0.0
var _stretch_v := 0.0
var _lag := Vector2.ZERO  # the body trailing behind its own movement
var _breath := 1.0
var _move_angle := 0.0
var _personality := {}
var _scale := 1.0
var _glow := 0.0
var _grey := 0.0
var _rim := PackedVector2Array()
var _rim_colors := PackedColorArray()
var _tip := Vector2.ZERO  # where the longest extension ends (what passes through it is drawn there)


func _count(n: int) -> int:
	return maxi(1, roundi(n * prefs.fx_scale()))


## Moves the shape towards the cell's motor plan (see BioNpcMotion). Every extension follows its own target with its own spring, the
## body leans into the work and trails behind when it travels. Called by the actor with the time since its last call.
func advance(delta: float) -> void:
	if state == null:
		return
	if _personality.is_empty():
		_personality = BioNpcMotion.personality(int(seed_angle * 1000.0))
	var speed := clampf(velocity.length() / (BioArt.UNIT * 5.0), 0.0, 1.0)
	if velocity.length() > 4.0:
		_move_angle = velocity.angle()
	var ctx := {"sil": role["silhouette"], "gesture": state.gesture, "phase": state.phase, "progress": state.progress, "working": state.is_working(),
		"face": facing.angle(), "aim": target_dir.angle(), "aim_vec": target_dir, "speed": speed, "t": t, "tempo": _personality["tempo"],
		"phase_offset": _personality["phase"], "motion": prefs.motion_scale()}
	var want := BioNpcMotion.limbs(ctx)
	for key in want:
		var w: Dictionary = want[key]
		if not _lobes.has(key):
			_lobes[key] = {"a": w["a"], "va": 0.0, "amp": 0.0, "vamp": 0.0, "w": w["w"], "k": w["k"]}
		var c: Dictionary = _lobes[key]
		var ang: Vector2 = BioNpcMotion.spring(float(c["a"]), float(c["va"]), float(c["a"]) + wrapf(float(w["a"]) - float(c["a"]), -PI, PI), delta, float(w["k"]))
		c["a"] = ang.x
		c["va"] = ang.y
		var amp: Vector2 = BioNpcMotion.spring(float(c["amp"]), float(c["vamp"]), float(w["amp"]), delta, float(w["k"]))
		c["amp"] = clampf(amp.x, 0.0, 1.5)
		c["vamp"] = amp.y
		c["w"] = lerpf(float(c["w"]), float(w["w"]), clampf(delta * 8.0, 0.0, 1.0))
		c["k"] = w["k"]
	for key in _lobes.keys():
		if not want.has(key):
			var c2: Dictionary = _lobes[key]
			var fade: Vector2 = BioNpcMotion.spring(float(c2["amp"]), float(c2["vamp"]), 0.0, delta, float(c2["k"]))
			c2["amp"] = maxf(fade.x, 0.0)
			c2["vamp"] = fade.y
			if float(c2["amp"]) < 0.01 and absf(float(c2["vamp"])) < 0.05:
				_lobes.erase(key)
	var body := BioNpcMotion.body(ctx)
	var r := radius_px
	var lean_target: Vector2 = body["lean"] * r
	var lx: Vector2 = BioNpcMotion.spring(_lean.x, _lean_v.x, lean_target.x, delta, 0.7)
	var ly: Vector2 = BioNpcMotion.spring(_lean.y, _lean_v.y, lean_target.y, delta, 0.7)
	_lean = Vector2(lx.x, ly.x)
	_lean_v = Vector2(lx.y, ly.y)
	var st: Vector2 = BioNpcMotion.spring(_stretch, _stretch_v, float(body["stretch"]), delta, 0.8)
	_stretch = st.x
	_stretch_v = st.y
	var follow := 1.0 - exp(-delta * 6.0)
	_lag = _lag.lerp((-velocity * 0.05).limit_length(r * 0.4), follow)
	_breath = lerpf(_breath, float(body["breath"]), follow)
	var k := 1.0 - exp(-delta * 8.0 * maxf(prefs.motion_scale(), 0.5))
	var scale_want := 1.0
	var glow_want := 0.0
	var grey_want := 0.0
	match state.phase:
		BioInteractionState.ANTICIPATE:
			scale_want = 0.9
			glow_want = 0.2
		BioInteractionState.ACT, BioInteractionState.PROGRESS:
			glow_want = 0.12 + 0.3 * state.progress
		BioInteractionState.BLOCKED:
			grey_want = 0.3
		BioInteractionState.HELP:
			grey_want = 0.15
			glow_want = 0.1
		BioInteractionState.CONFIRMED:
			scale_want = 1.0 + 0.14 * prefs.motion_scale()
			glow_want = 0.55 if not prefs.reduce_flash else 0.25
		BioInteractionState.CANCEL:
			scale_want = 0.84
			grey_want = 0.6
	_scale = lerpf(_scale, scale_want, k)
	_glow = lerpf(_glow, glow_want, k)
	_grey = lerpf(_grey, grey_want, k)


# --- the shape: the membrane as the springs of the motor plan shape it ---------------------------------------------------------

func _radius_factor(theta: float) -> float:
	var s := 1.0 + 0.035 * sin(3.0 * theta + t * 1.1 + seed_angle) + 0.022 * sin(5.0 * theta - t * 0.8) * prefs.motion_scale()
	for key in _lobes:
		var c: Dictionary = _lobes[key]
		var d := absf(wrapf(theta - float(c["a"]), -PI, PI))
		s += float(c["amp"]) * exp(-pow(d / maxf(float(c["w"]) * 1.35, 0.07), 2.0))
	if state.phase == BioInteractionState.CONFIRMED:  # a wave runs along the membrane
		var k := clampf(state.phase_time / BioInteractionState.CONFIRM_SECONDS, 0.0, 1.0)
		s += 0.08 * (1.0 - k) * sin(theta * 5.0 - t * 12.0) * prefs.motion_scale()
	s *= 1.0 + _stretch * cos(2.0 * (theta - _move_angle))  # longer along the heading, narrower across it
	return s * _scale * _breath


# --- colour: a gradient through the cell, along every extension --------------------------------------------------------------

func _tone(c: Color) -> Color:
	var g := c.get_luminance()
	return c.lerp(Color(g, g, g, c.a), _grey)


## The colour at a distance d from the centre (1 = the resting rim): the core in the middle, the role's edge colour at the rim and,
## along an extension, a lighter fading tint towards the tip.
func _ramp(d: float) -> Color:
	var core: Color = role["core"]
	var edge: Color = role["edge"]
	var inverted := str(role["silhouette"]) == "disc"  # a biconcave cell is darker at the dimple and brighter at the thick rim
	var centre := core.lerp(Color.WHITE, 0.25 + _glow)
	var body := core
	if inverted:
		centre = edge.darkened(0.35)
		body = core.lerp(Color.WHITE, 0.1)
	var c: Color
	if d <= 0.55:
		c = centre.lerp(body, d / 0.55)
	elif d <= 1.0:
		c = body.lerp(edge, (d - 0.55) / 0.45)
	else:
		c = edge.lerp(role["tint"], clampf((d - 1.0) / 0.8, 0.0, 1.0))
	c.a = clampf(0.9 - 0.35 * maxf(0.0, d - 1.0), 0.35, 0.9)
	return _tone(c)


func _build_rim() -> void:
	var n := POINTS_FULL if lod >= 2 else POINTS_LIGHT
	_rim.resize(n)
	_rim_colors.resize(n)
	var r := radius_px
	var best := 0.0
	for i in n:
		var theta := TAU * i / n
		var f := _radius_factor(theta)
		_rim[i] = Vector2.from_angle(theta) * r * f
		_rim_colors[i] = _ramp(f)
		if f > best:
			best = f
			_tip = _rim[i]


func _fan(points: PackedVector2Array, centre: Color, colors: PackedColorArray) -> void:
	var n := points.size()
	for i in n:
		var j := (i + 1) % n
		draw_primitive(PackedVector2Array([Vector2.ZERO, points[i], points[j]]), PackedColorArray([centre, colors[i], colors[j]]), PackedVector2Array())


func _draw() -> void:
	if state == null:
		return
	var tint: Color = role["tint"]
	var r := radius_px
	if lod == 0:
		var pulse := 0.7 + 0.3 * sin(t * 3.0 + seed_angle)
		draw_circle(Vector2.ZERO, r * 0.45, BioArt.with_alpha(tint, 0.85 * pulse))
		if state.phase == BioInteractionState.HELP or state.phase == BioInteractionState.BLOCKED:
			draw_arc(Vector2.ZERO, r * (0.9 + 0.2 * pulse), 0.0, TAU, 20, BioArt.with_alpha(BioUi.WARN, 0.9), 2.0)
		return
	_build_rim()
	_things_around(tint, r)  # what is not the cell, under it
	draw_set_transform(_lean + _lag, 0.0, Vector2.ONE)  # the whole body has moved: leaning into the work, trailing its own movement
	# 1. the body: a fan from the centre; centre colour to a colour per rim point, so the gradient follows every extension
	_fan(_rim, _ramp(0.0), _rim_colors)
	# 2. a soft highlight inside, lighter and fading to nothing: depth without a texture
	var inner := PackedVector2Array()
	var inner_colors := PackedColorArray()
	for i in _rim.size():
		inner.append(_rim[i] * 0.62)
		inner_colors.append(Color(1, 1, 1, 0.0))
	_fan(inner, Color(1, 1, 1, 0.28 + 0.2 * _glow), inner_colors)
	# 3. the membrane line, in the colours of the rim
	var closed := _rim.duplicate()
	closed.append(_rim[0])
	var line_colors := PackedColorArray()
	for i in closed.size():
		var c: Color = _rim_colors[i % _rim_colors.size()].lightened(0.35)
		c.a = 0.95
		line_colors.append(c)
	draw_polyline_colors(closed, line_colors, 2.5 if lod >= 2 else 2.0, true)
	if lod >= 2:
		_inside(r)
	_gesture_traces(tint, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_phase_marks(tint, r)
	if thanks > 0.0:
		var u := 1.0 - thanks / 1.2
		for i in 2:
			draw_arc(Vector2.ZERO, r * (1.3 + (u + i * 0.25) * 1.2), -PI * 0.9, -PI * 0.1, 12, BioArt.with_alpha(BioUi.GOOD, 0.8 * thanks / 1.2), 2.5)


## Nucleus and organelles, each a small gradient of its own, so the cell reads as a body with an inside.
func _inside(r: float) -> void:
	var edge: Color = role["edge"]
	var core: Color = role["core"]
	var breathe := 1.0 + 0.05 * sin(t * 2.0 + seed_angle) * prefs.motion_scale()
	var count := 3 if str(role["silhouette"]) == "lobed" else 1
	for i in count:
		var at := Vector2.from_angle(seed_angle + t * 0.3 * prefs.motion_scale() + i * TAU / count) * r * (0.22 if count > 1 else 0.0) + facing * r * 0.06
		var nr := r * (0.17 if count > 1 else 0.3) * breathe
		var centre_color := _tone(BioArt.with_alpha(Color.WHITE.lerp(core, 0.35), 0.9))
		var rim_color := _tone(BioArt.with_alpha(edge.darkened(0.15), 0.85))
		for k in 20:
			var a0 := TAU * k / 20.0
			var a1 := TAU * (k + 1) / 20.0
			var p0 := at + Vector2.from_angle(a0) * nr * (1.0 + 0.1 * sin(a0 * 3.0 + seed_angle))
			var p1 := at + Vector2.from_angle(a1) * nr * (1.0 + 0.1 * sin(a1 * 3.0 + seed_angle))
			draw_primitive(PackedVector2Array([at, p0, p1]), PackedColorArray([centre_color, rim_color, rim_color]), PackedVector2Array())
	for i in 3:  # organelles
		var a2 := seed_angle * 1.7 + i * 2.1 + t * 0.15 * prefs.motion_scale()
		var o := Vector2.from_angle(a2) * r * (0.45 + 0.1 * sin(a2 * 3.0))
		draw_circle(o, r * 0.1, BioArt.with_alpha(edge, 0.3))
		draw_circle(o, r * 0.05, BioArt.with_alpha(core.lerp(Color.WHITE, 0.4), 0.6))


# --- what the cell holds or moves: seen through the membrane or leaving through its extensions -------------------------------

func _gesture_traces(tint: Color, r: float) -> void:
	if not state.is_working():
		return
	var p := state.progress
	var aim := target_dir
	var light: Color = (role["core"] as Color).lerp(Color.WHITE, 0.4)
	match state.gesture:
		"carry":  # oxygen rides inside; as the delivery advances the vesicles pass out through the pocket that grew towards the tissue
			var left := ceili(5.0 * (1.0 - p))
			for i in 5:
				var inside := Vector2.from_angle(t * 1.4 + i * TAU / 5.0) * r * 0.3
				if i < left:
					draw_circle(inside, r * 0.075, BioArt.with_alpha(Color(1.0, 0.9, 0.75), 0.95))
				else:
					var u := fposmod(t * 0.8 + i * 0.2, 1.0)
					draw_circle(inside.lerp(_tip, u), r * 0.065 * (1.0 - 0.4 * u), BioArt.with_alpha(light, 0.9 * (1.0 - u * 0.5)))
		"engulf":  # the target is closed on, shrinking; a vacuole forms inside
			draw_circle(facing * r * 1.55, r * 0.5 * (1.0 - 0.85 * p), Color(0.55, 0.45, 0.25, 0.6))
			draw_circle(facing * r * 0.1, r * (0.1 + 0.2 * p), Color(0.0, 0.0, 0.0, 0.3))
		"detox":
			for i in _count(6):
				var u := fposmod(t * 0.7 + i / 6.0, 1.0)
				var side := facing.orthogonal()
				draw_circle(side * r * (2.4 * (1.0 - u) + 0.3), r * 0.08, BioArt.with_alpha(BioArt.TOXIN, 0.8 * (1.0 - u * 0.4)))
				draw_circle(-side * r * (0.8 + 1.9 * u), r * 0.07, BioArt.with_alpha(Color(0.75, 0.95, 1.0), 0.7 * (1.0 - u)))
		"signal":
			for i in _count(4):
				var u := fposmod(t * 0.8 + i * 0.25, 1.0)
				draw_circle(_tip.lerp(aim * r * 3.6, u), r * 0.1 * (1.0 - 0.4 * u), BioArt.with_alpha(tint, 0.9 * (1.0 - u)))
			draw_arc(Vector2.ZERO, r * (1.9 + fposmod(t * 0.9, 1.0)), aim.angle() - 0.7, aim.angle() + 0.7, 10, BioArt.with_alpha(tint, 0.4), 2.0)
		"sample":  # what the dendrites touch travels back to the body through them
			for i in _count(7):
				var a := seed_angle + i * TAU / 7.0
				var u := fposmod(t * 0.9 + i / 7.0, 1.0)
				draw_circle(Vector2.from_angle(a) * r * (1.9 - 1.5 * u), r * 0.06, BioArt.with_alpha(Color.WHITE, 0.85 * u))
		"seal":
			_fibrin(r, p)
		"feed":  # the stem cells being fed light up as the work advances; vesicles run down the limbs to them
			for i in 3:
				var a := seed_angle + 0.5 + i * TAU / 3.0
				var stem := Vector2.from_angle(a) * r * 2.55
				draw_circle(stem, r * 0.28, BioArt.with_alpha(role["core"], 0.2 + 0.55 * p))
				draw_arc(stem, r * 0.28, 0.0, TAU, 14, BioArt.with_alpha(role["edge"], 0.8), 1.5)
				var u := fposmod(t * 0.9 + i / 3.0, 1.0)
				draw_circle(Vector2.from_angle(a) * r * 2.45 * u, r * 0.08, BioArt.with_alpha(Color(1.0, 0.9, 0.5), 0.9))
		"defend":
			draw_arc(Vector2.ZERO, TELEGRAPH_UNITS * BioArt.UNIT * (0.25 + 0.75 * (1.0 - p)), 0.0, TAU, 48, BioArt.with_alpha(tint, 0.35), 3.0)
			_telegraph(1.0 - p)
	if state.contact and state.gesture != "defend":
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(_tip, r * 0.08 + r * 0.05 * pulse * prefs.motion_scale(), BioArt.with_alpha(tint, 0.6))


func _things_around(tint: Color, r: float) -> void:
	if state.phase == BioInteractionState.ANTICIPATE and state.gesture == "defend":
		_telegraph((state.progress - BioInteractionState.ANTICIPATE_AT) / (1.0 - BioInteractionState.ANTICIPATE_AT))
	if state.phase == BioInteractionState.APPROACH or state.phase == BioInteractionState.ANTICIPATE:
		var back := -facing
		for i in _count(3):
			var off := back * r * (1.5 + i * 0.5) + back.orthogonal() * (i - 1) * r * 0.25
			draw_line(off, off + back * r * 0.5, BioArt.with_alpha(tint, 0.28 - i * 0.07), 2.0 * (1.0 - i * 0.2), true)  # the wake in the fluid


func _telegraph(k: float) -> void:
	draw_arc(Vector2.ZERO, TELEGRAPH_UNITS * BioArt.UNIT, 0.0, TAU, 48, BioArt.with_alpha(BioUi.WARN, 0.2 + 0.4 * clampf(k, 0.0, 1.0)), 2.0)


func _fibrin(r: float, p: float) -> void:
	var gap := target_dir * r * 2.6
	var side := target_dir.orthogonal() * r * 1.5
	draw_line(gap - side, gap + side, Color(0.1, 0.0, 0.0, 0.45), 4.0, true)  # the breach
	var layers := clampi(ceili(p * 5.0), 1, 5)  # the plug grows in layers, never in one flash
	for l in layers:
		var y := (float(l) / 4.0 - 0.5) * 2.0
		var a := gap + side * y
		for k in 3:
			var b := gap - side * y * 0.6 + target_dir.orthogonal() * (k - 1) * r * 0.5
			draw_line(a, b, BioArt.with_alpha(Color(1.0, 0.9, 0.85), 0.35 + 0.1 * l), 1.5, true)


func _phase_marks(tint: Color, r: float) -> void:
	match state.phase:
		BioInteractionState.NOTICE:
			var a := t * 2.4 + seed_angle
			draw_circle(Vector2.from_angle(a) * r * 1.5, r * 0.08, BioArt.with_alpha(tint, 0.9))
		BioInteractionState.BLOCKED, BioInteractionState.HELP:
			var a1 := target_dir * r * 2.0
			var b := target_dir * r * 3.3
			draw_dashed_line(a1, a1.lerp(b, 0.4), BioArt.with_alpha(tint, 0.5), 2.0, 5.0)  # the vessel ahead, broken
			draw_dashed_line(a1.lerp(b, 0.7), b, BioArt.with_alpha(tint, 0.3), 2.0, 5.0)
			var c := a1.lerp(b, 0.55)
			var s := r * 0.2
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), BioArt.with_alpha(BioUi.BAD, 0.9), 2.5, true)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), BioArt.with_alpha(BioUi.BAD, 0.9), 2.5, true)
			if state.phase == BioInteractionState.HELP:  # a chemical call, spreading towards whoever could answer
				var base := target_dir.angle()
				for i in _count(3):
					var u := fposmod(t * 0.7 + i / 3.0, 1.0)
					draw_arc(Vector2.ZERO, r * (1.6 + 1.8 * u), base - 0.9, base + 0.9, 12, BioArt.with_alpha(BioUi.WARN, 0.7 * (1.0 - u)), 2.5)
		BioInteractionState.CONFIRMED:
			var k := clampf(state.phase_time / BioInteractionState.CONFIRM_SECONDS, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			draw_arc(Vector2.ZERO, r * (1.5 + 1.4 * e * prefs.motion_scale()), 0.0, TAU, 36, BioArt.with_alpha(BioUi.GOOD, 0.7 * (1.0 - k)), 2.5)
		BioInteractionState.CANCEL:
			var k2 := clampf(state.phase_time / BioInteractionState.CANCEL_SECONDS, 0.0, 1.0)
			for i in 4:
				var a2 := i * TAU / 4.0 + 0.3
				draw_arc(Vector2.ZERO, r * (1.45 - 0.15 * k2), a2, a2 + 0.8, 8, BioArt.with_alpha(BioUi.BAD, 0.6 * (1.0 - k2)), 2.0)
