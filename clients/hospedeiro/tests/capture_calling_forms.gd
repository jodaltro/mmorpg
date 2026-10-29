extends SceneTree
## Every calling form worn and given back (real renderer, offline): per form a row of tiles, the first half worn, the second half after release.
##   godot --path clients/hospedeiro --script res://tests/capture_forms.gd -- <output_dir>

const FORMS := ["neutrofilo", "t-citotoxico", "celula-nk", "macrofago", "eosinofilo", "t-auxiliar", "mastocito", "t-regulador", "linfocito-b", "dendritica"]


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
	var strip := Image.create_empty(120 * 16, 120 * FORMS.size(), false, Image.FORMAT_RGBA8)
	for r in FORMS.size():
		world.apply_engine_calling({"conflict": "x", "current": FORMS[r], "role": "x", "form": FORMS[r], "offer": []})
		for i in 8:
			await create_timer(0.35).timeout
			_tile(world, strip, i, r)
		world.apply_engine_calling({"conflict": "", "offer": []})
		for i in 8:
			await create_timer(0.35).timeout
			_tile(world, strip, 8 + i, r)
	strip.save_png(out_dir + "/forms.png")
	quit()


func _tile(world: BioWorld, strip: Image, col: int, row: int) -> void:
	var shot := root.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	var c := world.player.get_global_transform_with_canvas().origin
	strip.blit_rect(shot, Rect2i(int(c.x) - 60, int(c.y) - 60, 120, 120), Vector2i(120 * col, 120 * row))
