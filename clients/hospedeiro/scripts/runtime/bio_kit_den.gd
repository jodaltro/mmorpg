class_name BioKitDen
extends BioKit
## The dendritic cell, a Cartógrafa: it reads the room. A beam that sweeps it, a maturation that makes the next abilities count for more,
## and a passage through the lymph that opens two doors in the tissue.


func kinds() -> Array[String]:
	return ["beam", "empower", "portal"]


func find(_kind: String, _a: Dictionary, _origin: Vector2, _aim: Vector2) -> Array:
	return [host]


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, _targets: Array) -> void:
	match kind:
		"beam":
			_beam(def, a, aim, color)
		"empower":
			_empower(a, color)
		"portal":
			_portal(a, aim, color)


func _beam(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	limbs.reach(aim, 1.3, 0.1, 0.3, {"tint": color, "sweep": 0.0, "style": {"tip": &"fork", "base": 8.0, "tip_w": 4.0, "stiffness": 0.3}})
	body.elastic(aim, 0.2, 0.2, 0.08)
	await _wait(0.1)
	if _alive():
		BioScanBeam.open(host.get_parent(), host, aim_source, def, a, color)


## The cell matures: its next few abilities cost nothing and hit harder.
func _empower(a: Dictionary, color: Color) -> void:
	var me := host.combatant
	me.empower(int(a["charges"]), float(a["mult"]), float(a["seconds"]))
	body.swell(1.2, 0.35)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 80.0, 24, 0.5, 10.0, true)
	var halo := BioHalo.ring(host, color, func() -> bool: return is_instance_valid(host) and me.empower_charges() > 0)
	halo.count_source = func() -> int: return me.empower_charges() * 2


## Two doors: one where the cell points, one under its feet.
func _portal(a: Dictionary, aim: Vector2, color: Color) -> void:
	var from := host.global_position
	var spot := BioStrike.clear_point(host.get_world_2d(), from, from + aim * float(a["reach"]) * BioArt.UNIT, 1.0 * BioArt.UNIT)
	limbs.reach(aim, float(a["reach"]) + 0.2, 0.14, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "base": 14.0, "tip_w": 16.0}})
	body.elastic(aim, 0.25, 0.5, 0.08)
	await _wait(0.14)
	if _alive():
		BioPortalPair.open(host.get_parent(), host, spot, from, float(a["seconds"]), color)
