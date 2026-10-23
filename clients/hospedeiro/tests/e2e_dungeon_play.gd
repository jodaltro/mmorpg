extends SceneTree
## Plays the granuloma the way a person would (engine on, real renderer): enters it and fights for a while with the ability keys,
## measuring frame times to catch freezes. Prints the worst frame and whether the process kept advancing.
##   godot --path clients/hospedeiro --script res://tests/e2e_dungeon_play.gd -- <engine_url> <output_dir>

var world: BioWorld
var worst_ms := 0.0
var frames := 0
var last := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last > 0:
		worst_ms = maxf(worst_ms, (now - last) / 1000.0)
	last = now
	frames += 1
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8096"
	var out_dir: String = args[1] if args.size() > 1 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
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
	world.player.global_position = world.gate.global_position + Vector2(-16.0, 4.0) * BioArt.UNIT
	await create_timer(0.5).timeout
	await _shot(out_dir, "ux_0_far")
	world.player.global_position = world.gate.global_position + Vector2(1.0, 1.0) * BioArt.UNIT
	await create_timer(0.3).timeout
	var ctrl := world.player.get_node("Controller") as BioCellController
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	await _shot(out_dir, "ux_1_gate_near")
	var t0 := Time.get_ticks_msec()
	world.sync.enter_dungeon()  # what the E key does next to the gate
	await create_timer(1.0).timeout
	await _shot(out_dir, "ux_2_preparing")
	print("pressed E near the gate; near=", world.gate.is_near(), " eligible=", world.gate.eligible)
	await create_timer(1.5).timeout
	print("run in view: ", str(world.sync.link.view.get("dungeon", {}).get("run", null)).left(200))
	if not await _until(func() -> bool: return world.dungeon.active, 40.0):
		print("FAILED: the run never started")
		quit(1)
		return
	print("seconds from E to inside: ", (Time.get_ticks_msec() - t0) / 1000.0)
	print("inside, frames so far ", frames, " worst frame ms ", worst_ms)
	var started := Time.get_ticks_msec()
	var hang_at := frames
	while Time.get_ticks_msec() - started < 30000:
		var target: BioCellActor = null
		var best := INF
		for e in world.dungeon.enemies():
			var d := (e as BioCellActor).global_position.distance_to(world.player.global_position)
			if d < best:
				best = d
				target = e
		if target != null:
			var to := target.global_position - world.player.global_position
			ctrl.set_aim(to)
			ctrl.move(to.normalized() * 0.5)
			ctrl.lash()
		await create_timer(0.1).timeout
		if world.player.combatant.actor.vitals.membrane < 30.0:
			world.player.combatant.actor.vitals.membrane = world.player.combatant.actor.vitals.max_membrane
	print("played 30 s: frames advanced ", frames - hang_at, ", worst frame ms ", worst_ms, ", room ", world.dungeon.room_index, ", enemies ", world.dungeon.enemies().size())
	root.get_texture().get_image().save_png("%s/play.png" % out_dir)
	quit(0)


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.2).timeout
	return false

func _shot(dir: String, name: String) -> void:
	await create_timer(0.15).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
