extends TestCase
## The four newer classes (mast cell, eosinophil, NK cell, regulatory T cell): what makes each one its own in the body (form, nucleus,
## limbs, ghost) and, above all, in play. Each of their sixteen abilities is a verb the game did not have before: laying mines, gluing a
## fused bomb, chaining kills, bleeding into a blast; a latched rope, a crystal that keeps the blows, growing with kills, rolling like
## a ball; a blink behind the prey, a hunt that gives cooldowns back, vanishing, a recall; sleep, a link between enemies, a decoy, a
## singularity. These tests play each one.

var world: BioWorld

const CLASSES := [&"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]

## The numbers each kind reads from its ability: a missing one would be a crash in the middle of a fight.
const REQUIRED := {
	"mines": ["damage", "radius", "duration", "every", "max", "arm", "life"],
	"sticky": ["damage", "radius", "fuse", "stack", "range", "speed"],
	"cascade": ["damage", "radius", "duration"],
	"overload": ["damage", "per_hp", "radius", "bleed", "max_time", "floor"],
	"tether": ["damage", "pct", "cap", "duration", "range", "leash", "pull", "snap"],
	"crystal": ["damage", "seconds", "bank", "radius", "range"],
	"grow": ["seconds", "stacks", "dmg_per", "size_per", "heal_per"],
	"roll": ["damage", "seconds", "speed", "steer", "taken"],
	"blink": ["damage", "backstab", "range", "behind", "iframes", "distance"],
	"prey": ["range", "seconds", "refund", "atp", "speed"],
	"cloak": ["seconds", "strike", "speed"],
	"recall": ["delay", "damage", "width", "restore", "iframes"],
	"sleep": ["range", "seconds", "wake", "count"],
	"link": ["range", "count", "share", "seconds"],
	"decoy": ["reach", "hp", "seconds", "lure"],
	"pull": ["damage", "reach", "radius", "seconds", "pull", "core"],
}


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


## An enemy that really hunts: its brain runs. Returns the brain.
func _hunter(hp: float, at: float, dir: Vector2 = Vector2.RIGHT) -> Node:
	var def := BioDungeonPlan.enemy(&"cilindro_hialino").duplicate()
	def["hp"] = hp
	def["aggro"] = 14.0
	return BioFactory.spawn_enemy(world, world.player.global_position + dir.normalized() * at * BioArt.UNIT, world.player, def, 1.0, "viruses")


## The cell strikes this enemy with a plain blow of `damage`.
func _strike(foe: BioCellActor, damage: float) -> BioHitResult:
	return foe.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"test_blow", 0.0, damage, 0.0, 1.0, 0.0, 0.0))


## Takes the mouse out of it: the cell aims where the test says.
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


func test_all_sixteen_abilities_are_different_verbs_and_carry_what_they_need() -> void:
	var kinds := {}
	var older := ["devour", "cone", "pierce", "nova", "dash_strike", "bolt", "volley", "mark", "mark_all", "execute", "zone", "heal", "aura", "summon"]
	for lineage in CLASSES:
		for id in BioAbilityCatalog.ids_of_class(lineage):
			var a := BioAbilityCatalog.get_ability(id)
			var kind := str(a["kind"])
			assert_true(not older.has(kind), "%s is not one of the older kinds (%s)" % [id, kind])
			assert_true(REQUIRED.has(kind), "%s has a kind the test knows" % id)
			for key in REQUIRED.get(kind, []):
				assert_true(a.has(key), "%s carries %s" % [id, key])
			kinds[kind] = true
	assert_eq(kinds.size(), 16, "sixteen abilities, sixteen different kinds")


