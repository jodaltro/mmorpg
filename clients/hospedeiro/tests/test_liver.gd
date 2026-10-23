extends TestCase
## The liver (E3): a region at the end of the aorta, toxin motes the cell filters (at a cost, unless it has peroxisomes) and nutrients
## that are also kept as glycogen.

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


func _actor() -> BioActor:
	return BioActor.new("c", BioActor.Team.CELL, BioVitals.new(100.0, 50.0, 5.0))


func test_the_liver_is_a_place_joined_to_the_aorta() -> void:
	assert_true(BioAnatomy.region_def(BioBodyMap.FIGADO).size() > 0, "the liver is in the body")
	var path := BioAnatomy.route(BioBodyMap.seed_value, &"aorta", &"figado")
	assert_true(path.size() > 2, "and there is a vessel from the aorta to it")
	assert_true(BioAnatomy.in_body(BioBodyMap.seed_value, BioBodyMap.center_px(BioBodyMap.FIGADO) / BioArt.UNIT), "its centre is inside the membrane")
	assert_true(BioAnatomy.within(&"aorta", 1).has(&"figado"), "one hop from the aorta")


func test_a_toxin_costs_the_membrane_unless_the_cell_has_peroxisomes() -> void:
	var plain := _actor()
	BioToxinRules.filter(plain, false)
	assert_near(plain.vitals.membrane, 100.0 - BioToxinRules.DAMAGE)
	var resistant := _actor()
	resistant.vitals.atp = 10.0
	BioToxinRules.filter(resistant, true)
	assert_near(resistant.vitals.membrane, 100.0)
	assert_near(resistant.vitals.atp, 10.0 + BioToxinRules.RESISTANT_ATP)


func test_the_liver_holds_toxins_only_when_it_is_awake() -> void:
	assert_eq(tree.get_nodes_in_group("toxins").size(), 0, "nothing in the marrow")
	world.debug_goto(BioBodyMap.FIGADO)
	world.region = BioBodyMap.FIGADO
	world._update_live()
	world._populate(true)
	var want := int(BioAnatomy.region_def(BioBodyMap.FIGADO)["toxins"])
	assert_eq(tree.get_nodes_in_group("toxins").size() >= want, true, "the liver fills with toxin motes")


func test_filtering_a_toxin_is_reported_and_pays_pressure() -> void:
	var seen := [0]
	world.toxin_filtered.connect(func() -> void: seen[0] += 1)
	world.debug_goto(BioBodyMap.FIGADO)
	world.region = BioBodyMap.FIGADO
	world._update_live()
	world._populate(true)
	var toxin := tree.get_nodes_in_group("toxins")[0] as BioToxin
	toxin.global_position = world.player.global_position
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(seen[0], 1, "touching a toxin filters it once")


func test_a_nutrient_in_the_liver_is_also_kept_as_glycogen() -> void:
	var kept := [0]
	world.glycogen_stored.connect(func() -> void: kept[0] += 1)
	world.region = BioBodyMap.MEDULA
	world.player.combatant.nutrient_consumed.emit(0)
	assert_eq(kept[0], 0, "elsewhere nothing is stored")
	world.region = BioBodyMap.FIGADO
	world.player.combatant.nutrient_consumed.emit(0)
	assert_eq(kept[0], 1, "in the liver it is")
