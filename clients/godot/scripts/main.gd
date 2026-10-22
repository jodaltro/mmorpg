extends Node3D
## Fixed-isometric 3D client. The world's truth lives in the engine; this scene
## shows what the engine says the player can see and sends the player's intents.

const REGION_NAMES := {"vila": "Vila Cinzenta", "floresta": "Floresta Cinzenta", "estrada": "Estrada do Leste",
	"mina": "Mina de Kharum", "ruinas": "Ruinas de Asterion", "toca": "Toca dos Lebrinos"}
# Where each NPC stands in the plaza and what talking to them tries to do.
# The action is only an intent: the engine accepts or rejects it.
const REGION_ORIGIN := {"vila": Vector3(0, 0, 0), "floresta": Vector3(46, 0, 0)}
const NPCS := {
	"mira": {"at": Vector2(-5, -3), "female": true, "act": "diagnosticar"},
	"orin": {"at": Vector2(5, -3), "act": "examinar-poco"},
	"tomas": {"at": Vector2(-3, 4), "act": "ouvir-segredo"},
	"brom": {"at": Vector2(9, 2), "act": "forjar"},
	"lia": {"at": Vector2(3, 6), "female": true, "act": "entregar-ervas"},
	"kael": {"at": Vector2(-9, 1), "act": "cacar-lobos"},
	"elena": {"at": Vector2(-7, 6), "female": true, "act": "agradecer-elena"},
	"nino": {"at": Vector2(0, -6), "act": "procurar-botoes"},
	"sora": {"at": Vector2(8, -6), "female": true, "act": "treinar-sora"},
}

var client: WorldClient
var player: Actor
var cam_rig: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var _synced := false
var npc_nodes := {}  # entity id -> Actor, driven by view.others
var region := "vila"
var last_seq := 0
var _scenes := {}
var _rng := RandomNumberGenerator.new()
var hud_region: Label
var hud_log: RichTextLabel
var hud_side: Label
var hud_hint: Label
var _shake := 0.0
var _args := {}


func _ready() -> void:
	_rng.seed = 7
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_build_environment()
	_build_world()
	_build_player()
	_build_camera()
	_build_hud()
	client = WorldClient.new()
	client.base_url = _args.get("server", "http://127.0.0.1:8095")
	client.player_id = _args.get("player", "godot-1")
	client.player_name = _args.get("name", "Viajante")
	add_child(client)
	client.view_changed.connect(_on_view)
	client.start()
	if _args.has("autotest"):
		_autotest()


# --- world -----------------------------------------------------------------

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load("res://assets/%s.gltf" % path)
	return _scenes[path]


