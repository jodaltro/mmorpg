extends SceneTree
## End-to-end exploration against a running engine (real renderer): the cell is led by the chemical trail to a niche in the venule,
## comes back with a gene and the closed lung opens. Prints STEP lines and exits 1 at the first step that does not happen in time.
##   godot --path clients/hospedeiro --script res://tests/e2e_explore.gd -- <engine_url> <output_dir>

var world: BioWorld
var out_dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8097"
	out_dir = args[1] if args.size() > 1 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	if not await _until(func() -> bool: return world.sync.link.online and world.exploration.niche_count() > 0, 20.0):
		return _fail("connect and receive the exploration view")
	_step("connected; %d niches whisper, %d passages closed" % [world.exploration.niche_count(), world.exploration.gate_count()])
	if world.exploration.gate_count() != 1:
		return _fail("exactly the lung should be closed")
	var trail := world.exploration.compass(world.player.global_position, world.region)
	_step("the trail from the marrow points %s (%s)" % [trail.get("target", "nowhere"), trail.get("hint", "")])
	world.hud.show_banner("")
	await _shot("e2e_explore_01_marrow")

	# the marrow's own niche first, then on to the venule (what the compass would lead to)
	for niche in ["nicho-estroma", "bolsa-da-venula"]:
		var region := StringName(_niche_region(niche))
		world.player.global_position = BioBodyMap.niche_px(niche, region)
		if not await _until(func() -> bool: return _found(niche), 15.0):
			return _fail("the engine confirms the niche " + niche)
		_step("niche %s found" % niche)
		await create_timer(0.8).timeout
		await _shot("e2e_explore_02_" + niche)
	if not await _until(func() -> bool: return _genes().has("citoesqueleto-elastico"), 10.0):
		return _fail("the gene arrives in the genome")
	_step("genes now: %s" % str(_genes()))
	if not await _until(func() -> bool: return world.exploration.gate_count() == 0, 10.0):
		return _fail("the lung membrane opens")
	_step("the lung is open")

	world.player.global_position = BioBodyMap.center_px(BioBodyMap.PULMAO)
	if not await _until(func() -> bool: return str(world.sync.link.view.get("self", {}).get("region", "")) == "pulmao", 10.0):
		return _fail("the engine accepts the move into the lung")
	_step("the cell is in the lung, and the engine agrees")
	if not await _until(func() -> bool: return world.atlas.knows(&"pulmao"), 5.0):
		return _fail("the atlas knows the lung")
	await create_timer(0.5).timeout
	world.atlas.toggle()
	await create_timer(0.3).timeout
	await _shot("e2e_explore_03_atlas")
	print("E2E EXPLORE OK")
	quit(0)


func _niche_region(id: String) -> String:
	for n in world.exploration.niches:
		if str(n.get("id", "")) == id:
			return str(n.get("region", ""))
	return ""


func _found(id: String) -> bool:
	for n in world.sync.link.view.get("explore", {}).get("niches", []):
		if str(n.get("id", "")) == id:
			return bool(n.get("found", false))
	return false


func _genes() -> Array:
	var ev: Dictionary = world.sync.link.view.get("evolution", {})
	return ev.get("genes", []).map(func(g: Variant) -> String: return str(g.get("id", g)) if g is Dictionary else str(g))


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.15).timeout
	return false


func _shot(name: String) -> void:
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func _step(text: String) -> void:
	print("STEP ", text)


func _fail(step: String) -> void:
	print("FAIL ", step)
	quit(1)