func test_the_body_window_explains_every_class_and_every_ability() -> void:
	for lineage in [&"mieloide", &"linfoide", &"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"] + CLASSES:
		assert_true(BioLore.has_class(lineage), "%s has a class text" % lineage)
		assert_true(str(BioLore.class_info(lineage)["about"]).length() > 40 and str(BioLore.class_info(lineage)["play"]).length() > 20, "%s explains itself" % lineage)
	for lineage in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"] + CLASSES:
		for id in BioAbilityCatalog.ids_of_class(lineage):
			assert_true(BioLore.has_ability(id), "%s is explained" % id)
			assert_true(str(BioLore.ability_info(id)["how"]).length() > 20, "%s says how it works" % id)
	for id in BioAbilityCatalog.ids_of_class(&"mastocito"):
		assert_true(BioLore.KIND_NAMES.has(str(BioAbilityCatalog.get_ability(id)["kind"])), "%s has a readable kind" % id)
	world.debug_become(&"mastocito")
	world.body_panel.open(BioBodyPanel.FORM)
	await tree.process_frame
	assert_true(world.body_panel.content_text().contains("COMO JOGAR"), "the Form tab tells how to play the class")
	world.body_panel.show_tab(BioBodyPanel.ABILITIES)
	await tree.process_frame
	assert_true(world.body_panel.content_text().contains("COMO FUNCIONA"), "the Abilities tab tells how each one works")
	world.body_panel.close()


func test_a_body_of_each_class_draws_without_trouble() -> void:
	for lineage in CLASSES:
		world.debug_become(lineage)
		await tree.create_timer(0.25).timeout
		assert_true(world.player.is_active(), "%s lives" % lineage)


# ---------------------------------------------------------------- Mastócito, o Alarmista

func test_the_mast_cell_lays_mines_by_moving_and_they_go_off_when_an_enemy_comes() -> void:
	_ready_cell(&"mastocito")
	assert_eq(world.abilities.perform_id(&"granulos_latentes"), BioActor.AttackStatus.STARTED, "the trail is started")
	for k in 16:  # walking lays the granules; standing still would lay none
		world.player.global_position += Vector2.RIGHT * 1.3 * BioArt.UNIT
		await tree.create_timer(0.14).timeout
	var mines := tree.get_nodes_in_group("bio_mines")
	assert_true(mines.size() >= 3, "a trail of granules was left (%d)" % mines.size())
	var foe := _enemy(200.0, 30.0)
	foe.global_position = (mines[0] as Node2D).global_position
	await tree.create_timer(0.6).timeout
	assert_true(_lost(foe, 200.0) > 5.0, "the granule went off when the enemy stood on it (%.1f)" % _lost(foe, 200.0))


func test_the_trail_lays_nothing_while_the_cell_stands_still() -> void:
	_ready_cell(&"mastocito")
	world.abilities.perform_id(&"granulos_latentes")
	await tree.create_timer(1.0).timeout
	assert_true(tree.get_nodes_in_group("bio_mines").size() <= 1, "standing still lays at most the first granule")


func test_a_granule_that_goes_off_sets_off_the_next_one() -> void:
	_ready_cell(&"mastocito")
	var def := BioAbilityCatalog.attack_def(&"granulos_latentes")
	var a := BioMine.spawn(world, world.player, def, world.player.global_position + Vector2(8.0, 0.0) * BioArt.UNIT, 1.6, 0.0, 12.0, Color.ORANGE)
	var b := BioMine.spawn(world, world.player, def, world.player.global_position + Vector2(9.5, 0.0) * BioArt.UNIT, 1.6, 0.0, 12.0, Color.ORANGE)
	var foe := _enemy(300.0, 8.0)
	await tree.create_timer(0.7).timeout
	assert_true(not is_instance_valid(a) or a.is_queued_for_deletion(), "the first went off")
	assert_true(not is_instance_valid(b) or b.is_queued_for_deletion(), "and the second went with it")
	assert_true(_lost(foe, 300.0) > 0.0, "the enemy felt it")


