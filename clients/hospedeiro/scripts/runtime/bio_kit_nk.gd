class_name BioKitNk
extends BioKit
## The NK cell, the Assassino Natural: it steps out of nowhere behind its prey, hunts one enemy at a time and gets its strength back for
## every blow, vanishes from the enemy's sight, and ties a thread to where it stands so it can be pulled back through the fight.

var _anchored := false
var _anchor_id: StringName = &""
var _recall_now := false
var _cloaked := false


func kinds() -> Array[String]:
	return ["blink", "prey", "cloak", "recall"]


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	if kind == "cloak" or kind == "recall":
		return [host]
	if kind == "blink":  # with nobody in reach it is a plain jump
		var pool := BioTargeting.enemies(host.get_world_2d(), origin, float(a["range"]) * BioArt.UNIT, _team())
		var best := BioTargeting.best(pool, origin, aim, float(a["range"]) * BioArt.UNIT)
		return [best] if best != null else [host]
	return super.find(kind, a, origin, aim)


func cast(kind: String, id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"blink":
			_blink(def, a, aim, color, targets[0] as BioCellActor)
		"prey":
			_prey(a, color, targets[0] as BioCellActor)
		"cloak":
			_cloak(a, color)
		"recall":
			_recall(id, def, a, color)


func repress(id: StringName) -> bool:
	if _anchored and id == _anchor_id:
		_recall_now = true
		return true
	return false


## The cell is here, and then it is behind the target, and the blow lands from where nobody looks.
func _blink(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, target: BioCellActor) -> void:
	var from := host.global_position
	var prey := target if target != host else null
	var to: Vector2
	var dir := aim
	if prey != null:
		dir = (prey.global_position - from).normalized()
		to = prey.global_position + dir * float(a["behind"]) * BioArt.UNIT
	else:
		to = from + aim * float(a["distance"]) * BioArt.UNIT
	to = BioStrike.clear_point(host.get_world_2d(), from, to, 0.6 * BioArt.UNIT)
	BioStrike.beam(from, to, color, 24.0, 0.3)
	BioPfx.burst(BioFx.root, from, color, 14, 200.0, 0.4, 9.0)
	host.global_position = to
	host.velocity = dir * 3.0 * BioArt.UNIT
	host.cancel_dash()
	host.combatant.actor.invulnerable_until = maxf(host.combatant.actor.invulnerable_until, BioClock.now() + float(a["iframes"]))
	body.elastic(dir, 0.0, 0.55, 0.0)
	BioPfx.burst(BioFx.root, to, color.lerp(Color.WHITE, 0.4), 16, 220.0, 0.45, 10.0, -dir, 70.0)
	if prey != null and is_instance_valid(prey):
		BioStrike.land(host, prey, BioStrike.with_damage(def, def.damage * float(a["backstab"])), to - dir * BioArt.UNIT, color)
		BioSignature.play(&"scar", prey.global_position, color, 0.8, {"dir": dir}, null)
		BioFx.shake(0.14)


## One enemy is the prey: each blow on it gives cooldowns and energy back, and killing it gives all of them back.
func _prey(a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.14, 0.3, {"tint": color, "style": {"tip": &"fork", "base": 7.0, "tip_w": 4.0, "stiffness": 0.25}})
	body.elastic(target.global_position - host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.16)
	if not _alive() or not is_instance_valid(target):
		return
	var seconds := float(a["seconds"])
	host.combatant.hunt(target.combatant, seconds, float(a["refund"]), float(a["atp"]))
	host.combatant.haste(float(a["speed"]), seconds, 0.0)
	BioMarkGlyph.attach(target, color, seconds, &"prey")
	BioPfx.burst(BioFx.root, target.global_position, color, 10, 120.0, 0.4, 8.0)


## Missing-self: the cell is not there for the enemies. They lose it; the first blow it lands out of hiding is far stronger.
func _cloak(a: Dictionary, color: Color) -> void:
	var me := host.combatant
	var seconds := float(a["seconds"])
	me.vanish(seconds, float(a["strike"]))
	me.haste(float(a["speed"]), seconds, 0.0)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 70.0, 20, 0.5, 9.0, true)
	if _cloaked:
		return
	_cloaked = true
	var t := 0.0
	while _alive() and me.is_hidden():
		t += get_physics_process_delta_time()
		host.modulate.a = lerpf(host.modulate.a, 0.3 + 0.08 * sin(t * 9.0), 0.2)
		await get_tree().physics_frame
	_cloaked = false
	if is_instance_valid(host):
		host.modulate.a = 1.0
		BioPfx.burst(BioFx.root, host.global_position, color.lerp(Color.WHITE, 0.4), 14, 200.0, 0.4, 9.0)


## It drops an anchor with the life it has now. After a moment (or when the key is pressed again) the cell is pulled back to it in a
## straight line, hurting everything in the way and mending a share of what it lost since.
func _recall(id: StringName, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	if _anchored:
		return
	_anchored = true
	_anchor_id = id
	_recall_now = false
	var vitals := host.combatant.actor.vitals
	var stored := vitals.membrane
	var spot := host.global_position
	var delay := float(a["delay"])
	var anchor := BioAnchor.drop(host.get_parent(), spot, color, delay, stored / vitals.max_membrane)
	var until := BioClock.now() + delay
	while _alive() and not _recall_now and BioClock.now() < until:
		await get_tree().physics_frame
	_anchored = false
	if is_instance_valid(anchor):
		anchor.queue_free()
	if not _alive():
		return
	var from := host.global_position
	var width := float(a["width"]) * BioArt.UNIT
	BioStrike.beam(from, spot, color, width, 0.4)
	for e in BioTargeting.enemies(host.get_world_2d(), (from + spot) * 0.5, from.distance_to(spot) * 0.5 + width, _team()):
		if BioTargeting.distance_to_segment(e.global_position, from, spot) <= width:
			BioStrike.land(host, e, def, from, color)
	vitals.repair(maxf(0.0, stored - vitals.membrane) * float(a["restore"]))
	host.combatant.actor.invulnerable_until = maxf(host.combatant.actor.invulnerable_until, BioClock.now() + float(a["iframes"]))
	host.global_position = spot
	host.velocity = Vector2.ZERO
	host.cancel_dash()
	body.elastic((spot - from).normalized(), 0.0, 0.5, 0.0)
	BioPfx.ring_burst(BioFx.root, spot, color, 60.0, 24, 0.45, 10.0, true)
	BioFx.shake(0.12)
