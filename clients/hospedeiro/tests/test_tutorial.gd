extends TestCase

var world: BioWorld

func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	world.ensure_training_target()
	await tree.physics_frame

func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func test_guided_steps_require_real_movement_and_correct_practice_hit() -> void:
	var guide := world.tutorial
	assert_true(not guide.active, "tests never start onboarding automatically")
	guide.start()
	guide._process(0)
	assert_true(not BioUi.captures_input(), "coach leaves game controls usable")
	guide.advance()
	guide._process(0)
	guide.advance()
	assert_eq(guide.step, 1, "next cannot skip required movement")
	world.player.position += Vector2.RIGHT * BioArt.UNIT * 2.1
	guide._process(0)
	guide.advance()
	assert_eq(guide.step, 2)
	guide._enter(3)
	var dummy: BioCellActor = tree.get_nodes_in_group("training_targets")[0]
	dummy.combatant.receive_hit(world.player.combatant, BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT))
	guide._process(0)
	assert_true(not guide._fulfilled, "a toxin cannot satisfy the melee lesson")
	dummy.combatant.receive_hit(world.player.combatant, BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH))
	guide._process(0)
	assert_true(guide._fulfilled, "only confirmed contact advances practice")
	guide._enter(4)
	guide._process(0)
	assert_true(not guide._fulfilled, "hits from earlier lessons do not skip this one")
	dummy.combatant.receive_hit(world.player.combatant, BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT))
	guide._process(0)
	assert_true(guide._fulfilled)

func test_practice_never_dies_rewards_or_moves_even_with_lethal_damage() -> void:
	var dummy: BioCellActor = tree.get_nodes_in_group("training_targets")[0]
	var deaths := [0]
	var kills := [0]
	dummy.combatant.died.connect(func(_who: BioCombatant) -> void: deaths[0] += 1)
	world.player.combatant.enemy_defeated.connect(func(_who: BioCombatant) -> void: kills[0] += 1)
	dummy.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"test", 0, 99999, 0, 10, 99, 0))
	dummy.apply_impulse(Vector2.RIGHT * 99)
	assert_eq(dummy.combatant.actor.vitals.membrane, 100.0)
	assert_eq(dummy.velocity, Vector2.ZERO)
	assert_eq(deaths[0], 0)
	assert_eq(kills[0], 0)
	assert_true(not dummy.is_in_group("viruses"), "training does not consume wild spawn quotas")
	var other := BioFactory.spawn_player(world, Vector2.ZERO)
	other.combatant.actor.id = "other"
	dummy.combatant.receive_hit(other.combatant, BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH))
	assert_eq(world.tutorial._practice_count(BioAttackCatalog.FLAGELLUM_LASH), 0, "another player's hit cannot complete your tutorial")

func test_sanctuary_rejects_spawns_and_blocks_wild_damage_only() -> void:
	world._spawn_virus_at(Vector2.ZERO)
	world._spawn_native_at(&"virion", Vector2.ZERO)
	assert_eq(world.viruses().size(), 0)
	var enemy := BioFactory.spawn_virus(world, Vector2.RIGHT * BioArt.UNIT * 20, world.player).get_parent() as BioCellActor
	enemy.set_meta("sanctuary_bound", true)
	var attack := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	var result := world.player.combatant.receive_hit(enemy.combatant, attack)
	assert_eq(result.outcome, BioActor.HitOutcome.IGNORED)
	assert_eq(world.player.combatant.actor.vitals.membrane, 100.0)
	enemy.remove_meta("sanctuary_bound")
	result = world.player.combatant.receive_hit(enemy.combatant, attack)
	assert_eq(result.outcome, BioActor.HitOutcome.HIT, "unmarked instance combat still works")

func test_wild_movement_cannot_cross_into_refuge() -> void:
	var outside := BioBodyMap.center_px(BioBodyMap.SANGUE)
	var enemy := BioFactory.spawn_virus(world, outside, world.player).get_parent() as BioCellActor
	enemy.set_meta("sanctuary_bound", true)
	enemy.position = Vector2.ZERO
	enemy._respect_sanctuary(outside)
	assert_eq(enemy.position, outside)
	assert_eq(enemy.velocity, Vector2.ZERO)
	assert_true(BioSanctuary.contains(world.seed_value, BioBodyMap.RESIDENTS["estroma"]))
	assert_true(not BioSanctuary.contains(world.seed_value, outside / BioArt.UNIT))

