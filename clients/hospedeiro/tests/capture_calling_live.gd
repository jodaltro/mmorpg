extends SceneTree
## The cell's body across a real calling against a real isolated engine: before, worn, back and a while after, a tile every 0.3 s.
##   godot --path clients/hospedeiro --script res://tests/capture_calling_live.gd -- http://127.0.0.1:8198 <out_dir>

const REGIONS := ["pele", "baco", "figado", "intestino", "pulmao", "medula", "rim", "linfonodo", "cerebro"]
var _strip: Image
var _tile := 0


func _initialize() -> void:
	_run.call_deferred()


func _snap(world: BioWorld, seconds: float, tag: String) -> void:
	var n := int(seconds / 0.3)
	for i in n:
		await create_timer(0.3).timeout
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var c := world.player.get_global_transform_with_canvas().origin
		_strip.blit_rect(shot, Rect2i(int(c.x) - 80, int(c.y) - 80, 160, 160), Vector2i(160 * (_tile % 16), 160 * (_tile / 16)))
		_tile += 1
	print("LIVE %s: form=%s calling=%s tail_on=%s spikes=%d" % [tag, world.lineage_id, str(world.engine_calling_view().get("current", "")), world.player.get_node("Body").tail_on if world.player.has_node("Body") else "?", 0])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[1] if args.size() > 1 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	_strip = Image.create_empty(160 * 16, 160 * 6, false, Image.FORMAT_RGBA8)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0]
	root.add_child(world)
	await create_timer(25.0).timeout  # let the engine's look grow into the body first
	await _snap(world, 4.8, "before")
	var found := ""
	for round_i in 30:
		for region in REGIONS:
			world.player.global_position = BioBodyMap.center_px(StringName(region))
			await create_timer(1.6).timeout
			if BioCallingRules.is_choosing(world.engine_calling_view()):
				found = region
				break
		if found != "":
			break
	if found == "":
		print("LIVE no calling offered")
		quit(1)
		return
	world.calling_panel.chosen.emit(world.calling_panel.option_ids()[0])
	await create_timer(1.0).timeout
	await _snap(world, 4.8, "worn")
	world.player.global_position = BioBodyMap.center_px(&"sangue")
	await create_timer(1.5).timeout
	await _snap(world, 4.8, "back")
	await _snap(world, 9.6, "later")
	_strip.save_png(out_dir + "/live_strip.png")
	quit()
