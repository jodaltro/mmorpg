class_name BioGeneEffects
extends RefCounted
## Extra mechanics of expressed genes. Called only after a paid, validated cast.
## Preview draws a signature; it never queries targets, changes vitals or spawns damaging nodes.

static func preview(host: BioCellActor, id: StringName, aim: Vector2) -> void:
	if host.combatant.genome == null: return
	for effect in host.combatant.genome.transformations(id):
		var color := Color(str(effect.get("color", "#ffffff")))
		var at := host.global_position
		if str(effect.kind) in ["pool", "rupture"]: at += aim.normalized() * 2.0 * BioArt.UNIT
		BioSignature.play(&"grooves", at, color, 0.4, {"radius": float(effect.get("radius", 2.0)) * BioArt.UNIT})

static func apply(host: BioCellActor, id: StringName, aim: Vector2, def: BioAttackDef) -> void:
	if host.combatant.genome == null: return
	var ready: Dictionary = host.get_meta("gene_ready_at", {})
	for effect in host.combatant.genome.transformations(id):
		var gene := str(effect.gene)
		if BioClock.now() < float(ready.get(gene, 0)): continue
		ready[gene] = BioClock.now() + float(effect.get("cooldown", 0))
		host.set_meta("gene_ready_at", ready)
		var color := Color(str(effect.get("color", "#ffffff")))
		var radius := float(effect.get("radius", 2.5))
		var power := float(effect.get("power", 0.4))
		var damage := maxf(def.damage, 10.0) * power
		var hit := BioAttackDef.new(id, 0, damage, 0, radius, 0, 0).with_presentation(def.presentation_owner, def.presentation_token)
		var at := host.global_position
		match str(effect.kind):
			"volley":
				for i in int(effect.get("count", 2)):
					var side := -1.0 if i % 2 == 0 else 1.0
					var dir := aim.rotated(side * 0.22)
					BioAbilityBolt.spawn(host.get_parent(), host.combatant, hit, at + dir * BioArt.UNIT * 0.7, dir, 14, maxf(def.range_units, 6), color, BioAbilityCatalog.has(id))
			"pool", "aura":
				if effect.kind == "pool": at += aim * 2.0 * BioArt.UNIT
				BioAbilityZone.spawn(host.get_parent(), host, id, at, {"style":"acid", "color":color, "radius":radius, "duration":float(effect.get("duration", 3)), "tick":damage, "slow":float(effect.get("slow", 0)), "follow":effect.kind == "aura"})
			"guard":
				host.combatant.guard(float(effect.get("taken", 0.65)), float(effect.get("duration", 2)))
				BioSignature.play(&"wall", at, color, float(effect.get("duration", 2)), {"radius":radius * BioArt.UNIT}, host)
			"mend":
				host.combatant.actor.vitals.repair(float(effect.get("heal", 20)))
				for cell in host.get_tree().get_nodes_in_group("cells"):
					if cell == host or not cell is BioCellActor or not cell.is_active() or cell.get_world_2d() != host.get_world_2d(): continue
					if cell.combatant.actor.team == host.combatant.actor.team and cell.global_position.distance_to(at) <= radius * BioArt.UNIT:
						cell.combatant.actor.vitals.repair(float(effect.get("heal", 20)))
				BioSignature.play(&"grooves", at, color, 0.7, {"radius":radius * BioArt.UNIT})
			"chain":
				var pool := BioTargeting.enemies(host.get_world_2d(), at, radius * BioArt.UNIT, host.combatant.actor.team)
				pool.sort_custom(func(a: BioCellActor, b: BioCellActor) -> bool: return at.distance_squared_to(a.global_position) < at.distance_squared_to(b.global_position))
				var previous := at
				for i in mini(pool.size(), int(effect.get("count", 3))):
					var victim: BioCellActor = pool[i]
					BioStrike.beam(previous, victim.global_position, color, 3)
					previous = victim.global_position
					BioStrike.land(host, victim, hit, at, color)
			"rupture":
				_rupture(host, at + aim * 2.0 * BioArt.UNIT, hit, color, float(effect.get("duration", 0.5)))
			"nova":
				_nova(host, at, hit, color)

static func _nova(host: BioCellActor, at: Vector2, hit: BioAttackDef, color: Color) -> void:
	BioSignature.play(&"grooves", at, color, 0.6, {"radius":hit.range_units * BioArt.UNIT})
	for enemy in BioTargeting.enemies(host.get_world_2d(), at, hit.range_units * BioArt.UNIT, host.combatant.actor.team):
		BioStrike.land(host, enemy, hit, at, color)

static func _rupture(host: BioCellActor, at: Vector2, hit: BioAttackDef, color: Color, delay: float) -> void:
	var realm := host.get_world_2d()
	var parent := host.get_parent()
	BioSignature.play(&"cartwheel", at, color, delay, {"radius":hit.range_units * BioArt.UNIT})
	await host.get_tree().create_timer(delay).timeout
	if not is_instance_valid(host) or not is_instance_valid(parent) or host.get_parent() != parent or host.get_world_2d() != realm or not host.is_active() or not host.combatant.actor.vitals.is_alive(): return
	_nova(host, at, hit, color)
