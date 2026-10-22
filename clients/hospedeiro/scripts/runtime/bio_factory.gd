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
	actor.combatant.genome_changed.connect(func(g: BioGenome) -> void:
		body.apply_genome(g)
		tail.apply_genome(g))

	var executor := BioAttackExecutor.new()
	executor.configure(actor.combatant, actor)
	actor.add_child(executor)
	executor.performed.connect(func(id: StringName, dir: Vector2) -> void:
		if id == BioAttackCatalog.FLAGELLUM_LASH:
			tail.lash(dir, actor.combatant.actor.attack_def(id).range_units, BioAttackExecutor.LASH_HALF_ANGLE)
		elif id == BioAttackCatalog.MEMBRANE_DASH:
			tail.whip(1.0))

	var controller := BioCellController.new()
	controller.name = "Controller"
	controller.configure(actor, executor)
	actor.add_child(controller)
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
	actor.add_child(brain)
	var feedback := BioHitFeedback.new()
	feedback.configure(actor, body, BioArt.CRIMSON)
	actor.add_child(feedback)
	return brain


static func spawn_projectile(parent: Node, owner_combatant: BioCombatant, def: BioAttackDef, pos: Vector2, direction: Vector2) -> BioProjectile:
	var projectile := BioProjectile.new()
	projectile.name = "ToxinSpit"
	projectile.position = pos
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


static func _make_actor(parent: Node, node_name: String, pos: Vector2) -> BioCellActor:
	var actor := BioCellActor.new()
	actor.name = node_name
	actor.position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.5 * BioArt.UNIT
	shape.shape = circle
	actor.add_child(shape)
	var combatant := BioCombatant.new()
	combatant.name = "Combatant"
	actor.add_child(combatant)
	actor.combatant = combatant
	actor.add_to_group("cells")
	parent.add_child(actor)
	return actor