func test_the_unstable_glob_sticks_and_every_glob_makes_the_blast_bigger() -> void:
	_ready_cell(&"mastocito")
	var foe := _enemy(2000.0, 4.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"histamina_instavel"), BioActor.AttackStatus.STARTED, "the glob is thrown")
	await tree.create_timer(0.5).timeout
	var fuse: BioFuse = null
	for c in foe.get_children():
		if c is BioFuse:
			fuse = c
	assert_true(fuse != null, "it stuck")
	var single := fuse.blast_damage()
	_recharge()
	world.abilities.perform_id(&"histamina_instavel")
	await tree.create_timer(0.5).timeout
	assert_eq(fuse.stacks, 2, "the second glob stacked on the first")
	assert_true(fuse.blast_damage() > single * 1.4, "and the blast grew (%.1f against %.1f)" % [fuse.blast_damage(), single])
	await tree.create_timer(2.6).timeout
	assert_true(_lost(foe, 2000.0) >= single * 1.4, "it went off for what the stacks promised (%.1f)" % _lost(foe, 2000.0))


func test_a_kill_bursts_and_the_burst_kills_the_next_so_the_pack_goes_off_in_a_row() -> void:
	_ready_cell(&"mastocito")
	var a := _enemy(10.0, 5.0)
	var b := _enemy(10.0, 6.8, Vector2(1.0, 0.1))
	var c := _enemy(10.0, 8.6, Vector2(1.0, 0.2))
	var far := _enemy(10.0, 20.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"cascata_de_degranulacao"), BioActor.AttackStatus.STARTED, "the cascade is started")
	await tree.create_timer(0.3).timeout
	_strike(a, 100.0)
	await tree.create_timer(1.6).timeout
	assert_true(not is_instance_valid(b) or not b.combatant.actor.vitals.is_alive(), "the burst killed the second")
	assert_true(not is_instance_valid(c) or not c.combatant.actor.vitals.is_alive(), "and its burst, the third")
	assert_true(is_instance_valid(far) and far.combatant.actor.vitals.is_alive(), "the one far away was left alone")


func test_nothing_bursts_before_the_cascade_is_cast() -> void:
	_ready_cell(&"mastocito")
	var a := _enemy(10.0, 5.0)
	var b := _enemy(10.0, 6.8, Vector2(1.0, 0.1))
	_strike(a, 100.0)
	await tree.create_timer(0.6).timeout
	assert_true(is_instance_valid(b) and b.combatant.actor.vitals.is_alive(), "no cascade, no burst")


func test_anaphylaxis_spends_the_cells_own_membrane_and_the_blast_is_made_of_it() -> void:
	_ready_cell(&"mastocito", false)
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	var foe := _enemy(900.0, 2.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"anafilaxia"), BioActor.AttackStatus.STARTED, "the charge starts")
	await tree.create_timer(1.0).timeout
	var spent := vitals.max_membrane - vitals.membrane
	assert_true(spent > 8.0, "it bled membrane into the charge (%.1f)" % spent)
	assert_eq(_lost(foe, 900.0), 0.0, "and nothing is hurt while it holds")
	assert_eq(world.abilities.perform_id(&"anafilaxia"), BioActor.AttackStatus.STARTED, "the same key lets it go")
	await tree.create_timer(0.3).timeout
	assert_true(_lost(foe, 900.0) > 10.0 + spent, "the blast carries what was spent and more (%.1f for %.1f spent)" % [_lost(foe, 900.0), spent])


func test_anaphylaxis_never_bleeds_the_cell_to_death() -> void:
	_ready_cell(&"mastocito", false)
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	world.abilities.perform_id(&"anafilaxia")
	await tree.create_timer(3.2).timeout
	assert_true(vitals.is_alive() and vitals.membrane >= vitals.max_membrane * 0.1, "it let go by itself and lived (%.1f)" % vitals.membrane)


# ---------------------------------------------------------------- Eosinófilo, o Caça-Colossos

