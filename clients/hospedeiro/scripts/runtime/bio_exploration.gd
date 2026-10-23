class_name BioExploration
extends Node2D
## Exploring the body (E2): builds, from the engine's `explore` view, the membranes across the passages that are still closed to this
## cell and the hidden niches it may find, and works out the chemical trail (the compass) that leads it to the nearest niche it can
## reach. Without the engine there is nothing to explore: the body is only scenery and every way is open.

signal niche_reached(id: String)

var player: BioCellActor
var seed_value := 1337
var passages: Array = []
var niches: Array = []

var _gates := {}  # passage id -> BioPassageGate
var _niches := {}  # niche id -> BioNiche


func configure(who: BioCellActor, body_seed: int) -> void:
	player = who
	seed_value = body_seed


func gate_count() -> int:
	return _gates.size()


func niche_count() -> int:
	return _niches.size()


func apply(explore: Dictionary) -> void:
	passages = explore.get("passages", [])
	niches = explore.get("niches", [])
	for p in passages:
		var id := str(p.get("id", ""))
		var open := bool(p.get("open", true))
		if open and _gates.has(id):
			_gates[id].queue_free()
			_gates.erase(id)
		elif not open and not _gates.has(id):
			var at := BioAnatomy.link_point(seed_value, StringName(id), 0.5)
			if at.is_empty():
				continue
			var gate := BioPassageGate.new()
			add_child(gate)
			gate.configure(id, at["p"], at["dir"], float(at["half_width"]), str(p.get("hint", "")), player)
			_gates[id] = gate
	for n in niches:
		var id2 := str(n.get("id", ""))
		var visible_now := not bool(n.get("found", false)) and not str(n.get("hint", "")).is_empty()
		if not visible_now and _niches.has(id2):
			_niches[id2].queue_free()
			_niches.erase(id2)
		elif visible_now and not _niches.has(id2):
			var niche := BioNiche.new()
			add_child(niche)
			niche.position = BioBodyMap.niche_px(id2, StringName(str(n.get("region", ""))))
			niche.configure(id2, player)
			niche.reached.connect(func(found: String) -> void: niche_reached.emit(found))
			_niches[id2] = niche


## The way a cell in `from` can get to `to` without crossing a closed passage, as the list of regions (empty if there is none).
func open_route(from: StringName, to: StringName) -> Array[StringName]:
	var parent := {from: &""}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var at: StringName = queue.pop_front()
		for p in passages:
			if not bool(p.get("open", true)):
				continue
			var a := StringName(str(p.get("from", "")))
			var b := StringName(str(p.get("to", "")))
			var next := &""
			if a == at:
				next = b
			elif b == at:
				next = a
			if next != &"" and not parent.has(next):
				parent[next] = at
				queue.append(next)
	var out: Array[StringName] = []
	if not parent.has(to):
		return out
	var cur: StringName = to
	while cur != &"":
		out.push_front(cur)
		cur = parent[cur]
	return out


## The trail to follow: the nearest niche (by the way there) that the cell can reach now. `position` is the cell in px and `region`
## its region. Returns {} when there is nothing to find, else `target` (px), `distance` (units) and the niche's whisper as `hint`.
func compass(position: Vector2, region: StringName) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := INF
	for n in niches:
		if bool(n.get("found", false)) or str(n.get("hint", "")).is_empty():
			continue
		var steps := open_route(region, StringName(str(n.get("region", ""))))
		if steps.is_empty():
			continue
		var cost := float(steps.size())
		if steps.size() == 1:
			cost = position.distance_to(BioBodyMap.niche_px(str(n["id"]), steps[0])) / BioArt.UNIT * 0.001
		if cost < best_cost:
			best_cost = cost
			best = {"niche": n, "steps": steps}
	if best.is_empty():
		return {}
	var steps2: Array = best["steps"]
	var target: Vector2
	if steps2.size() == 1:
		target = BioBodyMap.niche_px(str(best["niche"]["id"]), steps2[0])
	else:
		var route := BioAnatomy.route(seed_value, steps2[0], steps2[1])
		var nearest := 0
		for i in route.size():
			if position.distance_to(route[i] * BioArt.UNIT) < position.distance_to(route[nearest] * BioArt.UNIT):
				nearest = i
		target = route[mini(nearest + 3, route.size() - 1)] * BioArt.UNIT
	return {"target": target, "distance": position.distance_to(target) / BioArt.UNIT, "hint": str(best["niche"].get("hint", ""))}
