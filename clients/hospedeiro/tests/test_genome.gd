extends TestCase


func _cell() -> BioActor:
	return BioActor.new("c", BioActor.Team.CELL, BioVitals.new(100.0, 100.0, 6.0))


func test_stats_multiply_and_add() -> void:
	var genome := BioGenome.new()
	assert_near(genome.stat(BioGene.SPEED), 1.0, 0.0001, "neutral speed")
	assert_near(genome.stat(BioGene.ATP_REGEN), 0.0, 0.0001, "neutral regen")
	genome.equip(&"cilios_ageis")
	genome.equip(&"membrana_espessa")
	assert_near(genome.stat(BioGene.SPEED), 1.18 * 0.9, 0.0001, "speed multiplies")
	assert_near(genome.stat(BioGene.MAX_MEMBRANE), 0.9 * 1.3, 0.0001, "membrane multiplies")
	genome.equip(&"mitocondria_avida")
	assert_near(genome.stat(BioGene.ATP_REGEN), 4.0, 0.0001, "regen is additive")


func test_slots_reabsorb_the_oldest_gene() -> void:
	var genome := BioGenome.new()
	var first_six := [&"cilios_ageis", &"cauda_longa", &"enzima_voraz", &"membrana_espessa", &"peroxissomos", &"nucleo_reativo"]
	for id in first_six:
		assert_eq(genome.equip(id), &"", "free slot")
	assert_eq(genome.equip(&"vesicula_toxica"), &"cilios_ageis", "oldest replaced")
	assert_eq(genome.equipped.size(), BioGenome.SLOTS)
	assert_eq(genome.equip(&"cauda_longa"), &"", "duplicate ignored")


func test_genome_reshapes_attacks_without_touching_the_catalog() -> void:
	var cell := _cell()
	cell.genome = BioGenome.new()
	cell.genome.equip(&"flagelo_calejado")
	cell.genome.equip(&"cauda_longa")
	cell.genome.equip(&"vesicula_toxica")
	var base := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	var lash := cell.attack_def(BioAttackCatalog.FLAGELLUM_LASH)
	assert_near(lash.damage, base.damage * 1.25 * 0.9, 0.001, "lash damage")
	assert_near(lash.range_units, base.range_units * 1.3, 0.001, "lash range")
	var spit := cell.attack_def(BioAttackCatalog.TOXIN_SPIT)
	assert_near(spit.atp_cost, BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT).atp_cost * 1.3, 0.001, "spit cost")
	assert_near(BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH).damage, base.damage, 0.0001, "catalog untouched")


func test_modified_cost_is_what_the_actor_pays() -> void:
	var cell := _cell()
	cell.genome = BioGenome.new()
	cell.genome.equip(&"vesicula_toxica")
	var expected := BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT).atp_cost * 1.3
	assert_eq(cell.try_begin_attack(BioAttackCatalog.TOXIN_SPIT, 0.0), BioActor.AttackStatus.STARTED)
	assert_near(cell.vitals.atp, 100.0 - expected, 0.001, "paid the mutated cost")


func test_nutrient_yield_gene() -> void:
	var cell := _cell()
	cell.genome = BioGenome.new()
	cell.genome.equip(&"enzima_voraz")
	cell.vitals.try_spend_atp(50.0)
	BioNutrientRules.consume(cell, BioNutrientRules.Kind.GLUCOSE)
	assert_near(cell.vitals.atp, 50.0 + BioNutrientRules.GLUCOSE_ATP * 1.5, 0.001)


func test_rescale_keeps_fractions_and_life() -> void:
	var vitals := BioVitals.new(100.0, 100.0, 5.0)
	vitals.take_damage(50.0)
	vitals.try_spend_atp(25.0)
	vitals.rescale(200.0, 80.0, 9.0)
	assert_near(vitals.membrane, 100.0, 0.001, "membrane fraction kept")
	assert_near(vitals.atp, 60.0, 0.001, "atp fraction kept")
	assert_near(vitals.atp_regen_per_second, 9.0)
	var dying := BioVitals.new(100.0, 100.0, 5.0)
	dying.take_damage(99.99)
	dying.rescale(10.0, 100.0, 5.0)
	assert_true(dying.is_alive(), "rescale never kills")


func test_pressure_creates_one_offer_of_three_unequipped_genes() -> void:
	var tracker := BioMutationTracker.new(7)
	var genome := BioGenome.new()
	genome.equip(&"cilios_ageis")
	assert_true(not tracker.add_pressure(BioMutationTracker.THRESHOLD - 1, genome), "below threshold")
	assert_true(tracker.add_pressure(1, genome), "threshold reached")
	assert_eq(tracker.offer.size(), 3, "three candidates")
	assert_true(not tracker.offer.has(&"cilios_ageis"), "already equipped genes are not offered")
	var pending := tracker.offer.duplicate()
	assert_true(not tracker.add_pressure(50, genome), "no second offer while one is pending")
	assert_eq(tracker.offer, pending, "pending offer unchanged")


