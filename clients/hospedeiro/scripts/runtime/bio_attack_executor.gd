class_name BioAttackExecutor
extends Node
## Turns an attack intent into physics queries. Cost, cooldown and damage are validated by the domain actor.

signal performed(attack_id: StringName, direction: Vector2)

## Default arc of the basic lash; the player's body narrows or widens it (a lance, a macrophage's arm).
const LASH_HALF_ANGLE := 75.0

var lash_half_angle := LASH_HALF_ANGLE
var half_angle_source: Callable  # optional: asks the body how wide its lash is

var _combatant: BioCombatant
var _host: BioCellActor
var _contact_def: BioAttackDef
var _contact_until := 0.0
var _contact_hits := {}


func configure(combatant: BioCombatant, host: BioCellActor) -> void:
	_combatant = combatant
	_host = host


func perform(id: StringName, aim: Vector2) -> int:
	if aim.length_squared() < 1e-4:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	var status := _combatant.actor.try_begin_attack(id, BioClock.now())
	if status != BioActor.AttackStatus.STARTED:
		return status
	if id == BioAttackCatalog.FLAGELLUM_LASH and half_angle_source.is_valid():
		lash_half_angle = half_angle_source.call()
	var def := _combatant.actor.attack_def(id)
	var origin := _host.global_position
	match id:
		BioAttackCatalog.FLAGELLUM_LASH:
			_do_lash(def, origin, aim)
		BioAttackCatalog.TOXIN_SPIT:
			var muzzle := origin + aim * 0.7 * BioArt.UNIT
			BioFactory.spawn_projectile(_host.get_parent(), _combatant, def, muzzle, aim)
			BioFx.burst(muzzle, BioArt.TOXIN, 5, 2.0, 0.25, 0.35)
		BioAttackCatalog.MEMBRANE_DASH:
			_host.dash(aim, def.range_units)
			BioFx.ring(origin, 0.5, BioArt.DEEP_BLUE)
		BioAttackCatalog.VIRAL_LUNGE:
			_host.dash(aim, def.range_units, 0.28)
			_contact_def = def
			_contact_until = BioClock.now() + 0.32
			_contact_hits.clear()
	performed.emit(id, aim)
	return status


func _physics_process(_delta: float) -> void:
	if BioClock.now() >= _contact_until:
		return
	for hit in _overlap(_host.global_position, 0.75 * BioArt.UNIT):
		_try_hit(hit, _contact_def, _host.global_position, _contact_hits)


func _do_lash(def: BioAttackDef, origin: Vector2, aim: Vector2) -> void:
	var seen := {}
	for collider in _overlap(origin, (def.range_units + 0.6) * BioArt.UNIT):
		var to: Vector2 = collider.global_position - origin
		var reach := to.length() - 0.5 * BioArt.UNIT
		if reach > def.range_units * BioArt.UNIT:
			continue
		if rad_to_deg(absf(aim.angle_to(to))) > lash_half_angle:
			continue
		_try_hit(collider, def, origin, seen)


func _overlap(point: Vector2, radius: float) -> Array:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = BioCellActor.LAYER_COMBATANT
	var found: Array = []
	for result in _host.get_world_2d().direct_space_state.intersect_shape(query, 32):
		found.append(result["collider"])
	return found


func _try_hit(collider: Object, def: BioAttackDef, from: Vector2, seen: Dictionary) -> void:
	var target := collider as BioCellActor
	if target == null or target == _host or seen.has(target):
		return
	seen[target] = true
	if not BioCombatRules.can_hit(_combatant.actor, target.combatant.actor):
		return
	var result := target.combatant.receive_hit(_combatant, def)
	if result.outcome != BioActor.HitOutcome.HIT and result.outcome != BioActor.HitOutcome.KILLED:
		return
	if def.knockback > 0.0:
		target.apply_impulse((target.global_position - from).normalized() * def.knockback)
