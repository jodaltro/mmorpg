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
const FIGHT_SECONDS := 0.2  # how often the invaders look for cells to attack
const INVADER_BLOW := 9.0  # one blow of an invader, times its own damage factor
const INVADER_COOLDOWN := 1.3
const BITE_UNITS := 2.8  # an invader this close to a cell is hitting it
const LURE_UNITS := 11.0  # an invader this close to a cell goes for it unless it is busy with the player
const SELF_UNITS := 3.0  # a cell hits back what is this close to it
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
var _fight_in := 0.0
var _invader_next := {}  # instance id -> when it may hit again
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
	_fight_in -= delta
	if _fight_in <= 0.0:
		_fight_in = FIGHT_SECONDS
		_fight()
	var now := Time.get_ticks_msec() * 0.001
	for w in workers:
		if w.is_down():
			_targets.erase(w)
			w.step(delta, w.pos, 800.0, null, Vector2.ZERO)
			continue
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
		var target: Variant = _targets.get(w)  # it may have been freed since: not typed as a Node2D
		var alive := is_instance_valid(target)
		var goal: Variant = (target as Node2D).global_position if alive else null
		var event := w.step(delta, center, radius, goal, BioBodyMap.flow_px(w.pos, now))
		if event == "done" and alive:
			_finish(w, target as Node2D)
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


## The invaders against the cells of the body. An invader goes for the nearest cell (unless it is busy with the player) and hits it when
## it is close; a cell that is not helpless hits back what touches it; a helpless one runs and calls for help. A cell at zero falls and
## comes back after a while. Presentation only: the engine's headcounts do not change.
func _fight() -> void:
	for w in workers:
		w.threat = null
	var now := BioClock.now()
	var unit := BioArt.UNIT
	var near_foe := {}  # BioWorker -> [invader, distance]
	for node in get_tree().get_nodes_in_group("viruses"):
		var e := node as BioCellActor
		if e == null or e.is_queued_for_deletion() or not e.is_active() or e.max_speed_units < 0.1 or not e.combatant.actor.vitals.is_alive():
			continue
		var best: BioWorker = null
		var best_d := INF
		for w in workers:
			if w.is_down():
				continue
			var d := w.pos.distance_to(e.global_position)
			if d < LURE_UNITS * unit and (w.threat == null or d < w.pos.distance_to(w.threat as Vector2)):
				w.threat = e.global_position
			if d < SELF_UNITS * unit and (not near_foe.has(w) or d < float(near_foe[w][1])):
				near_foe[w] = [e, d]
			if d < best_d:
				best_d = d
				best = w
		if best == null or best_d > LURE_UNITS * unit:
			continue
		e.lure((best.pos - e.global_position).normalized(), FIGHT_SECONDS * 3.0)
		var id := e.get_instance_id()
		if best_d <= BITE_UNITS * unit and now >= float(_invader_next.get(id, 0.0)):
			_invader_next[id] = now + INVADER_COOLDOWN
			_hurt_worker(best, INVADER_BLOW * maxf(e.combatant.damage_dealt_mult, 0.4), e)
	for w in near_foe:
		var worker := w as BioWorker
		if worker.stance == BioWorkerRoles.HELPLESS or worker.blow_in > 0.0 or worker.is_down():
			continue
		worker.blow_in = 1.2
		worker.aim = ((near_foe[w][0] as Node2D).global_position - worker.pos).normalized()
		strike(near_foe[w][0], worker.spec["core"], worker.dmg)
	if _invader_next.size() > 200:  # forget the invaders that are gone
		_invader_next.clear()


func _hurt_worker(w: BioWorker, amount: float, from: Node2D) -> void:
	var fell := w.take_blow(amount)
	_pulses.append({"pos": w.pos, "age": 0.0, "color": Color(1.0, 0.3, 0.3)})
	var away := (w.pos - from.global_position).normalized()
	w.vel += away * BioArt.UNIT * 2.0
	BioFx.burst(w.pos, w.spec["edge"], 6, 2.5)
	if fell:
		_targets.erase(w)
		BioFx.burst(w.pos, w.spec["core"], 18, 4.0, 0.4, 0.8)
		BioFx.ring(w.pos, 0.9, Color(1.0, 0.3, 0.3))


