extends TestCase

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


func _idle_virus(pos: Vector2) -> BioCellActor:
	var brain := BioFactory.spawn_virus(world, pos, world.player)
	brain.set_process(false)
	var cell := brain.get_parent() as BioCellActor
	cell.combatant.actor.vitals.max_membrane = 400.0  # sturdy dummies: tuned abilities must not kill them mid-test
	cell.combatant.actor.vitals.membrane = 400.0
	return cell


func _clear_viruses() -> void:
	for v in world.viruses():
		v.queue_free()
	await tree.process_frame


func test_catalog_has_four_abilities_per_class_with_valid_definitions() -> void:
	for lineage in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]:
		assert_eq(BioAbilityCatalog.ids_of_class(lineage).size(), 4, "four for %s" % lineage)
	for id in BioAbilityCatalog.ids_of_class(&"macrofago") + BioAbilityCatalog.ids_of_class(&"t_citotoxico"):
		var def := BioAbilityCatalog.attack_def(id)
		assert_true(def.atp_cost > 0.0 and def.cooldown > 0.0, "cost and cooldown for %s" % id)


func test_engine_ids_map_to_catalog_and_unknown_are_ignored() -> void:
	assert_eq(BioAbilityCatalog.normalise("onda-de-pseudopodes"), &"onda_de_pseudopodes", "hyphens become underscores")
	var runner := world.abilities
	assert_true(runner.learn(&"engolir"), "learns")
	assert_true(not runner.learn(&"engolir"), "only once")
	assert_true(not runner.learn(&"inexistente"), "unknown ignored")
	assert_eq(runner.known().size(), 1, "one slot used")


func test_view_skills_fill_slots_and_unclassed_skills_are_ignored() -> void:
	world.sync.apply_view({"tick": 1, "skills": [{"id": "engolir", "class": "macrofago"}, {"id": "farejar", "class": ""}, {"id": "onda-de-pseudopodes", "class": "macrofago"}]})
	assert_eq(world.abilities.known(), [&"engolir", &"onda_de_pseudopodes"] as Array[StringName], "class skills only")


func test_devour_damages_and_heals_and_charges_atp() -> void:
	await _clear_viruses()
	var virus := _idle_virus(Vector2(1.4, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	world.abilities.learn(&"engolir")
	world.player.combatant.actor.vitals.membrane = 50.0
	var atp := world.player.combatant.actor.vitals.atp
	var before := virus.combatant.actor.vitals.membrane
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.STARTED, "performed")
	await tree.create_timer(0.3).timeout  # the body stretches first, the bite lands with it
	assert_true(virus.combatant.actor.vitals.membrane < before, "damaged")
	assert_true(world.player.combatant.actor.vitals.membrane > 50.0, "healed by devouring")
	assert_true(world.player.combatant.actor.vitals.atp < atp, "paid ATP")
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.ON_COOLDOWN, "cooldown")


