extends TestCase

var world: BioWorld

func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	await tree.process_frame

func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func test_tutorial_handoff_and_menu_suppress_trail() -> void:
	var guide := world.journey
	guide._process(0)
	assert_true(not guide._card.visible and not guide.has_target)
	world.tutorial.completed = true
	guide._process(0)
	assert_true(guide._card.visible and guide.has_target)
	assert_true(guide._card.text.contains("Sangue"))
	guide.open()
	guide._process(0)
	assert_true(not guide._card.visible and not guide._ink.visible and guide.has_target, "menus hide ink without forgetting the route")
	guide.close()
	assert_true(guide.blocks_pointer(), "closing the coach cannot leak a click into combat")
	world.tutorial.start(true)
	guide._process(0)
	assert_true(not guide._card.visible, "replaying tutorial hides post-tutorial guidance")

func test_route_follows_vessel_and_honors_closed_passage() -> void:
	var goal := BioBodyMap.center_px(BioBodyMap.SANGUE)
	var point := world.journey.waypoint(goal)
	assert_true(not point.is_empty())
	assert_true(point.at.distance_to(world.player.position) < goal.distance_to(world.player.position), "use a nearby vessel waypoint, not a distant wall-crossing arrow")
	world.exploration.passages = [{"from": "medula", "to": "sangue", "open": false}]
	assert_true(world.journey.waypoint(goal).is_empty())
	world.exploration.passages[0]["open"] = true
	assert_true(not world.journey.waypoint(goal).is_empty())

func test_real_mission_takes_priority_without_accepting_offers() -> void:
	world.sync.system.set_active({"def": "primeiro-mergulho", "title": "Missão real", "objective": "Entre no sangue"})
	var next := world.journey.recommendation()
	assert_eq(next.title, "Missão real")
	assert_eq(next.at, BioBodyMap.center_px(BioBodyMap.SANGUE))
	world.sync.system.set_active({"def": "dynamic-unknown", "title": "Outra missão", "objective": "Objetivo do motor"})
	next = world.journey.recommendation()
	assert_eq(next.detail, "Objetivo do motor")
	assert_true(not next.has("at"), "never guess the destination of an unknown mission")
	world.sync.system.set_active({})
	world.sync.system.show_offer({"key": "test", "title": "Ajude o corpo"}, "")
	assert_eq(world.journey.recommendation().title, "Responda ao chamado")
	assert_true(world.sync.system._active.is_empty(), "reading a recommendation cannot accept a quest")

func test_atlas_lists_known_dungeons_with_large_buttons_and_routes_selection() -> void:
	world.atlas._panel.size = Vector2(600, 260)
	# draw callback builds the exact same hit/list data used by touch input.
	world.atlas.toggle()
	await tree.process_frame
	world.atlas.show_places()
	var found := false
	for child in world.atlas._info.content.get_children():
		if child is Button and child.text.contains("Granuloma"):
			found = true
			child.pressed.emit()
			assert_true(world.atlas._detail.text.contains("instância pessoal"))
			assert_true(world.atlas._detail.text.contains("indisponível"))
			world.atlas._go.pressed.emit()
			break
	assert_true(found, "known dungeon has a readable, tappable list entry")
	assert_eq(world.journey._pinned.get("at"), world.gate.global_position)
	assert_true(not world.atlas.is_open(), "marking a route closes the map")

func test_marked_destination_clears_on_arrival_and_dungeon_hides_guide() -> void:
	world.tutorial.completed = true
	world.journey.pin(Vector2.ZERO, "Refúgio")
	world.player.position = Vector2.ZERO
	world.journey._process(0)
	assert_true(world.journey._pinned.is_empty())
	world.dungeon.active = true
	world.journey._process(0)
	assert_true(not world.journey._card.visible and not world.journey.has_target)
	world.dungeon.active = false
	world.player.set_active(false)
	world.journey._process(0)
	assert_true(not world.journey._card.visible and not world.journey.has_target, "death hides guidance")

func test_first_blood_objectives_use_confirmed_counts() -> void:
	world.region = BioBodyMap.SANGUE
	world.player.position = BioBodyMap.center_px(world.region)
	var enemy := BioFactory.spawn_virus(world, world.player.position + Vector2(100,0), world.player).get_parent() as BioCellActor
	var next := world.journey.recommendation()
	assert_true(next.title.contains("Derrote um vírion"))
	assert_eq(next.at, enemy.position)
	world.sync.link.view = {"self": {"num": {"abates": 1, "nutrientes": 2}}}
	next = world.journey.recommendation()
	assert_true(next.title.contains("2/5"))
	world.sync.link.view.self.num.nutrientes = 5
	assert_true(not world.journey.recommendation().title.contains("/5"))

func test_pending_opening_offer_and_gene_notification_keep_the_trail() -> void:
	world.tutorial.completed = true
	world.sync.system.show_offer({"key":"first", "def":"primeiro-mergulho", "title":"Primeira travessia"}, "")
	world.tray.set_call("gene-reward", "mutation", "Gene conquistado", "biblioteca")
	world.journey._process(0)
	assert_true(world.journey.has_target and world.journey._ink.visible, "a notification cannot erase the route")
	assert_eq(world.journey.recommendation().at, BioBodyMap.center_px(BioBodyMap.SANGUE))
	world.tray.clear_call("gene-reward")
	world.journey._process(0)
	assert_true(world.journey._card.visible and world.journey.has_target)
