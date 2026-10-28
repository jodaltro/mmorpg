class_name BioNpcFx
extends Node2D
## The body language of a named cell, drawn procedurally over its membrane: a silhouette per role and a gesture per kind of work,
## laid out as notice → approach → anticipate → act → contact → progress → confirmed / cancel → recover. Everything here is a pure
## function of the interaction state and time, so nothing is stored per effect (no particle nodes), a late or repeated view replays
## nothing, and the effects never touch a collider or a fact. `lod`: 0 a pulsing dot, 1 silhouette and a simple gesture, 2 everything.

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


func _count(n: int) -> int:
	return maxi(1, roundi(n * prefs.fx_scale()))


func _sway(speed: float, amount: float) -> float:
	return sin(t * speed) * amount * prefs.motion_scale()


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
	if lod == 1:  # no deformable membrane here: a plain body, so the cell still reads at a distance
		draw_circle(Vector2.ZERO, r * 0.95, BioArt.with_alpha(role["core"], 0.22))
		draw_arc(Vector2.ZERO, r * 0.95, 0.0, TAU, 20, BioArt.with_alpha(role["edge"], 0.85), 2.5)
		draw_circle(Vector2.ZERO, r * 0.28, BioArt.with_alpha(role["core"], 0.9))
	_silhouette(tint, r)
	match state.phase:
		BioInteractionState.NOTICE:
			var a := t * 2.4 + seed_angle
			draw_circle(Vector2.from_angle(a) * r * 1.35, r * 0.1, BioArt.with_alpha(tint, 0.9))
			draw_arc(Vector2.ZERO, r * 1.2, a - 0.8, a + 0.8, 10, BioArt.with_alpha(tint, 0.35), 2.0)
		BioInteractionState.APPROACH:
			_wake(tint, r)
		BioInteractionState.ANTICIPATE:
			_wake(tint, r)
			_anticipate(tint, r)
		BioInteractionState.ACT, BioInteractionState.PROGRESS:
			_work(tint, r)
		BioInteractionState.BLOCKED:
			_blocked(tint, r)
		BioInteractionState.HELP:
			_help(tint, r)
		BioInteractionState.CONFIRMED:
			_confirmed(tint, r)
		BioInteractionState.CANCEL:
			_cancelled(r)
		BioInteractionState.RECOVER:
			var k := 1.0 - state.phase_time / BioInteractionState.RECOVER_SECONDS
			draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 28, BioArt.with_alpha(tint, 0.25 * k), 2.0)
	if thanks > 0.0:
		var u := 1.0 - thanks / 1.2
		for i in 2:
			draw_arc(Vector2.ZERO, r * (1.2 + (u + i * 0.25) * 1.2), -PI * 0.9, -PI * 0.1, 12, BioArt.with_alpha(BioUi.GOOD, 0.8 * thanks / 1.2), 2.5)


# --- silhouettes: what the cell is, before what it does ---------------------------------------------------------------------

