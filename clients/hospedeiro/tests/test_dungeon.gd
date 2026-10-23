extends TestCase

var world: BioWorld

const ROOMS := [
	{"id": "guarda-de-linfocitos", "name": "A guarda de linfócitos", "kind": "guard"},
	{"id": "parede-de-macrofagos", "name": "A parede de macrófagos", "kind": "wall"},
	{"id": "anel-interno", "name": "O anel interno", "kind": "wall"},
	{"id": "nucleo-necrotico", "name": "O núcleo necrótico", "kind": "core"},
	{"id": "bacilo", "name": "O bacilo", "kind": "boss"},
]


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _run(room: int = 0, modifier: String = "") -> Dictionary:
	var mod: Variant = {"id": modifier, "name": modifier, "desc": ""} if modifier != "" else null
	return {"state": "active", "seed": 123456, "room": room, "rooms": ROOMS, "modifier": mod}


func _kill_all() -> void:
	for e in world.dungeon.enemies():
		(e as BioCellActor).combatant.actor.vitals.take_damage(9999.0)
		e.queue_free()
	await tree.process_frame


func test_the_plan_is_the_same_for_the_same_seed_and_changes_with_modifiers() -> void:
	var a := BioDungeonPlan.room(99, 0, "guard", "")
	var b := BioDungeonPlan.room(99, 0, "guard", "")
	assert_eq(str(a["enemies"]), str(b["enemies"]), "same seed, same room")
	assert_true(str(a["enemies"]) != str(BioDungeonPlan.room(100, 0, "guard", "")["enemies"]), "another seed, another room")
	var patrol := (a["enemies"] as Array).size()
	assert_true(patrol >= 2 and patrol <= 4, "a patrol of two to four")
	assert_true((BioDungeonPlan.room(99, 0, "guard", "guarda-redobrada")["enemies"] as Array).size() > patrol, "a doubled guard is bigger")
	assert_true((BioDungeonPlan.room(99, 3, "core", "guarda-redobrada")["enemies"] as Array).size() < (BioDungeonPlan.room(99, 3, "core", "")["enemies"] as Array).size(), "and fewer later")
	assert_true((BioDungeonPlan.room(99, 3, "core", "necrose-viva")["enemies"] as Array).size() > (BioDungeonPlan.room(99, 3, "core", "")["enemies"] as Array).size(), "living necrosis adds bacilli")
	var boss := BioDungeonPlan.room(99, 4, "boss", "")
	assert_eq((boss["enemies"] as Array).filter(func(e: Dictionary) -> bool: return e["type"] == &"bacilo_mestre").size(), 1, "one boss")
	assert_true(float(BioDungeonPlan.enemy(&"bacilo_mestre")["hp"]) > 200.0, "and it is tough")


func test_a_run_builds_a_chamber_and_clears_room_by_room() -> void:
	var cleared: Array[int] = []
	world.dungeon.room_cleared.connect(func(i: int) -> void: cleared.append(i))
	world.dungeon.start(_run())
	await tree.physics_frame
	assert_true(world.dungeon.active, "the run is on")
	assert_true(world.player.global_position.distance_to(BioDungeon.CENTER) < 9.0 * BioArt.UNIT, "the cell is inside the chamber")
	assert_true(world.dungeon.enemies().size() >= 2 and world.dungeon.enemies().size() <= 4, "the first room has its patrol")
	await tree.create_timer(0.8).timeout
	assert_eq(cleared.size(), 0, "not clear while they live")
	await _kill_all()
	await tree.create_timer(0.3).timeout
	assert_eq(cleared, [0] as Array[int], "clearing the room is reported once")
	world.dungeon.advance(1)
	await tree.physics_frame
	assert_eq(world.dungeon.room_index, 1, "the next room")
	assert_true(world.dungeon.enemies().size() >= 2, "a bruiser and its fodder")
	world.dungeon.finish(true)
	await tree.process_frame
	assert_true(not world.dungeon.active, "finished")
	assert_eq(world.dungeon.enemies().size(), 0, "nothing is left behind")
	assert_true(world.player.global_position.distance_to(world.gate.global_position) < 5.0 * BioArt.UNIT, "back at the entrance")


func test_the_engine_view_drives_the_run() -> void:
	world.sync.apply_view({"tick": 1, "dungeon": {"available": [{"id": "granuloma", "eligible": true}]}})
	assert_true(world.gate.eligible, "the entrance opens for a ready cell")
	world.sync.apply_view({"tick": 2, "dungeon": {"available": [{"id": "granuloma", "eligible": false}]}})
	assert_true(not world.gate.eligible and not world.gate.hint.is_empty(), "and closes with a hint")
	world.sync.apply_view({"tick": 3, "dungeon": {"available": [], "run": _run(0, "em-febre")}})
	assert_true(world.dungeon.active and world.dungeon.modifier == "em-febre", "an active run builds the chamber with its modifier")
	world.sync.apply_view({"tick": 4, "dungeon": {"available": [], "run": _run(1, "em-febre")}})
	assert_eq(world.dungeon.room_index, 1, "the engine moved to the next room")
	var done := _run(4, "em-febre")
	done["state"] = "cleared"
	world.sync.apply_view({"tick": 5, "dungeon": {"available": [], "run": done}})
	assert_true(not world.dungeon.active, "a cleared run closes the chamber")


