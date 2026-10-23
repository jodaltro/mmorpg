extends SceneTree
## Against a running engine (with the advisor on): a cell matures, walks to the spleen, the intestine and the kidney, takes a mote in each
## (the engine's vital for the organ moves), and clears the procedural dungeon of each, the advisor picking the modifier from the organ's state.
##   godot --path clients/hospedeiro --script res://tests/e2e_organs.gd -- <engine_url> <output_dir>

var world: BioWorld
var out_dir := "."

## organ, mote kind, the vital the verb moves, the dungeon and its seal
const TOURS := [
	[&"baco", &"hemacia_velha", "hemacias", "centro-germinativo", "selo-do-baco"],
	[&"intestino", &"microbio", "microbiota", "criptas-profundas", "selo-do-intestino"],
	[&"rim", &"cristal_de_ureia", "ureia", "nefrons", "selo-do-rim"],
]


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
	for i in 90:  # maturity at the world's pace, enough for the kidney's dungeon too
		world.virus_destroyed.emit()
		await create_timer(0.08).timeout
	await world.sync.link.occur("achar-nicho", {"niche": "bolsa-da-venula"})
	_step("the venule's niche gave the key to the aorta")
	for id in [BioBodyMap.CORACAO, BioBodyMap.AORTA]:
		world.debug_goto(id)
		if not await _until(func() -> bool: return _region() == String(id), 10.0):
			return _fail("the engine moves the cell to %s" % String(id))
	for tour in TOURS:
		var organ: StringName = tour[0]
		world.debug_goto(BioBodyMap.AORTA)
		await create_timer(0.8).timeout
		world.debug_goto(organ)
		if not await _until(func() -> bool: return _region() == String(organ), 10.0):
			return _fail("the engine moves the cell to %s" % String(organ))
		_step("in %s" % String(organ))
		var vital_before := _vital(str(tour[2]))
		var mote := BioMote.new()
		mote.configure(tour[1])
		mote.position = world.player.global_position
		world.add_child(mote)
		mote.taken.connect(func(kind: StringName) -> void: world.organ_deed.emit(str(BioMoteRules.kind(kind)["action"])))
		if not await _until(func() -> bool: return _vital(str(tour[2])) != vital_before, 15.0):
			return _fail("the mote's deed moves the engine's vital %s (still %d)" % [tour[2], vital_before])
		_step("the mote moved %s: %d -> %d" % [tour[2], vital_before, _vital(str(tour[2]))])
		var door: BioGate = world.gates[tour[3]]
		if not await _until(func() -> bool: return door.eligible, 40.0):
			return _fail("the door of %s opens for the mature cell" % tour[3])
		world.player.global_position = door.global_position + Vector2(1.0, 1.0) * BioArt.UNIT
		await create_timer(0.4).timeout
		await _shot("e2e_o_%s_door" % String(organ))
		await world.sync.enter_dungeon(door)
		if not await _until(func() -> bool: return world.dungeon.active, 40.0):
			return _fail("the run of %s starts" % tour[3])
		var total := world.dungeon.rooms.size()
		_step("run in %s: modifier %s, %d rooms %s" % [tour[3], world.dungeon.modifier, total, str(world.dungeon.rooms.map(func(r: Dictionary) -> String: return str(r.get("kind", ""))))])
		for room in total:
			if not await _until(func() -> bool: return world.dungeon.room_index == room and world.dungeon.enemies().size() > 0, 40.0):
				return _fail("room %d of %s builds" % [room + 1, tour[3]])
			if room == 2:
				await create_timer(1.2).timeout
				await _shot("e2e_o_%s_room3" % String(organ))
			for e in world.dungeon.enemies():
				(e as BioCellActor).combatant.actor.vitals.take_damage(9999.0)
				e.queue_free()
			if room < total - 1 and not await _until(func() -> bool: return world.dungeon.room_index == room + 1, 40.0):
				return _fail("the engine confirms room %d of %s" % [room + 1, tour[3]])
		if not await _until(func() -> bool: return not world.dungeon.active, 40.0):
			return _fail("the cleared run of %s closes" % tour[3])
		var seal := str(tour[4])
		if not await _until(func() -> bool: return world.sync.link.view.get("skills", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == seal), 20.0):
			return _fail("the engine rewards %s with %s" % [tour[3], seal])
		_step("%s cleared and rewarded with %s" % [tour[3], seal])
		world.player.combatant.reset_vitals()
		await create_timer(0.5).timeout
	print("E2E OK")
	quit(0)


func _region() -> String:
	return str(world.sync.link.view.get("self", {}).get("region", ""))


func _vital(id: String) -> int:
	for v in world.sync.link.view.get("vitals", []):
		if str(v.get("id", "")) == id:
			return int(v.get("value", 0))
	return -1


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
