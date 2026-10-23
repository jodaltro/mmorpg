extends SceneTree
## Against a running engine: the restart button starts a new world and the cell rejoins as a newborn.
##   godot --path clients/hospedeiro --script res://tests/e2e_restart.gd -- <engine_url> <output_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else "http://127.0.0.1:8096"
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	await _until(func() -> bool: return world.sync.link.online)
	await create_timer(1.5).timeout
	world.abilities.learn(&"engolir")
	var before := int(world.sync.link.view.get("tick", 0))
	var health_before: Dictionary = (await world.sync.link.request(HTTPClient.METHOD_GET, "/v1/health")).body
	world.hud.press_restart()
	world.hud.press_restart()
	await _until(func() -> bool: return not world.sync.link.online)
	await _until(func() -> bool: return world.sync.link.online)
	await create_timer(1.5).timeout
	var health_after: Dictionary = (await world.sync.link.request(HTTPClient.METHOD_GET, "/v1/health")).body
	print("tick before ", health_before.get("tick"), " after ", health_after.get("tick"), " (view tick before ", before, ")")
	print("abilities after: ", world.abilities.known(), " lineage: '", world.lineage_id, "'")
	var ok := int(health_after.get("tick", 99)) < int(health_before.get("tick", 0)) and world.abilities.known().is_empty()
	root.get_texture().get_image().save_png("%s/restart.png" % (args[1] if args.size() > 1 else "."))
	print("RESTART OK" if ok else "RESTART FAILED")
	quit(0 if ok else 1)


func _until(cond: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and not cond.call():
		await create_timer(0.1).timeout