func test_the_rope_reels_the_victim_in_and_a_colossus_pays_more_than_a_speck() -> void:
	_ready_cell(&"eosinofilo")
	var big := _enemy(900.0, 6.0, Vector2.RIGHT)
	var small := _enemy(40.0, 6.0, Vector2.LEFT)
	await tree.physics_frame
	await tree.physics_frame
	var before := big.global_position.distance_to(world.player.global_position)
	assert_eq(world.abilities.perform_id(&"adesao"), BioActor.AttackStatus.STARTED, "the rope is thrown")
	await tree.create_timer(2.2).timeout
	assert_true(big.global_position.distance_to(world.player.global_position) < before - 1.0 * BioArt.UNIT, "the colossus was reeled in")
	var lost_big := _lost(big, 900.0)
	_recharge()
	_aim(Vector2.LEFT)
	world.abilities.perform_id(&"adesao")
	await tree.create_timer(2.2).timeout
	var lost_small := _lost(small, 40.0)
	assert_true(lost_big > 25.0, "the rope corrodes (%.1f)" % lost_big)
	assert_true(lost_big > lost_small * 1.5, "and the big one pays more than the small one (%.1f against %.1f)" % [lost_big, lost_small])


func test_the_rope_breaks_when_the_victim_dies() -> void:
	_ready_cell(&"eosinofilo")
	var foe := _enemy(20.0, 4.0)
	await tree.physics_frame
	world.abilities.perform_id(&"adesao")
	await tree.create_timer(0.3).timeout
	assert_true(world.get_children().any(func(c: Node) -> bool: return c is BioTether), "a rope holds")
	_strike(foe, 100.0)
	await tree.create_timer(0.4).timeout
	assert_true(not world.get_children().any(func(c: Node) -> bool: return c is BioTether and not c.is_queued_for_deletion()), "and it lets go of the dead")


func test_the_crystal_keeps_every_blow_and_gives_it_all_back_in_a_blast() -> void:
	_ready_cell(&"eosinofilo")
	var a := _enemy(400.0, 4.0)
	var b := _enemy(400.0, 5.8, Vector2(1.0, 0.1))
	var far := _enemy(400.0, 20.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"cristal_de_charcot"), BioActor.AttackStatus.STARTED, "the crystal grows")
	await tree.create_timer(0.4).timeout
	assert_true(a.combatant.is_encased(), "the enemy is in it")
	for k in 3:
		_strike(a, 20.0)
	assert_eq(_lost(a, 400.0), 0.0, "nothing hurt it inside")
	assert_near(a.combatant.stasis_bank(), 60.0, 1.0, "the blows were kept")
	await tree.create_timer(3.0).timeout
	assert_true(_lost(a, 400.0) > 60.0, "the one inside took it all when the crystal gave (%.1f)" % _lost(a, 400.0))
	assert_true(_lost(b, 400.0) > 50.0, "and so did the one beside it (%.1f)" % _lost(b, 400.0))
	assert_eq(_lost(far, 400.0), 0.0, "not the one far away")


func test_an_enemy_in_the_crystal_does_not_move_or_act() -> void:
	_ready_cell(&"eosinofilo")
	var brain := _hunter(500.0, 6.0)
	var foe := brain.get_parent() as BioCellActor
	await tree.create_timer(0.6).timeout
	world.abilities.perform_id(&"cristal_de_charcot")
	await tree.create_timer(0.4).timeout
	var held := foe.global_position
	await tree.create_timer(1.2).timeout
	assert_true(foe.global_position.distance_to(held) < 6.0, "it stood still inside (%.1f px)" % foe.global_position.distance_to(held))


func test_every_kill_makes_the_cell_bigger_and_harder_hitting() -> void:
	_ready_cell(&"eosinofilo")
	var me := world.player.combatant
	var foe := _enemy(3000.0, 3.0)
	var weak := _enemy(5.0, 4.0, Vector2(1.0, 0.5))
	var weaker := _enemy(5.0, 4.0, Vector2(1.0, -0.5))
	await tree.physics_frame
	var plain := _strike(foe, 20.0).damage_applied
	assert_eq(world.abilities.perform_id(&"hipertrofia"), BioActor.AttackStatus.STARTED, "it starts growing")
	assert_eq(me.growth_stacks(), 1, "one stack to begin with")
	_strike(weak, 50.0)
	_strike(weaker, 50.0)
	assert_eq(me.growth_stacks(), 3, "one more for each kill")
	await tree.create_timer(0.8).timeout
	assert_true(world.player.scale.x > 1.1, "the body is bigger (%.2f)" % world.player.scale.x)
	var grown := _strike(foe, 20.0).damage_applied
	assert_true(grown > plain * 1.2, "and it hits harder (%.1f against %.1f)" % [grown, plain])