func test_choose_equips_and_clears_offer() -> void:
	var tracker := BioMutationTracker.new(3)
	var genome := BioGenome.new()
	tracker.add_pressure(BioMutationTracker.THRESHOLD, genome)
	var picked: StringName = tracker.offer[1]
	tracker.choose(1, genome)
	assert_true(genome.has_gene(picked), "picked gene equipped")
	assert_true(not tracker.has_offer(), "offer cleared")


func test_declined_genes_are_not_offered_again_immediately() -> void:
	var tracker := BioMutationTracker.new(11)
	var genome := BioGenome.new()
	tracker.add_pressure(BioMutationTracker.THRESHOLD, genome)
	var first := tracker.offer.duplicate()
	tracker.decline()
	assert_true(not tracker.has_offer(), "declined offer gone")
	tracker.add_pressure(BioMutationTracker.THRESHOLD, genome)
	for id in tracker.offer:
		assert_true(not first.has(id), "declined gene %s must not come back right away" % id)


func test_offers_are_deterministic_for_a_seed() -> void:
	var a := BioMutationTracker.new(42)
	var b := BioMutationTracker.new(42)
	a.add_pressure(10, BioGenome.new())
	b.add_pressure(10, BioGenome.new())
	assert_eq(a.offer, b.offer)


func test_save_roundtrip_drops_unknown_genes() -> void:
	var genome := BioGenome.new()
	genome.equip(&"cilios_ageis")
	genome.equip(&"enzima_voraz")
	var restored := BioGenome.from_dict(genome.to_dict())
	assert_eq(restored.equipped, genome.equipped)
	var dirty := BioGenome.from_dict({"equipped": ["cilios_ageis", "does_not_exist", "cilios_ageis", "cauda_longa", "enzima_voraz", "membrana_espessa", "peroxissomos", "nucleo_reativo", "vesicula_toxica"]})
	var expected: Array[StringName] = [&"cilios_ageis", &"cauda_longa", &"enzima_voraz", &"membrana_espessa", &"peroxissomos", &"nucleo_reativo"]
	assert_eq(dirty.equipped, expected, "unknown, duplicated and extra genes dropped")


func test_every_gene_has_a_benefit_and_a_cost() -> void:
	for id in BioGeneCatalog.all_ids():
		var gene := BioGeneCatalog.get_gene(id)
		var gains := 0
		var costs := 0
		gains += gene.perks.size()  # a perk on a class ability is a benefit too
		for stat in gene.mods:
			var v: float = gene.mods[stat]
			var neutral: float = 0.0 if BioGene.is_additive(stat) else 1.0
			var lower_is_better: bool = stat in [BioGene.SPIT_COST, BioGene.DASH_COOLDOWN, BioGene.ABILITY_COOLDOWN, BioGene.ABILITY_COST]
			var good: bool = (v < neutral) if lower_is_better else (v > neutral)
			if good:
				gains += 1
			else:
				costs += 1
		assert_true(gains >= 1 and costs >= 1, "%s needs a benefit and a trade-off" % id)


func test_every_class_has_six_mutations_that_change_its_own_abilities() -> void:
	for lineage in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]:
		var own := BioGeneCatalog.class_ids(lineage)
		assert_eq(own.size(), 6, "six mutations for %s" % lineage)
		var abilities := BioAbilityCatalog.ids_of_class(lineage)
		var touched := 0
		for id in own:
			var gene := BioGeneCatalog.get_gene(id)
			for ability in gene.perks:
				assert_true(abilities.has(ability), "%s only touches abilities of its own class (%s)" % [id, ability])
				var params := BioAbilityCatalog.get_ability(ability)
				for key in gene.perks[ability]:
					var k := str(key).trim_prefix("+")
					assert_true(params.has(k), "%s perk %s exists on %s" % [id, k, ability])
				touched += 1
		assert_true(touched >= 4, "most of %s's mutations reshape an ability" % lineage)


func test_a_cell_only_meets_generic_and_its_own_class_mutations() -> void:
	var macro := BioGeneCatalog.ids_for(&"macrofago")
	assert_true(macro.has(&"fagossomo_profundo"), "own")
	assert_true(not macro.has(&"granzima_b"), "not another class's")
	assert_true(macro.has(&"cilios_ageis"), "generic")
	assert_true(BioGeneCatalog.all_ids().size() >= 48, "a wide pool")


