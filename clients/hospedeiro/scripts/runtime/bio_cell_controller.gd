class_name BioCellController
extends Node
## Player intents (move, aim, lash, spit, dash). Input devices and tests both drive this same surface.

const MAGNET_RADIUS_UNITS := 2.6

var aim := Vector2.RIGHT
var auto_target: BioCellActor
var manual_aim := false
var network_attack: Callable

var _host: BioCellActor
var _executor: BioAttackExecutor


func configure(host: BioCellActor, executor: BioAttackExecutor) -> void:
	_host = host
	_executor = executor


func move(direction: Vector2) -> void:
	_host.set_intent(direction if _host.combatant.actor.vitals.is_alive() else Vector2.ZERO)


func set_aim(direction: Vector2, manual: bool = true) -> void:
	if direction.length_squared() > 0.01:
		aim = direction.normalized()
		manual_aim = manual


func auto_aim(radius_units: float = 13.0) -> Vector2:
	var radius_squared := pow(radius_units * BioArt.UNIT, 2)
	if not is_instance_valid(auto_target) or not _valid_target(auto_target, radius_squared):
		auto_target = null
		var best := INF
		for node in get_tree().get_nodes_in_group("cells"):
			var candidate := node as BioCellActor
			if not _valid_target(candidate, radius_squared): continue
			var distance := _host.global_position.distance_squared_to(candidate.global_position)
			if distance < best:
				best = distance
				auto_target = candidate
	if auto_target != null:
		set_aim(_host.global_position.direction_to(auto_target.global_position), false)
	elif _host.intent != Vector2.ZERO:
		set_aim(_host.intent, false)
	manual_aim = false
	return aim


func _valid_target(candidate: BioCellActor, radius_squared: float) -> bool:
	return is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and candidate != _host and candidate.is_active() and candidate.get_world_2d() == _host.get_world_2d() and BioCombatRules.can_hit(_host.combatant.actor, candidate.combatant.actor) and _host.global_position.distance_squared_to(candidate.global_position) <= radius_squared


func lash() -> int:
	if not manual_aim:
		var previous := aim
		auto_aim(_host.combatant.actor.attack_def(BioAttackCatalog.FLAGELLUM_LASH).range_units + 0.5)
		if auto_target == null: aim = previous
	if network_attack.is_valid():
		return network_attack.call("lash")
	return _executor.perform(BioAttackCatalog.FLAGELLUM_LASH, aim)


func spit() -> int:
	if network_attack.is_valid():
		return network_attack.call("spit")
	return _executor.perform(BioAttackCatalog.TOXIN_SPIT, aim)


func dash() -> int:
	if network_attack.is_valid():
		return network_attack.call("dash")
	var dir := _host.intent if _host.intent.length_squared() > 0.04 else aim
	return _executor.perform(BioAttackCatalog.MEMBRANE_DASH, dir)


func _physics_process(delta: float) -> void:
	if not _host.combatant.actor.vitals.is_alive():
		return
	var radius := MAGNET_RADIUS_UNITS * BioArt.UNIT
	for node in get_tree().get_nodes_in_group("nutrients"):
		var nutrient := node as BioNutrient
		if nutrient != null and nutrient.get_world_2d() == _host.get_world_2d() and nutrient.global_position.distance_to(_host.global_position) <= radius:
			nutrient.attract(_host.global_position, delta)
