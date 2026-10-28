class_name BioWorkCrowd
extends Node2D
## The cohorts of the body, at work where the player can see them. For every cohort of a live organ a few cells are drawn (a share of the
## engine's headcount): defenders hunt the invaders of the organ, cleaners eat the toxins, old red cells, urea crystals and bacteria that
## the organ is made to clear, red cells ride the current. They compete with the player for those same things on the map. Presentation
## only: a number of the body never changes here, and an invader a worker finishes pays the player nothing.

const SYNC_SECONDS := 1.0
const RETARGET_SECONDS := 0.45
const HIT_DAMAGE := 16.0
const NEAR_UNITS := 34.0  # farther than this from the cell, a worker is moved to where the cell can see it
const REACH_UNITS := 22.0  # how far a worker looks for work
const VESSELS := [&"sangue", &"coracao", &"aorta"]  # where the red cells are seen: the whole circulation, not one place

var prefs: BioVisualPrefs = BioVisualPrefs.new()
var world: BioWorld
var workers: Array[BioWorker] = []

var _pops: Array = []
var _centers := {}
var _radii := {}
var _targets := {}  # BioWorker -> Node2D
var _sync_in := 0.0
var _retarget_in := 0.0
var _pulses: Array[Dictionary] = []  # {pos, age, color}
var _t := 0.0


func configure(p_world: BioWorld, visual: BioVisualPrefs) -> void:
	world = p_world
	prefs = visual
	z_index = -2
	for r in BioAnatomy.build(BioBodyMap.seed_value)["regions"]:
		_centers[StringName(r["id"])] = (r["center"] as Vector2) * BioArt.UNIT
		_radii[StringName(r["id"])] = float(r["radius"]) * BioArt.UNIT


func set_populations(pops: Array) -> void:
	_pops = pops
	_sync_in = 0.0


func count() -> int:
	return workers.size()


func count_of(cohort: String) -> int:
	var n := 0
	for w in workers:
		if w.cohort == cohort:
			n += 1
	return n


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_sync_in -= delta
	if _sync_in <= 0.0:
		_sync_in = SYNC_SECONDS
		_sync()
	_retarget_in -= delta
	var look := _retarget_in <= 0.0
	if look:
		_retarget_in = RETARGET_SECONDS
	var now := Time.get_ticks_msec() * 0.001
	for w in workers:
		var region := BioBodyMap.region_of(w.pos)
		if w.spec["mode"] == BioWorkerRoles.FLOW and not world.live_regions.has(region):  # carried out of sight: back into the circulation
			var live_vessels: Array = VESSELS.filter(func(v: StringName) -> bool: return world.live_regions.has(v))
			if not live_vessels.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("%s:%d" % [w.cohort, Time.get_ticks_msec() / 1000])
				w.pos = BioBodyMap.random_point_px(rng, live_vessels[rng.randi() % live_vessels.size()], world.player.global_position, 4.0)
				region = BioBodyMap.region_of(w.pos)
		_keep_near(w, region)
		var center: Vector2 = _centers.get(region, w.pos)
		var radius: float = _radii.get(region, 800.0)
		if look:
			_targets[w] = _find(w, region)
		var target: Node2D = _targets.get(w)
		var goal: Variant = target.global_position if is_instance_valid(target) else null
		var event := w.step(delta, center, radius, goal, BioBodyMap.flow_px(w.pos, now))
		if event == "done" and is_instance_valid(target):
			_finish(w, target)
		_chatter(w, delta)
	for i in range(_pulses.size() - 1, -1, -1):
		_pulses[i]["age"] = float(_pulses[i]["age"]) + delta
		if float(_pulses[i]["age"]) > 0.6:
			_pulses.remove_at(i)
	queue_redraw()


## Keeps the number of drawn cells of each cohort at its share of the engine's headcount, only in the organs near the player.
func _sync() -> void:
	var live: Array = world.live_regions
	var per: int = prefs.crowd_per_cohort()
	var budget: int = prefs.crowd_cap()
	var wanted := {}
	for p in _pops:
		var region := StringName(str(p.get("region", "")))
		if not live.has(region):
			continue
		var n := mini(BioWorkerRoles.drawn(int(p.get("count", 0)), per), budget)
		budget -= n
		var places: Array = [region]
		if str(p.get("role", "")) == "transporte":
			places = VESSELS.filter(func(v: StringName) -> bool: return live.has(v))
		wanted[str(p.get("id", ""))] = {"n": n, "region": region, "role": str(p.get("role", "")), "places": places}
		if budget <= 0:
			break
	for i in range(workers.size() - 1, -1, -1):  # cohorts that left the screen's neighbourhood, or shrank
		var w := workers[i]
		if not wanted.has(w.cohort) or count_of(w.cohort) > int(wanted[w.cohort]["n"]):
			_targets.erase(w)
			workers.remove_at(i)
	for id in wanted:
		var info: Dictionary = wanted[id]
		var have := count_of(id)
		for k in range(have, int(info["n"])):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d" % [id, k])
			var places: Array = info["places"]
			var where: StringName = places[k % places.size()] if not places.is_empty() else info["region"]
			workers.append(BioWorker.new(id, str(info["role"]), BioBodyMap.random_point_near_px(rng, where, world.player.global_position, NEAR_UNITS * 0.7, 4.0), rng.randf() * 10.0))