func _spawn(path: String, pos: Vector3, yaw := 0.0, scl := 1.0, parent: Node = null) -> Node3D:
	var n: Node3D = _scene(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * scl
	(parent if parent else self).add_child(n)
	return n


func _solid(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos + Vector3(0, size.y / 2, 0)
	body.rotation_degrees.y = yaw
	add_child(body)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)


func _build_world() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(170, 130)
	ground.mesh = plane
	ground.position = Vector3(25, 0, 0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.26)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(170, 1, 130)
	fcs.shape = fbox
	floor_body.add_child(fcs)
	floor_body.position = Vector3(25, -0.5, 0)
	add_child(floor_body)

	# Dirt road from the plaza to the forest.
	var road := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(30, 0.03, 3.2)
	road.mesh = rm
	road.position = Vector3(26, 0.015, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.42, 0.28)
	rmat.roughness = 1.0
	road.material_override = rmat
	add_child(road)

	# Plaza paving: 6x6 tiles of 2m.
	for x in 6:
		for z in 6:
			_spawn("village/Floor_UnevenBrick", Vector3(-5 + x * 2, 0.0, -5 + z * 2))

	_house(Vector3(-16, 0, -12), 3, 3, 0.0, false)
	_house(Vector3(15, 0, -14), 3, 4, 0.0, true)
	_house(Vector3(-17, 0, 14), 3, 3, 180.0, true)
	_house(Vector3(16, 0, 15), 3, 3, 180.0, false)

	# Market and clutter.
	_spawn("props/Table_Large", Vector3(3, 0, 8.5), 0.0)
	_spawn("props/Barrel", Vector3(5.2, 0, 8.4))
	_spawn("props/Barrel", Vector3(5.2, 0, 9.5))
	_spawn("props/Chest_Wood", Vector3(0.8, 0, 8.5), 20.0)
	_solid(Vector3(3, 0, 8.5), Vector3(2.8, 1, 1.2))
	_spawn("village/Prop_Wagon", Vector3(-9, 0, -4), 70.0)
	_solid(Vector3(-9, 0, -4), Vector3(4.0, 1.5, 2.0), 70.0)
	_spawn("village/Prop_Crate", Vector3(10.5, 0, 4.5))
	_spawn("village/Prop_Crate", Vector3(11.7, 0, 4.7), 25.0)
	_spawn("village/Prop_Crate", Vector3(11.0, 1.05, 4.6), 45.0)
	_solid(Vector3(11, 0, 4.6), Vector3(2.2, 1.1, 1.2))
	for i in 8:  # fence along the road
		_spawn("village/Prop_WoodenFence_Single", Vector3(14 + i * 2.0, 0, 3.0))
		_spawn("village/Prop_WoodenFence_Single", Vector3(14 + i * 2.0, 0, -3.0))

	# Trees: sparse around the village, dense in the forest.
	for i in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(34, 52)
		_tree(Vector3(cos(a) * r * 1.2 - 12, 0, sin(a) * r * 0.9))
	for i in 90:
		var p := Vector3(_rng.randf_range(34, 100), 0, _rng.randf_range(-38, 38))
		if abs(p.z) < 3.4 and p.x < 56:
			continue
		_tree(p)
	for i in 160:  # grass tufts
		var gp := Vector3(_rng.randf_range(-40, 90), 0, _rng.randf_range(-35, 35))
		if abs(gp.x) < 8 and abs(gp.z) < 8:
			continue
		_spawn("nature/Grass_Common_Short" if _rng.randf() < 0.6 else "nature/Grass_Common_Tall", gp, _rng.randf() * 360.0)

	_region_zone("vila", Vector3(0, 0, 0), Vector3(48, 6, 44))
	_region_zone("floresta", Vector3(46, 0, 0), Vector3(48, 6, 70))


func _tree(p: Vector3) -> void:
	if p.length() < 24 and abs(p.z) < 22:
		return
	var kinds: Array[String] = ["nature/CommonTree_1", "nature/CommonTree_2", "nature/CommonTree_3", "nature/DeadTree_1"]
	var kind: String = kinds[_rng.randi() % 4]
	var s := _rng.randf_range(0.8, 1.3)
	_spawn(kind, p, _rng.randf() * 360.0, s)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5 * s
	cyl.height = 3.0
	cs.shape = cyl
	body.add_child(cs)
	body.position = p + Vector3(0, 1.5, 0)
	add_child(body)


## A house of w x d modules (2 m each). The walls face outward, the door is in front (+z).
func _house(center: Vector3, w: int, d: int, yaw: float, brick: bool) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation_degrees.y = yaw
	add_child(root)
	var wall := "village/Wall_UnevenBrick_Straight" if brick else "village/Wall_Plaster_Straight"
	var door := "village/Wall_UnevenBrick_Door_Round" if brick else "village/Wall_Plaster_Door_Round"
	var window := "village/Wall_Plaster_Window_Wide_Round"
	for x in w:
		for z in d:
			_spawn("village/Floor_Brick", Vector3(-w + 1 + x * 2, 0.0, -d + 1 + z * 2), 0.0, 1.0, root)
	for i in w:
		var x := -w + 1 + i * 2
		_spawn(door if i == w / 2 else wall, Vector3(x, 0, d), 0.0, 1.0, root)
		_spawn(window if i % 2 == 0 else wall, Vector3(x, 0, -d), 180.0, 1.0, root)
	for j in d:
		var z := -d + 1 + j * 2
		_spawn(window if j % 2 == 1 else wall, Vector3(w, 0, z), 90.0, 1.0, root)
		_spawn(window if j % 2 == 1 else wall, Vector3(-w, 0, z), -90.0, 1.0, root)
	var roof := "village/Roof_RoundTiles_6x6"
	var roof_yaw := 0.0
	if w == 3 and d == 4:
		roof = "village/Roof_RoundTiles_6x8"
	elif w == 2 and d == 2:
		roof = "village/Roof_RoundTiles_4x4"
	_spawn(roof, Vector3(0, 3.0, 0), roof_yaw, 1.0, root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w * 2.0, 3.0, d * 2.0)
	cs.shape = box
	body.add_child(cs)
	body.position = Vector3(0, 1.5, 0)
	root.add_child(body)
	_spawn("props/Barrel", Vector3(w - 0.6, 0, d + 1.0), 0.0, 1.0, root)


func _region_zone(id: String, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	area.position = pos + Vector3(0, size.y / 2, 0)
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b == player and region != id:
			region = id
			client.move_region(id))


# --- player and camera -------------------------------------------------------

func _build_player() -> void:
	player = Actor.new()
	add_child(player)
	player.setup(_args.get("player", "godot-1"), _args.get("name", "Viajante"), false, true, "Ranger")
	player.idle_clip = "Sword_Idle"
	player.position = Vector3(0, 0, 0)


func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.rotation_degrees = Vector3(-35.264, 45, 0)  # true isometric
	add_child(cam_rig)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.0
	cam.near = 0.1
	cam.far = 250.0
	cam.position = Vector3(0, 0, 80)
	cam_rig.add_child(cam)
	cam.make_current()


func _process(delta: float) -> void:
	if player == null:
		return
	cam_rig.global_position = cam_rig.global_position.lerp(player.global_position, clampf(delta * 6.0, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.4
		cam.v_offset = randf_range(-1, 1) * _shake * 0.4
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_Q:
				attack()
			KEY_E:
				talk_nearest()
			KEY_R:
				player.play_once("Roll", 1.2)
			KEY_Y:
				_answer_quest(true)
			KEY_N:
				_answer_quest(false)


func click(screen: Vector2) -> void:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, 4)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.has_meta("actor"):
		interact(hit.collider.get_meta("actor"))
		return
	if absf(dir.y) > 0.001:
		var t := -from.y / dir.y
		if t > 0.0:
			player.walk_to(from + dir * t)


func interact(npc: Actor) -> void:
	player.walk_to(npc.global_position + (player.global_position - npc.global_position).normalized() * 1.6)
	await player.arrived
	if player.global_position.distance_to(npc.global_position) > 2.6:
		return
	player.face(npc.global_position - player.global_position)
	player.model.rotation.y = atan2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z)
	npc.model.rotation.y = atan2(player.global_position.x - npc.global_position.x, player.global_position.z - npc.global_position.z)
	player.play_once("Interact")
	var spec: Dictionary = NPCS.get(npc.entity_id, {})
	if spec.has("act"):
		var res := await client.act(spec.act)
		_report(npc.label.text, spec.act, res)
	await get_tree().create_timer(0.1).timeout


func talk_nearest() -> void:
	var best: Actor = null
	for n in npc_nodes.values():
		if best == null or n.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = n
	if best:
		interact(best)


func attack() -> void:
	if player.busy:
		return
	var fwd := Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))
	player.play_once("Sword_Regular_A", 1.3)
	await get_tree().create_timer(0.28).timeout
	_burst(player.global_position + fwd * 1.5 + Vector3(0, 1.1, 0))
	_shake = 0.6