func _silhouette(tint: Color, r: float) -> void:
	var sil := str(role["silhouette"])
	var near := lod >= 2
	match sil:
		"disc":  # biconcave: a dimple and a bright rim
			draw_circle(Vector2.ZERO, r * 0.42, Color(0.1, 0.0, 0.03, 0.32))
			draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 32, BioArt.with_alpha(tint, 0.55), 2.0)
		"lobed":  # a multilobed nucleus and granules
			for i in 3:
				var a := seed_angle + t * 0.35 * prefs.motion_scale() + i * TAU / 3.0
				draw_circle(Vector2.from_angle(a) * r * 0.3, r * 0.21, Color(0.42, 0.45, 0.95, 0.8))
			if near:
				for i in 10:
					draw_circle(Vector2.from_angle(i * TAU / 10.0 + seed_angle) * r * 0.66, r * 0.05, Color(1, 1, 1, 0.55))
		"pseudo":  # pseudopods that reach, vacuoles that fill
			var reach := 0.14 + (0.34 * state.progress if state.gesture == "engulf" and state.is_working() else 0.0)
			for i in 4:
				var a := seed_angle + i * TAU / 4.0 + _sway(0.8 + i * 0.2, 0.3)
				if state.gesture == "engulf" and state.is_working():
					a = lerp_angle(a, facing.angle(), 0.45)
				var tip := Vector2.from_angle(a) * r * (1.0 + reach + 0.06 * sin(t * 1.3 + i))
				draw_line(Vector2.from_angle(a) * r * 0.7, tip, BioArt.with_alpha(tint, 0.5), r * 0.34, true)
				draw_circle(tip, r * 0.17, BioArt.with_alpha(tint, 0.62))
			if near:
				for i in 3:
					draw_circle(Vector2.from_angle(seed_angle + i * 2.1) * r * 0.3, r * (0.14 + 0.08 * (state.progress if state.gesture == "engulf" else 0.0)), Color(0.0, 0.0, 0.0, 0.28))
		"branch":  # dendrites that feel the medium
			var n := 7
			var extend := 1.5 + (0.45 if state.is_working() else 0.0)
			for i in n:
				var a := seed_angle + i * TAU / n + _sway(1.3 + i * 0.17, 0.35)
				var mid := Vector2.from_angle(a) * r * 1.0
				var tip := mid + Vector2.from_angle(a + _sway(2.0, 0.5)) * r * (extend - 1.0)
				draw_line(Vector2.from_angle(a) * r * 0.6, mid, BioArt.with_alpha(tint, 0.55), 2.0, true)
				draw_line(mid, tip, BioArt.with_alpha(tint, 0.45), 1.5, true)
				draw_circle(tip, r * 0.07, BioArt.with_alpha(tint, 0.9))
		"cluster":  # platelets stay together
			for i in 2:
				var a := seed_angle + t * (0.9 + i * 0.3) * prefs.motion_scale() + i * PI
				var p := Vector2.from_angle(a) * r * (1.15 + 0.1 * i)
				draw_circle(p, r * 0.5, BioArt.with_alpha(tint, 0.55))
				draw_arc(p, r * 0.5, 0.0, TAU, 14, BioArt.with_alpha(role["edge"], 0.8), 1.5)
		"star":  # a stellate sinusoid cell
			for i in 5:
				var a := seed_angle + i * TAU / 5.0 + _sway(0.9 + i * 0.1, 0.15)
				draw_line(Vector2.from_angle(a) * r * 0.7, Vector2.from_angle(a) * r * 1.5, BioArt.with_alpha(tint, 0.6), r * 0.2, true)
				draw_circle(Vector2.from_angle(a) * r * 1.5, r * 0.1, BioArt.with_alpha(tint, 0.85))
		"anchor":  # stroma holding on to the matrix
			for i in 3:
				var a := PI * 0.5 + (i - 1) * 0.7
				draw_line(Vector2.from_angle(a) * r * 0.8, Vector2.from_angle(a) * r * 1.7, BioArt.with_alpha(tint, 0.5), 3.0, true)
				draw_circle(Vector2.from_angle(a) * r * 1.7, r * 0.1, BioArt.with_alpha(tint, 0.7))


# --- gestures -----------------------------------------------------------------------------------------------------------------

func _wake(tint: Color, r: float) -> void:
	var back := -facing
	for i in _count(3):
		var off := back * r * (1.15 + i * 0.5) + back.orthogonal() * (i - 1) * r * 0.25
		draw_line(off, off + back * r * 0.55, BioArt.with_alpha(tint, 0.3 - i * 0.07), 2.0 * (1.0 - i * 0.2), true)


func _anticipate(tint: Color, r: float) -> void:
	# A short contraction before the work: readable, never long (the leg is only a few seconds).
	var k := clampf((state.progress - BioInteractionState.ANTICIPATE_AT) / (1.0 - BioInteractionState.ANTICIPATE_AT), 0.0, 1.0)
	draw_arc(Vector2.ZERO, r * (1.5 - 0.45 * k), 0.0, TAU, 28, BioArt.with_alpha(tint, 0.2 + 0.45 * k), 2.0)
	if state.gesture == "defend":
		_telegraph(k)