func test_pause_resume_and_locked_class_do_not_block_initial_tutorial() -> void:
	var guide := world.tutorial
	guide.start()
	guide._enter(6)
	guide._process(0)
	assert_true(guide._fulfilled, "newborns are taught locked class abilities without being granted one")
	guide.stop()
	assert_true(not guide.active)
	guide.start()
	assert_eq(guide.step, 6)
	guide._enter(11)
	guide._process(0)
	guide.advance()
	assert_true(guide.completed and not guide.active)
	guide.start(true)
	assert_eq(guide.step, 0)

func test_online_practice_replica_preserves_server_confirmation_by_player() -> void:
	var client := BioOnlineClient.new()
	client.world = world
	var replica := client._spawn({"kind":"training", "p":[144,-48]}) as BioCellActor
	client._apply_actor(replica, {"hp":100, "atp":100, "practice":{"nk-alfa":{"toxin_spit":2}}})
	assert_eq((replica.combatant as BioTrainingCombatant).practice["nk-alfa"]["toxin_spit"], 2)
	assert_eq(replica.collision_layer, 0, "replica never resolves local damage")
	assert_true(not replica.is_physics_processing())
	client.free()

func test_menu_lessons_observe_opened_windows_and_do_not_fake_quests() -> void:
	world.tutorial.start()
	world.tutorial._enter(9)
	world.tutorial._process(0)
	assert_true(not world.tutorial._fulfilled)
	world.sync.system.open_missions()
	world.tutorial._process(0)
	assert_true(world.tutorial._fulfilled)
	assert_true(not world.tutorial._card.visible, "reading the real window leaves every button accessible")
	world.sync.system.close_missions()
	world.tutorial._enter(10)
	world.tutorial._process(0)
	assert_true(not world.tutorial._fulfilled)
	world.body_panel.open()
	world.tutorial._process(0)
	assert_true(world.tutorial._fulfilled)
	world.body_panel.close()

func test_progress_survives_reload_and_invalid_step_is_bounded() -> void:
	var guide := world.tutorial
	guide.persistence_path = "user://tutorial_test_isolated.json"
	world.save_path = "test-only"
	guide.start()
	guide._enter(4)
	guide.stop()
	guide.step = 0
	guide._load_progress()
	assert_eq(guide.step, 4)
	var file := FileAccess.open(guide.persistence_path, FileAccess.WRITE)
	file.store_string('{"version":1,"step":999,"completed":false}')
	file.close()
	guide._load_progress()
	assert_eq(guide.step, BioTutorial.STEPS.size() - 1)
	DirAccess.remove_absolute(guide.persistence_path)
	world.save_path = ""

func test_mobile_highlights_real_controls_and_menu_card_does_not_cover_options() -> void:
	world._build_for_touch()
	world.tutorial.start()
	world.tutorial._enter(3)
	world.tutorial._process(0)
	assert_true(world.tutorial._target_rect().has_point(world.touch.attack_stick.get_global_rect().get_center()))
	world.touch.menu.tapped.emit()
	world.tutorial._enter(9)
	world.tutorial._process(0)
	assert_eq(world.tutorial._card.position.x, 12.0, "coach moves to the left margin when menu opens")
	world.touch.close()

func test_online_mobile_aim_can_find_noncolliding_confirmed_training_replica() -> void:
	world._build_for_touch()
	var client := BioOnlineClient.new()
	client.world = world
	world.online_client = client
	var dummy: BioCellActor = tree.get_nodes_in_group("training_targets")[0]
	dummy.collision_layer = 0
	world.touch._refresh_aim()
	assert_eq(world.touch._target, dummy)
	world.online_client = null
	client.free()

func test_spotlight_preserves_controls_and_has_separate_holes_for_practice() -> void:
	world._build_for_touch()
	world.tutorial.start()
	world.tutorial._enter(3)
	world.tutorial._process(0.5)
	assert_eq(world.tutorial._veil.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(world.tutorial._ink.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(world.tutorial._material.get_shader_parameter("hole_count"), 4, "attack, target, player and movement stay lit")
	assert_true(float(world.tutorial._material.get_shader_parameter("opacity")) > 0.5, "background dims after its entrance transition")
	assert_true(not BioUi.captures_input(), "spotlight never captures the highlighted controls")
