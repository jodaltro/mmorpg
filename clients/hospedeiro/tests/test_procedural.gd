extends TestCase
## Procedural dungeons and the wild things of each organ: rooms drawn from the seed (shape, pillars, pools, who is in them), a cast of
## its own for every dungeon, spitters, nests and splitters, and a bestiary per region.

var world: BioWorld

const KINDS := ["guard", "wall", "core", "ambush", "pillars", "nest", "hazard", "boss"]


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


func _types(room: Dictionary) -> Array:
	return (room["enemies"] as Array).map(func(e: Dictionary) -> StringName: return e["type"])


func _run(dungeon: String, kind: String, seed_value: int = 4242) -> Dictionary:
	return {"dungeon": dungeon, "name": dungeon, "state": "active", "seed": seed_value, "room": 0, "rooms": [{"id": "x", "name": "x", "kind": kind}], "modifier": null}


func test_the_same_seed_gives_the_same_room_and_another_seed_another() -> void:
	for kind in KINDS:
		var a := BioDungeonPlan.room(31, 2, kind, "", "granuloma")
		var b := BioDungeonPlan.room(31, 2, kind, "", "granuloma")
		assert_eq(str(a), str(b), "%s: same seed, same room" % kind)
	var shapes := {}
	var radii := {}
	for seed_value in 20:
		var r := BioDungeonPlan.room(seed_value, 1, "wall", "", "granuloma")
		shapes[str(r["shape"]["kind"])] = true
		radii[snappedf(float(r["radius"]), 0.1)] = true
	assert_true(shapes.size() >= 2, "wall rooms are not always the same shape: %s" % [shapes.keys()])
	assert_true(radii.size() >= 8, "nor the same size")


func test_every_room_has_its_own_character() -> void:
	var ambush := BioDungeonPlan.room(7, 2, "ambush", "", "granuloma")
	assert_true((ambush["enemies"] as Array).size() >= 5 and float(ambush["grace"]) < 2.0, "an ambush is many, and does not wait")
	var pillars := BioDungeonPlan.room(7, 2, "pillars", "", "granuloma")
	assert_true((pillars["obstacles"] as Array).size() >= 4 and _types(pillars).has(&"bacilo_cuspidor"), "pillars hide spitters")
	var nest := BioDungeonPlan.room(7, 2, "nest", "", "granuloma")
	assert_true(_types(nest).has(&"colonia_de_bacilos"), "a nest has the nest")
	var hazard := BioDungeonPlan.room(7, 2, "hazard", "", "granuloma")
	assert_true((hazard["hazards"] as Array).size() >= 6, "a hazard room has pools")
	assert_true((BioDungeonPlan.room(7, 0, "guard", "", "granuloma")["obstacles"] as Array).is_empty(), "a guard room is bare")


func test_each_dungeon_has_its_own_cast() -> void:
	var gran := {}
	var cords := {}
	for seed_value in 12:
		for kind in KINDS:
			for t in _types(BioDungeonPlan.room(seed_value, 2, kind, "", "granuloma")):
				gran[t] = true
			for t in _types(BioDungeonPlan.room(seed_value, 2, kind, "", "cordoes-hepaticos")):
				cords[t] = true
	for t in gran:
		assert_true(not cords.has(t), "%s belongs to the granuloma only" % t)
	assert_true(cords.has(&"plasmodio") and cords.has(&"esporo_de_bile") and cords.has(&"cisto_hidatidico"), "the cords have a splitter, a spitter and a cyst")
	assert_true(gran.has(&"bacilo_cuspidor") and gran.has(&"colonia_de_bacilos"), "the granuloma a spitter and a colony")


func test_enemies_and_pillars_stay_inside_the_walls_of_any_shape() -> void:
	for seed_value in 25:
		for kind in KINDS:
			var room := BioDungeonPlan.room(seed_value, 1, kind, "", "cordoes-hepaticos")
			var base := float(room["radius"])
			for e in room["enemies"]:
				var reach := minf(float(e["radius"]) * base, 0.88 * BioDungeonPlan.wall_radius(room["shape"], base, float(e["angle"])))
				assert_true(reach <= BioDungeonPlan.wall_radius(room["shape"], base, float(e["angle"])), "an enemy of %s inside" % kind)
			for angle in 16:
				assert_true(BioDungeonPlan.wall_radius(room["shape"], base, angle * TAU / 16.0) > base * 0.6, "no wall pinches the room shut (%s, seed %d)" % [kind, seed_value])
			for o in room["obstacles"]:
				assert_true(Vector2.from_angle(float(o["angle"])).distance_to(Vector2.ZERO) > 0.0 and float(o["radius"]) <= 0.8, "pillars sit inside")


