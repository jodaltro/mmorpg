extends TestCase
## The abilities of the six older classes that were redone as new verbs (the other seven stay as the workhorses that carry the designs Jev
## makes for a cell). Each one is played here and its effect checked, and the whole set is held to one rule: forty abilities, forty
## different kinds, none repeating another's mechanic.

var world: BioWorld

const OLDER := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]
const NEWER := [&"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]


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


func _enemy(hp: float, at: float, dir: Vector2 = Vector2.RIGHT) -> BioCellActor:
	var def := BioEnemyCatalog.enemy(&"cilindro_hialino").duplicate()
	def["hp"] = hp
	def["speed"] = 0.0
	var brain := BioFactory.spawn_enemy(world, world.player.global_position + dir.normalized() * at * BioArt.UNIT, world.player, def, 1.0, "viruses")
	(brain as Node).set_process(false)
	return brain.get_parent() as BioCellActor


func _strike(foe: BioCellActor, damage: float) -> BioHitResult:
	return foe.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"test_blow", 0.0, damage, 0.0, 1.0, 0.0, 0.0))


func _aim(dir: Vector2) -> void:
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(world.player.get_node("Controller") as BioCellController).set_aim(dir)


func _ready_cell(lineage: StringName, god: bool = true) -> void:
	world.debug_become(lineage)
	world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
	world.player.combatant.actor._ready_at.clear()
	world.debug_god = god
	_aim(Vector2.RIGHT)


func _recharge() -> void:
	world.player.combatant.actor._ready_at.clear()
	world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp


func _lost(foe: BioCellActor, hp: float) -> float:
	return hp - foe.combatant.actor.vitals.membrane if is_instance_valid(foe) else hp


func test_forty_abilities_are_forty_different_kinds() -> void:
	var kinds := {}
	var count := 0
	for lineage in OLDER + NEWER:
		assert_eq(BioAbilityCatalog.ids_of_class(lineage).size(), 4, "%s has four" % lineage)
		for id in BioAbilityCatalog.ids_of_class(lineage):
			var kind := str(BioAbilityCatalog.get_ability(id)["kind"])
			assert_true(not kinds.has(kind), "%s repeats the kind of %s (%s)" % [id, kinds.get(kind, ""), kind])
			kinds[kind] = id
			count += 1
	assert_eq(count, 40, "forty abilities")
	assert_eq(kinds.size(), 40, "forty kinds")


func test_the_redone_abilities_carry_the_numbers_their_kinds_read() -> void:
	var need := {
		"counter": ["seconds", "taken", "reflect", "heal"], "stance": ["seconds", "power"], "phase": ["damage", "seconds", "speed", "taken"],
		"frenzy": ["seconds", "rate", "burn", "speed"], "beam": ["damage", "seconds", "range", "width", "turn", "every"], "empower": ["charges", "mult", "seconds"],
		"portal": ["reach", "seconds"], "complement": ["hits", "pct", "damage", "cap", "seconds", "range"], "replay": ["echo"],
		"turret": ["damage", "seconds", "every", "range", "taken", "speed"], "leap": ["damage", "radius", "distance", "knockback", "air"],
		"hold": ["damage", "step", "seconds", "range", "finish_below", "leash"], "massacre": ["damage", "radius", "base", "per_kill", "window"],
		"contagion": ["damage", "seconds", "spread", "hop", "hops", "range"], "allies": ["count", "hp", "damage", "seconds"],
		"lastchance": ["seconds", "restore"], "convert": ["give", "rate"],
	}
	var seen := 0
	for lineage in OLDER:
		for id in BioAbilityCatalog.ids_of_class(lineage):
			var a := BioAbilityCatalog.get_ability(id)
			if need.has(str(a["kind"])):
				seen += 1
				for key in need[str(a["kind"])]:
					assert_true(a.has(key), "%s carries %s" % [id, key])
	assert_eq(seen, 17, "seventeen redone")


