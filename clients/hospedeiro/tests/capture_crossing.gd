extends SceneTree
## Frames of the cell crossing the body from the marrow to the aorta (real renderer), the atlas, and the frame rate on the way.
##   godot --path clients/hospedeiro --script res://tests/capture_crossing.gd -- <output_dir>

const STEP := 0.1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir + "/walk")
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.8).timeout
	world.camera.zoom = Vector2.ONE * 0.9
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	var path: Array[Vector2] = BioAnatomy.route(BioBodyMap.seed_value, &"medula", &"aorta")
	var ctrl := world.player.get_node("Controller") as BioCellController
	var step := 0
	var frame := 0
	var shots := 0
	var worst := 0.0
	var samples := 0
	var total := 0.0
	var by_region := {}
	var started := Time.get_ticks_msec()
	var shoot := OS.get_cmdline_user_args().size() > 1  # a second argument: save the walk frames (slows the run down)
	while step < path.size() and Time.get_ticks_msec() - started < 180000:
		var to: Vector2 = path[step] * BioArt.UNIT - world.player.global_position
		if to.length() < 2.5 * BioArt.UNIT:
			step += 1
			continue
		ctrl.move(to.normalized())
		ctrl.set_aim(to)
		await process_frame
		var fps := Engine.get_frames_per_second()
		if frame > 90:
			by_region[world.region] = (by_region.get(world.region, []) as Array) + [fps]
			total += fps
			samples += 1
			worst = fps if samples == 1 else minf(worst, fps)
		world.decline_mutation()
		if frame % 120 == 0 and frame > 90:
			print("PERF %s process=%.1fms physics=%.1fms draws=%d objs=%d nodes=%d" % [world.region, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		if shoot and frame % 6 == 0:
			root.get_texture().get_image().save_png("%s/walk/f%03d.png" % [out_dir, shots])
			shots += 1
		frame += 1
	ctrl.move(Vector2.ZERO)
	for id in by_region:
		var list: Array = by_region[id]
		print("FPS %s mean=%.1f min=%.0f" % [id, list.reduce(func(a, b): return a + b, 0.0) / list.size(), list.min()])
	print("CROSSING steps=%d/%d frames=%d shots=%d mean_fps=%.1f worst_fps=%.1f seconds=%.1f" % [step, path.size(), frame, shots, total / maxf(samples, 1), worst, (Time.get_ticks_msec() - started) * 0.001])
	for id in [BioBodyMap.CORACAO, BioBodyMap.PULMAO, BioBodyMap.AORTA]:
		world.player.global_position = BioBodyMap.center_px(id)
		await create_timer(1.2).timeout
		world.decline_mutation()
		await create_timer(0.2).timeout
		root.get_texture().get_image().save_png("%s/region_%s.png" % [out_dir, id])
	world.atlas.toggle()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s/atlas.png" % out_dir)
	quit()
