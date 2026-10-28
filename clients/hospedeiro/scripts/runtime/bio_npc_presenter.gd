class_name BioNpcPresenter
extends Node2D
## Puts the engine's named cells into the world. One actor per canonical id, ever: its place is computed from the view (its region,
## the destination of the leg and the engine's own progress along it), so two clients draw the same cell in the same place, a
## reconnection cannot spawn a second one, and a cell outside the live regions costs nothing (it keeps working in the engine, with no
## node and no effect here). The interaction state of every cell is kept even without an actor, so entering a region never replays a
## finish. Only the engine's counters trigger success or failure cues.

signal cue(npc: String, kind: StringName, at: Vector2)  # "confirmed", "failed", "blocked", "asked"
signal thanked(npc: String, name_text: String)

const TICK_SECONDS := 4.0  # the universe's clock (universe.json tickSeconds)
## Where cells rest and work, as a fraction of the region radius: close to the middle, where cells arrive, so they are found.
const REST_SPREAD := 0.1
const WORK_SPREAD := 0.17
## What a gesture works on when the map has it: the groups of things a cell of that work turns to (the nearest wins).
const WORKS_ON := {"defend": ["viruses"], "patrol": ["viruses"], "kill": ["viruses"], "detox": ["toxins"], "engulf": ["motes", "viruses"]}
const FOE_REACH_UNITS := 9.0

var model := BioLivingModel.new()
var prefs := BioVisualPrefs.new()
var player: Node2D
var anatomy: BioAnatomyView
var my_id := ""
var foe_hit: Callable  # (invader: Node2D, color: Color): the named cells at combat work land their blows through the crowd

var _states := {}  # npc id -> BioInteractionState
var _actors := {}  # npc id -> BioNpcActor
var _centers := {}  # region -> centre in px
var _radii := {}  # region -> radius in px
var _routes := {}  # "from>to" -> PackedVector2Array (px)
var _blow := {}  # npc id -> seconds to the next blow
var _seen_tick := -1
var _tick_at := 0.0
var _thanks_seen := {}
var _first_memories := true


## What a cell at work can reach in its own organ (an invader, a toxin, an old red cell): the nearest, within a short reach.
func _foe_near(at: Vector2, region: StringName, groups: Array) -> Node2D:
	var best: Node2D = null
	var best_d := FOE_REACH_UNITS * BioArt.UNIT
	var nodes: Array[Node] = []
	for g in groups:
		nodes.append_array(get_tree().get_nodes_in_group(g))
	for node in nodes:
		var n := node as Node2D
		if n == null or n.is_queued_for_deletion() or (n is BioCellActor and not (n as BioCellActor).is_active()):
			continue
		if BioBodyMap.region_of(n.global_position) != region:
			continue
		var d := at.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func configure(p: Node2D, anatomy_view: BioAnatomyView, visual: BioVisualPrefs) -> void:
	player = p
	anatomy = anatomy_view
	prefs = visual


## The world began again, or the connection is new: forget the cells and treat the next view as history.
func forget() -> void:
	for a in _actors.values():
		if is_instance_valid(a):
			a.queue_free()
	_actors.clear()
	_states.clear()
	_thanks_seen.clear()
	_first_memories = true
	_seen_tick = -1
	model.reset()


## Applies a view; returns the conflict notices it implies (see BioLivingModel).
func apply_view(view: Dictionary) -> Array[Dictionary]:
	var notices := model.ingest(view)
	if model.tick != _seen_tick:
		_seen_tick = model.tick
		_tick_at = Time.get_ticks_msec() * 0.001
	for id in model.npcs:
		var entry: Dictionary = model.npcs[id]
		var st: BioInteractionState = _states.get(id)
		if st == null:
			st = BioInteractionState.new(id)
			_states[id] = st
		for kind in st.apply(entry, model.tick):
			cue.emit(id, kind, _actors[id].position if _actors.has(id) else Vector2.ZERO)
		_note_thanks(id, entry)
	_first_memories = false
	return notices


func _note_thanks(id: String, entry: Dictionary) -> void:
	for m in entry.get("memories", []):
		if str(m.get("kind", "")) != "ajuda-recebida":
			continue
		var key := "%s:%d" % [id, int(m.get("seq", 0))]
		if _thanks_seen.has(key):
			continue
		_thanks_seen[key] = true
		if _first_memories:
			continue  # remembered from before this session: no gesture
		if _actors.has(id):
			(_actors[id] as BioNpcActor).thank()
		thanked.emit(id, str(entry.get("name", id)).get_slice(",", 0))


func actor(id: String) -> BioNpcActor:
	return _actors.get(id)


func actor_count() -> int:
	return _actors.size()


func state_of(id: String) -> BioInteractionState:
	return _states.get(id)