func test_the_polarisation_cycles_through_the_two_forms_and_back() -> void:
	_ready_cell(&"macrofago")
	var me := world.player.combatant
	assert_eq(world.abilities.perform_id(&"polarizacao"), BioActor.AttackStatus.STARTED, "first press")
	assert_eq(me.stance_now(), &"m1", "M1")
	assert_true(me.dealing_mult(BioClock.now()) > 1.2, "M1 hits harder")
	var foe := _enemy(500.0, 3.0)
	var hit := _strike(foe, 20.0)
	await tree.physics_frame
	assert_true(foe.get_children().size() > 0 and hit.damage_applied > 20.0, "and what it hits is set alight (%.1f)" % hit.damage_applied)
	_recharge()
	world.abilities.perform_id(&"polarizacao")
	assert_eq(me.stance_now(), &"m2", "M2")
	assert_true(me.dealing_mult(BioClock.now()) < 0.9, "M2 hits softer")
	world.debug_god = false
	me.actor.vitals.membrane = 30.0
	await tree.create_timer(1.0).timeout
	assert_true(me.actor.vitals.membrane > 33.0, "and mends (%.1f)" % me.actor.vitals.membrane)
	_recharge()
	world.abilities.perform_id(&"polarizacao")
	assert_eq(me.stance_now(), &"", "the third press goes back to plain")


func test_the_phase_goes_through_bodies_that_would_have_blocked_it() -> void:
	_ready_cell(&"neutrofilo")
	var wall := _enemy(900.0, 1.6)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"diapedese")
	for k in 40:
		world.player.set_intent(Vector2.RIGHT)
		await tree.physics_frame
	assert_true(world.player.global_position.x > wall.global_position.x, "the cell is past the body that stood in its way")
	assert_true(_lost(wall, 900.0) > 3.0, "and stung it on the way (%.1f)" % _lost(wall, 900.0))


func test_without_the_phase_the_same_body_blocks_the_cell() -> void:
	_ready_cell(&"neutrofilo")
	var wall := _enemy(900.0, 1.6)
	await tree.physics_frame
	for k in 40:
		world.player.set_intent(Vector2.RIGHT)
		await tree.physics_frame
	assert_true(world.player.global_position.x < wall.global_position.x, "a plain cell stays behind it")


func test_the_burst_runs_the_cooldowns_faster_and_costs_membrane_but_never_all_of_it() -> void:
	_ready_cell(&"neutrofilo", false)
	var me := world.player.combatant
	var vitals := me.actor.vitals
	vitals.membrane = vitals.max_membrane
	world.abilities.perform_id(&"surto_oxidativo")
	me.actor._ready_at[&"something"] = BioClock.now() + 10.0
	await tree.create_timer(1.0).timeout
	assert_true(me.actor.cooldown_remaining(&"something", BioClock.now()) < 8.7, "a cooldown ran about twice as fast (%.1f s left of 10)" % me.actor.cooldown_remaining(&"something", BioClock.now()))
	assert_true(vitals.membrane < vitals.max_membrane, "and the membrane burned")
	await tree.create_timer(6.5).timeout
	assert_true(vitals.is_alive() and vitals.membrane >= vitals.max_membrane * 0.09, "it never burns to death (%.1f)" % vitals.membrane)
	assert_true(not me.is_frenzied(), "and it ends")


func test_the_sweep_follows_the_aim_slowly_and_burns_what_it_crosses() -> void:
	_ready_cell(&"dendritica")
	var ahead := _enemy(400.0, 3.0)
	var above := _enemy(400.0, 3.0, Vector2.UP)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"varredura"), BioActor.AttackStatus.STARTED, "the beam opens")
	await tree.create_timer(0.7).timeout
	assert_true(_lost(ahead, 400.0) > 0.0, "it burns what is ahead")
	assert_eq(_lost(above, 400.0), 0.0, "and not what is off to the side")
	_aim(Vector2.UP)
	await tree.create_timer(0.3).timeout
	assert_eq(_lost(above, 400.0), 0.0, "the beam only turns so fast: it has not got there yet")
	await tree.create_timer(1.3).timeout
	assert_true(_lost(above, 400.0) > 0.0, "but it gets there")


