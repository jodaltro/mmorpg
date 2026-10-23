extends SceneTree
## Against a running engine (with the advisor on): a cell matures, enters the granuloma, the advisor picks the modifier, the rooms of the run are
## cleared and the boss falls, and the engine rewards the run. Needs a real renderer for the screenshots.
##   godot --path clients/hospedeiro --script res://tests/e2e_dungeon.gd -- <engine_url> <output_dir>

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
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	for i in 27:  # maturity at the world's pace (see tools/tune_pacing.py)
		world.virus_destroyed.emit()
		await create_timer(0.1).timeout
	if not await _until(func() -> bool: return world.gate.eligible, 30.0):
		return _fail("the entrance opens once the cell is mature")
	_step("the granuloma is open to this cell")
	world.player.global_position = world.gate.global_position + Vector2(1.0, 1.0) * BioArt.UNIT
	await create_timer(0.3).timeout
	await _shot("e2e_d1_gate")
	await world.sync.enter_dungeon()
	if not await _until(func() -> bool: return world.dungeon.active, 40.0):
		return _fail("the run starts (advisor or default modifier)")
	_step("run started, modifier: %s, seed %d" % [world.dungeon.modifier, world.dungeon.seed_value])
	var total := world.dungeon.rooms.size()  # procedural: the run draws its own length
	_step("this run has %d rooms: %s" % [total, str(world.dungeon.rooms.map(func(r: Dictionary) -> String: return str(r.get("kind", ""))))])
	for room in total:
		if not await _until(func() -> bool: return world.dungeon.room_index == room and world.dungeon.enemies().size() > 0, 40.0):
			return _fail("room %d builds" % room)
		_step("room %d (%s): %d enemies" % [room + 1, world.dungeon.room_kind, world.dungeon.enemies().size()])
		if room in [0, 3, 4]:
			await create_timer(1.2).timeout
			await _shot("e2e_d2_room_%d" % (room + 1))
		for e in world.dungeon.enemies():
			(e as BioCellActor).combatant.actor.vitals.take_damage(9999.0)
			e.queue_free()
		if room < total - 1 and not await _until(func() -> bool: return world.dungeon.room_index == room + 1, 40.0):
			return _fail("the engine confirms room %d and opens the next" % (room + 1))
	if not await _until(func() -> bool: return not world.dungeon.active, 40.0):
		return _fail("the cleared run closes")
	_step("granuloma cleared")
	var skills: Array = world.sync.link.view.get("skills", []).map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	if not await _until(func() -> bool: return world.sync.link.view.get("skills", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == "selo-do-granuloma"), 20.0):
		return _fail("the engine rewards the clear with the seal (skills: %s)" % str(skills))
	_step("rewarded with the seal; first clear title: %s" % str(world.sync.link.view.get("skills", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == "primeiro-selador")))
	await _shot("e2e_d3_done")
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
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
