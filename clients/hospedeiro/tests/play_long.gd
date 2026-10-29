extends SceneTree
## A long game played the way a person plays, against a real (isolated) engine: it follows the guide to the crisis that asks for help,
## waits for the calling and takes one (varying which), then helps in turns: fights the invaders with the lash and the calling's
## abilities, carries loads to the place of the crisis, touches what drifts in the organ. It moves only with the input actions, so the
## walls, the GPS and the physics are the real ones. Every SHOT_SECONDS it saves a screenshot and logs the frame time, the crisis, the
## calling, its confirmed help and anything stuck.
##   godot --path clients/hospedeiro --script res://tests/play_long.gd -- <engine url> <minutes> <out dir>

const SHOT_SECONDS := 30.0
const MODES := ["fight", "carry", "touch"]

var world: BioWorld
var _out := "."
var _t := 0.0
var _mode := 0
var _mode_left := 0.0
var _choice := 0
var _last_pos := Vector2.ZERO
var _still := 0.0
var _frames: Array[float] = []
var _log: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _say(line: String) -> void:
	print(line)
	_log.append(line)


func _steer(to: Vector2) -> void:
	var d := to - world.player.global_position
	var v := d.normalized() if d.length() > BioArt.UNIT * 0.6 else Vector2.ZERO
	for a in ["bio_left", "bio_right", "bio_up", "bio_down"]:
		Input.action_release(a)
	if v.x < -0.2: Input.action_press("bio_left", -v.x)
	if v.x > 0.2: Input.action_press("bio_right", v.x)
	if v.y < -0.2: Input.action_press("bio_up", -v.y)
	if v.y > 0.2: Input.action_press("bio_down", v.y)


func _crisis() -> Dictionary:
	if world.sync == null or world.sync.presenter == null:
		return {}
	for c in world.sync.presenter.model.ordered():
		if BioConflictFocus.demanding(c):
			return c
	return {}


func _nearest(group: String, within_units: float) -> Node2D:
	var best: Node2D = null
	var best_d := within_units * BioArt.UNIT
	for n in get_nodes_in_group(group):
		var node := n as Node2D
		if node == null or node.is_queued_for_deletion() or (node is BioCellActor and not (node as BioCellActor).is_active()):
			continue
		var d := node.global_position.distance_to(world.player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	Input.action_release(action)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := float(args[1]) if args.size() > 1 else 20.0
	_out = args[2] if args.size() > 2 else "."
	DirAccess.make_dir_recursive_absolute(_out)
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = args[0] if args.size() > 0 else ""
	root.add_child(world)
	await create_timer(4.0).timeout
	var shot_in := 3.0
	var last := Time.get_ticks_usec()
	var shots := 0
	while _t < minutes * 60.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000000.0
		last = now
		_t += dt
		_frames.append(dt * 1000.0)
		if not world.player.is_active():  # dissolved: be born again, like a player pressing R
			_say("PLAY t=%5.0f the cell dissolved; respawn" % _t)
			await _tap("bio_respawn")
			await create_timer(1.0).timeout
			continue
		await _play(dt)
		shot_in -= dt
		if shot_in <= 0.0:
			shot_in = SHOT_SECONDS
			_report(shots)
			shots += 1
	_report(shots)
	var f := FileAccess.open(_out + "/play_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	quit()


func _play(dt: float) -> void:
	var c := _crisis()
	var view := world.engine_calling_view()
	if BioCallingRules.is_choosing(view) and world.calling_panel.is_card_visible():
		var ids := world.calling_panel.option_ids()
		var pick: String = ids[_choice % ids.size()]
		_choice += 1  # the next crisis takes another option: several ways to play
		_say("PLAY t=%5.0f calling offered %s, taking %s" % [_t, ids, pick])
		world.calling_panel.chosen.emit(pick)
		return
	if c.is_empty():  # nothing asks for help: wander and keep the cell fed
		var food := _nearest("nutrients", 30.0)
		_steer(food.global_position if food != null else world.player.global_position + Vector2.from_angle(_t * 0.3) * BioArt.UNIT * 4.0)
		return
	var region := StringName(str(c.get("region", "")))
	if world.region != region:  # follow the guide to the crisis
		var path := world.journey.navigation_path() if world.journey != null else PackedVector2Array()
		var to := path[mini(1, path.size() - 1)] if path.size() > 1 else BioBodyMap.center_px(region)
		_steer(to)
		_check_stuck(dt, "going to %s" % region)
		return
	_mode_left -= dt
	if _mode_left <= 0.0:
		_mode = (_mode + 1) % MODES.size()
		_mode_left = 25.0
	match MODES[_mode]:
		"fight":
			var foe := _nearest("viruses", 25.0)
			if foe == null:
				_mode_left = 0.0
				return
			_steer(foe.global_position)
			if foe.global_position.distance_to(world.player.global_position) < BioArt.UNIT * 4.0:
				Input.action_press("bio_lash")
				if randf() < 0.02:
					for k in ["bio_ab_1", "bio_ab_2", "bio_ab_3", "bio_ab_4"]:
						await _tap(k)
			else:
				Input.action_release("bio_lash")
		"carry":
			Input.action_release("bio_lash")
			var cargo := world.cargo
			if cargo == null or cargo.current_def() == "" or not is_instance_valid(cargo.site):
				_mode_left = 0.0
				return
			if cargo.carrying >= 0:
				_steer(cargo.site.global_position)
			else:
				var best := Vector2.ZERO
				var best_d := INF
				for l in cargo._loads:
					if float(l["back_in"]) <= 0.0 and (l["pos"] as Vector2).distance_to(world.player.global_position) < best_d:
						best_d = (l["pos"] as Vector2).distance_to(world.player.global_position)
						best = l["pos"]
				if best_d < INF:
					_steer(best)
			_check_stuck(dt, "carrying")
		"touch":
			Input.action_release("bio_lash")
			var mote := _nearest("motes", 30.0)
			if mote == null:
				mote = _nearest("toxins", 30.0)
			if mote == null:
				_mode_left = 0.0
				return
			_steer(mote.global_position)


func _check_stuck(dt: float, doing: String) -> void:
	if world.player.global_position.distance_to(_last_pos) < BioArt.UNIT * 0.3:
		_still += dt
		if _still > 6.0:
			_say("PLAY t=%5.0f STUCK for %.0f s while %s at %s (%s)" % [_t, _still, doing, world.player.global_position / BioArt.UNIT, world.region])
			_still = 0.0
			Input.action_press("bio_dash")  # a person would try to get loose
	else:
		_still = 0.0
		_last_pos = world.player.global_position


func _report(n: int) -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var mean := 0.0
	for f in _frames:
		mean += f
	mean /= maxf(1.0, _frames.size())
	var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	var worst: float = sorted[-1] if not sorted.is_empty() else 0.0
	_frames.clear()
	var c := _crisis()
	var mine := 0
	var mine_view: Variant = c.get("mine")
	if mine_view is Dictionary:
		for k in mine_view:
			mine += int(mine_view[k])
	var view := world.engine_calling_view()
	_say("PLAY t=%5.0f shot %02d | %s | fps mean %.1f ms p95 %.1f worst %.1f | crisis %s %s sev %s | calling %s | my help %d | carrying %d | invaders %d" % [
		_t, n, world.region, mean, p95, worst, str(c.get("def", "-")), str(c.get("phase", "")), str(c.get("severity", "")),
		str(view.get("current", "-")), mine, world.cargo.carrying if world.cargo != null else -1, get_nodes_in_group("viruses").size()])
	root.get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, n])
