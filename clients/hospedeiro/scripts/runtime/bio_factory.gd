class_name BioFactory
extends RefCounted
## Builds the procedural actors from code so tests and the main scene share one recipe.

static var _virus_counter := 0


static func spawn_player(parent: Node, pos: Vector2) -> BioCellActor:
	var actor := _make_actor(parent, "Player_Cell", pos)
	actor.thrust_units = 42.0
	actor.max_speed_units = 7.0
	actor.damping = 3.5
	actor.combatant.configure("player", BioActor.Team.CELL, 100.0, 100.0, 7.0)

	var body := BioCellBody.new()
	body.configure(0.55, BioArt.CYAN, BioArt.DEEP_BLUE, 0, 0.0, 0.0, 10)
	actor.add_child(body)
	var tail := BioFlagellum.new()
	tail.name = "Flagellum"
	tail.configure(0.3, 0.12, 17.0, BioArt.CYAN, 9)
	tail.root_color = BioArt.DEEP_BLUE
	tail.body_radius_px = 0.55 * BioArt.UNIT
	body.tail = tail
	actor.add_child(tail)
	tail.set_active(false)  # born as a plain ball: no tail until a lineage grows one
	actor.combatant.genome_changed.connect(func(g: BioGenome) -> void:
		body.apply_genome(g)
		tail.apply_genome(g))

	var limbs := BioLimbs.new()
	limbs.name = "Limbs"
	limbs.configure(actor, body)
	actor.add_child(limbs)
	var executor := BioAttackExecutor.new()
	executor.configure(actor.combatant, actor)
	actor.add_child(executor)
	executor.half_angle_source = limbs.lash_half_angle
	executor.visual_performed.connect(func(id: StringName, dir: Vector2) -> void:
		if id == BioAttackCatalog.FLAGELLUM_LASH:
			var reach := actor.combatant.actor.attack_def(id).range_units
			if tail.is_active():
				tail.lash(dir, reach, executor.lash_half_angle)
				body.elastic(dir, 0.08, 0.15, 0.06)
			else:  # no tail: the body lashes with whatever limb its form and look grow
				limbs.lash(dir, reach)
		elif id == BioAttackCatalog.MEMBRANE_DASH:
			tail.whip(1.0))

	var controller := BioCellController.new()
	controller.name = "Controller"
	controller.configure(actor, executor)
	actor.add_child(controller)
	var abilities := BioAbilityRunner.new()
	abilities.name = "Abilities"
	abilities.configure(actor, controller, limbs, body)
	actor.add_child(abilities)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, BioArt.CYAN)
	actor.add_child(feedback)
	var input := BioPlayerInput.new()
	input.configure(controller, actor)
	actor.add_child(input)
	return actor


static func spawn_virus(parent: Node, pos: Vector2, prey: BioCellActor) -> BioVirusBrain:
	var actor := _make_actor(parent, "Virus", pos)
	actor.thrust_units = 24.0
	actor.max_speed_units = 3.6
	actor.damping = 3.0
	_virus_counter += 1
	actor.combatant.configure("virus-%d" % _virus_counter, BioActor.Team.VIRUS, 40.0, 100.0, 0.0)
	actor.add_to_group("viruses")

	var body := BioCellBody.new()
	body.configure(0.6, BioArt.MAGENTA, BioArt.CRIMSON, 9, 0.34, 0.5, 8)
	actor.add_child(body)
	var executor := BioAttackExecutor.new()
	executor.configure(actor.combatant, actor)
	actor.add_child(executor)
	var brain := BioVirusBrain.new()
	brain.configure(actor, executor, body, prey)
	executor.performed.connect(body.attack_gesture)
	actor.add_child(brain)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, BioArt.CRIMSON)
	actor.add_child(feedback)
	return brain


