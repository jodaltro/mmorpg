extends SceneTree
## Enters the granuloma and then uses the REAL input path (actions, not the controller): can the cell move and attack in there?
##   godot --path clients/hospedeiro --script res://tests/e2e_dungeon_input.gd -- <engine_url>

var world: BioWorld


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else "http://127.0.0.1:8096"
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0
	root.add_child(world)
	await _until(func() -> bool: return world.sync.link.online, 20.0)
	BioFactory.spawn_nutrient(world, world.player.global_position, BioNutrientRules.Kind.GLUCOSE)
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	for i in 27:  # maturity at the world's pace (see tools/tune_pacing.py)
		world.virus_destroyed.emit()
		await create_timer(0.1).timeout
	await _until(func() -> bool: return world.gate.eligible, 30.0)
	world.player.global_position = world.gate.global_position + Vector2(1.0, 1.0) * BioArt.UNIT
	await create_timer(0.3).timeout
	_key(KEY_E, true)
	await create_timer(0.1).timeout
	_key(KEY_E, false)
	await _until(func() -> bool: return world.dungeon.active, 40.0)
	await create_timer(1.0).timeout
	print("inside: active=%s visible=%s alive=%s pos=%s" % [world.player.is_active(), world.player.visible, world.player.combatant.actor.vitals.is_alive(), world.player.global_position])
	var inputs := 0
	for child in world.player.get_children():
		if child is BioPlayerInput:
			inputs += 1
			print("input node processing: ", child.is_processing(), " mode ", child.process_mode)
	print("player process_mode ", world.player.process_mode, " physics processing ", world.player.is_physics_processing())
	var before := world.player.global_position
	_key(KEY_W, true)
	await create_timer(1.0).timeout
	_key(KEY_W, false)
	print("moved by pressing up: ", before.distance_to(world.player.global_position), " px; intent=", world.player.intent, " velocity=", world.player.velocity)
	var ctrl := world.player.get_node("Controller") as BioCellController
	print("lash status direct: ", ctrl.lash(), " (0 = started)")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await create_timer(0.3).timeout
	click.pressed = false
	Input.parse_input_event(click)
	print("atp after pressing lash: ", world.player.combatant.actor.vitals.atp, " cooldown left ", world.player.combatant.actor.cooldown_remaining(BioAttackCatalog.FLAGELLUM_LASH, BioClock.now()))
	var starts := [0]
	world.dungeon.room_started.connect(func(_i: int, _info: Dictionary) -> void: starts[0] += 1)
	var keys := [KEY_W, KEY_D, KEY_S, KEY_A]
	var last := world.player.global_position
	var worst_jump := 0.0
	for step in 40:
		var k: Key = keys[(step / 10) % 4]
		_key(k, true)
		await create_timer(0.5).timeout
		_key(k, false)
		var now := world.player.global_position
		worst_jump = maxf(worst_jump, now.distance_to(last))
		last = now
		if step % 8 == 0:
			print("t=%.1f pos=%s alive=%s hp=%.0f room=%d starts=%d" % [step * 0.5, now, world.player.combatant.actor.vitals.is_alive(), world.player.combatant.actor.vitals.membrane, world.dungeon.room_index, starts[0]])
	print("worst jump per 0.5s: ", worst_jump, " px; room starts: ", starts[0], "; dungeon active: ", world.dungeon.active)
	quit(0)


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.2).timeout
	return false

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