func test_the_maturation_makes_the_next_abilities_free_and_stronger() -> void:
	_ready_cell(&"dendritica")
	world.abilities.learn(&"onda_de_pseudopodes")
	var me := world.player.combatant
	var a := _enemy(2000.0, 2.0)
	var b := _enemy(2000.0, 2.0, Vector2.LEFT)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"onda_de_pseudopodes")
	await tree.create_timer(0.5).timeout
	var plain := _lost(a, 2000.0)
	_recharge()
	world.abilities.perform_id(&"maturacao")
	assert_eq(me.empower_charges(), 3, "three charges")
	var atp := me.actor.vitals.atp
	_recharge()
	world.abilities.perform_id(&"onda_de_pseudopodes")
	await tree.create_timer(0.5).timeout
	assert_eq(me.empower_charges(), 2, "one was spent")
	assert_true(_lost(b, 2000.0) > plain * 1.3, "the wave hit harder (%.1f against %.1f)" % [_lost(b, 2000.0), plain])
	assert_true(me.actor.vitals.atp >= atp - 1.0, "and cost nothing")


func test_the_passage_takes_the_cell_from_one_door_to_the_other() -> void:
	_ready_cell(&"dendritica")
	var start := world.player.global_position
	assert_eq(world.abilities.perform_id(&"passagem_linfatica"), BioActor.AttackStatus.STARTED, "the doors open")
	await tree.create_timer(0.9).timeout
	var pair := BioPortalPair.current
	assert_true(is_instance_valid(pair), "a pair exists")
	assert_true(pair.a.distance_to(start) > 3.0 * BioArt.UNIT, "one where the cell pointed")
	world.player.global_position = pair.a + Vector2(0.4, 0.0) * BioArt.UNIT
	await tree.create_timer(0.3).timeout
	assert_true(world.player.global_position.distance_to(pair.b) < 2.0 * BioArt.UNIT, "and the cell came out of the other (%.0f px away)" % world.player.global_position.distance_to(pair.b))


func test_complement_counts_the_blows_of_anyone() -> void:
	_ready_cell(&"linfocito_b")
	var foe := _enemy(500.0, 3.0)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"complemento")
	await tree.create_timer(0.4).timeout
	assert_eq(foe.combatant.complement_hits(), 3, "three to go")
	_strike(foe, 5.0)
	assert_eq(foe.combatant.complement_hits(), 2, "one fewer")
	var other := BioCombatant.new()
	other.configure("other", BioActor.Team.CELL, 100.0, 100.0, 0.0)
	world.add_child(other)
	foe.combatant.receive_hit(other, BioAttackDef.new(&"other", 0.0, 5.0, 0.0, 1.0, 0.0, 0.0))
	assert_eq(foe.combatant.complement_hits(), 1, "a blow from anyone counts")
	var before := foe.combatant.actor.vitals.membrane
	_strike(foe, 5.0)
	assert_true(before - foe.combatant.actor.vitals.membrane > 5.0 + 6.0, "the last one bursts it (%.1f)" % (before - foe.combatant.actor.vitals.membrane))
	other.queue_free()


func test_the_memory_repeats_the_last_ability_for_free_and_needs_one() -> void:
	_ready_cell(&"linfocito_b")
	world.abilities.learn(&"onda_de_pseudopodes")
	assert_eq(world.abilities.perform_id(&"memoria_imunologica"), BioAbilityRunner.NO_TARGET, "nothing to remember yet")
	var foe := _enemy(3000.0, 2.0)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"onda_de_pseudopodes")
	await tree.create_timer(0.5).timeout
	var once := _lost(foe, 3000.0)
	var atp := world.player.combatant.actor.vitals.atp
	var wave_ready := world.player.combatant.actor.cooldown_remaining(&"onda_de_pseudopodes", BioClock.now())
	assert_true(wave_ready > 1.0, "the wave is cooling down")
	assert_eq(world.abilities.perform_id(&"memoria_imunologica"), BioActor.AttackStatus.STARTED, "the memory acts")
	await tree.create_timer(0.8).timeout
	assert_true(_lost(foe, 3000.0) > once * 1.5, "the wave came out again (%.1f against %.1f)" % [_lost(foe, 3000.0), once])
	var memory_cost := float(BioAbilityCatalog.get_ability(&"memoria_imunologica")["cost"])
	assert_true(world.player.combatant.actor.vitals.atp > atp - memory_cost - 2.0, "and paid only for the memory")