func test_perks_change_the_ability_as_the_genome_performs_it() -> void:
	var genome := BioGenome.new()
	genome.lineage = &"macrofago"
	var base := BioAbilityCatalog.get_ability(&"lisossomo_acido")
	genome.equip(&"vacuolo_digestivo")
	var tuned := genome.tune(&"lisossomo_acido", base)
	assert_near(float(tuned["radius"]), float(base["radius"]) * 1.35, 0.001, "radius grows")
	assert_near(float(tuned["duration"]), float(base["duration"]) * 1.2, 0.001, "lasts longer")
	var other := genome.tune(&"engolir", BioAbilityCatalog.get_ability(&"engolir"))
	assert_near(float(other["heal"]), float(BioAbilityCatalog.get_ability(&"engolir")["heal"]), 0.001, "another ability is untouched")
	genome.equip(&"receptor_de_limpeza")
	var def := genome.modify(BioAbilityCatalog.attack_def(&"onda_de_pseudopodes"))
	assert_true(def.damage > BioAbilityCatalog.attack_def(&"onda_de_pseudopodes").damage * 1.3, "damage perk and general power reach the domain definition")
	var salva := BioGenome.new()
	salva.equip(&"hipermutacao_somatica")
	assert_eq(int(salva.tune(&"salva_de_anticorpos", BioAbilityCatalog.get_ability(&"salva_de_anticorpos"))["count"]), 7, "additive perk: +2 antibodies")


func test_the_summary_names_the_ability_a_mutation_reshapes() -> void:
	var text := BioGeneCatalog.get_gene(&"granulos_explosivos").summary()
	assert_true(text.contains("NETose"), "names NETose")
	assert_true(text.contains("explosão"), "and what changes")


func test_ascension_follows_the_share_of_own_class_mutations() -> void:
	var g := BioGenome.new()
	assert_near(g.ascension(), 0.0, 0.001, "a newborn has not risen")
	g.lineage = &"mieloide"
	g.equip(&"cilios_ageis")
	assert_near(g.ascension(), 0.0, 0.001, "a progenitor cannot rise")
	g.lineage = &"t_citotoxico"
	g.equipped = [&"cilios_ageis"] as Array[StringName]
	assert_near(g.ascension(), 0.0, 0.001, "generic mutations do not count")
	g.equip(&"receptor_fas")
	assert_near(g.ascension(), 1.0 / 4.0, 0.001, "one of four")
	g.equip(&"granzima_b")
	g.equip(&"agulha_litica")
	g.equip(&"miosina_de_contracao")
	assert_near(g.ascension(), 1.0, 0.001, "four of the class's own: the final form")


func test_every_form_has_its_own_nucleus_and_ghost_silhouette() -> void:
	var seen := {}
	for form in [&"mieloide", &"macrofago", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]:
		var shape := []
		for i in 12:
			shape.append(snappedf(BioNucleusShapes.radius_at(form, i * TAU / 12.0, 0.0), 0.05))
		assert_true(not seen.has(shape), "%s nucleus differs from the others" % form)
		seen[shape] = true
	var outlines := {}
	for form in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]:
		var outline := []
		for i in 16:
			outline.append(snappedf(BioGhostForm.radius_mul(form, i * TAU / 16.0, 1.0), 0.05))
		outlines[str(outline)] = true
	assert_eq(outlines.size(), 6, "six different ghosts")


func test_the_ghost_grows_gradually_and_nothing_is_added() -> void:
	for form in [&"macrofago", &"linfocito_b", &"t_citotoxico"]:
		assert_near(BioGhostForm.radius_mul(form, 1.0, 0.0), 1.0, 0.0001, "%s is untouched at zero" % form)
		var up := -PI * 0.5
		var head_a := BioGhostForm.radius_mul(form, up, 0.4)
		var head_b := BioGhostForm.radius_mul(form, up, 1.0)
		assert_true(head_b > head_a and head_a > 1.0, "%s: the head grows with the ascension" % form)
		for i in 64:  # one smooth outline: every angle keeps a sane radius
			var v := BioGhostForm.radius_mul(form, i * TAU / 64.0, 1.0)
			assert_true(v >= 0.45 and v < 2.2, "%s radius %f stays a single body" % [form, v])
	assert_true(BioGhostForm.head_center(&"macrofago", 20.0, 1.0).y < -10.0, "the nucleus rises into the head")


func test_a_body_stands_up_only_with_its_class_mutations() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	world.genome.lineage = &"t_auxiliar"
	for id in BioGeneCatalog.class_ids(&"t_auxiliar").slice(0, 3):
		world.genome.equip(id)
	world.player.combatant.set_genome(world.genome)
	body._ascend = 1.0
	await tree.create_timer(0.3).timeout
	assert_true(body._human > 0.9, "the humanoid factor is up")
	world.genome.equipped = []
	world.player.combatant.set_genome(world.genome)
	assert_near(body._ascend_target, 0.0, 0.001, "and falls back when the class genes are gone")
	world.queue_free()
	await tree.process_frame


func test_each_slot_has_its_own_pocket_so_marks_never_overlap() -> void:
	var rim := PackedVector2Array()
	for i in 64:
		rim.append(Vector2.from_angle(i * TAU / 64.0) * 30.0)
	var spots: Array[Vector2] = []
	for slot in BioGenome.SLOTS:
		spots.append(BioOrganelles.pocket_position(rim, slot))
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_true(spots[i].distance_to(spots[j]) > 12.0, "pockets %d and %d are apart" % [i, j])
	for id in BioGeneCatalog.all_ids():
		assert_true(not BioGeneCatalog.get_gene(id).mark.is_empty(), "%s has a visible mark" % id)
