class_name BioKitB
extends BioKit
## The B lymphocyte, o Anticorpomante: it marks an enemy with complement so that the third blow bursts it, remembers the last thing it
## did and does it again, and turns into a plasma cell, a factory that cannot move and does not stop shooting.


func kinds() -> Array[String]:
	return ["complement", "replay", "turret"]


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	match kind:
		"turret":
			return [host]
		"replay":
			var runner := get_parent() as BioAbilityRunner
			return [host] if runner != null and runner.last_cast != &"" else []  # nothing done yet: nothing to remember
	return super.find(kind, a, origin, aim)


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"complement":
			_complement(a, color, targets[0] as BioCellActor)
		"replay":
			_replay(a, color)
		"turret":
			_turret(def, a, color)


## Antibodies cover the enemy and call the complement: the pores open one by one with every blow it takes, and the last one bursts it.
func _complement(a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.14, 0.3, {"tint": color, "style": {"tip": &"y", "base": 8.0, "tip_w": 6.0, "stiffness": 0.5}})
	body.elastic(target.global_position - host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.16)
	if not _alive() or not is_instance_valid(target) or not target.combatant.actor.vitals.is_alive():
		return
	var seconds := float(a["seconds"])
	target.combatant.complement(int(a["hits"]), float(a["pct"]), float(a["damage"]), float(a["cap"]), seconds)
	BioMarkGlyph.attach(target, color, seconds, &"complement")
	BioPfx.burst(BioFx.root, target.global_position, color, 10, 120.0, 0.4, 8.0)


## The cell remembers: the last ability it cast comes out again, free, and a little weaker.
func _replay(a: Dictionary, color: Color) -> void:
	var runner := get_parent() as BioAbilityRunner
	body.swell(1.2, 0.3)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 80.0, 24, 0.45, 10.0, true)
	await _wait(0.15)
	if not _alive():
		return
	host.combatant.echo(float(a["echo"]), 1.5)
	runner.perform_free(runner.last_cast)


## The cell fills with cisternae and stands still: for a few seconds it sheds antibodies at whatever is nearest, taking less from what
## reaches it. The antibodies are the ones the cell has designed (trajectory, calibre, impact).
func _turret(def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var me := host.combatant
	var runner := get_parent() as BioAbilityRunner
	var seconds := float(a["seconds"])
	me.guard(float(a["taken"]), seconds)
	host.slow(0.04, seconds + 0.3)
	body.swell(1.3, seconds)
	BioSignature.play(&"cartwheel", host.global_position, color, 0.6, {"radius": 40.0}, host)
	var shot := BioProjectileDesign.params(runner.projectile_traits) if BioProjectileDesign.is_designed(runner.projectile_traits) else {}
	var until := BioClock.now() + seconds
	var reach := float(a["range"]) * BioArt.UNIT
	while BioClock.now() < until and _alive():
		var near := BioTargeting.enemies(host.get_world_2d(), host.global_position, reach, _team())
		var target := BioTargeting.best(near, host.global_position, Vector2.ZERO, reach)
		if target != null:
			var dir := (target.global_position - host.global_position).normalized()
			body.elastic(dir, 0.0, 0.25, 0.0)
			BioAbilityBolt.spawn(host.get_parent(), me, def, host.global_position + dir * 0.7 * BioArt.UNIT, dir, float(a["speed"]), float(a["range"]), color, true, shot)
		await _wait(float(a["every"]))
	if is_instance_valid(host):
		host.slow(1.0, 0.01)
		body.swell(1.0, 0.2)
