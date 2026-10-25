class_name BioCellController
extends Node
## Player intents (move, aim, lash, spit, dash). Input devices and tests both drive this same surface.

const MAGNET_RADIUS_UNITS := 2.6

var aim := Vector2.RIGHT
var network_attack: Callable

var _host: BioCellActor
var _executor: BioAttackExecutor


func configure(host: BioCellActor, executor: BioAttackExecutor) -> void:
	_host = host
	_executor = executor


func move(direction: Vector2) -> void:
	_host.set_intent(direction if _host.combatant.actor.vitals.is_alive() else Vector2.ZERO)


func set_aim(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		aim = direction.normalized()


func lash() -> int:
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
