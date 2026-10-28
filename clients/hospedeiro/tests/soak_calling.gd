extends SceneTree
## The calling, end to end in the real game against a real (isolated, fast) engine: walk the organs until a crisis offers callings,
## pick one through the panel's own signal, check the engine confirmed it and the cell wears the form, then leave and check it is given back.
##   godot --path clients/hospedeiro --script res://tests/soak_calling.gd -- http://127.0.0.1:8198 2>&1 | grep -E "CALLING|ERROR|SCRIPT"

const REGIONS := ["pele", "baco", "figado", "intestino", "pulmao", "medula", "rim", "linfonodo", "cerebro"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else "http://127.0.0.1:8198"
	root.add_child(world)
	await create_timer(3.0).timeout
	var found := ""
	for round_i in 40:
		for region in REGIONS:
			world.player.global_position = BioBodyMap.center_px(StringName(region))
			await create_timer(1.6).timeout
			var view := world.engine_calling_view()
			if BioCallingRules.is_choosing(view):
				found = region
				break
		if found != "":
			break
	if found == "":
		print("CALLING no crisis offered a calling in the time given")
		quit(1)
		return
	var view := world.engine_calling_view()
	var ids := world.calling_panel.option_ids()
	print("CALLING offered in %s: %s (card visible: %s)" % [found, ids, world.calling_panel.is_card_visible()])
	var before := world.lineage_id
	world.calling_panel.chosen.emit(ids[0])
	await create_timer(2.5).timeout
	view = world.engine_calling_view()
	print("CALLING held: %s role %s form %s | cell wears %s (was %s) | chip: %s" % [view.get("current"), view.get("role"), view.get("form"), world.lineage_id, before, world.calling_panel.chip_text()])
	world.player.global_position = BioBodyMap.center_px(&"sangue")
	await create_timer(3.0).timeout
	view = world.engine_calling_view()
	print("CALLING after leaving: current '%s', cell wears %s (base %s)" % [view.get("current", ""), world.lineage_id, before])
	quit()