## The nearest thing this worker works on in its own organ, or null.
func _find(w: BioWorker, region: StringName) -> Node2D:
	var mode: StringName = w.spec["mode"]
	if mode == BioWorkerRoles.FLOW or mode == BioWorkerRoles.WANDER:
		return null
	var group := &"viruses" if mode == BioWorkerRoles.HUNT else StringName(w.spec["group"])
	var kind: StringName = w.spec.get("kind", &"")
	var best: Node2D = null
	var best_d := REACH_UNITS * BioArt.UNIT
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		if mode == BioWorkerRoles.EAT and kind != &"" and not (n is BioMote and (n as BioMote).kind == kind):
			continue
		if node is BioCellActor and not (node as BioCellActor).is_active():
			continue
		if BioBodyMap.region_of(n.global_position) != region:
			continue
		var d := w.pos.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## A cell that fell far behind the player is born again at the edge of what is seen, in its own organ: the crowd lives where the player is.
func _keep_near(w: BioWorker, region: StringName) -> void:
	if world.player == null or w.spec["mode"] == BioWorkerRoles.FLOW:
		return
	if w.pos.distance_to(world.player.global_position) < NEAR_UNITS * BioArt.UNIT:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%f" % [w.cohort, w.seed_value + _t])
	var p := BioBodyMap.random_point_near_px(rng, region, world.player.global_position, NEAR_UNITS * 0.8, 10.0)
	if BioBodyMap.region_of(p) == region:
		w.pos = p
		w.vel = Vector2.ZERO


## A worker at its job says a short thing now and then, near the player and only as many at once as the preset allows.
func _chatter(w: BioWorker, delta: float) -> void:
	w.say_left = maxf(0.0, w.say_left - delta)
	w.say_in -= delta
	if w.say_in > 0.0:
		return
	if w.state != &"work" or world.player == null or w.pos.distance_to(world.player.global_position) > 1100.0:
		w.say_in = 1.0
		return
	var speaking := 0
	for o in workers:
		if o.say_left > 0.0:
			speaking += 1
	if BioSpeechBubble.live + speaking >= int(prefs.get_number("speech_cap")):
		w.say_in = 2.0
		return
	var salt := int(Time.get_ticks_msec() / 331) + int(w.seed_value * 100.0)
	w.say = BioSpeech.crowd_line(w.role, salt, w.say)
	w.say_left = BioSpeechBubble.SHOW_SECONDS
	w.say_in = BioSpeech.gap(salt) + 3.0


func _finish(w: BioWorker, target: Node2D) -> void:
	strike(target, w.spec["core"])
	if not target is BioCellActor:
		_targets.erase(w)


## One blow (or one bite) of a cell of the body on a thing of the map. The named cells use it too when they work against an invader.
func strike(target: Node2D, color: Color) -> void:
	_pulses.append({"pos": target.global_position, "age": 0.0, "color": color})
	if target is BioCellActor:
		var combatant := (target as BioCellActor).combatant
		var alive_before := combatant.actor.vitals.is_alive()
		combatant.actor.vitals.take_damage(HIT_DAMAGE)
		if alive_before and not combatant.actor.vitals.is_alive():
			combatant.set_meta("npc_kill", true)  # a worker's kill pays the player nothing
			combatant.died.emit(combatant)
	else:
		target.queue_free()


func _draw() -> void:
	if world == null:
		return
	var view := get_viewport_rect().grow(240.0)
	var to_screen := get_global_transform_with_canvas()
	for w in workers:
		if not view.has_point(to_screen * w.pos):
			continue
		_draw_worker(w)
		if w.say_left > 0.0:
			_draw_balloon(w)
	for p in _pulses:
		var k: float = float(p["age"]) / 0.6
		draw_arc(p["pos"], BioArt.UNIT * (0.5 + 1.3 * k), 0.0, TAU, 24, BioArt.with_alpha(p["color"], 0.8 * (1.0 - k)), 2.0, true)


func _draw_balloon(w: BioWorker) -> void:
	var font := ThemeDB.fallback_font
	var size := roundi(12.0 * prefs.text_scale)
	var text_size := font.get_string_size(w.say, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var fade := clampf(minf(w.say_left, BioSpeechBubble.SHOW_SECONDS - w.say_left) / 0.4, 0.0, 1.0)
	var box := Rect2(w.pos + Vector2(-text_size.x * 0.5 - 7.0, -float(w.spec["size"]) * BioArt.UNIT - text_size.y - 22.0), text_size + Vector2(14.0, 8.0))
	var style := BioUi.style(Color(0.02, 0.05, 0.09, 0.82 * fade), Color(1, 1, 1, 0.35 * fade), 8, 0)
	draw_style_box(style, box)
	draw_string(font, box.position + Vector2(7.0, text_size.y * 0.8 + 2.0), w.say, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 1.0, 1.0, fade))


func _draw_worker(w: BioWorker) -> void:
	var near := world.player != null and w.pos.distance_to(world.player.global_position) < 900.0
	BioCellArt.draw(self, w, _t, near)
	if w.state == &"work" and is_instance_valid(_targets.get(w)):
		var to := ((_targets[w] as Node2D).global_position - w.pos)
		draw_line(w.pos + to.normalized() * BioArt.UNIT * 0.5, w.pos + to * 0.92, BioArt.with_alpha(w.spec["core"], 0.35), 1.5, true)  # the contact
