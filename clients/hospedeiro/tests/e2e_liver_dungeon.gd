extends SceneTree
## Against a running engine (with the advisor on): a cell matures, gets the key to the aorta, walks to the liver, enters the Cordões
## Hepáticos, the advisor picks the modifier from what the liver's state allows, the five rooms are cleared and the engine rewards the run.
##   godot --path clients/hospedeiro --script res://tests/e2e_liver_dungeon.gd -- <engine_url> <output_dir>

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
	await create_timer(0.5).timeout
	for id in [BioBodyMap.SANGUE, BioBodyMap.SANGUE]:
		world.debug_goto(id)
		await create_timer(0.6).timeout
	for i in 27:  # maturity at the world's pace (see tools/tune_pacing.py)
		world.virus_destroyed.emit()
		await create_timer(0.1).timeout
	await world.sync.link.occur("achar-nicho", {"niche": "bolsa-da-venula"})
	_step("the venule's niche gave the elastic cytoskeleton")
	for id in [BioBodyMap.CORACAO, BioBodyMap.AORTA, BioBodyMap.FIGADO]:
		world.debug_goto(id)
		if not await _until(func() -> bool: return str(world.sync.link.view.get("self", {}).get("region", "")) == String(id), 10.0):
			return _fail("the engine moves the cell to %s" % String(id))
		_step("in %s" % String(id))
	var door := world.liver_gate
	if not await _until(func() -> bool: return door.eligible, 30.0):
		return _fail("the cords open once the cell is mature, inside the liver")
	_step("the cords are open to this cell")
	world.player.global_position = door.global_position + Vector2(1.0, 1.0) * BioArt.UNIT
	await create_timer(0.4).timeout
	await _shot("e2e_l1_gate")
	await world.sync.enter_dungeon(door)
	if not await _until(func() -> bool: return world.dungeon.active, 40.0):
		return _fail("the run starts (advisor or default modifier)")
	if world.dungeon.dungeon_id != "cordoes-hepaticos":
		return _fail("the run is the cords, not %s" % world.dungeon.dungeon_id)
	_step("run started: %s, modifier: %s, seed %d" % [world.dungeon.title, world.dungeon.modifier, world.dungeon.seed_value])
	for room in 5:
		if not await _until(func() -> bool: return world.dungeon.room_index == room and world.dungeon.enemies().size() > 0, 40.0):
			return _fail("room %d builds" % room)
		var kinds := {}
		for e in world.dungeon.enemies():
			kinds[str(e.get_meta("kind", ""))] = true
		_step("room %d (%s): %d enemies %s" % [room + 1, world.dungeon.room_kind, world.dungeon.enemies().size(), str(kinds.keys())])
		if room in [0, 3, 4]:
			await create_timer(1.2).timeout
			await _shot("e2e_l2_room_%d" % (room + 1))
		for e in world.dungeon.enemies():
			(e as BioCellActor).combatant.actor.vitals.take_damage(9999.0)
			e.queue_free()
		if room < 4 and not await _until(func() -> bool: return world.dungeon.room_index == room + 1, 40.0):
			return _fail("the engine confirms room %d and opens the next" % (room + 1))
	if not await _until(func() -> bool: return not world.dungeon.active, 40.0):
		return _fail("the cleared run closes")
	_step("cords cleared")
	var seals := func() -> bool: return world.sync.link.view.get("skills", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == "selo-do-figado")
	if not await _until(seals, 20.0):
		return _fail("the engine rewards the clear with the liver's seal")
	_step("rewarded with the seal; first clear title: %s" % str(world.sync.link.view.get("skills", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == "primeiro-filtro")))
	await _shot("e2e_l3_done")
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
