extends SceneTree
## Prints the balance of every ability (value, price, worth) and every mutation (score by rarity).
##   godot --headless --path clients/hospedeiro --script res://tests/balance_report.gd
## Lines start with ABILITY or GENE so they can be parsed.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lash := BioAttackCatalog.get_def(BioAttackCatalog.FLAGELLUM_LASH)
	print("LASH worth %.2f" % (lash.damage / (lash.atp_cost + BioBalance.COOLDOWN_PRICE * lash.cooldown)))
	for lineage in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]:
		for id in BioAbilityCatalog.ids_of_class(lineage):
			var a := BioAbilityCatalog.get_ability(id)
			print("ABILITY %s %s value %.1f price %.1f worth %.2f" % [lineage, id, BioBalance.ability_value(id, a), BioBalance.ability_price(a), BioBalance.worth(id, a)])
	for id in BioGeneCatalog.all_ids():
		var gene := BioGeneCatalog.get_gene(id)
		var rarity := ""
		print("GENE %s %s score %.1f" % [id, gene.requires_lineage, BioBalance.gene_score(id)])
	quit()
