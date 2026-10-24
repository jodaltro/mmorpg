class_name BioKitTcy
extends BioKit
## The cytotoxic T cell, o Executor: it jumps over the crowd and lands on it, takes one enemy in a grip that tightens until it ends, and,
## when the room is full of its kills, passes sentence on every enemy that is nearly dead.


func kinds() -> Array[String]:
	return ["leap", "hold", "massacre"]


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	if kind == "leap" or kind == "massacre":
		return [host]
	return super.find(kind, a, origin, aim)


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"leap":
			_leap(def, a, aim, color)
		"hold":
			_hold(def, a, color, targets[0] as BioCellActor)
		"massacre":
			_massacre(def, a, color)


## A jump over everything (bodies cannot stop it, nothing can hurt it in the air) that ends in a blow on the ground.
func _leap(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	var from := host.global_position
	var to := BioStrike.clear_point(host.get_world_2d(), from, from + aim * float(a["distance"]) * BioArt.UNIT, 0.8 * BioArt.UNIT)
	var air := float(a["air"])
	host.ghost(air + 0.1)
	host.cancel_dash()
	host.combatant.actor.invulnerable_until = maxf(host.combatant.actor.invulnerable_until, BioClock.now() + air)
	BioPfx.burst(BioFx.root, from, color, 12, 160.0, 0.4, 9.0)
	var t := 0.0
	while t < air and _alive():
		t += get_physics_process_delta_time()
		var f := clampf(t / air, 0.0, 1.0)
		host.global_position = from.lerp(to, f)
		host.velocity = Vector2.ZERO
		host.scale = Vector2.ONE * (1.0 + 0.5 * sin(f * PI))
		await get_tree().physics_frame
	if not is_instance_valid(host):
		return
	host.scale = Vector2.ONE
	if not _alive():
		return
	var at := host.global_position
	BioPfx.ring_burst(BioFx.root, at, color, float(a["radius"]) * BioArt.UNIT * 0.9, 44, 0.5, 12.0)
	BioPfx.burst(BioFx.root, at, color.lerp(Color.WHITE, 0.4), 26, 300.0, 0.5, 11.0)
	BioFx.shake(0.22)
	body.elastic(Vector2.DOWN, 0.0, 0.6, 0.0)
	for e in BioTargeting.enemies(host.get_world_2d(), at, float(a["radius"]) * BioArt.UNIT, _team()):
		BioStrike.land(host, e, def, at, color)


## A needle goes in and the synapse holds: see BioSqueeze.
func _hold(def: BioAttackDef, a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.1, 0.4, {"tint": color, "style": {"tip": &"spear", "stiffness": 0.95, "wave": 0.03, "barbs": 3}})
	body.elastic(target.global_position - host.global_position, 0.3, 0.6, 0.08)
	await _wait(0.1)
	if _alive() and is_instance_valid(target) and target.combatant.actor.vitals.is_alive():
		BioSqueeze.grip(host, target, def, a, color)


## The more the cell has killed in the last seconds, the more nearly dead an enemy can be and still be sentenced: every enemy in the room
## is hurt, and those at or below the threshold are finished.
func _massacre(def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var me := host.combatant
	var threshold := minf(float(a["base"]) + float(a["per_kill"]) * me.kills_within(float(a["window"])), 0.85)
	var origin := host.global_position
	var radius := float(a["radius"]) * BioArt.UNIT
	body.swell(1.3, 0.25)
	BioPfx.ring_burst(BioFx.root, origin, color, radius * 0.5, 40, 0.8, 12.0)
	BioFx.shake(0.2)
	await _wait(0.25)
	if not _alive():
		return
	for e in BioTargeting.enemies(host.get_world_2d(), origin, radius, _team()):
		BioStrike.land(host, e, def, origin, color)
		if not is_instance_valid(e):
			continue
		var v := e.combatant.actor.vitals
		if v.is_alive() and v.membrane / v.max_membrane <= threshold:
			BioStrike.land(host, e, BioStrike.with_damage(def, v.membrane + 1.0), origin, color)
			BioSignature.play(&"pore", e.global_position, color, 1.2, {}, null)