func _telegraph(k: float) -> void:
	var reach := TELEGRAPH_UNITS * BioArt.UNIT
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, BioArt.with_alpha(BioUi.WARN, 0.2 + 0.4 * k), 2.0)


func _work(tint: Color, r: float) -> void:
	var p := state.progress
	var touch_point := target_dir * r * 2.2
	match state.gesture:
		"carry":
			_vesicles(tint, r, touch_point, p)
		"patrol":
			var a := facing.angle() + _sway(1.6, 0.9)
			var tip := Vector2.from_angle(a) * r * 3.4
			draw_line(Vector2.from_angle(a) * r, tip, BioArt.with_alpha(tint, 0.35), 3.0, true)
			draw_arc(Vector2.ZERO, r * 3.4, a - 0.28, a + 0.28, 10, BioArt.with_alpha(tint, 0.22), 6.0)
		"defend":
			_telegraph(1.0 - p)
			var reach := TELEGRAPH_UNITS * BioArt.UNIT * (0.25 + 0.75 * (1.0 - p))  # the threat recedes as the load falls
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, BioArt.with_alpha(tint, 0.35), 3.0)
			for i in _count(8):
				var a := i * TAU / 8.0 + seed_angle
				draw_line(Vector2.from_angle(a) * r * 0.9, Vector2.from_angle(a) * r * (1.35 + _sway(5.0, 0.1)), BioArt.with_alpha(tint, 0.85), 2.5, true)
		"engulf":
			var target := facing * r * 1.9
			var debris := r * 0.5 * (1.0 - 0.85 * p)
			draw_circle(target, debris, Color(0.55, 0.45, 0.25, 0.55))
			var spread := lerpf(1.25, 0.25, p)
			for side: float in [-1.0, 1.0]:
				var a0 := facing.angle() + side * spread
				var from := Vector2.from_angle(facing.angle() + side * 0.9) * r * 0.9
				draw_line(from, target + Vector2.from_angle(a0 + PI) * debris * 1.3, BioArt.with_alpha(tint, 0.6), r * 0.3, true)
		"detox":
			for i in _count(6):
				var u := fposmod(t * 0.7 + i / 6.0, 1.0)
				var side := facing.orthogonal()
				var inbound := side * r * (2.6 * (1.0 - u)) + facing * r * (0.4 * sin(i * 2.0))
				draw_circle(inbound, r * 0.09, BioArt.with_alpha(BioArt.TOXIN, 0.8 * (1.0 - u * 0.4)))
				var outbound := -side * r * (0.9 + 2.0 * u) + facing * r * (0.3 * sin(i * 2.0))
				draw_circle(outbound, r * 0.08, BioArt.with_alpha(Color(0.75, 0.95, 1.0), 0.7 * (1.0 - u)))
		"signal":
			for i in _count(4):
				var u := fposmod(t * 0.8 + i * 0.25, 1.0)
				draw_circle(target_dir * r * (1.2 + 2.4 * u), r * 0.1 * (1.0 - 0.4 * u), BioArt.with_alpha(tint, 0.9 * (1.0 - u)))
			draw_arc(Vector2.ZERO, r * (1.2 + fposmod(t * 0.9, 1.0)), target_dir.angle() - 0.7, target_dir.angle() + 0.7, 10, BioArt.with_alpha(tint, 0.4), 2.0)
		"sample":
			for i in _count(7):
				var a := seed_angle + i * TAU / 7.0
				var u := fposmod(t * 0.9 + i / 7.0, 1.0)
				draw_circle(Vector2.from_angle(a) * r * (2.0 - 1.4 * u), r * 0.07, BioArt.with_alpha(Color(1, 1, 1), 0.85 * u))
		"seal":
			_fibrin(tint, r, p)
		_:
			draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 24, BioArt.with_alpha(tint, 0.3), 2.0)
	if state.contact:
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(touch_point, r * 0.1 + r * 0.06 * pulse * prefs.motion_scale(), BioArt.with_alpha(tint, 0.55))


