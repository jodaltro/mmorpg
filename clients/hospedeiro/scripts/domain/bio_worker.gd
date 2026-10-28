class_name BioWorker
extends RefCounted
## One cell of a cohort at work: it wanders in its organ, goes to what it works on, works on it for a moment and says so. Pure: the
## world hands it the place of its target and the current, and it answers with where it is and when the work is done.

const WORK_SECONDS := 0.9
const CONTACT := 0.9  # units: this close to the target is work
const EDGE := 0.82  # of the organ's radius: it turns back before the wall

var cohort := ""
var role := ""
var spec: Dictionary = {}
var pos := Vector2.ZERO  # pixels
var vel := Vector2.ZERO
var state := &"wander"  # wander | seek | work
var work := 0.0  # 0..1 of the work in progress
var aim := Vector2.DOWN
var seed_value := 0.0
var say := ""  # the balloon the cell shows now, and for how long
var say_left := 0.0
var say_in := 0.0

var _wander_to := Vector2.ZERO
var _wander_left := 0.0


func _init(p_cohort: String, p_role: String, at: Vector2, p_seed: float) -> void:
	cohort = p_cohort
	role = p_role
	spec = BioWorkerRoles.spec(p_role)
	pos = at
	seed_value = p_seed
	say_in = 3.0 + fmod(p_seed * 5.0, 6.0)
	_wander_to = at


## Advances by `delta`. `center` and `radius` are the organ's (px); `target` is a point or null; `flow` is the current there (px/s).
## Returns "done" on the step the work on the target is finished.
func step(delta: float, center: Vector2, radius: float, target: Variant, flow: Vector2) -> String:
	var unit := BioArt.UNIT
	var speed: float = float(spec["speed"]) * unit
	var mode: StringName = spec["mode"]
	var event := ""
	var want := Vector2.ZERO
	if mode == BioWorkerRoles.FLOW:
		want = flow + Vector2.from_angle(seed_value * 3.0 + Time.get_ticks_msec() * 0.0004) * 0.25 * speed
		state = &"wander"
	elif target != null:
		var to: Vector2 = (target as Vector2) - pos
		aim = to.normalized() if to.length() > 1.0 else aim
		if to.length() <= CONTACT * unit:
			state = &"work"
			work += delta / WORK_SECONDS
			want = Vector2.ZERO
			if work >= 1.0:
				work = 0.0
				event = "done"
		else:
			state = &"seek"
			work = 0.0
			want = to.normalized() * speed
	else:
		state = &"wander"
		work = 0.0
		_wander_left -= delta
		if _wander_left <= 0.0 or pos.distance_to(_wander_to) < unit:
			_wander_left = 2.0 + fmod(seed_value * 7.0, 2.5)
			var a := seed_value * 11.0 + Time.get_ticks_msec() * 0.0007
			_wander_to = center + Vector2.from_angle(a) * radius * 0.6 * fposmod(seed_value * 3.1, 1.0)
		want = (_wander_to - pos).normalized() * speed * 0.45
	var from_center := pos - center
	if from_center.length() > radius * EDGE:  # never through the wall
		want = -from_center.normalized() * speed
	vel = vel.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	pos += vel * delta
	return event
