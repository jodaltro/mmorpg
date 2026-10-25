class_name BioDungeon
extends Node2D
## A dungeon run on the game server side: a round chamber far from the body, one room at a time. The engine gives the seed,
## the rooms and the modifier of the run (BioDungeonPlan turns them into enemies); this node builds the chamber, spawns the
## enemies, says when the room is clear and when the cell fell. It never decides rewards: the engine does, from what is confirmed.

signal room_started(index: int, info: Dictionary)
signal room_cleared(index: int)
signal run_failed
signal finished(cleared: bool)

const CENTER := Vector2(0.0, 5600.0)
const GRACE_SECONDS := 3.5  # enemies hold still while the cell gets its bearings
const CLEAR_HEAL := 0.4  # share of the membrane given back when a room is cleared

var active := false
var briefing := false
var replica_mode := false  # online client: draws the chamber; only the trusted host spawns and clears it
var room_index := -1
var seed_value := 0
var modifier := ""
var dungeon_id := "granuloma"
var title := "GRANULOMA"
var returns: Dictionary = {}  # dungeon id -> where the cell comes out after a clear
var rooms: Array = []
var chamber_radius := 8.0
var room_kind := ""
var shape := {"kind": "round"}  # the outline of the chamber (see BioDungeonPlan.wall_radius)
var obstacles: Array[Dictionary] = []  # pillars on the floor of this room: {pos (px, local), radius (px)}

var _player: BioCellActor
var _walls: StaticBody2D
var _rule := {}
var _saved_regen := 0.0
var _clear_sent := false
var _built_at := 0.0
var _respawn_in := 0.0
var _quorum_in := 0.0
var _return_to := Vector2.ZERO
var _t := 0.0
var _grace_until := 0.0
var _outline := PackedVector2Array()
var _hazards: Array[Node] = []
var _awake := true


func bind(player: BioCellActor, return_to: Vector2) -> void:
	_player = player
	_return_to = return_to
	z_index = -6
	material = BioArt.additive()
	player.combatant.died.connect(func(_who: BioCombatant) -> void:
		if active:
			run_failed.emit()
			finish(false))


func enemies() -> Array:
	return get_tree().get_nodes_in_group("dungeon_enemies").filter(func(n: Node2D) -> bool: return n.get_world_2d() == get_world_2d())


func start(run: Dictionary) -> void:
	if active:
		if briefing and str(run.get("state", "")) == "active":
			briefing = false
			_player.set_meta("dungeon_briefing", false)
			_player.combatant.actor.vitals.atp_regen_per_second = _saved_regen * float(_rule["regen_mult"])
			advance(int(run.get("room", 0)))
		return
	active = true
	seed_value = int(run.get("seed", 1))
	dungeon_id = str(run.get("dungeon", "granuloma"))
	title = "GRANULOMA" if dungeon_id == "granuloma" else str(run.get("name", "")).to_upper()
	if returns.has(dungeon_id):
		_return_to = returns[dungeon_id]
	var mod: Variant = run.get("modifier")
	modifier = str((mod as Dictionary).get("id", "")) if mod is Dictionary else ""
	rooms = run.get("rooms", [])
	_rule = BioDungeonPlan.rules(modifier)
	var vitals := _player.combatant.actor.vitals
	_saved_regen = vitals.atp_regen_per_second
	vitals.atp_regen_per_second = _saved_regen * float(_rule["regen_mult"])
	if str(run.get("state", "")) == "ready":
		vitals.atp_regen_per_second = _saved_regen
		briefing = true
		_player.set_meta("dungeon_briefing", true)
		global_position = CENTER
		room_index = -1
		chamber_radius = 8.0
		shape = {"kind":"round"}
		_build_walls()
		_player.global_position = CENTER
		_player.velocity = Vector2.ZERO
		queue_redraw()
		return
	advance(int(run.get("room", 0)))


## Builds the room `index`: walls, enemies, the cell at the edge of the chamber.
func advance(index: int) -> void:
	if index < 0 or index >= rooms.size():
		return
	_free_room()
	room_index = index
	var info: Dictionary = rooms[index]
	room_kind = str(info.get("kind", "guard"))
	var plan := BioDungeonPlan.room(seed_value, index, room_kind, modifier, dungeon_id)
	chamber_radius = float(plan["radius"])
	shape = plan["shape"]
	global_position = CENTER
	_plan_obstacles(plan)
	_build_walls()
	if not replica_mode:
		_plan_hazards(plan)
	_player.global_position = CENTER + Vector2(0.0, wall_at(PI * 0.5) * 0.8 * BioArt.UNIT)
	_player.velocity = Vector2.ZERO
	var speed := float(_rule["speed_mult"])
	for e in ([] if replica_mode else plan["enemies"]):
		var angle := float(e["angle"])
		var reach := minf(float(e["radius"]) * chamber_radius, 0.88 * wall_at(angle))
		_spawn(StringName(e["type"]), CENTER + Vector2.from_angle(angle) * reach * BioArt.UNIT, speed)
	_clear_sent = false
	_built_at = BioClock.now()
	_respawn_in = float(_rule["respawn_every"])
	_set_awake(false)  # a few seconds before they come
	_grace_until = BioClock.now() + float(plan.get("grace", GRACE_SECONDS))
	room_started.emit(index, info)
	queue_redraw()