## An enemy shaped by BioDungeonPlan.enemy: hp, speed, size, colours and how it fights (it lunges, it shoots from afar, or it is a nest).
## `group` is where it is counted: the dungeon's enemies by default, or "viruses" for the wild ones of an organ. Returns its brain.
static func spawn_enemy(parent: Node, pos: Vector2, prey: BioCellActor, def: Dictionary, speed_mult: float = 1.0, group: String = "dungeon_enemies") -> Node:
	var actor := _make_actor(parent, str(def.get("name", "Enemy")), pos)
	var speed := float(def["speed"]) * speed_mult
	actor.thrust_units = 12.0 + 4.0 * speed
	actor.max_speed_units = maxf(speed, 0.01)
	actor.damping = 3.0
	_virus_counter += 1
	actor.combatant.configure("enemy-%d" % _virus_counter, BioActor.Team.VIRUS, float(def["hp"]), 100.0, 0.0)
	actor.add_to_group(group)
	actor.combatant.damage_dealt_mult = float(def.get("damage", 1.0))
	var size := float(def["size"])
	(actor.get_child(0) as CollisionShape2D).shape = _circle(size * 0.9)
	var body := BioCellBody.new()
	body.configure(size, def["core"], def["edge"], int(def["spikes"]), float(def.get("spike_len", 0.3 if int(def["spikes"]) > 0 else 0.0)), float(def.get("spin", 0.5)), 8)
	actor.add_child(body)
	var executor := BioAttackExecutor.new()
	executor.configure(actor.combatant, actor)
	actor.add_child(executor)
	var brain: Node
	match str(def.get("behavior", "lunge")):
		"ranged":
			var shooter := BioRangedBrain.new()
			shooter.configure(actor, executor, body, prey)
			shooter.aggro_range_units = float(def["aggro"])
			shooter.lunge_range_units = float(def["lunge"])
			shooter.telegraph_seconds = maxf(float(def["telegraph"]), 0.05)
			shooter.recover_seconds = float(def["recover"])
			brain = shooter
		"nest":
			var nest := BioNestBrain.new()
			nest.every = float((def["spawns"] as Dictionary)["every"])
			nest.cap = int((def["spawns"] as Dictionary)["cap"])
			nest.configure(actor, body)
			brain = nest
		_:
			var biter := BioVirusBrain.new()
			biter.configure(actor, executor, body, prey)
			biter.aggro_range_units = float(def["aggro"])
			biter.lunge_range_units = float(def["lunge"])
			biter.telegraph_seconds = maxf(float(def["telegraph"]), 0.05)
			biter.recover_seconds = float(def["recover"])
			brain = biter
			if speed <= 0.0:
				brain.set_process(false)  # an emitter never moves
	actor.add_child(brain)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, def["edge"])
	executor.performed.connect(body.attack_gesture)
	actor.add_child(feedback)
	return brain


## A decoy of the cell: a ghostly body that enemies can hit, with a life of its own, that does nothing but stand there.
static func spawn_decoy(parent: Node, pos: Vector2, hp: float, color: Color) -> BioCellActor:
	var actor := _make_actor(parent, "Decoy", pos)
	actor.remove_from_group("cells")  # the current does not carry it away
	actor.thrust_units = 0.0
	actor.max_speed_units = 0.01
	actor.damping = 6.0
	_virus_counter += 1
	actor.combatant.configure("decoy-%d" % _virus_counter, BioActor.Team.CELL, hp, 0.0, 0.0)
	var body := BioCellBody.new()
	body.configure(0.55, color.lerp(Color.WHITE, 0.3), color.darkened(0.3), 0, 0.0, 0.3, 8)
	actor.add_child(body)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, color)
	actor.add_child(feedback)
	actor.modulate.a = 0.7
	return actor


