extends SceneTree
## Plays the real game against a real engine and measures each organ: frame time (mean, p95, worst), script and physics time, draw calls,
## nodes, drawn crowd cells and invaders. Stays a while in each organ moving around it, the way a player does.
##   godot --path clients/hospedeiro --script res://tests/soak_perf.gd -- http://127.0.0.1:8198 <seconds per organ>

const REGIONS := ["medula", "sangue", "coracao", "pulmao", "aorta", "figado", "baco", "intestino", "rim", "pele", "linfonodo", "cerebro"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[1]) if args.size() > 1 else 12.0
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else ""
	root.add_child(world)
	await create_timer(4.0).timeout
	print("PERF organ        mean_ms  p95_ms  worst_ms  proc_ms  phys_ms  draws  nodes  crowd  invaders")
	for region in REGIONS:
		var center := BioBodyMap.center_px(StringName(region))
		world.player.global_position = center
		await create_timer(1.5).timeout
		var frames: Array[float] = []
		var proc := 0.0
		var phys := 0.0
		var draws := 0.0
		var t := 0.0
		var last := Time.get_ticks_usec()
		while t < seconds:
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			frames.append(ms)
			t += ms / 1000.0
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var a := t * 0.7  # walk a slow circle in the organ
			world.player.global_position = center + Vector2.from_angle(a) * BioArt.UNIT * 10.0
		var n := float(frames.size())
		var sorted := frames.duplicate()
		sorted.sort()
		var mean := 0.0
		for f in frames:
			mean += f
		mean /= n
		print("PERF %-12s %7.1f %7.1f %9.1f %8.2f %8.2f %6.0f %6d %6d %9d" % [region, mean, sorted[int(n * 0.95)], sorted[-1], proc / n, phys / n, draws / n,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), world.sync.crowd.count(), get_nodes_in_group("viruses").size()])
	quit()
