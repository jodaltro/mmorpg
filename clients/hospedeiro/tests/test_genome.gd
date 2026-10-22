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
	for id in [&"cilios_ageis", &"cauda_longa", &"enzima_voraz"]:
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
	var dirty := BioGenome.from_dict({"equipped": ["cilios_ageis", "does_not_exist", "cilios_ageis", "cauda_longa", "enzima_voraz", "membrana_espessa"]})
	var expected: Array[StringName] = [&"cilios_ageis", &"cauda_longa", &"enzima_voraz"]
	assert_eq(dirty.equipped, expected, "unknown, duplicated and extra genes dropped")


func test_every_gene_has_a_benefit_and_a_cost() -> void:
	for id in BioGeneCatalog.all_ids():
		var gene := BioGeneCatalog.get_gene(id)
		var gains := 0
		var costs := 0
		for stat in gene.mods:
			var v: float = gene.mods[stat]
			var neutral: float = 0.0 if BioGene.is_additive(stat) else 1.0
			var lower_is_better: bool = stat == BioGene.SPIT_COST or stat == BioGene.DASH_COOLDOWN
			var good: bool = (v < neutral) if lower_is_better else (v > neutral)
			if good:
				gains += 1
			else:
				costs += 1
		assert_true(gains >= 1 and costs >= 1, "%s needs a benefit and a trade-off" % id)