## An auxiliary called by a T helper cell: it fights on the cell's side for a while (see BioAllyBrain).
static func spawn_ally(parent: Node, pos: Vector2, owner: BioCellActor, hp: float, def: BioAttackDef, color: Color, seconds: float) -> BioCellActor:
	var actor := _make_actor(parent, "Auxiliar", pos)
	actor.remove_from_group("cells")
	actor.add_to_group("allies")
	actor.thrust_units = 30.0
	actor.max_speed_units = 5.2
	actor.damping = 3.0
	_virus_counter += 1
	actor.combatant.configure("ally-%d" % _virus_counter, BioActor.Team.CELL, hp, 0.0, 0.0)
	actor.combatant.enemy_defeated.connect(func(victim: BioCombatant) -> void:
		if is_instance_valid(owner): owner.combatant.enemy_defeated.emit(victim))
	var body := BioCellBody.new()
	body.configure(0.34, color.lerp(Color.WHITE, 0.3), color.darkened(0.25), 0, 0.0, 0.4, 8)
	actor.add_child(body)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, color)
	actor.add_child(feedback)
	var brain := BioAllyBrain.new()
	brain.configure(actor, body, owner, def, color, seconds)
	actor.add_child(brain)
	return actor


static func _circle(radius_units: float) -> CircleShape2D:
	var circle := CircleShape2D.new()
	circle.radius = radius_units * BioArt.UNIT
	return circle


static func spawn_projectile(parent: Node, owner_combatant: BioCombatant, def: BioAttackDef, pos: Vector2, direction: Vector2) -> BioProjectile:
	var projectile := BioProjectile.new()
	projectile.name = "ToxinSpit"
	projectile.position = pos
	projectile.set_meta("action_token", def.presentation_token)
	projectile.set_meta("action_owner", def.presentation_owner)
	projectile.launch(owner_combatant, def, direction)
	parent.add_child(projectile)
	return projectile


static func spawn_nutrient(parent: Node, pos: Vector2, kind: int) -> BioNutrient:
	var nutrient := BioNutrient.new()
	nutrient.name = "Nutrient"
	nutrient.position = pos
	nutrient.configure(kind)
	parent.add_child(nutrient)
	return nutrient


## The body's walls: one closed outline (world units) used both as collision and as the glowing membrane.
static func create_body_boundary(parent: Node, outline_units: PackedVector2Array) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "BodyWalls"
	wall.collision_layer = BioCellActor.LAYER_WALL
	wall.collision_mask = 0
	var segments := PackedVector2Array()
	var ring := Line2D.new()
	ring.closed = true
	ring.width = 10.0
	ring.default_color = BioArt.with_alpha(BioArt.MAGENTA, 0.35)
	ring.material = BioArt.additive()
	ring.z_index = -5
	var count := outline_units.size()
	for i in count:
		var a := outline_units[i] * BioArt.UNIT
		var b := outline_units[(i + 1) % count] * BioArt.UNIT
		segments.append(a)
		segments.append(b)
		ring.add_point(a)
	var shape := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = segments
	shape.shape = concave
	wall.add_child(shape)
	wall.add_child(ring)
	parent.add_child(wall)
	return wall


static func spawn_training_target(parent: Node, pos: Vector2) -> BioCellActor:
	var cell := _make_actor(parent, "TrainingTarget", pos, BioTrainingCombatant.new())
	cell.set_meta("training", true)
	cell.add_to_group("training_targets")
	cell.combatant.configure("practice", BioActor.Team.VIRUS, 100, 100, 0)
	cell.combatant.set_process(false)
	cell.set_physics_process(false)
	var body := BioCellBody.new()
	body.configure(0.65, BioArt.CYAN, BioArt.JADE, 0, 0, 0, 8)
	cell.add_child(body)
	var label := Label.new()
	label.text = "ALVO DE TREINO\nInofensivo · sem recompensas"
	label.position = Vector2(-110, -68)
	label.size.x = 220
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	cell.add_child(label)
	var feedback := BioHitFeedback.new()
	feedback.configure(cell, body, BioArt.CYAN)
	cell.add_child(feedback)
	return cell


static func _make_actor(parent: Node, node_name: String, pos: Vector2, custom_combatant: BioCombatant = null) -> BioCellActor:
	var actor := BioCellActor.new()
	actor.name = node_name
	actor.position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.5 * BioArt.UNIT
	shape.shape = circle
	actor.add_child(shape)
	var combatant := custom_combatant if custom_combatant != null else BioCombatant.new()
	combatant.name = "Combatant"
	actor.add_child(combatant)
	actor.combatant = combatant
	actor.add_to_group("cells")
	parent.add_child(actor)
	return actor