func _spawn(kind: StringName, at: Vector2, speed: float) -> BioCellActor:
	var def := BioDungeonPlan.enemy(kind).duplicate()
	def["hp"] = float(def["hp"]) * float(_rule.get("hp_mult", 1.0))
	var brain := BioFactory.spawn_enemy(get_parent(), at, _player, def, speed)
	var cell := brain.get_parent() as BioCellActor
	cell.set_meta("base_speed", cell.max_speed_units)
	cell.set_meta("kind", String(kind))
	cell.set_meta("brain", brain)
	if not _awake:
		brain.set_process(false)
	var split: Variant = def.get("split")
	if split is Dictionary:  # it comes apart into smaller ones when it dies
		cell.combatant.died.connect(func(_who: BioCombatant) -> void:
			if active:
				_split.call_deferred(StringName((split as Dictionary)["kind"]), int((split as Dictionary)["count"]), cell.global_position, speed))
	if brain is BioNestBrain:  # it lays more of its brood until it is broken
		var brood := StringName(str((def["spawns"] as Dictionary)["kind"]))
		(brain as BioNestBrain).spawn = func(pos: Vector2) -> void:
			if active:
				_spawn(brood, pos, speed)
		(brain as BioNestBrain).alive_of_kind = func() -> int:
			return enemies().filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == String(brood)).size()
	if kind == &"bacilo_mestre" or bool(def.get("boss", false)):
		var slam := BioBossSlam.new()
		slam.configure(cell, _body_of(cell), _player)
		slam.summon_requested.connect(func(pos: Vector2) -> void:
			if active:
				_spawn(BioDungeonPlan.reinforcement_of(dungeon_id), pos, speed))
	return cell


func _split(kind: StringName, count: int, at: Vector2, speed: float) -> void:
	if not active:
		return
	for i in count:
		_spawn(kind, at + Vector2.from_angle(randf() * TAU) * 0.9 * BioArt.UNIT, speed)


## Lets the enemies of the room move (or holds them still).
func _set_awake(on: bool) -> void:
	_awake = on
	for e in enemies():
		var brain: Variant = e.get_meta("brain", null)
		if brain is Node:
			(brain as Node).set_process(on and (float((e as BioCellActor).max_speed_units) > 0.05 or brain is BioNestBrain))


## Seconds left of the grace period (0 when the room is live).
func grace_left() -> float:
	return maxf(0.0, _grace_until - BioClock.now()) if active else 0.0


func _body_of(cell: BioCellActor) -> BioCellBody:
	for child in cell.get_children():
		if child is BioCellBody:
			return child
	return null


## How far the wall is from the centre in this direction, in world units (the chamber is not always round).
func wall_at(angle: float) -> float:
	return BioDungeonPlan.wall_radius(shape, chamber_radius, angle)


func _plan_obstacles(plan: Dictionary) -> void:
	obstacles = []
	for o in plan.get("obstacles", []):
		var angle := float(o["angle"])
		obstacles.append({"pos": Vector2.from_angle(angle) * float(o["radius"]) * wall_at(angle) * BioArt.UNIT, "radius": float(o["size"]) * BioArt.UNIT * 0.6})


func _plan_hazards(plan: Dictionary) -> void:
	for h in plan.get("hazards", []):
		var angle := float(h["angle"])
		var pool := BioHazardPool.new()
		pool.configure(float(h["size"]), BioDungeonPlan.family(dungeon_id)["hazard"])
		pool.position = Vector2.from_angle(angle) * float(h["radius"]) * wall_at(angle) * BioArt.UNIT
		add_child(pool)
		_hazards.append(pool)


func _build_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.collision_layer = BioCellActor.LAYER_WALL
	_walls.collision_mask = 0
	var segments := PackedVector2Array()
	var n := 64
	_outline = PackedVector2Array()
	for i in n + 1:
		var a := i * TAU / n
		_outline.append(Vector2.from_angle(a) * wall_at(a) * BioArt.UNIT)
	for i in n:
		segments.append(_outline[i])
		segments.append(_outline[i + 1])
	var wall_shape := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = segments
	wall_shape.shape = concave
	_walls.add_child(wall_shape)
	for o in obstacles:
		var pillar := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(o["radius"])
		pillar.shape = circle
		pillar.position = o["pos"]
		_walls.add_child(pillar)
	add_child(_walls)


