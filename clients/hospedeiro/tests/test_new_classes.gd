extends TestCase
## The four newer classes (mast cell, eosinophil, NK cell, regulatory T cell): what makes each one its own, in the body (form, nucleus,
## limbs, ghost) and in play (the new kinds of ability: melting a share of the victim's life, a chain of leaps, a wall of clots, and the
## weakening of whoever is hit).

var world: BioWorld

const CLASSES := [&"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]


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


## A still enemy with this much life, `at` units from the cell in the direction `dir`.
func _enemy(hp: float, at: float, dir: Vector2 = Vector2.RIGHT) -> BioCellActor:
	var def := BioDungeonPlan.enemy(&"cilindro_hialino").duplicate()
	def["hp"] = hp
	def["speed"] = 0.0
	var brain := BioFactory.spawn_enemy(world, world.player.global_position + dir.normalized() * at * BioArt.UNIT, world.player, def, 1.0, "viruses")
	(brain as Node).set_process(false)
	return brain.get_parent() as BioCellActor


## Takes the mouse out of it: the cell aims where the test says.
func _aim(dir: Vector2) -> void:
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(world.player.get_node("Controller") as BioCellController).set_aim(dir)


func _ready_cell(lineage: StringName) -> void:
	world.debug_become(lineage)
	world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
	world.player.combatant.actor._ready_at.clear()
	world.debug_god = true


func test_each_class_has_four_abilities_six_genes_and_a_body_of_its_own() -> void:
	var tips := {}
	var nuclei := {}
	for lineage in CLASSES:
		assert_eq(BioAbilityCatalog.ids_of_class(lineage).size(), 4, "%s has four abilities" % lineage)
		assert_eq(BioGeneCatalog.class_ids(lineage).size(), 6, "%s has six class genes" % lineage)
		assert_true(not BioLineageCatalog.mods_of(lineage).is_empty() and BioLineageCatalog.display_name(lineage) != "Esfera", "%s is a lineage with a name" % lineage)
		assert_true(not BioGhostForm.bumps(lineage).is_empty(), "%s has a risen shape" % lineage)
		tips[str(BioLimbStyle.for_body(lineage, {}, [])["tip"]) + str(BioLimbStyle.for_body(lineage, {}, [])["length"])] = true
		var edge := []
		for k in 8:
			edge.append(snappedf(BioNucleusShapes.radius_at(lineage, k * 0.8, 0.0), 0.01))
		nuclei[str(edge)] = true
		var p := BioCellForms.params(lineage, [] as Array[StringName])
		assert_true(float(p["size"]) != 0.82, "%s has a size of its own" % lineage)
	assert_eq(tips.size(), 4, "four different limbs")
	assert_eq(nuclei.size(), 4, "four different nuclei")


func test_a_body_of_each_class_draws_without_trouble() -> void:
	for lineage in CLASSES:
		world.debug_become(lineage)
		await tree.create_timer(0.25).timeout
		assert_true(world.player.is_active(), "%s lives" % lineage)
	world.genome.equipped = [&"granulos_de_histamina", &"degranulacao_explosiva"] as Array[StringName]
	world.genome.lineage = &"mastocito"
	world.player.combatant.set_genome(world.genome)
	await tree.create_timer(0.2).timeout


func test_melting_takes_a_share_of_the_victims_own_life() -> void:
	_ready_cell(&"eosinofilo")
	var small := _enemy(40.0, 1.6)
	var colossus := _enemy(600.0, 1.7, Vector2(1.0, 0.1))
	await tree.physics_frame
	await tree.physics_frame
	world.player.set_intent(Vector2.ZERO)
	_aim(Vector2.RIGHT)
	assert_eq(world.abilities.perform_id(&"granulo_caustico"), BioActor.AttackStatus.STARTED, "the melt is cast")
	await tree.create_timer(0.4).timeout
	var lost_small := 40.0 - small.combatant.actor.vitals.membrane
	var lost_big := 600.0 - colossus.combatant.actor.vitals.membrane
	assert_true(lost_big > lost_small * 2.0, "the colossus loses far more than the speck (%.1f against %.1f)" % [lost_big, lost_small])


func test_a_chain_of_leaps_hits_each_enemy_once() -> void:
	_ready_cell(&"celula_nk")
	var foes: Array[BioCellActor] = [_enemy(500.0, 3.0, Vector2.RIGHT), _enemy(500.0, 4.0, Vector2(1.0, 1.0)), _enemy(500.0, 5.0, Vector2(1.0, -1.0))]
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"cadeia_letal"), BioActor.AttackStatus.STARTED, "the chain is cast")
	await tree.create_timer(1.2).timeout
	for f in foes:
		assert_true(f.combatant.actor.vitals.membrane < 500.0, "every enemy in reach was hit")
	assert_true(foes[0].combatant.actor.vitals.membrane > 400.0, "and only once each")


func test_a_wall_of_clots_rises_and_expires() -> void:
	_ready_cell(&"t_regulador")
	assert_eq(world.abilities.perform_id(&"muro_de_tolerancia"), BioActor.AttackStatus.STARTED, "the wall is cast")
	await tree.create_timer(0.5).timeout
	var clots := world.get_children().filter(func(c: Node) -> bool: return c is BioClot)
	assert_eq(clots.size(), 3, "three clots")
	assert_true((clots[0] as BioClot).collision_layer == BioCellActor.LAYER_WALL, "solid for the cells")
	for c in clots:
		(c as BioClot).duration = 0.1
	await tree.create_timer(0.4).timeout
	assert_eq(world.get_children().filter(func(c: Node) -> bool: return c is BioClot and not c.is_queued_for_deletion()).size(), 0, "and they crumble when the time is up")


