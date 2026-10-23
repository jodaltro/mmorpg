class_name BioRangedBrain
extends Node
## A spitter: it keeps its distance (backs off when you come close, closes in when you are far), glows, and throws a projectile at you.
## It is fragile up close, so the way to beat it is to cross the room, or to break its line with a pillar.

enum State { WANDER, KEEP, TELEGRAPH, RECOVER }

var aggro_range_units := 13.0
var lunge_range_units := 8.0  # how far it shoots
var telegraph_seconds := 0.7
var recover_seconds := 1.4
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
			_host.set_intent(_wander_direction * 0.3)
			if has_prey and dist < aggro_range_units:
				state = State.KEEP
		State.KEEP:
			if not has_prey or dist > aggro_range_units * 1.5:
				state = State.WANDER
				return
			var preferred := lunge_range_units * 0.7
			if dist < preferred - 1.5:
				_host.set_intent(-to_prey.normalized() * 0.9)  # too close: back away
			elif dist > preferred + 1.5:
				_host.set_intent(to_prey.normalized() * 0.7)
			else:
				_host.set_intent(to_prey.normalized().orthogonal() * 0.35)  # circle at a distance
			if dist <= lunge_range_units and actor.cooldown_remaining(BioAttackCatalog.ENEMY_SPIT, now) <= 0.0:
				state = State.TELEGRAPH
				_state_until = now + telegraph_seconds
		State.TELEGRAPH:
			_host.set_intent(Vector2.ZERO)
			_body.set_telegraph(1.0 - clampf((_state_until - now) / telegraph_seconds, 0.0, 1.0))
			if now >= _state_until:
				_body.set_telegraph(0.0)
				var dir := to_prey if has_prey else Vector2.RIGHT
				if _executor.perform(BioAttackCatalog.ENEMY_SPIT, dir) == BioActor.AttackStatus.STARTED:
					state = State.RECOVER
					_state_until = now + recover_seconds * 0.6
				else:
					state = State.KEEP
		State.RECOVER:
			_host.set_intent(Vector2.ZERO)
			if now >= _state_until:
				state = State.KEEP
