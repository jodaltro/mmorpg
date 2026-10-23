extends TestCase
## The focus Jev designs for every non-projectile ability: wide reaches more and hits softly, precise is narrow, long and hits hard.
## The same risk and reward as the projectile, so no focus is strictly better.

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"macrofago"
	world.player.combatant.set_genome(world.genome)
	world.abilities.learn(&"onda_de_pseudopodes")
	world.player.global_position = Vector2.ZERO


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _dummy(at_units: Vector2) -> BioCellActor:
	BioFactory.spawn_virus(world, at_units * BioArt.UNIT, world.player)
	var v := world.viruses().back() as BioCellActor
	for child in v.get_children():
		if child is BioVirusBrain:
			child.queue_free()
	v.velocity = Vector2.ZERO
	v.max_speed_units = 0.0
	v.combatant.actor.vitals.max_membrane = 1000.0
	v.combatant.actor.vitals.membrane = 1000.0
	return v


func test_each_focus_pays_for_how_hard_it_is_to_land() -> void:
	var worths := []
	for k in BioAbilityFocus.FOCUS:
		var f: Dictionary = BioAbilityFocus.FOCUS[k]
		worths.append(float(f["damage"]) * float(f["odds"]))
	worths.sort()
	assert_true(worths[-1] / worths[0] < 1.12, "damage x odds is the same within 12%%: %s" % str(worths))
	assert_true(float(BioAbilityFocus.FOCUS["preciso"]["damage"]) > float(BioAbilityFocus.FOCUS["amplo"]["damage"]) * 1.5, "the precise focus hits much harder than the wide one")
	assert_true(float(BioAbilityFocus.FOCUS["amplo"]["width"]) > float(BioAbilityFocus.FOCUS["preciso"]["width"]) * 2.0, "and the wide one is more than twice as wide")


func test_the_focus_reshapes_the_ability_and_leaves_the_catalog_alone() -> void:
	var nova := BioAbilityCatalog.get_ability(&"onda_de_pseudopodes")
	var wide := BioAbilityFocus.apply(nova, BioAbilityFocus.params({"foco": "amplo"}))
	var narrow := BioAbilityFocus.apply(nova, BioAbilityFocus.params({"foco": "preciso"}))
	assert_near(float(wide["radius"]), float(nova["radius"]) * 1.45, 0.001, "the wide nova is wider")
	assert_near(float(narrow["radius"]), float(nova["radius"]) * 0.65, 0.001, "the precise nova is narrower")
	assert_near(float(BioAbilityCatalog.get_ability(&"onda_de_pseudopodes")["radius"]), float(nova["radius"]), 0.0001, "the catalog is untouched")
	var bolt := BioAbilityCatalog.get_ability(&"anticorpo_y")
	assert_eq(BioAbilityFocus.apply(bolt, BioAbilityFocus.params({"foco": "amplo"})), bolt, "projectiles have their own design: the focus leaves them alone")
	assert_eq(BioAbilityFocus.apply(nova, {}), nova, "no focus, no change")


func test_the_focus_changes_who_a_real_nova_reaches_and_how_hard_it_hits() -> void:
	var near := _dummy(Vector2(2.0, 0))
	var mid := _dummy(Vector2(4.2, 0))  # the plain nova (3.3) misses it; the wide one (4.8) reaches it; the precise one (2.1) misses even the first
	var results := {}
	for foco in ["preciso", "medio", "amplo"]:
		world.apply_design({"foco": foco}, "debug")
		near.combatant.actor.vitals.membrane = 1000.0
		mid.combatant.actor.vitals.membrane = 1000.0
		world.player.combatant.actor._ready_at.clear()
		world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
		world.abilities.perform(0)
		await tree.create_timer(0.6).timeout
		results[foco] = [1000.0 - near.combatant.actor.vitals.membrane, 1000.0 - mid.combatant.actor.vitals.membrane]
		await tree.create_timer(0.4).timeout
	assert_true(results["amplo"][1] > 0.0 and results["medio"][1] == 0.0, "only the wide nova reaches the far one: %s" % str(results))
	assert_true(results["preciso"][0] > results["medio"][0] and results["medio"][0] > results["amplo"][0], "but the precise one hits the near one hardest: %s" % str(results))


func test_the_basic_attack_and_projectiles_ignore_the_focus() -> void:
	world.apply_design({"foco": "preciso"}, "debug")
	var t := _dummy(Vector2(2, 0))
	var lash := BioAttackDef.new(&"chicote", 0.0, 20.0, 0.0, 3.0, 0.0, 0.0)
	t.combatant.receive_hit(world.player.combatant, lash)
	assert_near(1000.0 - t.combatant.actor.vitals.membrane, 20.0, 0.01, "the lash is not an ability of a focus")
	assert_true(not BioAbilityFocus.applies_to(&"anticorpo_y"), "a bolt is designed as a projectile")
	assert_true(BioAbilityFocus.applies_to(&"onda_de_pseudopodes"), "a nova is subject to the focus")
	world.apply_design({}, "motor")
