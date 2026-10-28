extends TestCase
## E2, exploring the body: closed passages hold, niches shimmer and are reached, the compass leads to what the cell can reach, and the
## atlas remembers what the engine says was visited.

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _explore(lung_open: bool, found: Array = []) -> Dictionary:
	return {
		"passages": [
			{"id": "sinusoide", "from": "medula", "to": "sangue", "name": "Sinusoide", "open": true},
			{"id": "veia_cava", "from": "sangue", "to": "coracao", "name": "Vênula coletora", "open": true},
			{"id": "arteria_pulmonar", "from": "coracao", "to": "pulmao", "name": "Artéria pulmonar", "open": lung_open, "hint": "" if lung_open else "Só passa quem tem o citoesqueleto elástico."},
			{"id": "aorta_ascendente", "from": "coracao", "to": "aorta", "name": "Aorta ascendente", "open": true},
		],
		"niches": [
			{"id": "nicho-estroma", "region": "medula", "name": "Bolsa do estroma" if found.has("nicho-estroma") else "?", "found": found.has("nicho-estroma"), "hint": "" if found.has("nicho-estroma") else "brilho de cílios"},
			{"id": "bolsa-da-venula", "region": "sangue", "name": "?", "found": found.has("bolsa-da-venula"), "hint": "" if found.has("bolsa-da-venula") else "uma dobra da vênula"},
			{"id": "gruta-alveolar", "region": "pulmao", "name": "?", "found": false, "hint": "uma gruta entre os alvéolos"},
		],
	}


func test_a_closed_passage_holds_and_an_open_one_lets_go() -> void:
	world.exploration.apply(_explore(false))
	assert_eq(world.exploration.gate_count(), 1, "one membrane, across the pulmonary artery")
	var at := BioAnatomy.link_point(BioBodyMap.seed_value, &"arteria_pulmonar", 0.5)
	var start := (at["p"] as Vector2) * BioArt.UNIT - (at["dir"] as Vector2) * 4.0 * BioArt.UNIT
	world.player.global_position = start
	await tree.physics_frame
	world.player.velocity = Vector2.ZERO
	for frame in 150:
		world.player.set_intent(at["dir"])
		await tree.physics_frame
	var progress := (world.player.global_position - start).dot(at["dir"]) / BioArt.UNIT
	assert_true(progress < 4.0, "the membrane holds the cell back (it advanced %.1f units, the gate is 4 ahead)" % progress)
	world.exploration.apply(_explore(true))
	await tree.process_frame
	assert_eq(world.exploration.gate_count(), 0, "with the key the membrane is gone")


func test_niches_appear_only_where_the_engine_whispers_and_are_reached() -> void:
	world.exploration.apply(_explore(false))
	assert_eq(world.exploration.niche_count(), 3, "three niches with hints")
	var reached: Array[String] = []
	world.exploration.niche_reached.connect(func(id: String) -> void: reached.append(id))
	world.player.global_position = BioBodyMap.niche_px("nicho-estroma", &"medula")
	await tree.create_timer(0.3).timeout
	assert_eq(reached, ["nicho-estroma"] as Array[String], "arriving at the niche tells the engine once")
	world.exploration.apply(_explore(false, ["nicho-estroma"]))
	await tree.process_frame
	assert_eq(world.exploration.niche_count(), 2, "a found niche is gone")
	assert_true(BioAnatomy.in_body(BioBodyMap.seed_value, BioBodyMap.niche_px("gruta-alveolar", &"pulmao") / BioArt.UNIT), "niches hide inside the body")


func test_the_compass_leads_to_the_nearest_niche_the_cell_can_reach() -> void:
	world.exploration.apply(_explore(false))
	var from_marrow := world.exploration.compass(BioBodyMap.center_px(&"medula") + Vector2(40.0, 0.0), &"medula")
	assert_eq(str(from_marrow["hint"]), "brilho de cílios", "in the marrow the nearest is the marrow's own")
	world.exploration.apply(_explore(false, ["nicho-estroma"]))
	var onward := world.exploration.compass(BioBodyMap.center_px(&"medula"), &"medula")
	assert_eq(str(onward["hint"]), "uma dobra da vênula", "then it leads on to the venule, never into the closed lung")
	assert_true((onward["target"] as Vector2).x > 0.0, "and the trail points towards the vessel that goes there")
	world.exploration.apply(_explore(false, ["nicho-estroma", "bolsa-da-venula"]))
	assert_true(world.exploration.compass(BioBodyMap.center_px(&"coracao"), &"coracao").is_empty(), "with the lung closed there is nothing left that can be reached")
	world.exploration.apply(_explore(true, ["nicho-estroma", "bolsa-da-venula"]))
	var lung := world.exploration.compass(BioBodyMap.center_px(&"coracao"), &"coracao")
	assert_eq(str(lung["hint"]), "uma gruta entre os alvéolos", "once the lung opens, the trail leads there")


func test_the_engines_memory_changes_nothing_on_an_atlas_without_fog() -> void:
	assert_true(world.atlas.knows(&"pulmao"), "the lung is already on the map")
	world.atlas.merge(["medula", "sangue", "pulmao", "lugar-que-nao-existe"])
	assert_true(not world.atlas.knows(&"lugar-que-nao-existe"), "and unknown places are ignored")


func test_the_advisors_route_leads_the_compass() -> void:
	var explore := _explore(true)
	explore["route"] = "bolsa-da-venula"
	world.exploration.apply(explore)
	var trail := world.exploration.compass(BioBodyMap.center_px(&"medula"), &"medula")
	assert_eq(str(trail["hint"]), "uma dobra da vênula", "even with a closer niche, the route is the advisor's pick")
	explore["route"] = ""
	world.exploration.apply(explore)
	assert_eq(str(world.exploration.compass(BioBodyMap.center_px(&"medula"), &"medula")["hint"]), "brilho de cílios", "without a route, the nearest leads")


func test_the_codex_shows_what_is_known_and_hides_the_rest() -> void:
	var codex := [
		{"id": "cx-medula", "kind": "regiao", "title": "A medula óssea", "unlocked": true, "text": "A fábrica do sangue."},
		{"id": "cx-alveolos", "kind": "regiao", "title": "???", "unlocked": false},
		{"id": "cx-febre", "kind": "corpo", "title": "???", "unlocked": false},
	]
	world.codex_panel.set_data(codex, [])
	assert_eq(world.codex_panel.unlocked_count(), 1, "one entry unlocked")
	world.codex_panel.toggle()
	assert_true(world.codex_panel.is_open(), "B opens the codex")
	world.codex_panel.toggle()


func test_adapting_to_a_place_helps_the_cell_only_there() -> void:
	world.set_adapted(["medula"])
	assert_near(world.player.combatant.actor.vitals.regen_scale, 1.15, 0.0001, "in the marrow the adapted cell regenerates faster")
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	await tree.create_timer(0.5).timeout
	assert_near(world.player.combatant.actor.vitals.regen_scale, 1.0, 0.0001, "elsewhere it does not")
	world.set_adapted([])
