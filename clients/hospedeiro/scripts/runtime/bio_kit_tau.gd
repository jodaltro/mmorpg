class_name BioKitTau
extends BioKit
## The helper T cell, o Maestro: it gives a fever that spreads from enemy to enemy, calls auxiliaries that fight for it, buys the cell a
## second chance against the blow that would end it, and trades what it has too much of for what it lacks.

var _saved_color := Color(1.0, 0.85, 0.4)


func kinds() -> Array[String]:
	return ["contagion", "allies", "lastchance", "convert"]


func configure(p_host: BioCellActor, p_aim: BioCellController, p_limbs: BioLimbs, p_body: BioCellBody) -> void:
	super.configure(p_host, p_aim, p_limbs, p_body)
	host.combatant.saved.connect(_on_saved)


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	if kind == "contagion":
		return super.find(kind, a, origin, aim)
	return [host]


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, _aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"contagion":
			_contagion(def, a, color, targets[0] as BioCellActor)
		"allies":
			_allies(a, color)
		"lastchance":
			_last_chance(a, color)
		"convert":
			_convert(a, color)


func _contagion(def: BioAttackDef, a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.14, 0.3, {"tint": color, "style": {"tip": &"bulb", "base": 9.0, "tip_w": 8.0, "stiffness": 0.25, "wave": 0.5}})
	body.elastic(target.global_position - host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.16)
	if _alive() and is_instance_valid(target) and target.combatant.actor.vitals.is_alive():
		BioFever.catch_on(target, host, def, a, int(a["hops"]), color)
		BioPfx.burst(BioFx.root, target.global_position, color, 12, 140.0, 0.4, 9.0)


## Cells bud off the membrane and run to fight.
func _allies(a: Dictionary, color: Color) -> void:
	_saved_color = color
	var count := int(a["count"])
	limbs.radial(count, 1.5, 0.14, 0.35, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "stiffness": 0.3}})
	body.swell(1.12, 0.3)
	await _wait(0.3)
	if not _alive():
		return
	var blow := BioStrike.with_damage(BioAbilityCatalog.attack_def(&"chamado_aos_auxiliares"), float(a["damage"]))
	for k in count:
		var at := host.global_position + Vector2.from_angle(k * TAU / float(count) + randf() * 0.5) * 1.6 * BioArt.UNIT
		BioFactory.spawn_ally(host.get_parent(), at, host, float(a["hp"]), blow, color, float(a["seconds"]))
		BioPfx.burst(BioFx.root, at, color, 8, 120.0, 0.4, 8.0)


## A golden ring: the next blow that would kill is not felt as one.
func _last_chance(a: Dictionary, color: Color) -> void:
	_saved_color = color
	var me := host.combatant
	me.guardian(float(a["seconds"]), float(a["restore"]))
	body.swell(1.15, 0.4)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 70.0, 22, 0.5, 9.0, true)
	BioHalo.ring(host, color, func() -> bool: return is_instance_valid(host) and me.has_guardian())


func _on_saved() -> void:
	BioPfx.ring_burst(BioFx.root, host.global_position, _saved_color, 150.0, 48, 0.7, 14.0)
	BioPfx.burst(BioFx.root, host.global_position, Color.WHITE, 30, 320.0, 0.6, 12.0)
	BioFx.shake(0.2)


## Spends what the cell has more of (in proportion) to refill what it lacks most: membrane for energy when it is full of life and empty
## of energy, energy for membrane the other way round. It never spends the membrane below a quarter.
func _convert(a: Dictionary, color: Color) -> void:
	var v := host.combatant.actor.vitals
	var give := float(a["give"])
	var rate := float(a["rate"])
	var life := v.membrane / v.max_membrane
	var energy := v.atp / maxf(v.max_atp, 0.01)
	if life >= energy:
		var spend := minf(v.max_membrane * give, maxf(v.membrane - v.max_membrane * 0.25, 0.0))
		v.take_damage(spend)
		v.add_atp(spend / v.max_membrane * rate * v.max_atp)
	else:
		var spend2 := minf(v.max_atp * give, v.atp)
		v.try_spend_atp(spend2)
		v.repair(spend2 / v.max_atp * rate * v.max_membrane)
	body.swell(1.15, 0.3)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 60.0, 20, 0.5, 9.0, life < energy)
