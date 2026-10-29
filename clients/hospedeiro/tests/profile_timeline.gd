extends SceneTree
## Frame by frame process time in one organ, to tell a constant load from periodic spikes.
##   godot --path clients/hospedeiro --script res://tests/profile_timeline.gd -- <engine url> <organ>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else ""
	root.add_child(world)
	await create_timer(4.0).timeout
	world.player.global_position = BioBodyMap.center_px(StringName(args[1] if args.size() > 1 else "aorta"))
	await create_timer(3.0).timeout
	var line := ""
	var values: Array[float] = []
	for i in 240:
		await process_frame
		values.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	values.sort()
	print("TL min %.1f p10 %.1f p50 %.1f p90 %.1f max %.1f" % [values[0], values[24], values[120], values[216], values[-1]])
	quit()