func test_mark_without_target_costs_nothing_and_with_target_amplifies_damage() -> void:
	await _clear_viruses()
	world.abilities.learn(&"apresentar_antigeno")
	var atp := world.player.combatant.actor.vitals.atp
	assert_eq(world.abilities.perform(0), BioAbilityRunner.NO_TARGET, "no target")
	assert_near(world.player.combatant.actor.vitals.atp, atp, 0.01, "nothing spent")
	var virus := _idle_virus(Vector2(3.0, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.STARTED, "marked")
	await tree.create_timer(0.35).timeout  # the limb has to reach the target first
	assert_true(virus.combatant.is_marked(), "is marked")
	var lash := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	var before := virus.combatant.actor.vitals.membrane
	virus.combatant.receive_hit(world.player.combatant, lash)
	assert_near(before - virus.combatant.actor.vitals.membrane, lash.damage * float(BioAbilityCatalog.get_ability(&"apresentar_antigeno")["mult"]), 0.05, "a marked cell takes the mark multiplier")


func test_trap_zone_bursts_after_its_delay() -> void:
	await _clear_viruses()
	var virus := _idle_virus(Vector2(2.2, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	world.abilities.learn(&"netose")
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	var before := virus.combatant.actor.vitals.membrane
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.STARTED, "trap laid")
	await tree.create_timer(0.5).timeout
	assert_near(virus.combatant.actor.vitals.membrane, before, 0.01, "still armed")
	await tree.create_timer(1.2).timeout
	assert_true(virus.combatant.actor.vitals.membrane < before, "burst")


func test_antibody_bolt_flies_and_hits() -> void:
	await _clear_viruses()
	var virus := _idle_virus(Vector2(5.0, 0.0) * BioArt.UNIT)
	await tree.physics_frame
	world.abilities.learn(&"anticorpo_y")
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	var before := virus.combatant.actor.vitals.membrane
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.STARTED, "fired")
	await tree.create_timer(0.9).timeout
	assert_true(virus.combatant.actor.vitals.membrane < before, "bolt landed")


func test_shield_reduces_damage_taken() -> void:
	world.abilities.learn(&"muralha_de_carne")
	var player := world.player.combatant
	var hit := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	var virus := _idle_virus(Vector2(8.0, 0.0) * BioArt.UNIT)
	var start := player.actor.vitals.membrane
	player.receive_hit(virus.combatant, hit)
	var plain := start - player.actor.vitals.membrane
	player.actor.vitals.membrane = start
	player.actor.invulnerable_until = 0.0
	assert_eq(world.abilities.perform(0), BioActor.AttackStatus.STARTED, "shield up")
	player.receive_hit(virus.combatant, hit)
	assert_near(start - player.actor.vitals.membrane, plain * float(BioAbilityCatalog.get_ability(&"muralha_de_carne")["taken"]), 0.05, "takes only what the shield lets through")


func test_restart_world_returns_to_a_plain_newborn() -> void:
	world.abilities.learn(&"engolir")
	world.genome.equipped = [&"cilios_ageis"] as Array[StringName]
	world.player.combatant.set_genome(world.genome)
	world.lineage_id = &"macrofago"
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	await world.restart_world()
	assert_eq(world.abilities.known().size(), 0, "no abilities")
	assert_eq(world.genome.equipped.size(), 0, "no genes")
	assert_eq(world.lineage_id, &"", "plain ball again")
	assert_true(world.player.combatant.actor.vitals.is_alive(), "alive")
	assert_true(world.player.global_position.distance_to(BioBodyMap.center_px(BioBodyMap.MEDULA)) < 5.0, "back in the marrow")
	assert_eq(world.viruses().size(), world.virus_count, "fresh virions")


func test_restart_button_needs_a_second_press_to_confirm() -> void:
	var fired := [0]
	world.hud.restart_requested.disconnect(world.restart_world)
	world.hud.restart_requested.connect(func() -> void: fired[0] += 1)
	world.hud.press_restart()
	assert_eq(fired[0], 0, "first press only arms")
	world.hud.press_restart()
	assert_eq(fired[0], 1, "second press confirms")


func test_basic_lash_grows_a_limb_that_follows_the_form() -> void:
	await _clear_viruses()
	var limbs := world.player.get_node("Limbs") as BioLimbs
	var ball := limbs.style()
	assert_eq(ball["tip"], &"blob", "a newborn ball reaches with a blunt pseudopod")
	var body := limbs.body()
	body.form = &"t_citotoxico"
	assert_eq(limbs.style()["tip"], &"spear", "a killer cell has a lance")
	assert_true(limbs.lash_half_angle() < 30.0, "a lance is narrow")
	body.form = &"macrofago"
	assert_eq(limbs.style()["tip"], &"cup", "a macrophage scoops")
	assert_true(limbs.lash_half_angle() > 70.0, "and sweeps wide")
	body.form = &"esfera"
	(world.player.get_node("Controller") as BioCellController).lash()
	await tree.process_frame
	assert_true(tree.get_nodes_in_group("limbs").size() >= 1, "the lash grew a limb")


func test_look_axes_change_the_limb_procedurally() -> void:
	var calm := BioLimbStyle.for_body(&"mieloide", {}, [])
	var fierce := BioLimbStyle.for_body(&"mieloide", {"ferocidade": 100, "agilidade": 100, "robustez": 100}, [])
	assert_true(fierce["barbs"] > calm["barbs"], "ferocity grows barbs")
	assert_true(fierce["length"] > calm["length"], "agility lengthens")
	assert_true(fierce["base"] > calm["base"], "robustness thickens")
	var social := BioLimbStyle.for_body(&"mieloide", {"sociabilidade": 100}, [])
	assert_true(social["branches"] > calm["branches"], "sociability branches")


func test_body_stretches_like_rubber_and_settles() -> void:
	var body := world.player.get_node("Limbs").body() as BioCellBody
	body.set_process(false)  # stepped by hand with a fixed delta: the result must not depend on how fast this run's frames are
	body.elastic(Vector2.RIGHT, 0.2, 0.6, 0.05)
	var peak := 0.0
	for i in 40:  # two thirds of a second at 60 steps a second
		body._step_elastic(1.0 / 60.0)
		peak = maxf(peak, absf(body._stretch))
	assert_true(peak > 0.08, "it deformed (%f)" % peak)
	for i in 120:
		body._step_elastic(1.0 / 60.0)
	assert_true(absf(body._stretch) < 0.02, "and settled back")
