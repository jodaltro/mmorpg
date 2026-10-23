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
var room_index := -1
var seed_value := 0
var modifier := ""
var rooms: Array = []
var chamber_radius := 8.0
var room_kind := ""

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
	return get_tree().get_nodes_in_group("dungeon_enemies")


func start(run: Dictionary) -> void:
	if active:
		return
	active = true
	seed_value = int(run.get("seed", 1))
	var mod: Variant = run.get("modifier")
	modifier = str((mod as Dictionary).get("id", "")) if mod is Dictionary else ""
	rooms = run.get("rooms", [])
	_rule = BioDungeonPlan.rules(modifier)
	var vitals := _player.combatant.actor.vitals
	_saved_regen = vitals.atp_regen_per_second
	vitals.atp_regen_per_second = _saved_regen * float(_rule["regen_mult"])
	advance(int(run.get("room", 0)))


## Builds the room `index`: walls, enemies, the cell at the edge of the chamber.
func advance(index: int) -> void:
	if index < 0 or index >= rooms.size():
		return
	_free_room()
	room_index = index
	var info: Dictionary = rooms[index]
	room_kind = str(info.get("kind", "guard"))
	var plan := BioDungeonPlan.room(seed_value, index, room_kind, modifier)
	chamber_radius = float(plan["radius"])
	global_position = CENTER
	_build_walls()
	_player.global_position = CENTER + Vector2(0.0, chamber_radius * 0.8 * BioArt.UNIT)
	_player.velocity = Vector2.ZERO
	var speed := float(_rule["speed_mult"])
	for e in plan["enemies"]:
		var at: Vector2 = CENTER + Vector2.from_angle(float(e["angle"])) * float(e["radius"]) * chamber_radius * BioArt.UNIT
		_spawn(StringName(e["type"]), at, speed)
	_clear_sent = false
	_built_at = BioClock.now()
	_respawn_in = float(_rule["respawn_every"])
	_set_awake(false)  # a few seconds before they come
	_grace_until = BioClock.now() + GRACE_SECONDS
	room_started.emit(index, info)
	queue_redraw()


func _spawn(kind: StringName, at: Vector2, speed: float) -> BioCellActor:
	var def := BioDungeonPlan.enemy(kind)
	var brain := BioFactory.spawn_enemy(get_parent(), at, _player, def, speed)
	var cell := brain.get_parent() as BioCellActor
	cell.set_meta("base_speed", cell.max_speed_units)
	cell.set_meta("kind", String(kind))
	cell.set_meta("brain", brain)
	if not _awake:
		brain.set_process(false)
	if kind == &"bacilo_mestre":
		var slam := BioBossSlam.new()
		slam.configure(cell, _body_of(cell), _player)
		slam.summon_requested.connect(func(pos: Vector2) -> void:
			if active:
				_spawn(&"bacilo", pos, speed))
	return cell


## Lets the enemies of the room move (or holds them still).
func _set_awake(on: bool) -> void:
	_awake = on
	for e in enemies():
		var brain: Variant = e.get_meta("brain", null)
		if brain is Node:
			(brain as Node).set_process(on and float((e as BioCellActor).max_speed_units) > 0.05)


## Seconds left of the grace period (0 when the room is live).
func grace_left() -> float:
	return maxf(0.0, _grace_until - BioClock.now()) if active else 0.0


func _body_of(cell: BioCellActor) -> BioCellBody:
	for child in cell.get_children():
		if child is BioCellBody:
			return child
	return null


func _build_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.collision_layer = BioCellActor.LAYER_WALL
	_walls.collision_mask = 0
	var segments := PackedVector2Array()
	var n := 48
	var r := chamber_radius * BioArt.UNIT
	for i in n:
		segments.append(Vector2.from_angle(i * TAU / n) * r)
		segments.append(Vector2.from_angle((i + 1) * TAU / n) * r)
	var shape := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = segments
	shape.shape = concave
	_walls.add_child(shape)
	add_child(_walls)


func _free_room() -> void:
	for e in enemies():
		e.queue_free()
	if is_instance_valid(_walls):
		_walls.queue_free()
		_walls = null


func finish(cleared: bool) -> void:
	if not active:
		return
	active = false
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
	_t += delta
	if not active:
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
			_spawn(&"bacilo", CENTER + Vector2.from_angle(randf() * TAU) * chamber_radius * 0.4 * BioArt.UNIT, float(_rule["speed_mult"]))
	if bool(_rule["quorum"]):  # while an emitter lives, the others are faster
		_quorum_in -= delta
		if _quorum_in <= 0.0:
			_quorum_in = 0.4
			var emitters := alive.filter(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == "emissor").size()
			for e in alive:
				(e as BioCellActor).max_speed_units = float(e.get_meta("base_speed", 1.0)) * (1.4 if emitters > 0 else 1.0)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var r := chamber_radius * BioArt.UNIT
	var pulse := 0.5 + 0.5 * sin(_t * 1.4)
	var wall := Color(1.0, 0.45, 0.62)
	match room_kind:
		"guard":
			wall = Color(0.55, 0.8, 1.0)
		"core", "boss":
			wall = Color(0.6, 0.95, 0.3)
	for ring in 3:
		var rr := r + ring * 14.0
		var segs := 14
		for i in segs:
			var a := i * TAU / segs + _t * 0.05 * (1 if ring % 2 == 0 else -1)
			draw_arc(Vector2.ZERO, rr, a, a + TAU / segs * 0.85, 8, Color(wall.r, wall.g, wall.b, 0.5 - 0.15 * ring), 8.0 - ring * 2.0, true)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r * 1.1, Vector2.ONE * r * 2.2), false, Color(wall.r, wall.g, wall.b, 0.05 + 0.03 * pulse))
	if room_kind == "core" or room_kind == "boss":  # necrotic tissue: sickly glows
		for k in 7:
			var a := k * 2.399
			var p := Vector2.from_angle(a) * r * (0.25 + 0.5 * fmod(k * 0.37, 1.0))
			draw_texture_rect(BioArt.glow_texture(), Rect2(p - Vector2.ONE * 60.0, Vector2.ONE * 120.0), false, Color(0.5, 0.85, 0.2, 0.06 + 0.03 * pulse))