func test_the_factory_stands_still_and_does_not_stop_shooting() -> void:
	_ready_cell(&"linfocito_b")
	var foe := _enemy(900.0, 4.0)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"fabrica_de_plasmocito")
	var spot := world.player.global_position
	for k in 40:
		world.player.set_intent(Vector2.UP)
		await tree.physics_frame
	assert_true(world.player.global_position.distance_to(spot) < 0.6 * BioArt.UNIT, "the cell did not move (%.0f px)" % world.player.global_position.distance_to(spot))
	await tree.create_timer(1.0).timeout
	assert_true(_lost(foe, 900.0) > 10.0, "and it shot the enemy again and again (%.1f)" % _lost(foe, 900.0))


func test_the_leap_crosses_everything_and_lands_with_a_blow() -> void:
	_ready_cell(&"t_citotoxico")
	var wall := _enemy(900.0, 2.5)
	var target := _enemy(900.0, 5.6, Vector2(1.0, 0.1))
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"salto_letal"), BioActor.AttackStatus.STARTED, "the cell jumps")
	await tree.create_timer(1.0).timeout
	assert_true(world.player.global_position.x > 4.8 * BioArt.UNIT, "it landed far off (%.0f px)" % world.player.global_position.x)
	assert_true(absf(world.player.scale.x - 1.0) < 0.01, "and is its own size again")
	assert_true(_lost(target, 900.0) > 5.0, "the landing hurt what stood there (%.1f)" % _lost(target, 900.0))
	assert_true(is_instance_valid(wall), "(the body it jumped over was not in its way)")


func test_the_grip_holds_the_enemy_in_front_and_finishes_the_nearly_dead() -> void:
	_ready_cell(&"t_citotoxico")
	var strong := _enemy(900.0, 3.5)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"sinapse_letal"), BioActor.AttackStatus.STARTED, "the grip closes")
	await tree.create_timer(0.8).timeout
	assert_true(strong.combatant.is_stunned(), "the enemy cannot act")
	assert_true(strong.global_position.distance_to(world.player.global_position) < 2.2 * BioArt.UNIT, "and it was dragged in front of the cell")
	await tree.create_timer(1.9).timeout
	assert_true(_lost(strong, 900.0) > 15.0, "the squeeze hurt (%.1f)" % _lost(strong, 900.0))
	assert_true(not strong.combatant.is_stunned(), "and let go")
	strong.queue_free()
	await tree.physics_frame
	await tree.physics_frame
	_recharge()
	var weak := _enemy(40.0, 3.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"sinapse_letal"), BioActor.AttackStatus.STARTED, "the second grip closes")
	await tree.create_timer(2.6).timeout
	assert_true(not is_instance_valid(weak) or not weak.combatant.actor.vitals.is_alive(), "the nearly dead one was finished")


