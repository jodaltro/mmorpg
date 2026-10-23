extends TestCase


func test_every_mutation_has_a_known_organelle_and_many_kinds_are_used() -> void:
	var kinds := {}
	for id in BioGeneCatalog.all_ids():
		var mark := BioGeneCatalog.get_gene(id).mark
		assert_true(BioOrganelles.SCALE.has(str(mark.get("kind", ""))), "%s has a known organelle kind (%s)" % [id, mark.get("kind", "")])
		kinds[mark["kind"]] = true
	assert_true(kinds.size() >= 12, "a wide variety of organelles: %d kinds" % kinds.size())


func test_organelles_float_freely_but_never_leave_the_membrane() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.genome.lineage = &"macrofago"
	for id in BioGeneCatalog.class_ids(&"macrofago"):
		world.genome.equip(id)
	world.player.combatant.set_genome(world.genome)
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	await tree.create_timer(0.3).timeout
	var start := {}
	for id in body.organelles():
		start[id] = (body.organelles()[id]["p"] as Vector2)
	var worst := 0.0
	var moved := 0.0
	for frame in 400:
		await tree.process_frame
		var rim := body.rim()
		var r := BioOrganelles.body_radius(rim)
		for id in body.organelles():
			var p: Vector2 = body.organelles()[id]["p"]
			var limit := BioOrganelles.rim_radius_at(rim, p.angle())
			worst = maxf(worst, p.length() / maxf(limit, 1.0))
			moved = maxf(moved, p.distance_to(start[id]) / r)
	assert_eq(body.organelles().size(), 6, "one organelle per mutation")
	assert_true(worst < 0.95, "none ever reaches the membrane (worst %f of the way out)" % worst)
	assert_true(moved > 0.3, "they drift about by themselves (moved %f body radii)" % moved)
	world.player.velocity = Vector2(2500.0, 0.0)  # a jolt must not throw them out either
	for frame in 60:
		await tree.process_frame
		var rim2 := body.rim()
		for id in body.organelles():
			var p2: Vector2 = body.organelles()[id]["p"]
			assert_true(p2.length() <= BioOrganelles.rim_radius_at(rim2, p2.angle()) * 0.95, "still inside after a jolt")
	world.genome.equipped = []
	world.player.combatant.set_genome(world.genome)
	await tree.process_frame
	assert_eq(body.organelles().size(), 0, "no mutation, no organelle")
	world.queue_free()
	await tree.process_frame


func test_the_ghost_body_keeps_them_inside_too() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.genome.lineage = &"linfocito_b"
	for id in BioGeneCatalog.class_ids(&"linfocito_b"):
		world.genome.equip(id)
	world.player.combatant.set_genome(world.genome)
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	body._ascend = 1.0
	for frame in 300:
		await tree.process_frame
		var rim := body.rim()
		for id in body.organelles():
			var p: Vector2 = body.organelles()[id]["p"]
			assert_true(p.length() <= BioOrganelles.rim_radius_at(rim, p.angle()) * 0.95, "inside the ghost silhouette")
	world.queue_free()
	await tree.process_frame
