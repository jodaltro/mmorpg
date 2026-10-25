class_name BioCellActor
extends CharacterBody2D
## Physical body of a cell: thrust, drag, dash and knockback. Collision layer 1 = combatants, 4 = walls.

const LAYER_COMBATANT := 1
const LAYER_WALL := 4

var combatant: BioCombatant
var thrust_units := 42.0
var max_speed_units := 7.0
var damping := 3.5
var intent := Vector2.ZERO
var _slow_until := 0.0
var _slow_factor := 1.0

var _dash_until := 0.0
var _dash_velocity := Vector2.ZERO

## Rolling (the eosinophil curled into a ball): it keeps its speed, bounces off walls and bodies and can be steered a little.
signal bumped(collider: Object, normal: Vector2)
var _ghost_until := 0.0
var _roll_until := 0.0
var _roll_velocity := Vector2.ZERO
var _roll_steer := 0.0


func _init() -> void:
	collision_layer = LAYER_COMBATANT
	collision_mask = LAYER_COMBATANT | LAYER_WALL
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func is_dashing() -> bool:
	return BioClock.now() < _dash_until


func set_intent(value: Vector2) -> void:
	intent = value.limit_length(1.0)


func dash(direction: Vector2, distance_units: float, duration: float = 0.18) -> void:
	if direction.length_squared() < 1e-4:
		return
	_dash_velocity = direction.normalized() * distance_units * BioArt.UNIT / duration
	_dash_until = BioClock.now() + duration


## Curls into a ball for `seconds`: it flies at `speed_units` and bounces; `steer` is how fast the aim can turn it (radians per second).
func roll(direction: Vector2, speed_units: float, seconds: float, steer: float) -> void:
	if direction.length_squared() < 1e-4:
		return
	_roll_velocity = direction.normalized() * speed_units * BioArt.UNIT
	_roll_until = BioClock.now() + seconds
	_roll_steer = steer


func is_rolling() -> bool:
	return BioClock.now() < _roll_until


func end_roll() -> void:
	if is_rolling():
		velocity = _roll_velocity * 0.35
	_roll_until = 0.0


## Passes through bodies (not walls) for `seconds`: it is not there for the other cells, which cannot stop it, push it or hit it.
func ghost(seconds: float) -> void:
	_ghost_until = maxf(_ghost_until, BioClock.now() + seconds)


func is_ghost() -> bool:
	return BioClock.now() < _ghost_until


## Stops a dash or a lunge in its tracks.
func cancel_dash() -> void:
	_dash_until = 0.0


## Whoever hunts this cell (an enemy's brain) hunts `prey` instead, e.g. a decoy.
func retarget(prey: BioCellActor) -> void:
	for child in get_children():
		if child.has_method("set_prey"):
			child.call("set_prey", prey)


## Instant velocity change in world units per second.
func apply_impulse(units_per_second: Vector2) -> void:
	if has_meta("training"): return
	velocity += units_per_second * BioArt.UNIT


## Ability effect: movement multiplied by `factor` for `seconds` (nets, fever, opsonisation).
func slow(factor: float, seconds: float) -> void:
	_slow_factor = factor
	_slow_until = BioClock.now() + seconds


func is_slowed() -> bool:
	return BioClock.now() < _slow_until


func set_active(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	collision_layer = LAYER_COMBATANT if on else 0
	collision_mask = (LAYER_COMBATANT | LAYER_WALL) if on else 0


func is_active() -> bool:
	return visible


func _physics_process(delta: float) -> void:
	var previous := global_position
	if is_active():  # a ghost is not there for the other cells: they neither block it nor are pushed by it, nor can they hit it
		collision_layer = 0 if is_ghost() else LAYER_COMBATANT
		collision_mask = LAYER_WALL if is_ghost() else (LAYER_COMBATANT | LAYER_WALL)
	if is_rolling():
		if intent.length_squared() > 0.01:
			var turn := _roll_velocity.angle_to(intent)
			_roll_velocity = _roll_velocity.rotated(clampf(turn, -_roll_steer * delta, _roll_steer * delta))
		velocity = _roll_velocity
		var crash := move_and_collide(velocity * delta)
		if crash != null:
			var normal := crash.get_normal()
			_roll_velocity = _roll_velocity.bounce(normal)
			bumped.emit(crash.get_collider(), normal)
		_respect_sanctuary(previous)
		return
	if combatant != null and combatant.is_stunned():  # asleep or in a crystal: it only drifts to a halt
		_dash_until = 0.0
		velocity -= velocity * minf(1.0, damping * 2.0 * delta)
		move_and_slide()
		_respect_sanctuary(previous)
		return
	if is_dashing():
		velocity = _dash_velocity
	else:
		var speed_stat := combatant.actor.stat(BioGene.SPEED) * combatant.speed_mult() * (_slow_factor if BioClock.now() < _slow_until else 1.0)
		velocity = BioMovementModel.step(velocity, intent, delta, thrust_units, max_speed_units, damping, speed_stat, BioArt.UNIT)
	move_and_slide()
	_respect_sanctuary(previous)


func _respect_sanctuary(previous: Vector2) -> void:
	if has_meta("sanctuary_bound") and BioSanctuary.contains(BioBodyMap.seed_value, global_position / BioArt.UNIT):
		global_position = previous
		velocity = Vector2.ZERO
		_dash_until = 0
		_roll_until = 0