func test_modifiers_change_the_run() -> void:
	world.dungeon.start(_run(3, "em-febre"))
	await tree.physics_frame
	var vitals := world.player.combatant.actor.vitals
	var before := vitals.membrane
	await tree.create_timer(1.0).timeout
	assert_true(vitals.membrane < before, "the fever drains the cell")
	world.dungeon.finish(false)
	var regen := vitals.atp_regen_per_second
	world.dungeon.start(_run(0, "ar-rarefeito"))
	assert_near(vitals.atp_regen_per_second, regen * 0.45, 0.01, "thin air slows ATP")
	world.dungeon.finish(false)
	assert_near(vitals.atp_regen_per_second, regen, 0.01, "and gives it back when the run ends")
	world.dungeon.start(_run(3, "quorum-ativo"))
	await tree.create_timer(0.7).timeout
	var bacillus: BioCellActor = null
	for e in world.dungeon.enemies():
		if str(e.get_meta("kind", "")) == "bacilo":
			bacillus = e
	assert_true(bacillus != null and bacillus.max_speed_units > float(bacillus.get_meta("base_speed")) * 1.3, "quorum emitters make the others faster")


func test_the_boss_slam_hurts_only_inside_its_radius() -> void:
	world.dungeon.start(_run(4))
	await tree.physics_frame
	var boss: BioCellActor = null
	for e in world.dungeon.enemies():
		if str(e.get_meta("kind", "")) == "bacilo_mestre":
			boss = e
	assert_true(boss != null, "the boss is in the last room")
	var slam: BioBossSlam = null
	for child in boss.get_children():
		if child is BioBossSlam:
			slam = child
	assert_true(slam != null, "with its slam")
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	world.player.global_position = boss.global_position + Vector2(9.0, 0.0) * BioArt.UNIT
	slam._slam()
	assert_near(vitals.membrane, vitals.max_membrane, 0.001, "far away: untouched")
	boss.combatant.actor._ready_at.clear()
	world.player.global_position = boss.global_position + Vector2(2.0, 0.0) * BioArt.UNIT
	slam._slam()
	assert_true(vitals.membrane < vitals.max_membrane, "close: hit")


func test_dying_in_the_dungeon_reports_the_failure() -> void:
	var failed := [0]
	world.dungeon.run_failed.connect(func() -> void: failed[0] += 1)
	world.dungeon.start(_run(2))
	await tree.physics_frame
	world.player.combatant.actor.vitals.take_damage(9999.0)
	world.player.combatant.receive_hit(world.player.combatant, BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH))
	world.player.combatant.died.emit(world.player.combatant)
	await tree.process_frame
	assert_eq(failed[0], 1, "the failure is reported to the engine once")
	assert_true(not world.dungeon.active, "and the run is over")


func test_a_newcomer_who_only_walks_about_survives_the_first_room() -> void:
	world.dungeon.start(_run(0, "em-febre"))
	await tree.physics_frame
	assert_true(world.dungeon.grace_left() > 2.0, "the enemies hold still at first")
	var first := world.dungeon.enemies()[0] as BioCellActor
	var at := first.global_position
	await tree.create_timer(1.5).timeout
	assert_true(first.global_position.distance_to(at) < 4.0, "and really do not move during the grace period")
	await tree.create_timer(12.0).timeout
	assert_true(world.player.combatant.actor.vitals.is_alive(), "twelve idle seconds into the room the cell is still alive")


func test_falling_in_the_dungeon_brings_the_cell_back_to_the_portal() -> void:
	world.dungeon.start(_run(1))
	await tree.physics_frame
	world.player.combatant.actor.vitals.take_damage(9999.0)
	world.player.combatant.died.emit(world.player.combatant)
	await tree.process_frame
	assert_true(world.hud.banner_text().contains("granuloma"), "the banner says where the cell fell")
	world.respawn_player()
	assert_true(world.player.is_active(), "it is back")
	assert_true(world.player.global_position.distance_to(world.gate.global_position) < 5.0 * BioArt.UNIT, "at the portal, not in the marrow")


func test_clearing_a_room_gives_a_breath() -> void:
	world.dungeon.start(_run(0))
	await tree.physics_frame
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = 20.0
	await _kill_all()
	await tree.create_timer(1.2).timeout
	assert_true(vitals.membrane >= 55.0, "the membrane is partly restored between rooms")
