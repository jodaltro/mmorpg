extends TestCase
## Every organ always has work and a health the player can read; what the player does shows in the panel.

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


func _organ(health: int = 60, mine: int = 0) -> Dictionary:
	return {"id": "pele", "name": "Pele", "health": health, "metrics": [{"id": "ferida", "label": "Abertura da ferida", "value": 80, "raw": 20}, {"id": "desgaste", "label": "Desgaste do tecido", "value": 40, "raw": 60}],
		"needs": [{"role": "cura", "weight": 3, "covered": 1}, {"role": "combate", "weight": 1, "covered": 0}], "crisis": "", "here": 1, "mine": mine, "deeds": []}


func test_every_region_has_routine_work_named_for_the_organ() -> void:
	for region in BioBodyMap.NAMES:
		if not BioTerrainRules.PROPS.has("organ-%s" % region):
			continue
		var verbs := BioTerrainRules.verbs_for("organ-%s" % region)
		assert_true(verbs.size() >= 2, "%s has at least two kinds of routine work" % region)
		for v in verbs:
			assert_eq(BioTerrainRules.action(v, "organ-%s" % region), "terreno-%s-organ-%s" % [v, region], "the engine action")
	for region in ["pele", "medula", "sangue", "coracao", "pulmao", "aorta", "figado", "baco", "intestino", "rim", "linfonodo", "cerebro"]:
		assert_true(BioTerrainRules.PROPS.has("organ-%s" % region), "%s has props for its routine" % region)


func test_words_and_colours_of_health() -> void:
	assert_eq(BioOrganRules.health_word(20), "crítica")
	assert_eq(BioOrganRules.health_word(100), "ótima")
	assert_true(BioOrganRules.health_color(90).g > BioOrganRules.health_color(20).g, "green is healthier than red")
	assert_eq(BioOrganRules.delta_text(70, 60), "+10%")
	assert_eq(BioOrganRules.delta_text(60, 60), "estável")
	assert_eq(BioOrganRules.deed_label("terreno-curar-organ-figado"), "Curar")
	assert_eq(BioOrganRules.deed_label("entregar-fibrina"), "Entrega")


func test_the_organ_panel_shows_the_organ_and_the_players_own_work() -> void:
	world.tutorial.completed = true
	world.player.global_position = BioBodyMap.center_px(&"pele")
	for i in 4:
		await tree.process_frame
	world.apply_engine_organs([_organ(60)])
	world.organ_panel._in = 0.0
	world.organ_panel._refresh()
	assert_true(world.organ_panel.is_shown(), "the organ the player stands in is always on screen")
	assert_eq(world.organ_panel.entered_health(), 60, "the health when they arrived is the starting point")
	world.organ_deed.emit("terreno-limpar-organ-pele")
	world.organ_deed.emit("terreno-limpar-organ-pele")
	assert_eq(world.organ_panel.log_lines().size(), 1, "the same work is counted, not repeated")
	assert_eq(int(world.organ_panel.log_lines()[0]["count"]), 2)
	world.apply_engine_organs([_organ(68, 2)])
	world.organ_panel._refresh()
	assert_eq(BioOrganRules.delta_text(68, world.organ_panel.entered_health()), "+8%", "the health moved with the work")


func test_an_organ_without_a_crisis_has_props_to_work_on() -> void:
	world.player.global_position = BioBodyMap.center_px(&"pele")
	for i in 4:
		await tree.process_frame
	world.terrain._look_in = 0.0
	await tree.process_frame
	await tree.process_frame
	assert_eq(world.terrain.current_def(), "organ-pele", "no crisis: the organ's own routine")
	assert_true(not world.terrain.props().is_empty(), "there is always something to do")
	var can := BioOrganRules.can_do("pele", "cura", false, "")
	assert_true((can["mine"] as Array).size() > 0 and (can["others"] as Array).size() > 0, "some work is the calling's and some only other callings'")