func test_the_mass_lysis_sentences_the_nearly_dead_and_grows_with_the_kills() -> void:
	_ready_cell(&"t_citotoxico")
	var low := _enemy(100.0, 5.0)
	var mid := _enemy(100.0, 6.0, Vector2(1.0, 0.4))
	var high := _enemy(100.0, 6.0, Vector2(1.0, -0.4))
	low.combatant.actor.vitals.membrane = 15.0
	mid.combatant.actor.vitals.membrane = 41.0
	high.combatant.actor.vitals.membrane = 90.0
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"lise_em_massa")
	await tree.create_timer(0.8).timeout
	assert_true(not is_instance_valid(low) or not low.combatant.actor.vitals.is_alive(), "the nearly dead one is sentenced")
	assert_true(is_instance_valid(mid) and mid.combatant.actor.vitals.is_alive(), "the one at 41 percent is not, with no kills behind the cell")
	assert_true(is_instance_valid(high) and _lost(high, 100.0) > 0.0, "and the healthy one is hurt but lives")
	_recharge()
	for k in 3:
		var fodder := _enemy(5.0, 8.0, Vector2(0.3 * k, 1.0))
		_strike(fodder, 100.0)
	await tree.process_frame
	var mid2 := _enemy(100.0, 6.0, Vector2(1.0, 0.4))
	mid2.combatant.actor.vitals.membrane = 41.0
	await tree.physics_frame
	world.abilities.perform_id(&"lise_em_massa")
	await tree.create_timer(0.8).timeout
	assert_true(not is_instance_valid(mid2) or not mid2.combatant.actor.vitals.is_alive(), "after three kills the same enemy is sentenced")


func test_the_fever_passes_to_the_neighbour_and_on() -> void:
	_ready_cell(&"t_auxiliar")
	var a := _enemy(400.0, 3.0)
	var b := _enemy(400.0, 5.0, Vector2(1.0, 0.1))
	var far := _enemy(400.0, 14.0)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"febre_contagiosa")
	await tree.create_timer(3.3).timeout
	assert_true(_lost(a, 400.0) > 0.0, "the first one burns")
	assert_true(b.get_children().any(func(c: Node) -> bool: return c is BioFever) or _lost(b, 400.0) > 0.0, "the neighbour caught it")
	assert_eq(_lost(far, 400.0), 0.0, "the one far away did not")


func test_the_auxiliaries_go_after_the_enemy_and_bite_it() -> void:
	_ready_cell(&"t_auxiliar")
	var foe := _enemy(900.0, 5.0)
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"chamado_aos_auxiliares")
	await tree.create_timer(0.6).timeout
	assert_eq(tree.get_nodes_in_group("allies").size(), int(BioAbilityCatalog.get_ability(&"chamado_aos_auxiliares")["count"]), "the auxiliaries came")
	await tree.create_timer(3.0).timeout
	assert_true(_lost(foe, 900.0) > 8.0, "and they bit the enemy (%.1f)" % _lost(foe, 900.0))


func test_the_second_chance_spares_one_mortal_blow() -> void:
	_ready_cell(&"t_auxiliar", false)
	var me := world.player.combatant
	me.actor.vitals.membrane = 20.0
	world.abilities.perform_id(&"segunda_chance")
	assert_true(me.has_guardian(), "the ring is up")
	var foe := _enemy(100.0, 8.0)
	var mortal := BioAttackDef.new(&"mortal", 0.0, 500.0, 0.0, 1.0, 0.0, 0.0)
	me.receive_hit(foe.combatant, mortal)
	assert_true(me.actor.vitals.is_alive(), "the blow that would have killed did not")
	assert_true(me.actor.vitals.membrane > me.actor.vitals.max_membrane * 0.3, "and part of the membrane is back (%.1f)" % me.actor.vitals.membrane)
	me.actor.invulnerable_until = 0.0
	me.receive_hit(foe.combatant, mortal)
	assert_true(not me.actor.vitals.is_alive(), "but only one: the next one kills")


func test_the_transfusion_trades_what_is_plentiful_for_what_is_lacking() -> void:
	_ready_cell(&"t_auxiliar", false)
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	vitals.atp = 25.0
	world.player.combatant.actor._ready_at.clear()
	world.abilities.perform_id(&"transfusao")
	assert_true(vitals.membrane < vitals.max_membrane - 5.0 and vitals.atp > 25.0 - float(BioAbilityCatalog.get_ability(&"transfusao")["cost"]) + 5.0, "full of life and out of energy: membrane became energy (%.1f, %.1f)" % [vitals.membrane, vitals.atp])
	_recharge()
	vitals.membrane = 30.0
	vitals.atp = vitals.max_atp
	world.abilities.perform_id(&"transfusao")
	assert_true(vitals.membrane > 35.0, "full of energy and hurt: energy became membrane (%.1f)" % vitals.membrane)