func _free_room() -> void:
	for h in _hazards:
		if is_instance_valid(h):
			h.queue_free()
	_hazards.clear()
	obstacles = []
	if not replica_mode:
		for e in enemies():
			e.queue_free()
	if is_instance_valid(_walls):
		_walls.queue_free()
		_walls = null


func finish(cleared: bool) -> void:
	if not active:
		return
	active = false
	briefing = false
	if is_instance_valid(_player): _player.set_meta("dungeon_briefing", false)
	_free_room()
	if is_instance_valid(_player):
		_player.combatant.actor.vitals.atp_regen_per_second = _saved_regen
		if cleared:
			_player.global_position = _return_to
			_player.velocity = Vector2.ZERO
	room_index = -1
	finished.emit(cleared)
	queue_redraw()


func _process(delta: float) -> void:
	if replica_mode:
		return
	_t += delta
	if not active:
		return
	if briefing:
		queue_redraw()
		return
	var vitals := _player.combatant.actor.vitals
	if float(_rule["drain"]) > 0.0 and vitals.is_alive():
		vitals.take_damage(float(_rule["drain"]) * delta)
	if not _awake and BioClock.now() >= _grace_until:
		_set_awake(true)
	var alive := enemies()
	if not _clear_sent and BioClock.now() - _built_at > 0.6 and alive.is_empty():
		_clear_sent = true
		vitals.repair(vitals.max_membrane * CLEAR_HEAL)  # a breath between rooms
		vitals.add_atp(vitals.max_atp)
		room_cleared.emit(room_index)
	if float(_rule["respawn_every"]) > 0.0 and (room_kind == "core" or room_kind == "boss") and not _clear_sent:
		_respawn_in -= delta
		if _respawn_in <= 0.0:
			_respawn_in = float(_rule["respawn_every"])
			_spawn(BioDungeonPlan.reinforcement_of(dungeon_id), CENTER + Vector2.from_angle(randf() * TAU) * chamber_radius * 0.4 * BioArt.UNIT, float(_rule["speed_mult"]))
	if bool(_rule["quorum"]):  # while an emitter lives, the others are faster
		_quorum_in -= delta
		if _quorum_in <= 0.0:
			_quorum_in = 0.4
			var emitters := alive.filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == String(BioDungeonPlan.emitter_of(dungeon_id))).size()
			for e in alive:
				(e as BioCellActor).max_speed_units = float(e.get_meta("base_speed", 1.0)) * (1.4 if emitters > 0 else 1.0)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var r := chamber_radius * BioArt.UNIT
	var pulse := 0.5 + 0.5 * sin(_t * 1.4)
	var colors: Dictionary = BioDungeonPlan.family(dungeon_id)["colors"]
	var wall: Color = colors["wall"]
	match room_kind:
		"guard":
			wall = colors["guard"]
		"core", "boss":
			wall = colors["deep"]
	var count := _outline.size() - 1
	for ring in 3:
		var grow := 1.0 + ring * 14.0 / maxf(r, 1.0)
		var offset := int(_t * 3.0 * (1 if ring % 2 == 0 else -1)) % count
		var points := PackedVector2Array()
		for k in count + 1:
			points.append(_outline[(k + offset + count) % count] * grow)
		var i := 0
		while i + 4 < points.size():  # dashes
			draw_polyline(points.slice(i, i + 5), Color(wall.r, wall.g, wall.b, 0.5 - 0.15 * ring), 8.0 - ring * 2.0, true)
			i += 6
	for o in obstacles:  # pillars
		var at: Vector2 = o["pos"]
		var pr := float(o["radius"])
		draw_circle(at, pr * 1.5, Color(wall.r, wall.g, wall.b, 0.07))
		draw_circle(at, pr, Color(0.03, 0.04, 0.07, 0.95))
		draw_arc(at, pr, 0.0, TAU, 20, Color(wall.r, wall.g, wall.b, 0.8), 2.5, true)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r * 1.1, Vector2.ONE * r * 2.2), false, Color(wall.r, wall.g, wall.b, 0.05 + 0.03 * pulse))
	if room_kind == "core" or room_kind == "boss":  # necrotic tissue: sickly glows
		for k in 7:
			var a := k * 2.399
			var p := Vector2.from_angle(a) * r * (0.25 + 0.5 * fmod(k * 0.37, 1.0))
			draw_texture_rect(BioArt.glow_texture(), Rect2(p - Vector2.ONE * 60.0, Vector2.ONE * 120.0), false, Color(0.5, 0.85, 0.2, 0.06 + 0.03 * pulse))
