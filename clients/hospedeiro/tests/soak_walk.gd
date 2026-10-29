extends SceneTree
## Walks the player through the organs the way a person does (a continuous path, not a jump), wearing a calling when one is offered, against a
## real isolated fast engine, and logs every change of form, calling and region with the time. A form that flaps on a region edge shows up here.
##   godot --path clients/hospedeiro --script res://tests/soak_walk.gd -- http://127.0.0.1:8198 <out_dir> 2>&1 | grep -E "WALK|ERROR|SCRIPT"

const ROUTE := ["medula", "sangue", "coracao", "aorta", "figado", "aorta", "baco", "aorta", "intestino", "aorta", "rim", "aorta", "coracao", "pulmao", "coracao", "sangue", "medula"]
const SPEED_UNITS := 9.0  # units per second, like the cell at a run

var _log: Array = []
var _last := ""
var _strip: Image
var _tiles := 0


func _initialize() -> void:
	_run.call_deferred()


func _note(world: BioWorld, t: float) -> void:
	var key := "%s|%s|%s" % [world.region, str(world.engine_calling_view().get("current", "")), world.lineage_id]
	if key != _last:
		_last = key
		_log.append([t, key])
		print("WALK t=%5.1f region=%s calling=%s form=%s" % [t, world.region, str(world.engine_calling_view().get("current", "")), world.lineage_id])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[1] if args.size() > 1 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else "http://127.0.0.1:8198"
	root.add_child(world)
	await create_timer(3.0).timeout
	var t := 0.0
	_strip = Image.create_empty(140 * 16, 140 * 12, false, Image.FORMAT_RGBA8)
	for stop in ROUTE:
		var target := BioBodyMap.center_px(StringName(stop))
		while world.player.global_position.distance_to(target) > BioArt.UNIT * 2.0:
			var step := minf(SPEED_UNITS * BioArt.UNIT * 0.1, world.player.global_position.distance_to(target))
			world.player.global_position += (target - world.player.global_position).normalized() * step
			await create_timer(0.1).timeout
			t += 0.1
			_note(world, t)
			var view := world.engine_calling_view()
			if BioCallingRules.is_choosing(view) and world.calling_panel.option_ids().size() > 0:
				world.calling_panel.chosen.emit(world.calling_panel.option_ids()[0])
			if int(t * 10.0) % 20 == 0 and _tiles < 16 * 12:
				var shot := root.get_texture().get_image()
				shot.convert(Image.FORMAT_RGBA8)
				var c := world.player.get_global_transform_with_canvas().origin
				_strip.blit_rect(shot, Rect2i(int(c.x) - 70, int(c.y) - 70, 140, 140), Vector2i(140 * (_tiles % 16), 140 * (_tiles / 16)))
				_tiles += 1
		await create_timer(1.0).timeout
		t += 1.0
		_note(world, t)
	_strip.save_png(out_dir + "/walk_strip.png")
	print("WALK changes: %d over %.0f s" % [_log.size(), t])
	quit()
