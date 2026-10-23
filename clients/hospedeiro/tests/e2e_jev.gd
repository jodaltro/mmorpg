extends SceneTree
## End to end against a running engine WITH Jev: a few deeds, then the first design is asked, Jev answers, and the Jev panel shows who
## decided what (real renderer). Exits 1 if no answer by Jev shows up.
##   godot --path clients/hospedeiro --script res://tests/e2e_jev.gd -- <engine_url> <output_dir>

var world: BioWorld


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8099"
	var out_dir: String = args[1] if args.size() > 1 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	if not await _until(func() -> bool: return world.sync.link.online, 20.0):
		return _fail("connect")
	print("STEP connected; badge: ", world.jev_panel.badge_text())
	for i in 4:
		world.sync.link.occur("estilo-chicote")
		world.sync.link.occur("derrotar-virus")
	if not await _until(func() -> bool: return int(world.jev_panel.totals()["jev"]) >= 5, 120.0):
		print("badge: ", world.jev_panel.badge_text())
		return _fail("Jev answered some decisions")
	await create_timer(1.0).timeout
	print("STEP badge: ", world.jev_panel.badge_text())
	print("STEP design: ", world.design_traits)
	world.jev_panel.toggle()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out_dir + "/jev_panel.png")
	world.jev_panel.toggle()
	world.debug_menu.toggle()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out_dir + "/debug_menu.png")
	print("E2E JEV OK")
	quit(0)


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.2).timeout
	return false


func _fail(step: String) -> void:
	print("FAIL ", step)
	quit(1)
