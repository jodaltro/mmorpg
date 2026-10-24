class_name BioKitMast
extends BioKit
## The mast cell, the Alarmista: a bomber. It lays granules behind it as it moves, glues unstable globs to enemies, turns every kill into
## a chain of bursts, and, when it dares, bleeds its own membrane into one enormous blast.

var _charging := false
var _charging_id: StringName = &""
var _release := false


func kinds() -> Array[String]:
	return ["mines", "sticky", "cascade", "overload"]


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	if kind == "sticky" or kind == "mines" or kind == "cascade" or kind == "overload":
		return [host]  # none of them needs a target
	return super.find(kind, a, origin, aim)


func cast(kind: String, id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, _targets: Array) -> void:
	match kind:
		"mines":
			_mines(def, a, color)
		"sticky":
			_sticky(def, a, aim, color)
		"cascade":
			_cascade(def, a, color)
		"overload":
			_overload(id, def, a, color)


func repress(id: StringName) -> bool:
	if _charging and id == _charging_id:
		_release = true
		return true
	return false


## The granules: for a few seconds, one is dropped wherever the cell has moved on from the last. Oldest go first when there are too many.
func _mines(def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var until := BioClock.now() + float(a["duration"])
	var last := host.global_position + Vector2(1000.0, 0.0)
	var cap := int(a["max"])
	body.swell(1.15, 0.3)
	while BioClock.now() < until and _alive():
		if host.global_position.distance_to(last) < 0.9 * BioArt.UNIT:
			await _wait(0.08)  # standing still lays nothing: the trail is made by moving
			continue
		last = host.global_position
		var mine_nodes := get_tree().get_nodes_in_group("bio_mines").filter(func(n: Node) -> bool: return (n as BioMine).owner_cell == host)
		while mine_nodes.size() >= cap:
			(mine_nodes.pop_front() as BioMine).queue_free()
		BioMine.spawn(host.get_parent(), host, def, host.global_position, float(a["radius"]), float(a["arm"]), float(a["life"]), color)
		body.swell(1.08, 0.12)
		await _wait(float(a["every"]))


## A glob budded off the membrane and fired: it sticks to what it hits, and goes off after its fuse.
func _sticky(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	limbs.reach(aim, 1.1, 0.08, 0.16, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "base": 12.0, "tip_w": 16.0, "stiffness": 0.5}})
	body.elastic(aim, 0.3, 0.0, 0.08)
	await _wait(0.09)
	if not _alive():
		return
	host.apply_impulse(-aim * 1.3)
	BioGlob.spawn(host.get_parent(), host, def, host.global_position + aim * 0.8 * BioArt.UNIT, aim, a, color)


## For a while, everything the cell kills bursts, and so does everything that burst kills.
func _cascade(def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var me := host.combatant
	me.start_cascade(float(a["duration"]), def, float(a["radius"]))
	body.swell(1.25, 0.4)
	limbs.radial(7, 1.3, 0.12, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "bumps": 3, "base": 10.0, "tip_w": 10.0}})
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 90.0, 22, 0.5, 9.0, true)
	BioHalo.ring(host, color, func() -> bool: return is_instance_valid(host) and me.is_cascading())


## The cell bleeds membrane into the blast for as long as it dares (or until the key is pressed again, or the limit is reached): what it
## spends is what the blast is made of. It never bleeds to death.
func _overload(id: StringName, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	if _charging:
		return
	_charging = true
	_charging_id = id
	_release = false
	var vitals := host.combatant.actor.vitals
	var max_time := float(a["max_time"])
	var floor_hp := vitals.max_membrane * float(a["floor"])
	var rate := vitals.max_membrane * float(a["bleed"])
	var full_radius := float(a["radius"])
	var ring := BioChargeRing.over(host, color, full_radius * BioArt.UNIT)
	host.slow(0.55, max_time + 0.5)
	var spent := 0.0
	var held := 0.0
	while _alive() and not _release and held < max_time:
		var delta := get_physics_process_delta_time()
		var drain := minf(rate * delta, vitals.membrane - floor_hp)
		if drain <= 0.0:
			break
		vitals.take_damage(drain)
		spent += drain
		held += delta
		ring.fraction = held / max_time
		body.swell(1.0 + 0.32 * ring.fraction, 0.06)
		await get_tree().physics_frame
	ring.queue_free()
	_charging = false
	if not _alive():
		return
	var fraction := clampf(held / max_time, 0.0, 1.0)
	var radius := full_radius * (0.45 + 0.55 * fraction)
	var blow := BioStrike.with_damage(def, def.damage + float(a["per_hp"]) * spent)
	var origin := host.global_position
	host.slow(1.0, 0.01)
	limbs.radial(clampi(int(radius * 3.0), 8, 14), radius, 0.09, 0.16, {"tint": color, "sweep": 0.0})
	body.swell(0.8, 0.14)
	BioPfx.ring_burst(BioFx.root, origin, color, radius * BioArt.UNIT * 0.9, 56, 0.6, 13.0)
	BioPfx.burst(BioFx.root, origin, color.lerp(Color.WHITE, 0.4), 50, 420.0, 0.7, 13.0)
	BioSignature.play(&"bodies", origin, color, 1.6, {}, null)
	BioFx.shake(0.1 + 0.25 * fraction)
	for e in BioTargeting.enemies(host.get_world_2d(), origin, radius * BioArt.UNIT, _team()):
		BioStrike.land(host, e, blow, origin, color)