## A worker at its job says a short thing now and then, near the player and only as many at once as the preset allows.
func _chatter(w: BioWorker, delta: float) -> void:
	w.say_left = maxf(0.0, w.say_left - delta)
	w.say_in -= delta
	if w.say_in > 0.0:
		return
	var calling := w.threat != null and w.stance == BioWorkerRoles.HELPLESS
	if (w.state != &"work" and not calling) or world.player == null or w.pos.distance_to(world.player.global_position) > 1100.0:
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
	w.say = BioSpeech.line("", "help", salt, w.say) if calling else BioSpeech.crowd_line(w.role, salt, w.say)
	w.say_left = BioSpeechBubble.SHOW_SECONDS
	w.say_in = (4.0 if calling else BioSpeech.gap(salt) + 3.0)


func _finish(w: BioWorker, target: Node2D) -> void:
	strike(target, w.spec["core"], w.dmg if target is BioCellActor else HIT_DAMAGE)
	if not target is BioCellActor:
		_targets.erase(w)


## One blow (or one bite) of a cell of the body on a thing of the map. The named cells use it too when they work against an invader.
func strike(target: Node2D, color: Color, damage: float = HIT_DAMAGE) -> void:
	_pulses.append({"pos": target.global_position, "age": 0.0, "color": color})
	if target is BioCellActor:
		var combatant := (target as BioCellActor).combatant
		var alive_before := combatant.actor.vitals.is_alive()
		combatant.actor.vitals.take_damage(damage)
		for child in target.get_children():  # the invader reels and shows it was hit
			if child is BioCellBody:
				(child as BioCellBody).hit_reaction(Vector2.from_angle(randf() * TAU))
		BioFx.burst(target.global_position, color, 6, 3.0)
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
		if w.is_down() or not view.has_point(to_screen * w.pos):
			continue
		_draw_worker(w)
		if w.say_left > 0.0:
			_draw_balloon(w)
	for node in get_tree().get_nodes_in_group("viruses"):  # the wounded invaders show how much is left of them
		var e := node as BioCellActor
		if e == null or not e.is_active() or not view.has_point(to_screen * e.global_position):
			continue
		var v := e.combatant.actor.vitals
		if v.is_alive() and v.membrane < v.max_membrane - 0.5:
			_draw_bar(e.global_position + Vector2(0, -BioArt.UNIT * 0.9), v.membrane / v.max_membrane, Color(1.0, 0.35, 0.4))
	for p in _pulses:
		var k: float = float(p["age"]) / 0.6
		draw_arc(p["pos"], BioArt.UNIT * (0.5 + 1.3 * k), 0.0, TAU, 24, BioArt.with_alpha(p["color"], 0.8 * (1.0 - k)), 2.0, true)


func _draw_bar(at: Vector2, fraction: float, color: Color) -> void:
	var box := Rect2(at + Vector2(-14.0, 0.0), Vector2(28.0, 4.0))
	draw_rect(box, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(box.position, Vector2(box.size.x * clampf(fraction, 0.0, 1.0), box.size.y)), color)


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
	if w.hurt > 0.0:
		draw_arc(w.pos, float(w.spec["size"]) * BioArt.UNIT * 1.1, 0.0, TAU, 20, Color(1, 1, 1, w.hurt * 0.8), 2.5, true)
	if w.hp < w.max_hp - 0.5:
		_draw_bar(w.pos + Vector2(0, -float(w.spec["size"]) * BioArt.UNIT - 8.0), w.hp / w.max_hp, Color(0.45, 1.0, 0.6))
	if w.state == &"work" and is_instance_valid(_targets.get(w)):
		var to := ((_targets[w] as Node2D).global_position - w.pos)
		draw_line(w.pos + to.normalized() * BioArt.UNIT * 0.5, w.pos + to * 0.92, BioArt.with_alpha(w.spec["core"], 0.35), 1.5, true)  # the contact