func test_the_ball_bounces_off_what_it_hits_and_hurts_it() -> void:
	_ready_cell(&"eosinofilo")
	var foe := _enemy(500.0, 4.0)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"rolagem"), BioActor.AttackStatus.STARTED, "the cell curls up")
	await tree.create_timer(0.25).timeout
	assert_true(world.player.is_rolling(), "it is rolling")
	await tree.create_timer(0.7).timeout
	assert_true(_lost(foe, 500.0) > 5.0, "the ball hurt what it hit (%.1f)" % _lost(foe, 500.0))
	await tree.create_timer(2.5).timeout
	assert_true(not world.player.is_rolling(), "and it uncurls when the time is up")


# ---------------------------------------------------------------- Célula NK, o Assassino Natural

func test_the_blink_puts_the_cell_behind_the_prey_and_the_blow_lands_harder() -> void:
	_ready_cell(&"celula_nk")
	var foe := _enemy(900.0, 4.5)
	await tree.physics_frame
	await tree.physics_frame
	var plain := _strike(foe, 12.5).damage_applied
	assert_eq(world.abilities.perform_id(&"passo_sem_identidade"), BioActor.AttackStatus.STARTED, "the cell steps")
	await tree.create_timer(0.3).timeout
	assert_true(world.player.global_position.x > foe.global_position.x, "it is behind the enemy now")
	assert_true(_lost(foe, 900.0) - plain > plain * 1.4, "and the blow from behind was harder than a plain one (%.1f against %.1f)" % [_lost(foe, 900.0) - plain, plain])


func test_with_nobody_in_reach_the_blink_is_a_short_jump() -> void:
	_ready_cell(&"celula_nk")
	var from := world.player.global_position
	assert_eq(world.abilities.perform_id(&"passo_sem_identidade"), BioActor.AttackStatus.STARTED, "it jumps")
	await tree.create_timer(0.2).timeout
	assert_true(world.player.global_position.distance_to(from) > 2.5 * BioArt.UNIT, "and it went somewhere (%.1f px)" % world.player.global_position.distance_to(from))


func test_the_hunt_gives_cooldowns_back_with_every_blow_and_everything_back_with_the_kill() -> void:
	_ready_cell(&"celula_nk")
	var me := world.player.combatant
	var prey := _enemy(300.0, 4.0)
	var other := _enemy(300.0, 5.0, Vector2(1.0, 0.5))
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"predar"), BioActor.AttackStatus.STARTED, "the hunt begins")
	await tree.create_timer(0.4).timeout
	assert_true(me.hunted() == prey.combatant, "the prey is chosen")
	me.actor.try_begin_attack(&"camuflagem_de_mhc", BioClock.now())
	var before := me.actor.cooldown_remaining(&"camuflagem_de_mhc", BioClock.now())
	_strike(other, 10.0)
	assert_near(me.actor.cooldown_remaining(&"camuflagem_de_mhc", BioClock.now()), before, 0.1, "a blow on anyone else gives nothing back")
	_strike(prey, 10.0)
	assert_true(me.actor.cooldown_remaining(&"camuflagem_de_mhc", BioClock.now()) < before - 0.8, "a blow on the prey gives time back")
	_strike(prey, 1000.0)
	assert_eq(me.actor.cooldown_remaining(&"camuflagem_de_mhc", BioClock.now()), 0.0, "and the kill gives it all")
	assert_eq(me.actor.cooldown_remaining(&"predar", BioClock.now()), 0.0, "the hunt itself included")
	await tree.process_frame


