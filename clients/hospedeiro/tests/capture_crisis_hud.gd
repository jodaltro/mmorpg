extends SceneTree
## The whole screen during a crisis, in the real game against an isolated engine: arriving, waiting for the offer, the offer, the calling worn,
## and leaving. Full frames, to judge the feed, the crisis card and the call to action together.
##   godot --path clients/hospedeiro --script res://tests/capture_crisis_hud.gd -- http://127.0.0.1:8198 <out_dir>

const REGIONS := ["pele", "baco", "figado", "intestino", "pulmao", "medula", "rim", "linfonodo", "cerebro"]


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String, dir: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("HUD shot %s" % name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[1]
	DirAccess.make_dir_recursive_absolute(dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0]
	root.add_child(world)
	await create_timer(4.0).timeout
	_shot("0_start", dir)
	var found := ""
	for round_i in 40:
		for region in REGIONS:
			world.player.global_position = BioBodyMap.center_px(StringName(region))
			await create_timer(0.5).timeout
			var v := world.engine_calling_view()
			if str(v.get("conflict", "")) != "" and not (v.get("offer", []) as Array).is_empty():
				found = region
				break
		if found != "":
			break
	if found == "":
		print("HUD no crisis")
		quit(1)
		return
	_shot("1_arrived", dir)
	for i in 40:  # the offer shows after a short stay; the crisis may also end meanwhile
		await create_timer(0.25).timeout
		if world.calling_panel.is_card_visible():
			break
	await create_timer(0.3).timeout
	_shot("2_offer", dir)
	if world.calling_panel.option_ids().is_empty():
		print("HUD the crisis ended before the offer")
		quit(1)
		return
	world.calling_panel.chosen.emit(world.calling_panel.option_ids()[0])
	await create_timer(2.0).timeout
	_shot("3_worn", dir)
	await create_timer(6.0).timeout
	_shot("4_later", dir)
	world.player.global_position = BioBodyMap.center_px(&"sangue")
	await create_timer(4.0).timeout
	_shot("5_left", dir)
	quit()
