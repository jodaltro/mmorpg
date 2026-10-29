extends TestCase
## Carrying help to a crisis: loads in the organ, a place of the tissue that needs them, and a delivery that is a confirmed deed.

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _skin_crisis(severity: int, tick: int = 10) -> Dictionary:
	return {"tick": tick, "quests": [], "others": [], "signs": [], "beliefs": [], "events": [], "skills": [], "society": [],
		"conflicts": {"revision": 1, "focus": "c1", "active": [{"id": "c1", "def": "ferida-na-pele", "title": "Ferida na pele", "phase": "active",
			"region": "pele", "revision": 1, "since": 5, "severity": severity, "peak": 60, "metrics": []}], "recent": []}}


func test_every_crisis_has_something_to_carry_and_a_place_for_it() -> void:
	for def in BioConflictFocus.ORGAN:
		assert_true(BioCargoRules.has(def), "%s has a load and a place" % def)
		var c := BioCargoRules.of(def)
		assert_true(str(c["action"]).begins_with("entregar-"), "%s is delivered by an engine action" % def)
		assert_true(BioCargoRules.hint(def).contains(str(c["cargo"])), "the card says what to carry")
	assert_eq(BioCargoRules.healed({"severity": 60, "peak": 60, "phase": "active"}), 0.0, "as bad as it got: the place looks sick")
	assert_eq(BioCargoRules.healed({"severity": 0, "peak": 60, "phase": "contained"}), 1.0, "no severity left: it looks calm")
	var site := BioCargoRules.site_px("ferida-na-pele", &"pele")
	for i in BioCargoRules.ITEMS:
		var p := BioCargoRules.source_px("ferida-na-pele", &"pele", i, 0)
		assert_eq(BioBodyMap.region_of(p), &"pele", "a load lies in the organ of its crisis")
		assert_true(p.distance_to(site) >= BioCargoRules.SOURCE_MIN_UNITS * BioArt.UNIT * 0.99, "and away from the place: carrying is a walk")


func test_the_cell_picks_up_a_load_drags_it_and_delivering_it_is_a_confirmed_deed() -> void:
	world.player.global_position = BioBodyMap.center_px(&"pele")
	for i in 4:
		await tree.process_frame
	world.sync.apply_view(_skin_crisis(50))
	world.cargo._look_in = 0.0
	await tree.process_frame
	await tree.process_frame
	assert_eq(world.cargo.current_def(), "ferida-na-pele", "the crisis of the organ has its place and loads")
	assert_true(is_instance_valid(world.cargo.site), "the place is in the tissue")
	assert_eq(world.cargo.loads(), BioCargoRules.ITEMS, "a few loads lie around")
	var deeds: Array = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	world.player.global_position = world.cargo._loads[0]["pos"]
	await tree.process_frame
	await tree.process_frame
	assert_eq(world.cargo.carrying, 0, "touching a load picks it up")
	assert_true(world.cargo.site.waiting, "and the place calls for it")
	world.player.global_position = world.cargo.site.global_position
	for i in 30:  # the load is dragged behind the cell: give it a moment to follow
		await tree.create_timer(0.1).timeout
		if not deeds.is_empty():
			break
	assert_eq(deeds, ["entregar-fibrina"], "dropping it on the place is the crisis's confirmed deed")
	assert_eq(world.cargo.carrying, -1, "and the cell carries nothing again")
	world.sync.apply_view(_skin_crisis(10, 11))
	await tree.create_timer(BioCargoDirector.LOOK_SECONDS + 0.2).timeout
	assert_true(world.cargo.site.healed > 0.5, "the place heals with the crisis's numbers")


func test_while_a_load_is_carried_the_guide_leads_to_its_place() -> void:
	world.tutorial.completed = true
	world.player.global_position = BioBodyMap.center_px(&"pele")
	for i in 4:
		await tree.process_frame
	world.sync.apply_view(_skin_crisis(50))
	await tree.create_timer(BioCargoDirector.LOOK_SECONDS + 0.2).timeout
	world.player.global_position = world.cargo._loads[0]["pos"]
	await tree.create_timer(0.3).timeout
	assert_eq(world.cargo.carrying, 0, "the load is picked up")
	assert_true(world.journey.has_manual_destination(), "and the guide now leads to its place")
	world.player.global_position = world.cargo.site.global_position
	await tree.create_timer(0.5).timeout
	assert_true(not world.journey.has_manual_destination(), "delivered, the guide lets go of the place")
