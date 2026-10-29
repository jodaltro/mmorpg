extends SceneTree
## Where the frame goes: in one organ, every kind of node (by script class) is switched off in turn and the process time measured again.
##   godot --path clients/hospedeiro --script res://tests/profile_classes.gd -- <engine url> <organ>


func _initialize() -> void:
	_run.call_deferred()


func _measure(seconds: float) -> float:
	var n := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < seconds * 1000000.0:
		await process_frame
		n += 1
	return (Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, n)


func _classes(node: Node, out: Dictionary) -> void:
	var s: Script = node.get_script()
	var name: String = s.get_global_name() if s != null else node.get_class()
	if s != null and name == "":
		name = s.resource_path.get_file()
	if not out.has(name):
		out[name] = []
	out[name].append(node)
	for c in node.get_children():
		_classes(c, out)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else ""
	root.add_child(world)
	await create_timer(4.0).timeout
	world.player.global_position = BioBodyMap.center_px(StringName(args[1] if args.size() > 1 else "aorta"))
	await create_timer(3.0).timeout
	var base: float = await _measure(3.0)
	print("PROF base %.2f ms" % base)
	var by := {}
	_classes(world, by)
	var names := by.keys()
	names.sort_custom(func(a, b) -> bool: return by[a].size() > by[b].size())
	for name in names:
		var nodes: Array = by[name].filter(func(x: Node) -> bool: return is_instance_valid(x) and x != world)
		if nodes.is_empty() or name in ["Node2D", "CollisionShape2D", "Label", "Control", "PanelContainer", "VBoxContainer", "HBoxContainer", "MarginContainer", "Button", "CanvasLayer"]:
			continue
		var on1: float = await _measure(0.7)
		var saved := []
		for x in nodes:
			saved.append([x, x.process_mode, x.visible if x is CanvasItem else true])
			x.process_mode = Node.PROCESS_MODE_DISABLED
			if x is CanvasItem:
				x.visible = false
		var off: float = await _measure(0.7)
		for e in saved:
			if is_instance_valid(e[0]):
				e[0].process_mode = e[1]
				if e[0] is CanvasItem:
					e[0].visible = e[2]
		var on2: float = await _measure(0.7)
		var saves := (on1 + on2) * 0.5 - off
		if saves > 1.0:
			print("PROF %-28s x%-4d saves %.2f ms (on %.1f/%.1f off %.1f)" % [name, nodes.size(), saves, on1, on2, off])
	quit()
