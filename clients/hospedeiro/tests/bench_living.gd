extends SceneTree
## (pass preset names after -- to run only those) Frame cost of the living body with 1/20/50/100 cells near the camera, per visual preset (real renderer). Prints one line per case.
##   godot --path clients/hospedeiro --resolution 1280x720 --script res://tests/bench_living.gd


func _initialize() -> void:
	_run.call_deferred()


func _society(n: int) -> Array:
	var out: Array = []
	var tasks := ["transportar-oxigenio", "defender-pulmao", "apresentar-antigenos", "limpar-alveolos", "selar-ferida", "limpar-toxinas", "colher-sinais"]
	for i in n:
		out.append({"id": "bench%d" % i, "name": "Célula %d" % i, "region": "pulmao", "phase": "travel", "task": tasks[i % tasks.size()], "done": 1, "failed": 0, "step": 1,
			"steps": 3, "since": 90, "dest": "pulmao", "arrive": 4000})
	return out


func _percentile(sorted_ms: Array, p: float) -> float:
	return sorted_ms[clampi(int(sorted_ms.size() * p), 0, sorted_ms.size() - 1)]


func _run() -> void:
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.8).timeout
	world.player.global_position = BioBodyMap.center_px(&"pulmao")
	await create_timer(0.5).timeout
	var presenter := world.sync.presenter
	for preset in OS.get_cmdline_user_args() if OS.get_cmdline_user_args().size() > 0 else ["alto", "padrao", "economico"]:
		for n in [0, 1, 7, 20, 50, 100]:
			presenter.forget()
			presenter.prefs.preset = preset
			presenter.apply_view({"tick": 100, "society": _society(n), "conflicts": {"revision": 1, "focus": "", "active": [], "recent": []}})
			await create_timer(1.0).timeout
			var frames: Array = []
			var last := Time.get_ticks_usec()
			var until := last + 3_000_000
			while Time.get_ticks_usec() < until:
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
			frames.sort()
			var sum := 0.0
			for f in frames:
				sum += f
			print("BENCH preset=%s cells=%d actors=%d frames=%d mean=%.2fms p50=%.2f p95=%.2f p99=%.2f nodes=%d" % [preset, n, presenter.actor_count(), frames.size(),
				sum / frames.size(), _percentile(frames, 0.5), _percentile(frames, 0.95), _percentile(frames, 0.99), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	quit()