func _burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 28
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	p.mesh = m
	p.position = pos
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _answer_quest(accept: bool) -> void:
	for q in client.view.get("quests", []):
		if q.state == "offered":
			var res: Dictionary
			if accept:
				res = await client.accept(q.key)
			else:
				res = await client.decline(q.key)
			_report(q.title, "accept" if accept else "decline", res)
			return


func _report(who: String, what: String, res: Dictionary) -> void:
	if res.status == 200:
		var lines: Array = []
		for e in res.body.get("events", []):
			if e.get("text", "") != "":
				lines.append(e.text)
		_log("[color=#9fdc7a]%s[/color] %s: %s" % [who, what, " / ".join(lines) if lines.size() > 0 else "feito"])
	else:
		_log("[color=#e8806a]%s[/color] %s recusado: %s" % [who, what, res.body.get("error", "sem resposta (%d)" % res.status)])


# --- view from the engine ---------------------------------------------------

func _on_view(v: Dictionary) -> void:
	var me: Dictionary = v.get("self", {})
	if not _synced:  # start where the engine says the character is
		_synced = true
		region = me.get("region", "vila")
		player.global_position = REGION_ORIGIN.get(region, Vector3.ZERO)
		cam_rig.global_position = player.global_position
	hud_region.text = "%s   |   hora %s   |   tick %d" % [REGION_NAMES.get(me.get("region", ""), me.get("region", "?")), str(int(v.get("hour", -1))), int(v.get("tick", 0))]
	_sync_npcs(v)
	_sun(int(v.get("hour", -1)))
	for e in v.get("events", []):
		if int(e.seq) > last_seq:
			last_seq = int(e.seq)
			if e.get("text", "") != "":
				_log("[color=#c9b3ff]%s[/color]" % e.text)
	var side := "Habilidades:\n"
	for s in v.get("skills", []):
		side += "  • %s (%s)\n" % [s.name, s.rarity]
	side += "\nMissoes:\n"
	for q in v.get("quests", []):
		if q.state == "offered" or q.state == "active":
			side += "  • [%s] %s\n" % [q.state, q.title]
	hud_side.text = side
	var offered := ""
	for q in v.get("quests", []):
		if q.state == "offered":
			offered = "Oferta: %s   [Y] aceitar  [N] recusar" % q.title
	hud_hint.text = offered if offered != "" else "Clique: mover/falar | E: falar com o mais proximo | Espaco/Q: golpe | R: rolar"


