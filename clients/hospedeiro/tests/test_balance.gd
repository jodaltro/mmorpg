extends TestCase
## The balance yardstick (BioBalance) holds the whole content to one standard: every class ability is worth the same per ATP and
## per second of cooldown, and every mutation is worth what its rarity says. If someone edits a number and breaks the band, this
## fails and says which one. Re-tune with tests/balance_tune.gd and tools/gen_mutations.py (see Docs/Hospedeiro/Balance.md).

const CLASSES := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar", &"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]


func test_every_class_ability_sits_in_the_same_worth_band() -> void:
	var lash := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	var lash_worth := lash.damage / (lash.atp_cost + BioBalance.COOLDOWN_PRICE * lash.cooldown)
	var count := 0
	for lineage in CLASSES:
		for id in BioAbilityCatalog.ids_of_class(lineage):
			var a := BioAbilityCatalog.get_ability(id)
			var w := BioBalance.worth(id, a)
			count += 1
			var goal := BioBalance.target_worth(lineage)
			assert_true(absf(w - goal) <= goal * BioBalance.WORTH_TOLERANCE, "%s is worth %.2f, its class band is %.2f +/- %d%%" % [id, w, goal, int(BioBalance.WORTH_TOLERANCE * 100.0)])
			assert_true(w > lash_worth * 0.85, "%s must not be worse than the basic lash (%.2f)" % [id, lash_worth])
			assert_true(float(a["cooldown"]) >= 1.0, "%s has a real cooldown" % id)
	assert_eq(count, 40, "all 40 abilities were measured")


func test_the_counter_never_makes_the_cell_untouchable() -> void:
	var a := BioAbilityCatalog.get_ability(&"contragolpe")
	assert_true(float(a["taken"]) >= 0.2, "a counter lets at least a fifth through")
	assert_true(float(a["seconds"]) <= 4.0, "and does not last long")


func test_every_mutation_is_worth_what_its_rarity_says() -> void:
	var rarity: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gene_rarity.json"))
	var by_rarity := {}
	for id in BioGeneCatalog.all_ids():
		var r: String = rarity[String(id)]
		var score := BioBalance.gene_score(id)
		var target := BioBalance.target_for(r)
		assert_true(absf(score - target) <= maxf(1.5, target * BioBalance.RARITY_TOLERANCE), "%s (%s) scores %.1f, the target is %.1f" % [id, r, score, target])
		by_rarity[r] = float(by_rarity.get(r, 0.0)) + score
	assert_true(by_rarity.size() == 4, "four rarities in use")
	var mean := func(r: String) -> float: return float(by_rarity[r]) / float(rarity.values().count(r))
	assert_true(mean.call("comum") < mean.call("incomum") and mean.call("incomum") < mean.call("rara") and mean.call("rara") < mean.call("epica"), "rarer is stronger")


func test_no_mutation_is_a_pure_upgrade() -> void:
	for id in BioGeneCatalog.all_ids():
		var gene := BioGeneCatalog.get_gene(id)
		var costs := 0
		for stat in gene.mods:
			var v: float = gene.mods[stat]
			var hurts: bool = (v < 0.0) if stat == &"atp_regen" else ((v > 1.0) if BioBalance.LOWER_IS_BETTER.has(stat) else (v < 1.0))
			if hurts:
				costs += 1
		assert_true(costs >= 1, "%s has a trade-off" % id)
