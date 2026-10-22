extends TestCase

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""  # tests never touch the player's real save
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _idle_virus(pos: Vector2) -> BioCellActor:
	var brain := BioFactory.spawn_virus(world, pos, world.player)
	brain.set_process(false)
	return brain.get_parent() as BioCellActor


func _controller() -> BioCellController:
	return world.player.get_node("Controller") as BioCellController


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func test_world_boots_with_player_viruses_nutrients_and_frames_advance() -> void:
	assert_true(world.player != null, "player exists")
	assert_eq(world.viruses().size(), 6, "virus count")
	assert_true(world.nutrient_count() >= 45, "nutrients")
	assert_true(world.hud != null, "hud")
	var frame := Engine.get_process_frames()
	for i in 3:
		await tree.process_frame
	assert_true(Engine.get_process_frames() > frame, "frames advance")


func test_lash_damages_virus_using_catalog_value_and_respects_cooldown() -> void:
	var virus := _idle_virus(Vector2(1.2, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	var ctrl := _controller()
	ctrl.set_aim(Vector2.RIGHT)
	assert_eq(ctrl.lash(), BioActor.AttackStatus.STARTED, "first lash")
	var vit := virus.combatant.actor.vitals
	var dmg := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH).damage
	assert_near(vit.membrane, vit.max_membrane - dmg, 0.001, "damage from catalog")
	assert_eq(ctrl.lash(), BioActor.AttackStatus.ON_COOLDOWN, "second lash")
	assert_near(vit.membrane, vit.max_membrane - dmg, 0.001, "no extra damage on cooldown")


func test_lash_sweeps_the_tail() -> void:
	var tail := world.player.get_node_or_null("Flagellum") as BioFlagellum
	assert_true(tail != null, "player has a flagellum")
	if tail == null:
		return
	var ctrl := _controller()
	ctrl.set_aim(Vector2.RIGHT)
	assert_true(not tail.is_lashing(), "tail idle before lash")
	ctrl.lash()
	assert_true(tail.is_lashing(), "tail sweeping after lash")
	await _wait(0.4)
	assert_true(not tail.is_lashing(), "tail returns to rest")


func test_lash_does_not_hit_behind_the_player() -> void:
	var virus := _idle_virus(Vector2(-1.2, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	var ctrl := _controller()
	ctrl.set_aim(Vector2.RIGHT)
	ctrl.lash()
	var vit := virus.combatant.actor.vitals
	assert_near(vit.membrane, vit.max_membrane, 0.001, "virus behind is untouched")


func test_toxin_spit_projectile_hits_distant_virus() -> void:
	var virus := _idle_virus(Vector2(5.0, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	var ctrl := _controller()
	ctrl.set_aim(Vector2.RIGHT)
	assert_eq(ctrl.spit(), BioActor.AttackStatus.STARTED, "spit started")
	var vit := virus.combatant.actor.vitals
	var deadline := BioClock.now() + 2.0
	while vit.membrane >= vit.max_membrane and BioClock.now() < deadline:
		await tree.physics_frame
	assert_true(vit.membrane < vit.max_membrane, "projectile damaged the virus")


func test_nutrient_restores_atp() -> void:
	var vitals := world.player.combatant.actor.vitals
	vitals.try_spend_atp(60.0)
	var before := vitals.atp
	BioFactory.spawn_nutrient(world, world.player.global_position, BioNutrientRules.Kind.GLUCOSE)
	for i in 4:
		await tree.physics_frame
	assert_true(vitals.atp >= before + BioNutrientRules.GLUCOSE_ATP - 0.5, "glucose gave atp")


func test_virus_telegraphs_then_lunges_and_damages_player() -> void:
	var prey := world.player.combatant.actor.vitals
	var brain := BioFactory.spawn_virus(world, Vector2(3.0, 0.0) * BioArt.UNIT, world.player)
	var deadline := BioClock.now() + 8.0
	var saw_telegraph := false
	while prey.membrane >= prey.max_membrane and BioClock.now() < deadline:
		if is_instance_valid(brain) and brain.state_name() == "TELEGRAPH":
			saw_telegraph = true
		await tree.physics_frame
	assert_true(saw_telegraph, "lunge is telegraphed")
	assert_true(prey.membrane < prey.max_membrane, "lunge landed")


func test_death_shows_banner_and_respawn_restores_player() -> void:
	var attacker := _idle_virus(Vector2(30.0, 30.0) * BioArt.UNIT)
	var lunge := BioAttackCatalog.get_def(BioAttackCatalog.VIRAL_LUNGE)
	var i := 0
	while i < 12 and world.player.combatant.actor.vitals.is_alive():
		world.player.combatant.receive_hit(attacker.combatant, lunge)
		i += 1
	await tree.process_frame
	assert_true(not world.player.is_active(), "player deactivated")
	assert_true(world.hud.banner_text() != "", "banner shown")
	world.respawn_player()
	await tree.process_frame
	assert_true(world.player.is_active(), "player active again")
	assert_true(world.player.combatant.actor.vitals.is_alive(), "alive again")
	assert_eq(world.hud.banner_text(), "", "banner cleared")


func test_dash_moves_player_and_grants_invulnerability() -> void:
	var ctrl := _controller()
	ctrl.move(Vector2.RIGHT)
	assert_eq(ctrl.dash(), BioActor.AttackStatus.STARTED, "dash started")
	var start_x := world.player.global_position.x
	await _wait(0.2)
	assert_true(world.player.global_position.x - start_x > 1.5 * BioArt.UNIT, "dash covered distance")
	assert_true(world.player.combatant.actor.invulnerable_until > 0.0, "i-frames granted")


func test_pressure_offers_a_mutation_and_picking_reshapes_the_cell() -> void:
	world.add_pressure(BioMutationTracker.THRESHOLD)
	assert_true(world.tracker.has_offer(), "offer created")
	assert_true(world.panel.is_offer_visible(), "offer shown")
	var picked: StringName = world.tracker.offer[0]
	world.pick_mutation(0)
	assert_true(world.genome.has_gene(picked), "gene equipped")
	assert_true(not world.panel.is_offer_visible(), "offer hidden")
	assert_true(world.player.combatant.actor.genome == world.genome, "player expresses the genome")


func test_genome_persists_between_sessions() -> void:
	var path := "user://test_genome_%d.json" % Time.get_ticks_usec()
	world.save_path = path
	world.add_pressure(BioMutationTracker.THRESHOLD)
	var picked: StringName = world.tracker.offer[1]
	world.pick_mutation(1)
	var tracker := BioMutationTracker.new()
	var loaded := BioGenomeStore.load_state(path, tracker)
	assert_true(loaded.has_gene(picked), "saved gene reloads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
