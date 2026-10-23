extends SceneTree
## End-to-end codex and route against a running engine (real renderer): entries unlock as the cell visits places, the route arrives
## from the engine's `rota` decision, and the codex panel shows it. Prints STEP lines and exits 1 at the first step that fails.
##   godot --path clients/hospedeiro --script res://tests/e2e_codex.gd -- <engine_url> <output_dir>

var world: BioWorld
var out_dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8099"
	out_dir = args[1] if args.size() > 1 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	if not await _until(func() -> bool: return world.sync.link.online and world.codex_panel.entries.size() > 0, 20.0):
		return _fail("connect and receive the codex")
	_step("codex has %d entries, %d unlocked" % [world.codex_panel.entries.size(), world.codex_panel.unlocked_count()])
	if world.codex_panel.unlocked_count() < 1:
		return _fail("the marrow entry is unlocked at the start")
	for id in [BioBodyMap.SANGUE, BioBodyMap.CORACAO]:
		world.player.global_position = BioBodyMap.center_px(id)
		await create_timer(1.5).timeout
	if not await _until(func() -> bool: return world.codex_panel.unlocked_count() >= 3, 25.0):
		return _fail("visiting the venule and the heart unlocks entries")
	_step("after the venule and the heart: %d unlocked" % world.codex_panel.unlocked_count())
	if not await _until(func() -> bool: return world.exploration.route_id != "", 90.0):
		return _fail("the rota decision sets a route")
	_step("route from the engine: %s" % world.exploration.route_id)
	world.hud.show_banner("")
	world.codex_panel.toggle()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out_dir + "/e2e_codex_panel.png")
	print("E2E CODEX OK")
	quit(0)


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.15).timeout
	return false


func _step(text: String) -> void:
	print("STEP ", text)


func _fail(step: String) -> void:
	print("FAIL ", step)
	quit(1)
