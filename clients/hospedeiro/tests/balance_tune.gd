extends SceneTree
## Writes data/balance.json from the yardstick. Run twice: first the abilities, then (with those applied) the mutations.
##   godot --headless --path clients/hospedeiro --script res://tests/balance_tune.gd -- abilities|genes
## The mutations need each one's rarity: it is read from data/gene_rarity.json (written by tools/gen_mutations.py).

const PATH := "res://data/balance.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "abilities"
	var data: Dictionary = {}
	if FileAccess.file_exists(PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if stage == "abilities":
		var out := {}
		for lineage in [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar", &"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]:
			for id in BioAbilityCatalog.ids_of_class(lineage):
				var changed := BioBalance.tune_ability(id)
				if not changed.is_empty():
					out[String(id)] = changed
		data["abilities"] = out
	else:
		var rarity: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gene_rarity.json"))
		var out := {}
		for id in BioGeneCatalog.all_ids():
			out[String(id)] = BioBalance.tune_gene(id, str(rarity.get(String(id), "incomum")))
		data["genes"] = out
	DirAccess.make_dir_recursive_absolute("res://data")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	print("wrote ", PATH, " (", stage, ")")
	quit()