func test_a_pillared_room_builds_collision_and_a_pool_room_builds_hazards() -> void:
	world.dungeon.start(_run("granuloma", "pillars"))
	await tree.physics_frame
	assert_true(world.dungeon.obstacles.size() >= 4, "the room has its pillars")
	assert_true(world.dungeon.shape.has("kind"), "and a shape")
	var shooters := world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "bacilo_cuspidor")
	assert_true(shooters.size() >= 2 and (shooters[0].get_meta("brain") as Node) is BioRangedBrain, "spitters have the ranged brain")
	world.dungeon.finish(false)
	await tree.process_frame
	world.dungeon.start(_run("granuloma", "hazard", 99))
	await tree.physics_frame
	var pools := world.dungeon.get_children().filter(func(c: Node) -> bool: return c is BioHazardPool)
	assert_true(pools.size() >= 6, "the pools are on the floor")
	var vitals := world.player.combatant.actor.vitals
	var pool := pools[0] as BioHazardPool
	world.player.global_position = pool.global_position
	var before := vitals.membrane
	await tree.create_timer(0.8).timeout
	assert_true(vitals.membrane < before, "standing in a pool hurts")
	world.dungeon.finish(false)
	await tree.process_frame
	assert_eq(world.dungeon.get_children().filter(func(c: Node) -> bool: return c is BioHazardPool and not c.is_queued_for_deletion()).size(), 0, "and the pools go with the room")


func test_a_nest_lays_its_brood_until_it_is_broken() -> void:
	world.dungeon.start(_run("granuloma", "nest"))
	await tree.physics_frame
	var nest := world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "colonia_de_bacilos")[0] as BioCellActor
	var brain := nest.get_meta("brain") as BioNestBrain
	assert_true(brain != null, "a nest has the nest brain")
	var before := world.dungeon.enemies().size()
	brain._next = BioClock.now() - 0.1
	brain.set_process(true)
	await tree.process_frame
	await tree.process_frame
	assert_eq(world.dungeon.enemies().size(), before + 1, "it lays one more")
	nest.combatant.actor.vitals.take_damage(9999.0)
	nest.queue_free()
	await tree.process_frame
	assert_true(world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "colonia_de_bacilos").is_empty(), "broken: no more laying")


func test_a_splitter_comes_apart_when_it_dies() -> void:
	world.dungeon.start(_run("cordoes-hepaticos", "wall"))
	await tree.physics_frame
	world.dungeon._spawn(&"plasmodio", world.player.global_position + Vector2(5.0, 0.0) * BioArt.UNIT, 1.0)
	var parasite := world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "plasmodio")[0] as BioCellActor
	parasite.combatant.actor.vitals.take_damage(9999.0)
	parasite.combatant.died.emit(parasite.combatant)
	parasite.queue_free()
	await tree.process_frame
	await tree.process_frame
	var young := world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "merozoito")
	assert_eq(young.size(), 2, "two merozoites take its place")


func test_a_spitter_throws_a_projectile_that_hurts() -> void:
	world.dungeon.start(_run("granuloma", "guard"))
	await tree.physics_frame
	world.dungeon._spawn(&"bacilo_cuspidor", world.player.global_position + Vector2(0.0, -6.0) * BioArt.UNIT, 1.0)
	var spitter := world.dungeon.enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "bacilo_cuspidor")[0] as BioCellActor
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	world.player.global_position = spitter.global_position + Vector2(0.0, 6.0) * BioArt.UNIT
	var executor: BioAttackExecutor = null
	for child in spitter.get_children():
		if child is BioAttackExecutor:
			executor = child
	assert_eq(executor.perform(BioAttackCatalog.ENEMY_SPIT, Vector2(0.0, 1.0)), BioActor.AttackStatus.STARTED, "it can shoot")
	await tree.create_timer(1.0).timeout
	assert_true(vitals.membrane < vitals.max_membrane, "the shot reaches the cell")


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
				assert_true(not BioDungeonPlan.enemy(kind).is_empty(), "%s is defined" % kind)
	assert_true(seen[&"coracao"].has(&"trombo") and seen[&"pulmao"].has(&"pneumococo") and seen[&"aorta"].has(&"embolo") and seen[&"figado"].has(&"plasmodio"), "each organ its own")
	assert_true(not seen[&"pulmao"].has(&"plasmodio") and not seen[&"figado"].has(&"trombo"), "and not each other's")


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