func test_a_weakened_enemy_hits_for_less() -> void:
	_ready_cell(&"t_regulador")
	var foe := _enemy(300.0, 2.5)
	await tree.physics_frame
	await tree.physics_frame
	world.debug_god = false
	var vitals := world.player.combatant.actor.vitals
	var strike := BioAttackCatalog.get_def(BioAttackCatalog.VIRAL_LUNGE)
	vitals.membrane = vitals.max_membrane
	world.player.combatant.receive_hit(foe.combatant, strike)
	var plain := vitals.max_membrane - vitals.membrane
	world.player.combatant.actor._ready_at.clear()
	vitals.membrane = vitals.max_membrane
	foe.combatant.weaken(0.5, 5.0)
	world.player.combatant.receive_hit(foe.combatant, strike)
	var weak := vitals.max_membrane - vitals.membrane
	assert_true(plain > 0.0 and weak < plain * 0.7, "a weakened foe hits softer (%.1f against %.1f)" % [weak, plain])
	assert_near(foe.combatant.dealing_mult(BioClock.now() + 10.0), 1.0, 0.0001, "and recovers when the time is up")


func test_the_suppression_and_the_zone_of_tolerance_weaken_what_they_touch() -> void:
	_ready_cell(&"t_regulador")
	var foe := _enemy(300.0, 2.0)
	_aim(Vector2.RIGHT)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"supressao_celular"), BioActor.AttackStatus.STARTED, "the suppression is cast")
	await tree.create_timer(0.6).timeout
	assert_true(foe.combatant.dealing_mult(BioClock.now()) < 0.7, "the marked enemy deals less")
	world.player.combatant.actor._ready_at.clear()
	var other := _enemy(300.0, 3.0, Vector2(1.0, 0.0))
	await tree.physics_frame
	BioAbilityZone.spawn(world, world.player, &"zona_de_tolerancia", other.global_position, BioAbilityCatalog.get_ability(&"zona_de_tolerancia"))
	await tree.create_timer(0.8).timeout
	assert_true(other.combatant.dealing_mult(BioClock.now()) < 0.8, "and so does the one inside the zone")


func test_the_granule_burst_and_the_drifting_cloud_hurt() -> void:
	_ready_cell(&"mastocito")
	var foe := _enemy(500.0, 2.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"choque_anafilatico"), BioActor.AttackStatus.STARTED, "the burst is cast")
	await tree.create_timer(1.0).timeout
	assert_true(foe.combatant.actor.vitals.membrane < 500.0, "the burst reaches the enemy")
	var edema := BioAbilityCatalog.get_ability(&"edema")
	var before := foe.combatant.actor.vitals.membrane
	BioAbilityZone.spawn(world, world.player, &"edema", foe.global_position, edema)
	await tree.create_timer(1.2).timeout
	assert_true(foe.combatant.actor.vitals.membrane < before, "the edema eats at it")
	_ready_cell(&"eosinofilo")
	var cloud := BioAbilityCatalog.get_ability(&"nuvem_de_peroxidase")
	assert_true(float(cloud["drift"]) > 0.0, "the eosinophil's cloud walks by itself")


func test_the_volley_of_granules_leaves_the_mast_cell_in_a_fan() -> void:
	_ready_cell(&"mastocito")
	assert_eq(world.abilities.perform_id(&"chuva_de_granulos"), BioActor.AttackStatus.STARTED, "the volley is cast")
	await tree.create_timer(0.4).timeout
	var bolts := world.get_children().filter(func(c: Node) -> bool: return c is BioAbilityBolt)
	assert_true(bolts.size() >= 5, "a fan of granules: %d" % bolts.size())


## The engine's universe and the client's catalogues must say the same: every class ability, lineage and mutation the engine can hand out
## exists on the client with the same class (a missing one would be a gift the cell could not use).
func test_every_class_ability_lineage_and_mutation_of_the_universe_exists_in_the_client() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../../universes/hospedeiro/universe.json")
	var u: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(not u.is_empty(), "the universe was read")
	for l in u["lineages"]:
		if int(l.get("tier", 1)) == 2:
			var id := BioLineageCatalog.normalise(str(l["id"]))
			assert_true(not BioLineageCatalog.mods_of(id).is_empty(), "%s is a lineage of the client" % id)
			assert_true(not BioGhostForm.bumps(id).is_empty(), "%s has a risen shape" % id)
	var per_class := {}
	for s in u["skills"]:
		var cls := str(s.get("class", ""))
		if cls.is_empty():
			continue
		var id := BioAbilityCatalog.normalise(str(s["id"]))
		assert_true(BioAbilityCatalog.has(id), "%s is an ability of the client" % id)
		assert_eq(str(BioAbilityCatalog.get_ability(id).get("class", "")), str(BioLineageCatalog.normalise(cls)), "%s belongs to the same class on both sides" % id)
		per_class[cls] = int(per_class.get(cls, 0)) + 1
	for cls in per_class:
		assert_eq(per_class[cls], 4, "%s has four abilities in the universe" % cls)
	for m in u["mutations"]:
		var gid := StringName(str(m["id"]).replace("-", "_"))
		assert_true(BioGeneCatalog.all_ids().has(gid), "%s is a mutation of the client" % gid)
