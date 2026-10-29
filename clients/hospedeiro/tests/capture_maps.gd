extends SceneTree
## The atlas and the minimap with the names of the places (real renderer, offline).
##   godot --path clients/hospedeiro --script res://tests/capture_maps.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(1.0).timeout
	world.player.global_position = BioBodyMap.center_px(&"coracao") + Vector2(-12, 6) * BioArt.UNIT
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(dir + "/minimap.png")
	world.atlas.toggle()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(dir + "/atlas.png")
	quit()