func test_a_cloaked_cell_is_lost_by_the_enemy_and_its_first_blow_is_the_ambush() -> void:
	_ready_cell(&"celula_nk")
	var brain := _hunter(5000.0, 9.0)
	var foe := brain.get_parent() as BioCellActor
	await tree.create_timer(0.7).timeout
	assert_eq(brain.state_name(), "CHASE", "the enemy is after the cell")
	var plain := _strike(foe, 10.0).damage_applied
	world.abilities.perform_id(&"camuflagem_de_mhc")
	await tree.create_timer(0.6).timeout
	assert_eq(brain.state_name(), "WANDER", "it lost the cell")
	var ambush := _strike(foe, 10.0).damage_applied
	assert_true(ambush > plain * 2.0, "the first blow from the shadow is the ambush (%.1f against %.1f)" % [ambush, plain])
	assert_true(not world.player.combatant.is_hidden(), "and the cell is seen again")
	var after := _strike(foe, 10.0).damage_applied
	assert_near(after, plain, 0.5, "the next blow is a plain one")


func test_the_anchor_pulls_the_cell_back_through_the_fight_and_mends_a_share_of_what_it_lost() -> void:
	_ready_cell(&"celula_nk", false)
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane
	var spot := world.player.global_position
	var foe := _enemy(600.0, 2.5)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"ancora_de_vigilancia"), BioActor.AttackStatus.STARTED, "the anchor is dropped")
	world.player.global_position += Vector2(5.0, 0.0) * BioArt.UNIT
	vitals.membrane -= 30.0
	var hurt := vitals.membrane
	await tree.create_timer(0.3).timeout
	assert_eq(world.abilities.perform_id(&"ancora_de_vigilancia"), BioActor.AttackStatus.STARTED, "the same key calls it back")
	await tree.create_timer(0.4).timeout
	assert_true(world.player.global_position.distance_to(spot) < 0.6 * BioArt.UNIT, "the cell is where the anchor was")
	assert_true(vitals.membrane > hurt + 20.0, "and it mended most of what it lost (%.1f -> %.1f)" % [hurt, vitals.membrane])
	assert_true(_lost(foe, 600.0) > 10.0, "the enemy on the way was hurt (%.1f)" % _lost(foe, 600.0))


func test_the_anchor_calls_the_cell_back_by_itself_when_the_time_is_up() -> void:
	_ready_cell(&"celula_nk")
	var spot := world.player.global_position
	world.abilities.perform_id(&"ancora_de_vigilancia")
	world.player.global_position += Vector2(4.0, 0.0) * BioArt.UNIT
	await tree.create_timer(3.7).timeout
	assert_true(world.player.global_position.distance_to(spot) < 0.6 * BioArt.UNIT, "back at the anchor with no second press")


# ---------------------------------------------------------------- Linfócito T regulador, o Pacificador

func test_the_sleeper_does_nothing_until_hurt_and_the_blow_that_wakes_it_lands_harder() -> void:
	_ready_cell(&"t_regulador")
	var brain := _hunter(5000.0, 6.0)
	var foe := brain.get_parent() as BioCellActor
	await tree.create_timer(0.5).timeout
	var plain := _strike(foe, 10.0).damage_applied
	_recharge()
	assert_eq(world.abilities.perform_id(&"anergia"), BioActor.AttackStatus.STARTED, "the spores are thrown")
	await tree.create_timer(0.5).timeout
	assert_true(foe.combatant.is_asleep(), "it sleeps")
	var held := foe.global_position
	await tree.create_timer(1.0).timeout
	assert_true(foe.global_position.distance_to(held) < 8.0, "and does not move")
	var wake := _strike(foe, 10.0).damage_applied
	assert_true(wake > plain * 1.4, "the blow that wakes it lands harder (%.1f against %.1f)" % [wake, plain])
	assert_true(not foe.combatant.is_asleep(), "and it is awake")


func test_the_big_ones_sleep_lighter() -> void:
	_ready_cell(&"t_regulador")
	var small := _enemy(100.0, 4.0)
	var big := _enemy(900.0, 4.0, Vector2(1.0, 0.8))
	await tree.physics_frame
	await tree.physics_frame
	world.abilities.perform_id(&"anergia")
	await tree.create_timer(0.5).timeout
	_recharge()
	_aim(Vector2(1.0, 0.8).normalized())
	world.abilities.perform_id(&"anergia")
	await tree.create_timer(0.5).timeout
	var now := BioClock.now()
	assert_true(small.combatant._sleep_until - now > big.combatant._sleep_until - now + 0.8, "the colossus woke first")


