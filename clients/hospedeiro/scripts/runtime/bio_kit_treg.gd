class_name BioKitTreg
extends BioKit
## The regulatory T cell, the Pacificador: it puts enemies to sleep, ties them together so a wound on one is a wound on all, throws a
## decoy of itself that the enemies take for the real thing, and opens a point of tolerance that pulls the whole room into one heap.

const BIG_HP := 300.0  # the big ones sleep lighter
const LINK_REACH_UNITS := 6.5


func kinds() -> Array[String]:
	return ["sleep", "link", "decoy", "pull"]


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	match kind:
		"decoy", "pull":
			return [host]
		"sleep":
			var pool := BioTargeting.enemies(host.get_world_2d(), origin, float(a["range"]) * BioArt.UNIT, _team()).filter(func(e: BioCellActor) -> bool: return not e.combatant.is_asleep())
			var first := BioTargeting.best(_typed(pool), origin, aim, float(a["range"]) * BioArt.UNIT)
			if first == null:
				return []
			var out: Array = [first]
			pool.sort_custom(func(x: BioCellActor, y: BioCellActor) -> bool: return x.global_position.distance_to(first.global_position) < y.global_position.distance_to(first.global_position))
			for e in pool:
				if out.size() >= int(a["count"]):
					break
				if e != first:
					out.append(e)
			return out
		"link":
			var near := BioTargeting.enemies(host.get_world_2d(), origin, float(a["range"]) * BioArt.UNIT, _team())
			var first2 := BioTargeting.best(near, origin, aim, float(a["range"]) * BioArt.UNIT)
			if first2 == null:
				return []
			var around := BioTargeting.enemies(host.get_world_2d(), first2.global_position, LINK_REACH_UNITS * BioArt.UNIT, _team()).filter(func(e: BioCellActor) -> bool: return e != first2)
			around.sort_custom(func(x: BioCellActor, y: BioCellActor) -> bool: return x.global_position.distance_to(first2.global_position) < y.global_position.distance_to(first2.global_position))
			if around.is_empty():
				return []  # a link needs two
			var group: Array = [first2]
			for e in around:
				if group.size() >= int(a["count"]):
					break
				group.append(e)
			return group
	return super.find(kind, a, origin, aim)


func _typed(list: Array) -> Array[BioCellActor]:
	var out: Array[BioCellActor] = []
	for e in list:
		out.append(e as BioCellActor)
	return out


func cast(kind: String, id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"sleep":
			_sleep(a, color, targets)
		"link":
			_link(a, color, targets)
		"decoy":
			_decoy(a, aim, color)
		"pull":
			_pull(def, a, aim, color)


## Spores of calm: whoever they touch drops where it stands. The first blow it takes wakes it, and lands harder for it.
func _sleep(a: Dictionary, color: Color, targets: Array) -> void:
	for t in targets:
		limbs.reach_node(t as Node2D, float(a["range"]) + 0.5, 0.14, 0.3, {"tint": color, "style": {"tip": &"bulb", "base": 9.0, "tip_w": 7.0, "stiffness": 0.2, "wave": 0.6}})
	body.elastic(targets[0].global_position - host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.18)
	for t in targets:
		if not is_instance_valid(t):  # freed while the spores flew
			continue
		var cell := t as BioCellActor
		if cell == null or not cell.combatant.actor.vitals.is_alive():
			continue
		var seconds := float(a["seconds"]) * (0.4 if cell.combatant.actor.vitals.max_membrane >= BIG_HP else 1.0)
		cell.combatant.put_to_sleep(seconds, float(a["wake"]))
		cell.cancel_dash()
		BioMarkGlyph.attach(cell, color, seconds, &"sleep")
		BioPfx.burst(BioFx.root, cell.global_position, color, 10, 80.0, 0.5, 8.0, Vector2.UP, 50.0)


## Two to four enemies share their wounds: what one of them loses, the others lose a share of too.
func _link(a: Dictionary, color: Color, targets: Array) -> void:
	for t in targets:
		limbs.reach_node(t as Node2D, float(a["range"]) + LINK_REACH_UNITS, 0.14, 0.3, {"tint": color, "style": {"tip": &"fork", "base": 6.0, "tip_w": 3.0, "stiffness": 0.2, "wave": 0.5}})
	body.elastic(targets[0].global_position - host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.18)
	var group: Array = []
	for t in targets:
		if is_instance_valid(t) and (t as BioCellActor).combatant.actor.vitals.is_alive():
			group.append((t as BioCellActor).combatant)
	if group.size() < 2:
		return
	var seconds := float(a["seconds"])
	var cells: Array = []
	for c in group:
		(c as BioCombatant).link_with(group, seconds, float(a["share"]))
		cells.append((c as BioCombatant).get_parent())
	BioSynapse.tie(host.get_parent(), cells, color, seconds)


## A copy of the cell, thrown ahead. Every enemy near it goes after it instead, and keeps going until it falls or its time is up.
func _decoy(a: Dictionary, aim: Vector2, color: Color) -> void:
	var from := host.global_position
	var spot := BioStrike.clear_point(host.get_world_2d(), from, from + aim * float(a["reach"]) * BioArt.UNIT, 0.8 * BioArt.UNIT)
	limbs.reach(aim, float(a["reach"]) + 0.2, 0.14, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "base": 14.0, "tip_w": 16.0}})
	body.elastic(aim, 0.25, 0.5, 0.08)
	await _wait(0.14)
	if not _alive():
		return
	var decoy := BioFactory.spawn_decoy(host.get_parent(), spot, float(a["hp"]), color)
	BioPfx.ring_burst(BioFx.root, spot, color, 60.0, 22, 0.5, 9.0)
	var lured: Array[BioCellActor] = []
	var until := BioClock.now() + float(a["seconds"])
	var pulse := 0.0
	while _alive() and is_instance_valid(decoy) and decoy.combatant.actor.vitals.is_alive() and BioClock.now() < until:
		_lure(decoy, lured, float(a["lure"]) * BioArt.UNIT)
		pulse += 0.5
		BioPfx.ring_burst(BioFx.root, decoy.global_position, color, 40.0 + 10.0 * fmod(pulse, 2.0), 8, 0.4, 7.0, true)
		await _wait(0.5)
	for e in lured:
		if is_instance_valid(e) and _alive():
			e.retarget(host)
	if is_instance_valid(decoy):
		BioPfx.burst(BioFx.root, decoy.global_position, color, 22, 200.0, 0.6, 10.0)
		decoy.queue_free()


func _lure(decoy: BioCellActor, lured: Array[BioCellActor], radius_px: float) -> void:
	for group in ["viruses", "dungeon_enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			var e := node as BioCellActor
			if e == null or lured.has(e) or not e.is_active() or not e.combatant.actor.vitals.is_alive():
				continue
			if e.global_position.distance_to(decoy.global_position) <= radius_px:
				e.retarget(decoy)
				lured.append(e)


## A point of tolerance opens ahead and draws everything in; when it collapses, the heap takes the blow.
func _pull(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	var from := host.global_position
	var spot := BioStrike.clear_point(host.get_world_2d(), from, from + aim * float(a["reach"]) * BioArt.UNIT, 0.8 * BioArt.UNIT)
	limbs.reach(aim, float(a["reach"]) + 0.2, 0.14, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "base": 17.0, "tip_w": 20.0}})
	body.elastic(aim, 0.25, 0.5, 0.08)
	await _wait(0.14)
	if _alive():
		BioSingularity.open(host.get_parent(), host, def, spot, a, color)