func _sync_npcs(v: Dictionary) -> void:
	var here := {}
	var i := 0
	for o in v.get("others", []):
		if o.kind != "npc" or o.get("region", "") != v.self.get("region", ""):
			continue
		here[o.id] = o
	for id in npc_nodes.keys():
		if not here.has(id):
			npc_nodes[id].queue_free()
			npc_nodes.erase(id)
	for id in here:
		if npc_nodes.has(id):
			continue
		var spec: Dictionary = NPCS.get(id, {})
		var at: Vector2 = spec.get("at", Vector2(-12 + (i % 5) * 6, 11))
		i += 1
		var npc := Actor.new()
		add_child(npc)
		npc.setup(id, here[id].name.split(",")[0], spec.get("female", false), id == "orin" or id == "sora", "Ranger" if id == "orin" or id == "sora" or id == "kael" else "Peasant")
		npc.idle_clip = "Idle_Talking" if id == "tomas" else "Idle"
		npc.play(npc.idle_clip)
		npc.position = REGION_ORIGIN.get(region, Vector3.ZERO) + Vector3(at.x, 0, at.y)
		npc.model.rotation.y = atan2(-at.x, -at.y)
		npc_nodes[id] = npc


func _sun(hour: int) -> void:
	if hour < 0:
		return
	var day := clampf(sin((hour - 6) / 12.0 * PI), 0.0, 1.0)
	sun.light_energy = lerpf(0.15, 1.3, day)
	env.background_color = Color(0.05, 0.07, 0.15).lerp(Color(0.55, 0.72, 0.9), day)
	env.ambient_light_energy = lerpf(0.25, 0.65, day)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_region = _label(layer, Vector2(16, 10), 22)
	hud_side = _label(layer, Vector2(16, 48), 16)
	hud_hint = _label(layer, Vector2(16, 690), 16)
	hud_log = RichTextLabel.new()
	hud_log.bbcode_enabled = true
	hud_log.scroll_active = false
	hud_log.fit_content = true
	hud_log.position = Vector2(760, 12)
	hud_log.size = Vector2(500, 300)
	hud_log.add_theme_font_size_override("normal_font_size", 15)
	hud_log.add_theme_color_override("default_color", Color.WHITE)
	hud_log.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_log.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud_log)


func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


var _log_lines: Array = []
func _log(bb: String) -> void:
	_log_lines.append(bb)
	if _log_lines.size() > 9:
		_log_lines.pop_front()
	hud_log.text = "\n".join(_log_lines)
	print("LOG ", bb)


# --- automated check ---------------------------------------------------------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir: String = _args.get("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("SHOT ", name)


func _autotest() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {"view": not client.view.is_empty(), "npcs": npc_nodes.size()}
	await _shot("01_plaza")
	for who in ["orin", "brom"]:
		if npc_nodes.has(who):
			interact(npc_nodes[who])
			await player.arrived
			await get_tree().create_timer(1.2).timeout
			await _shot("02_" + who)
	var offered := false
	for q in client.view.get("quests", []):
		offered = offered or q.state == "offered"
	ok["quest_offered"] = offered
	if offered:
		await _answer_quest(true)
		await get_tree().create_timer(1.6).timeout
		ok["quest_active"] = client.view.get("quests", []).any(func(q): return q.state == "active")
	attack()
	await get_tree().create_timer(0.45).timeout
	await _shot("03_attack")
	await get_tree().create_timer(1.0).timeout
	cam.size = 3.5
	await get_tree().create_timer(0.6).timeout
	await _shot("05_closeup")
	cam.size = 14.0
	player.walk_to(Vector3(44, 0, 0))
	await player.arrived
	await get_tree().create_timer(2.5).timeout
	await _shot("04_forest")
	ok["region_local"] = region
	ok["region_server"] = client.view.get("self", {}).get("region", "")
	ok["skills"] = client.view.get("skills", []).size()
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()