func _process(delta: float) -> void:
	if not model.have_view or anatomy == null:
		return
	var fine := float(model.tick) + clampf((Time.get_ticks_msec() * 0.001 - _tick_at) / TICK_SECONDS, 0.0, 0.99)
	var live := anatomy.live
	var wanted: Array[Dictionary] = []
	for id in model.npcs:
		var entry: Dictionary = model.npcs[id]
		var st: BioInteractionState = _states[id]
		st.advance(delta)
		if str(entry.get("phase", "")) == "travel":
			var since := float(entry.get("since", 0))
			var arrive := float(entry.get("arrive", 0))
			if arrive > since:
				st.refine((fine - since) / (arrive - since))
		var region := StringName(str(entry.get("region", "")))
		var dest := StringName(str(entry.get("dest", "")))
		if live.has(region) or (dest != &"" and live.has(dest)):
			wanted.append({"id": id, "entry": entry})
	for id in _actors.keys():
		if not wanted.any(func(w: Dictionary) -> bool: return w["id"] == id):
			_actors[id].queue_free()
			_actors.erase(id)
	var by_distance: Array[Dictionary] = []
	for w in wanted:
		var id: String = w["id"]
		var entry: Dictionary = w["entry"]
		var st: BioInteractionState = _states[id]
		var a: BioNpcActor = _actors.get(id)
		var where := _where(entry, st)
		if a == null:
			a = BioNpcActor.new()
			a.name = "Npc_" + id
			a.configure(id, str(entry.get("name", id)), st, prefs)
			add_child(a)
			a.place(where.pos)
			_actors[id] = a
		a.target = where.pos
		a.aim(where.aim)
		if st.is_working() and WORKS_ON.has(st.gesture) and foe_hit.is_valid():
			var foe := _foe_near(a.position, StringName(str(entry.get("region", ""))), WORKS_ON[st.gesture])
			if foe != null:  # the cell turns on the invader and lands its blows on it
				a.aim(foe.global_position - a.position)
				_blow[id] = float(_blow.get(id, 1.2)) - delta
				if float(_blow[id]) <= 0.0:
					_blow[id] = 1.2
					foe_hit.call(foe, BioNpcRoles.role(id).get("tint", Color.WHITE))
		by_distance.append({"a": a, "d": player.global_position.distance_to(a.position) if player != null else 0.0})
	by_distance.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["d"] < y["d"])
	var cap := int(prefs.get_number("npc_cap"))
	var near := prefs.get_number("lod_near")
	var far := prefs.get_number("lod_far")
	for i in by_distance.size():
		var d: float = by_distance[i]["d"]
		var level := 2 if d < near else 1 if d < far else 0
		if level == 2 and i >= cap:
			level = 1  # only the nearest few get the full deformable membrane
		(by_distance[i]["a"] as BioNpcActor).lod = level


# --- where a cell stands ------------------------------------------------------------------------------------------------------

## The anatomy lookups rebuild the body definition on each call, so a region's centre and radius are read once.
func _center(region: StringName) -> Vector2:
	if not _centers.has(region):
		_centers[region] = BioBodyMap.center_px(region)
		_radii[region] = BioBodyMap.radius_units(region) * BioArt.UNIT
	return _centers[region]


func _spot(region: StringName, key: String, spread: float) -> Vector2:
	var angle := float(absi(key.hash()) % 628) / 100.0
	var center := _center(region)
	return center + Vector2.from_angle(angle) * float(_radii[region]) * spread


func _route(from: StringName, to: StringName, npc: String, task: String) -> PackedVector2Array:
	var key := "%s>%s>%s>%s" % [from, to, npc, task]
	if _routes.has(key):
		return _routes[key]
	var pts := PackedVector2Array()
	pts.append(_spot(from, npc + "rest", REST_SPREAD))
	for p in BioAnatomy.route(BioBodyMap.seed_value, from, to):
		pts.append(p * BioArt.UNIT)
	pts.append(_spot(to, task if task != "" else npc + "rest", WORK_SPREAD))
	_routes[key] = pts
	return pts


static func sample(poly: PackedVector2Array, f: float) -> Vector2:
	if poly.size() < 2:
		return poly[0] if poly.size() == 1 else Vector2.ZERO
	var total := 0.0
	for i in range(1, poly.size()):
		total += poly[i - 1].distance_to(poly[i])
	var want := clampf(f, 0.0, 1.0) * total
	for i in range(1, poly.size()):
		var seg := poly[i - 1].distance_to(poly[i])
		if want <= seg or i == poly.size() - 1:
			return poly[i - 1].lerp(poly[i], want / maxf(seg, 0.001))
		want -= seg
	return poly[-1]


func _where(entry: Dictionary, st: BioInteractionState) -> Dictionary:
	var npc := str(entry.get("id", ""))
	var region := StringName(str(entry.get("region", "medula")))
	var dest := StringName(str(entry.get("dest", "")))
	var task := str(entry.get("task", ""))
	var center := _center(region)
	var pos := _spot(region, npc + "rest", REST_SPREAD)
	var aim := (pos - center)
	match str(entry.get("phase", "idle")):
		"travel":
			if dest != &"" and dest != region:
				var poly := _route(region, dest, npc, task)
				pos = sample(poly, st.progress)
				aim = poly[-1] - pos
			elif dest == region:
				pos = _spot(region, task, WORK_SPREAD) + Vector2.from_angle(float(absi(npc.hash()) % 628) / 100.0) * 1.3 * BioArt.UNIT
				aim = pos - center
		"blocked", "seek_help":
			if dest != &"" and dest != region:
				var poly2 := _route(region, dest, npc, task)
				pos = sample(poly2, 0.9)
				aim = poly2[-1] - pos
	if aim.length() < 1.0:
		aim = Vector2.DOWN
	return {"pos": pos, "aim": aim}
