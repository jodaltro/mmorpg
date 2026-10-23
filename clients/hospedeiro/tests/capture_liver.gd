extends SceneTree
## Screenshots of the liver (real renderer): arriving, with toxin motes and nutrients around the cell.
##   godot --path clients/hospedeiro --script res://tests/capture_liver.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.8).timeout
	var where := StringName(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else BioBodyMap.FIGADO
	world.debug_goto(where)
	await create_timer(1.5).timeout
	var near := 0
	for t in get_nodes_in_group("toxins"):
		if near < 6:
			(t as Node2D).global_position = world.player.global_position + Vector2(140.0, -60.0).rotated(near * 1.1)
			near += 1
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out_dir + "/" + String(where) + ".png")
	print("toxins ", get_nodes_in_group("toxins").size(), " nutrients ", get_nodes_in_group("nutrients").size())
	quit()
