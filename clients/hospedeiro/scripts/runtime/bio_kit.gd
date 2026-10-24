class_name BioKit
extends Node
## The abilities of one class that need more than a hit: mines, fuses, tethers, crystals, hunts, links, decoys. The runner (BioAbilityRunner)
## spends the cost and starts the cooldown, then asks the kit of the ability's kind to do it. A kit may keep a state of its own (a
## charge being held, an anchor waiting), and `repress` lets the same key finish it.

var host: BioCellActor
var aim_source: BioCellController
var limbs: BioLimbs
var body: BioCellBody


func configure(p_host: BioCellActor, p_aim: BioCellController, p_limbs: BioLimbs, p_body: BioCellBody) -> void:
	host = p_host
	aim_source = p_aim
	limbs = p_limbs
	body = p_body


## The kinds of ability this kit performs.
func kinds() -> Array[String]:
	return []


## Who the ability would act on, found BEFORE it is paid for: an empty list means "nobody to act on" and the cast costs nothing.
## The default is the one enemy nearest to the aim; a kit overrides it for the kinds that need more (or none).
func find(_kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	var pool := BioTargeting.enemies(host.get_world_2d(), origin, float(a["range"]) * BioArt.UNIT, host.combatant.actor.team)
	var best := BioTargeting.best(pool, origin, aim, float(a["range"]) * BioArt.UNIT)
	return [] if best == null else [best]


## Does the ability. `targets` is what `find` returned.
func cast(_kind: String, _id: StringName, _def: BioAttackDef, _a: Dictionary, _aim: Vector2, _color: Color, _targets: Array) -> void:
	pass


## True when the key pressed again finished something this kit was holding (and then nothing is paid for).
func repress(_id: StringName) -> bool:
	return false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _alive() -> bool:
	return is_instance_valid(host) and host.combatant.actor.vitals.is_alive()


func _team() -> int:
	return host.combatant.actor.team