func test_a_link_shares_each_wound_with_the_others_and_needs_two_to_exist() -> void:
	_ready_cell(&"t_regulador")
	var lone := _enemy(300.0, 4.0)
	await tree.physics_frame
	await tree.physics_frame
	var atp := world.player.combatant.actor.vitals.atp
	assert_eq(world.abilities.perform_id(&"sinapse_imunologica"), BioAbilityRunner.NO_TARGET, "a lone enemy cannot be linked")
	assert_eq(world.player.combatant.actor.vitals.atp, atp, "and it cost nothing")
	var b := _enemy(300.0, 5.0, Vector2(1.0, 0.4))
	var c := _enemy(300.0, 5.0, Vector2(1.0, -0.4))
	await tree.physics_frame
	assert_eq(world.abilities.perform_id(&"sinapse_imunologica"), BioActor.AttackStatus.STARTED, "now there are enough")
	await tree.create_timer(0.5).timeout
	assert_true(lone.combatant.is_linked() and b.combatant.is_linked(), "they are tied")
	_strike(lone, 40.0)
	var share := _lost(b, 300.0)
	assert_true(share > 10.0 and share < 40.0, "the wound reached the others in part (%.1f)" % share)
	assert_true(_lost(c, 300.0) > 10.0 or _lost(b, 300.0) > 10.0, "at least two of them")
	var echo := _lost(lone, 300.0)
	assert_near(echo, 40.0, 3.0, "and it did not echo back on the one that was hit (%.1f)" % echo)


func test_the_decoy_takes_the_enemies_and_gives_them_back_when_it_falls() -> void:
	_ready_cell(&"t_regulador")
	var brain := _hunter(500.0, 8.0)
	await tree.create_timer(0.4).timeout
	assert_eq(world.abilities.perform_id(&"autoantigeno"), BioActor.AttackStatus.STARTED, "the decoy is thrown")
	await tree.create_timer(0.9).timeout
	var decoy: BioCellActor = null
	for c in world.get_children():
		if c is BioCellActor and c.name == "Decoy":
			decoy = c
	assert_true(decoy != null, "there is a decoy")
	assert_true(brain._prey == decoy, "and the enemy is after it, not after the cell")
	decoy.combatant.actor.vitals.membrane = 0.0
	await tree.create_timer(1.2).timeout
	assert_true(brain._prey == world.player, "it came back for the cell when the decoy fell")


func test_the_singularity_pulls_the_room_into_a_heap_and_the_collapse_hurts_the_heap() -> void:
	_ready_cell(&"t_regulador")
	var spot := world.player.global_position + Vector2.RIGHT * 4.5 * BioArt.UNIT
	var foes: Array[BioCellActor] = [_enemy(300.0, 8.0, Vector2(1.0, 0.8)), _enemy(300.0, 8.5, Vector2(1.0, -0.8)), _enemy(300.0, 7.0, Vector2(1.0, 0.0))]
	await tree.physics_frame
	await tree.physics_frame
	var before := 0.0
	for f in foes:
		before += f.global_position.distance_to(spot)
	assert_eq(world.abilities.perform_id(&"singularidade_de_tolerancia"), BioActor.AttackStatus.STARTED, "the point opens")
	await tree.create_timer(1.6).timeout
	var after := 0.0
	for f in foes:
		after += f.global_position.distance_to(spot)
	assert_true(after < before * 0.6, "they were drawn in (%.0f px against %.0f px)" % [after, before])
	await tree.create_timer(1.0).timeout
	var hurt := 0
	for f in foes:
		if _lost(f, 300.0) > 5.0:
			hurt += 1
	assert_true(hurt >= 2, "the collapse hurt the heap (%d of 3)" % hurt)


# ---------------------------------------------------------------- the universe and the client agree

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
