extends TestCase
## The behaviour Jev designs for each family of abilities: every mode is held to one yardstick (a lower direct blow for its own gain)
## and each one is checked on real bodies: the cone that closes, the nova that pulses or repels, the thrust that harpoons, the dash
## that strikes again, the zone that wanders, the bite that sucks.

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


func _hit(target: BioCellActor, ability: StringName, mode_family: String, mode_id: String) -> void:
	world.player.combatant.modes = {mode_family: mode_id} if mode_id != "padrao" else {}
	var def := BioAttackDef.new(ability, 0.0, 20.0, 0.0, 3.0, 0.0, 0.0)
	target.combatant.receive_hit(world.player.combatant, def)


func _lost(v: BioCellActor) -> float:
	return 1000.0 - v.combatant.actor.vitals.membrane


func test_every_mode_is_worth_about_the_plain_blow() -> void:
	for family in BioAbilityMode.FAMILIES:
		for m in BioAbilityMode.FAMILIES[family]:
			var worth := BioAbilityMode.worth(m)
			assert_true(worth > 0.95 and worth < 1.2, "%s / %s is worth %.2f of the plain blow" % [family, m, worth])


func test_every_option_of_the_universe_is_a_mode_that_exists() -> void:
	var universe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../universes/hospedeiro/universe.json"))
	var seen := 0
	for t in universe["appearance"]["traits"]:
		for family in BioAbilityMode.TRAIT_OF:
			if str(t["id"]) == BioAbilityMode.TRAIT_OF[family]:
				seen += 1
				var ids: Array = (t["options"] as Array).map(func(o: Dictionary) -> String: return str(o["id"]))
				ids.sort()
				var known: Array = (BioAbilityMode.FAMILIES[family] as Array).duplicate()
				known.sort()
				assert_eq(ids, known, "the universe offers exactly the modes of %s" % family)
	assert_eq(seen, 6, "six families are designed")


func test_families_and_modes_come_from_the_catalog() -> void:
	assert_eq(BioAbilityMode.family_of(&"dendritos_em_chicote"), "cone", "a whip is a cone")
	assert_eq(BioAbilityMode.family_of(&"onda_de_pseudopodes"), "nova", "a wave is a nova")
	assert_eq(BioAbilityMode.family_of(&"anticorpo_y"), "", "a projectile has its own design")
	assert_eq(BioAbilityMode.family_of(&"chicote"), "", "the lash has no modes")
	var modes := BioAbilityMode.from_traits({"modo_cone": "fecha", "modo_zona": "nao-existe", "modo_nova": "pulsos"})
	assert_eq(modes, {"cone": "fecha", "nova": "pulsos"}, "only real modes are taken")


func test_a_closing_cone_drags_the_victim_to_the_caster() -> void:
	var t := _dummy(Vector2(3, 0))
	_hit(t, &"dendritos_em_chicote", "cone", "fecha")
	await tree.create_timer(0.3).timeout
	assert_true(t.global_position.x < 3.0 * BioArt.UNIT - 5.0, "it was pulled in (%.0f px from where it stood)" % (3.0 * BioArt.UNIT - t.global_position.x))
	assert_near(_lost(t), 20.0 * 0.9, 0.05, "for a little less damage")


func test_a_lashing_cone_strikes_twice() -> void:
	var t := _dummy(Vector2(3, 0))
	_hit(t, &"dendritos_em_chicote", "cone", "chicoteia")
	assert_near(_lost(t), 20.0 * 0.7, 0.05, "the first lash is softer")
	await tree.create_timer(0.6).timeout
	assert_near(_lost(t), 20.0 * (0.7 + 0.5), 0.05, "the second comes back a beat later")


func test_a_pulsing_nova_beats_three_times_and_a_repelling_one_throws_enemies_out() -> void:
	var t := _dummy(Vector2(2, 0))
	_hit(t, &"onda_de_pseudopodes", "nova", "pulsos")
	await tree.create_timer(1.0).timeout
	assert_near(_lost(t), 20.0 * (0.48 + 2.0 * 0.32), 0.05, "three beats in all")
	var r := _dummy(Vector2(2, 3))
	var before := r.global_position
	_hit(r, &"onda_de_pseudopodes", "nova", "repele")
	await tree.create_timer(0.3).timeout
	assert_true(r.global_position.distance_to(world.player.global_position) > before.distance_to(world.player.global_position) + 5.0, "it was thrown away from the caster")


func test_a_harpoon_and_a_suction_pull_prey_in() -> void:
	var a := _dummy(Vector2(4, 0))
	_hit(a, &"perforina", "pierce", "arpao")
	await tree.create_timer(0.3).timeout
	var pulled_a := 4.0 * BioArt.UNIT - a.global_position.x
	var b := _dummy(Vector2(0, 4))
	_hit(b, &"engolir", "devour", "suga")
	await tree.create_timer(0.3).timeout
	assert_true(pulled_a > 5.0 and 4.0 * BioArt.UNIT - b.global_position.y > 5.0, "both reel the victim in (%.0f and %.0f px)" % [pulled_a, 4.0 * BioArt.UNIT - b.global_position.y])


func test_a_double_dash_strikes_again() -> void:
	var t := _dummy(Vector2(3, 0))
	_hit(t, &"golpe_litico", "dash_strike", "dupla")
	await tree.create_timer(0.7).timeout
	assert_near(_lost(t), 20.0 * (0.65 + 0.55), 0.05, "the second strike lands a beat later")


func test_a_wandering_zone_drifts_towards_the_nearest_enemy() -> void:
	var near := _dummy(Vector2(5, 0))
	near.combatant.actor.vitals.membrane = 1000.0
	var params := BioAbilityMode.apply(BioAbilityCatalog.get_ability(&"lisossomo_acido"), "zone", {"zone": "migra"})
	assert_true(float(params["drift"]) > 0.0, "the mode sets a drift")
	assert_true(float(params["radius"]) < float(BioAbilityCatalog.get_ability(&"lisossomo_acido")["radius"]), "and a smaller zone")
	var zone := BioAbilityZone.spawn(world, world.player, &"lisossomo_acido", Vector2(1.5, 0.0) * BioArt.UNIT, params)
	await tree.create_timer(1.2).timeout
	assert_true(zone.global_position.x > 1.5 * BioArt.UNIT + 20.0, "it wandered %.0f px towards the enemy" % (zone.global_position.x - 1.5 * BioArt.UNIT))
	zone.queue_free()


func test_without_modes_everything_is_as_before() -> void:
	var t := _dummy(Vector2(3, 0))
	_hit(t, &"dendritos_em_chicote", "cone", "padrao")
	await tree.create_timer(0.6).timeout
	assert_near(_lost(t), 20.0, 0.05, "one blow, full damage")
	var p := BioAbilityMode.apply(BioAbilityCatalog.get_ability(&"lisossomo_acido"), "zone", {})
	assert_true(not p.has("drift"), "and no drift")
