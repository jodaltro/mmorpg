extends SceneTree
## Frame times (real renderer) while fighting: a macrophage with all its abilities against a pack of virions, with and without a
## designed effect style. Prints mean/p95/p99/max frame time and the slowest frames.
##   godot --path clients/hospedeiro --script res://tests/perf_combat.gd -- [style]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var style := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var mode := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "all"  # all | nolash | noabilities | novirus | idle
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0 if mode in ["novirus", "idle"] else 10
	root.add_child(world)
	await create_timer(1.0).timeout
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"macrofago"
	world.player.combatant.set_genome(world.genome)
	for id in [&"engolir", &"onda_de_pseudopodes", &"lisossomo_acido", &"muralha_de_carne"]:
		world.abilities.learn(id)
	if style != "":
		world.apply_design({"efeito": style}, "debug")
	var ctrl := world.player.get_node("Controller") as BioCellController
	var times: Array[float] = []
	var started := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var frame := 0
	while Time.get_ticks_msec() - started < 15000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		frame += 1
		world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
		world.player.combatant.actor.vitals.membrane = world.player.combatant.actor.vitals.max_membrane
		var nearest: Node2D = null
		for v in world.viruses():
			if nearest == null or (v as Node2D).global_position.distance_to(world.player.global_position) < nearest.global_position.distance_to(world.player.global_position):
				nearest = v
		if nearest != null:
			ctrl.set_aim(nearest.global_position - world.player.global_position)
			ctrl.move((nearest.global_position - world.player.global_position).normalized() * 0.4)
		if frame % 20 == 0 and (mode in ["all", "nolash", "novirus"] or mode.begins_with("ab")):
			world.player.combatant.actor._ready_at.clear()
			world.abilities.perform(int(mode.substr(2)) if mode.begins_with("ab") else (frame / 20) % 4)
		if OS.get_environment("HIDE") == "limbs":
			for l in get_nodes_in_group("limbs"):
				(l as CanvasItem).visible = false
		if OS.get_environment("HIDE") == "particles":
			for c in root.find_children("*", "CPUParticles2D", true, false):
				(c as CanvasItem).visible = false
		if OS.get_environment("HIDE") == "zones":
			for z in root.find_children("*", "Node2D", true, false):
				if z.get_script() != null and z.get_script().get_global_name() in ["BioAbilityZone", "BioFxLife"]:
					(z as CanvasItem).visible = false
		if frame % 4 == 0 and mode in ["all", "noabilities", "novirus"]:
			ctrl.lash()
	var hist := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		hist[n.get_class() + (":" + str(n.get_script().get_global_name()) if n.get_script() != null else "")] = int(hist.get(n.get_class() + (":" + str(n.get_script().get_global_name()) if n.get_script() != null else ""), 0)) + 1
		stack.append_array(n.get_children())
	var keys := hist.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return hist[a] > hist[b])
	print("NODES ", keys.slice(0, 8).map(func(k: String) -> String: return "%s=%d" % [k, hist[k]]))
	times = times.slice(30)
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	print("PERF mode=%s draws=%d objs=%d phys=%.1fms proc=%.1fms style=%s frames=%d mean=%.1fms p95=%.1fms p99=%.1fms max=%.1fms over25ms=%d nodes=%d" % [mode, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, style if style != "" else "-", times.size(), mean, sorted[int(sorted.size() * 0.95)], sorted[int(sorted.size() * 0.99)], sorted[-1], times.filter(func(t: float) -> bool: return t > 25.0).size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	quit()
