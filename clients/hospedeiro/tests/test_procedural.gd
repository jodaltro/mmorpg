extends TestCase
## The wild things of each organ: a bestiary per region, every kind defined, and what lives in the newest places of the body.

var world: BioWorld

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


func test_each_organ_has_its_own_wild_things() -> void:
	assert_eq(BioBestiary.natives(&"sangue"), [[&"virion", 100]], "the blood has only its virions")
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for region in [&"coracao", &"pulmao", &"aorta", &"figado"]:
		var kinds := {}
		for i in 80:
			kinds[BioBestiary.pick(region, rng)] = true
		seen[region] = kinds
		assert_true(kinds.size() >= 2, "%s has more than one kind" % region)
		for kind in kinds:
			if kind != BioBestiary.VIRION:
				assert_true(not BioEnemyCatalog.enemy(kind).is_empty(), "%s is defined" % kind)
	assert_true(seen[&"coracao"].has(&"trombo") and seen[&"pulmao"].has(&"pneumococo") and seen[&"aorta"].has(&"embolo") and seen[&"figado"].has(&"plasmodio"), "each organ its own")
	assert_true(not seen[&"pulmao"].has(&"plasmodio") and not seen[&"figado"].has(&"trombo"), "and not each other's")


func test_the_new_places_have_their_own_wild_things() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var expected := {&"pele": [&"estafilococo", &"fungo_da_pele"], &"linfonodo": [&"micobacteria_do_no", &"celula_metastatica"], &"cerebro": [&"ameba_cerebral", &"agregado_amiloide"]}
	for region in expected:
		var seen := {}
		for i in 120:
			seen[BioBestiary.pick(region, rng)] = true
		for kind in expected[region]:
			assert_true(seen.has(kind), "%s hosts %s" % [region, kind])
			assert_true(not BioEnemyCatalog.enemy(kind).is_empty() and float(BioEnemyCatalog.enemy(kind)["hp"]) > 0.0, "%s is defined" % kind)
		assert_true(seen.has(BioBestiary.VIRION), "%s still gets the odd virion" % region)
	assert_eq(BioEnemyCatalog.enemy(&"ameba_cerebral")["split"]["kind"], &"ameba_filha", "the brain amoeba divides into an existing kind")
	assert_true(not BioEnemyCatalog.enemy(&"ameba_filha").is_empty(), "and the daughter is defined")


func test_wild_things_live_in_their_organ_and_pay_in_pressure() -> void:
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.FIGADO)
	for i in 3:
		await tree.process_frame
	world.virus_count = 12
	world._populate(true)
	var native := world.viruses().filter(func(v: Node) -> bool: return BioBodyMap.region_of((v as Node2D).global_position) == BioBodyMap.FIGADO)
	assert_true(native.size() >= 3, "the liver is populated")
	var kinds := {}
	for v in native:
		kinds[v.has_meta("base_speed")] = true
	assert_true(kinds.has(true), "and not only with virions")
	var seen := [0]
	world.virus_destroyed.connect(func() -> void: seen[0] += 1)
	world._spawn_native_at(&"pneumococo", world.player.global_position + Vector2(8.0, 0.0) * BioArt.UNIT)
	var cocci := world.viruses().filter(func(v: Node) -> bool: return (v as BioCellActor).combatant.actor.vitals.max_membrane == 18.0)
	assert_eq(cocci.size(), 2, "the cocci come in a pair")
	(cocci[0] as BioCellActor).combatant.died.emit((cocci[0] as BioCellActor).combatant)
	assert_eq(seen[0], 1, "a kill is reported like any virion's")
