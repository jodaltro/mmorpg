extends SceneTree
## The player's body while a calling is worn and after it is given back, in the real renderer: a few frames each, to see it jump or twist.
##   godot --path clients/hospedeiro --script res://tests/capture_calling.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(1.5).timeout
	var held := {"conflict": "x", "current": "t-regulador", "role": "controle", "form": "t-regulador", "offer": []}
	var none := {"conflict": "", "offer": []}
	# a strip of the cell's neighbourhood every 0.3 s, so a jump or a twist shows as a different tile
	var strip := Image.create_empty(160 * 12, 160 * 3, false, Image.FORMAT_RGBA8)
	var row := 0
	for p in [["worn", held], ["back", none], ["again", held]]:
		world.apply_engine_calling(p[1])
		for i in 12:
			await create_timer(0.3 if row != 0 or i > 0 else 2.0).timeout
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			var c := world.player.get_global_transform_with_canvas().origin
			strip.blit_rect(shot, Rect2i(int(c.x) - 80, int(c.y) - 80, 160, 160), Vector2i(160 * i, 160 * row))
		row += 1
	strip.save_png(out_dir + "/strip.png")
	quit()
