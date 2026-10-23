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


## Instant velocity change in world units per second.
func apply_impulse(units_per_second: Vector2) -> void:
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
	if is_dashing():
		velocity = _dash_velocity
	else:
		var speed_stat := combatant.actor.stat(BioGene.SPEED) * combatant.speed_mult() * (_slow_factor if BioClock.now() < _slow_until else 1.0)
		velocity += intent * thrust_units * speed_stat * BioArt.UNIT * delta
		velocity -= velocity * minf(1.0, damping * delta)
		var cap := max_speed_units * speed_stat * BioArt.UNIT
		if velocity.length() > cap:
			velocity = velocity.move_toward(velocity.normalized() * cap, 60.0 * BioArt.UNIT * delta)
	move_and_slide()