func _vesicles(tint: Color, r: float, touch_point: Vector2, p: float) -> void:
	# Oxygen rides inside the cell and passes through a capillary link into the tissue as the delivery advances.
	var load_left := ceili(5.0 * (1.0 - p))
	for i in 5:
		var inside := Vector2.from_angle(t * 1.4 + i * TAU / 5.0) * r * 0.28
		if i < load_left:
			draw_circle(inside, r * 0.075, BioArt.with_alpha(Color(1.0, 0.85, 0.7), 0.9))
		else:
			var u := fposmod(t * 0.8 + i * 0.2, 1.0)
			draw_circle(inside.lerp(touch_point, u), r * 0.06, BioArt.with_alpha(tint, 0.85 * (1.0 - u)))
	draw_dashed_line(Vector2.ZERO, touch_point, BioArt.with_alpha(tint, 0.4), 2.0, 6.0)
	draw_circle(touch_point, r * (0.2 + 0.5 * p), BioArt.with_alpha(tint, 0.18 + 0.2 * p))


func _fibrin(tint: Color, r: float, p: float) -> void:
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
	draw_line(Vector2.ZERO, gap, BioArt.with_alpha(tint, 0.25), 2.0, true)


func _blocked(tint: Color, r: float) -> void:
	# The way is shut: the vessel ahead is drawn broken, and the cell shakes a little, looking for another.
	var a := target_dir * r * 1.2
	var b := target_dir * r * 2.6
	draw_dashed_line(a, a.lerp(b, 0.4), BioArt.with_alpha(tint, 0.5), 2.0, 5.0)
	draw_dashed_line(a.lerp(b, 0.7), b, BioArt.with_alpha(tint, 0.3), 2.0, 5.0)
	var c := a.lerp(b, 0.55)
	var s := r * 0.2
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), BioArt.with_alpha(BioUi.BAD, 0.9), 2.5, true)
	draw_line(c + Vector2(-s, s), c + Vector2(s, -s), BioArt.with_alpha(BioUi.BAD, 0.9), 2.5, true)


func _help(tint: Color, r: float) -> void:
	# A chemical call towards whoever could answer: arcs that spread, not a permanent mark.
	_blocked(tint, r)
	var base := target_dir.angle()
	for i in _count(3):
		var u := fposmod(t * 0.7 + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, r * (1.3 + 1.8 * u), base - 0.9, base + 0.9, 12, BioArt.with_alpha(BioUi.WARN, 0.7 * (1.0 - u)), 2.5)


func _confirmed(tint: Color, r: float) -> void:
	var k := clampf(state.phase_time / BioInteractionState.CONFIRM_SECONDS, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	if not prefs.reduce_flash:
		draw_circle(Vector2.ZERO, r * (0.9 + 0.5 * e), BioArt.with_alpha(tint, 0.22 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r * (1.0 + 1.6 * e * prefs.motion_scale() + 0.4 * (1.0 - prefs.motion_scale())), 0.0, TAU, 36, BioArt.with_alpha(BioUi.GOOD, 0.85 * (1.0 - k)), 3.0)
	for i in _count(6):
		var a := i * TAU / 6.0 + seed_angle
		draw_line(Vector2.from_angle(a) * r * (1.1 + 0.8 * e), Vector2.from_angle(a) * r * (1.3 + 1.2 * e), BioArt.with_alpha(BioUi.GOOD, 0.8 * (1.0 - k)), 2.0, true)


func _cancelled(r: float) -> void:
	var k := clampf(state.phase_time / BioInteractionState.CANCEL_SECONDS, 0.0, 1.0)
	for i in 4:
		var a := i * TAU / 4.0 + 0.3
		draw_arc(Vector2.ZERO, r * (1.2 - 0.15 * k), a, a + 0.9, 8, BioArt.with_alpha(BioUi.BAD, 0.7 * (1.0 - k)), 2.5)
