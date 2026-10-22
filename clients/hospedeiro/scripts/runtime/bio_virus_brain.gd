class_name BioVirusBrain
extends Node
## Readable lunge pattern: stalk, glow red (telegraph), commit to a straight lunge, then recover and be punishable.

enum State { WANDER, CHASE, TELEGRAPH, LUNGE, RECOVER }

var aggro_range_units := 9.0
var lunge_range_units := 4.2
var telegraph_seconds := 0.65
var recover_seconds := 1.1
var state: int = State.WANDER

var _host: BioCellActor
var _executor: BioAttackExecutor
var _body: BioCellBody
var _prey: BioCellActor
var _state_until := 0.0
var _wander_until := 0.0
var _wander_direction := Vector2.RIGHT


func configure(host: BioCellActor, executor: BioAttackExecutor, body: BioCellBody, prey: BioCellActor) -> void:
	_host = host
	_executor = executor
	_body = body
	_prey = prey


func set_prey(prey: BioCellActor) -> void:
	_prey = prey


func state_name() -> String:
	return State.keys()[state]


func _process(_delta: float) -> void:
	if _host == null:
		return
	var actor := _host.combatant.actor
	if not actor.vitals.is_alive():
		_host.set_intent(Vector2.ZERO)
		_body.set_telegraph(0.0)
		return
	var now := BioClock.now()
	var has_prey := is_instance_valid(_prey) and _prey.is_active() and _prey.combatant.actor.vitals.is_alive()
	var to_prey := _prey.global_position - _host.global_position if has_prey else Vector2.ZERO
	var dist := to_prey.length() / BioArt.UNIT

	match state:
		State.WANDER:
			if now >= _wander_until:
				_wander_until = now + randf_range(2.0, 4.0)
				_wander_direction = Vector2.from_angle(randf() * TAU)
			_host.set_intent(_wander_direction * 0.35)
			if has_prey and dist < aggro_range_units:
				state = State.CHASE
		State.CHASE:
			if not has_prey or dist > aggro_range_units * 1.4:
				state = State.WANDER
				return
			_host.set_intent(to_prey.normalized() * 0.8)
			if dist <= lunge_range_units and actor.cooldown_remaining(BioAttackCatalog.VIRAL_LUNGE, now) <= 0.0:
				state = State.TELEGRAPH
				_state_until = now + telegraph_seconds
		State.TELEGRAPH:
			_host.set_intent(Vector2.ZERO)
			_body.set_telegraph(1.0 - clampf((_state_until - now) / telegraph_seconds, 0.0, 1.0))
			if now >= _state_until:
				_body.set_telegraph(0.0)
				var dir := to_prey if has_prey else Vector2.RIGHT
				if _executor.perform(BioAttackCatalog.VIRAL_LUNGE, dir) == BioActor.AttackStatus.STARTED:
					state = State.LUNGE
					_state_until = now + 0.35
				else:
					state = State.CHASE
		State.LUNGE:
			if now >= _state_until:
				state = State.RECOVER
				_state_until = now + recover_seconds
				_host.set_intent(Vector2.ZERO)
		State.RECOVER:
			_host.set_intent(Vector2.ZERO)
			if now >= _state_until:
				state = State.CHASE
