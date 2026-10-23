extends SceneTree
## Against a running engine: the cell grows seven genes (one more than the slots), the Body window picks them when calm, the eldest
## goes to the library, a build is saved, a gene is swapped from the library, and the saved build brings the old set back.
##   godot --path clients/hospedeiro --script res://tests/e2e_body.gd -- <engine_url> <output_dir>

var world: BioWorld
var out_dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8096"
	out_dir = args[1] if args.size() > 1 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	if not await _until(func() -> bool: return world.sync.link.online, 20.0):
		return _fail("connect")
	_step("connected")
	BioFactory.spawn_nutrient(world, world.player.global_position, BioNutrientRules.Kind.GLUCOSE)
	await create_timer(0.6).timeout

	var chosen := 0
	var kills := 0
	var rounds := 0
	while chosen < 7 and rounds < 80:
		rounds += 1
		for i in 10:  # a threshold's worth of kills, then wait for the engine (and Jev) to compose the offer
			world.virus_destroyed.emit()
			kills += 1
			await create_timer(0.08).timeout
		if not await _until(func() -> bool: return not world.panel.offer_kind().is_empty(), 45.0):
			continue
		var kind := world.panel.offer_kind()
		world.sensor.state.reset()
		world.body_panel.open()
		if not await _until(func() -> bool: return world.body_panel.pick(0), 5.0):
			return _fail("an offer (%s) is chosen from the Body window when calm" % kind)
		if kind == "mutation":
			chosen += 1
			_step("gene %d chosen (%d kills)" % [chosen, kills])
		else:
			_step("differentiation chosen (%d kills)" % kills)
		if not await _until(func() -> bool: return world.panel.offer_kind().is_empty() or world.panel.offer_kind() != kind, 30.0):
			return _fail("the engine confirms the choice")
		world.body_panel.close()
	if chosen < 7:
		return _fail("seven genes after %d kills" % kills)

	var ev := func() -> Dictionary: return world.engine_evolution_view()
	if not await _until(func() -> bool: return (ev.call().get("library", []) as Array).size() == 1, 10.0):
		return _fail("the eldest gene went to the library, not away: %s" % str(ev.call().get("library")))
	_step("library holds the eldest gene: %s" % str(ev.call()["library"][0]["name"]))
	var before: Array = (ev.call()["genes"] as Array).map(func(g: Dictionary) -> String: return str(g["id"]))

	world.sensor.state.reset()
	world.body_panel.open(BioBodyPanel.BUILDS)
	world.body_panel.save_build(1)
	if not await _until(func() -> bool: return ((ev.call().get("builds", [{}])[0] as Dictionary).get("genes", []) as Array).size() == 6, 10.0):
		return _fail("build 1 is saved with the six expressed genes")
	_step("build 1 saved")

	world.body_panel.show_tab(BioBodyPanel.GENES)
	world.body_panel._swap_in = str(ev.call()["library"][0]["id"])
	world.body_panel._swap_out = before[0]
	world.body_panel.refresh()
	await _shot("e2e_b1_swap_preview")
	world.body_panel.express_selected()
	if not await _until(func() -> bool: return not (ev.call()["genes"] as Array).any(func(g: Dictionary) -> bool: return str(g["id"]) == before[0]), 10.0):
		return _fail("the swap is confirmed: the old gene is silenced")
	_step("swapped: the old gene is in the library now")
	if world.body_panel.lock_reason().is_empty():
		return _fail("the body rests after the change")
	_step("the body rests: %s" % world.body_panel.lock_reason())
	await _shot("e2e_b2_resting")

	if not await _until(func() -> bool: return world.body_panel.lock_reason().is_empty(), 30.0):
		return _fail("the rest ends")
	world.body_panel.apply_build(1)
	var back := func() -> bool:
		var now: Array = (ev.call()["genes"] as Array).map(func(g: Dictionary) -> String: return str(g["id"]))
		now.sort()
		var want := before.duplicate()
		want.sort()
		return now == want
	if not await _until(back, 10.0):
		return _fail("applying build 1 brings the old set back")
	_step("build 1 applied: the old set is expressed again")
	await _shot("e2e_b3_applied")
	print("E2E OK")
	quit(0)


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.2).timeout
	return false


func _step(text: String) -> void:
	print("STEP ok: ", text)


func _fail(what: String) -> void:
	print("STEP FAILED: ", what)
	quit(1)


func _shot(name: String) -> void:
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
