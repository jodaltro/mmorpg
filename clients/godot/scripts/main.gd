extends Node3D
## Fixed-isometric 3D client. The world's truth lives in the engine; this scene
## shows what the engine says the player can see and sends the player's intents.

const REGION_NAMES := {"vila": "Vila Cinzenta", "floresta": "Floresta Cinzenta", "estrada": "Estrada do Leste",
	"mina": "Mina de Kharum", "ruinas": "Ruinas de Asterion", "toca": "Toca dos Lebrinos"}
# Where each NPC stands in their region. Talking to one is the "conversar"
# intent: whoever is around sees it, and from then on they know the player.
const REGION_ORIGIN := {"vila": Vector3(0, 0, 0), "estrada": Vector3(24, 0, 0), "floresta": Vector3(64, 0, 0),
	"mina": Vector3(106, 0, 0), "ruinas": Vector3(136, 0, 0), "toca": Vector3(66, 0, 41)}
# Combat outcomes are reported by fights, never offered as menu options.
const COMBAT_REPORTED := ["enfrentar-bandidos", "cacar-lobos", "cacar-javali", "cacar-javali-branco", "defender-vila"]
# Threats appear and end through public world events (the engine decides when).
# Defeating a camp is reported back as a confirmed occurrence; the engine validates it.
const THREATS := {
	"estrada": {"region": "estrada", "event": "bandits", "end": "bandits-left", "kind": "bandido", "action": "enfrentar-bandidos",
		"at": [Vector2(-3, -5), Vector2(2, 5), Vector2(7, -4)]},
	"vila": {"region": "vila", "event": "wolves", "end": "wolves-left", "kind": "lobo", "action": "cacar-lobos",
		"at": [Vector2(-9, -9), Vector2(9, 9), Vector2(-9, 9)]},
	# Boars roam the forest all the time; each one is its own confirmed hunt and they return later.
	"floresta": {"region": "floresta", "always": true, "per_kill": true, "kind": "javali", "action": "cacar-javali", "respawn": 25.0,
		"at": [Vector2(-8, -20), Vector2(8, 20), Vector2(16, -24)]},  # in the woods, off the road
	# When the seal shatters, corrupted creatures come to the village (the player has to know it).
	"corrupcao": {"region": "vila", "belief": "seal-shattered", "kind": "corrompido", "action": "defender-vila",
		"at": [Vector2(-10, 9), Vector2(10, -9), Vector2(-10, -9)]},
	# The White Boar: only at night, only for who found its tracks, only until it falls.
	"branco": {"region": "floresta", "night_fact": "white-boar-sign", "slain_fact": "white-boar-slain", "kind": "javali_branco",
		"action": "cacar-javali-branco", "at": [Vector2(16, -16)]},
}
const COMBO := [
	{"clip": "Sword_Regular_A", "hit": 0.30, "dmg": 22.0, "speed": 1.3},
	{"clip": "Sword_Regular_B", "hit": 0.30, "dmg": 28.0, "speed": 1.3},
	{"clip": "Sword_Regular_C", "hit": 0.34, "dmg": 38.0, "speed": 1.25},
]
const NPC_NAMES := {"mira": "Mira, a curandeira", "orin": "Orin, o guarda", "tomas": "Velho Tomas", "brom": "Brom, o ferreiro",
	"lia": "Lia, a comerciante", "kael": "Kael, o cacador", "elena": "Irma Elena", "nino": "Nino", "garrick": "Garrick, chefe da mina",
	"pipo": "Pipo, o lebrino anciao", "sora": "Sora, mestra de laminas"}
const NPCS := {
	"mira": {"at": Vector2(-5, -3), "female": true},
	"orin": {"at": Vector2(5, -3)},
	"tomas": {"at": Vector2(-3, 4)},
	"brom": {"at": Vector2(9, 2)},
	"lia": {"at": Vector2(3, 6), "female": true},
	"kael": {"at": Vector2(-9, 1)},
	"elena": {"at": Vector2(-7, 6), "female": true},
	"nino": {"at": Vector2(0, -6)},
	"sora": {"at": Vector2(3, -1), "female": true},
	"pipo": {"at": Vector2(-3, -1)},
	"garrick": {"at": Vector2(2, -4)},
}

var client: WorldClient
var player: Actor
var cam_rig: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var _synced := false
var cam_focus: Node3D  # tests: look at something other than the player
var enemies: Array[Enemy] = []
var threat_on := {}
var threat_forced := {}  # dev: --threat=region keeps a camp up whatever the world says
var camp_done := {}
var player_hp := 100.0
var player_max := 100.0
var player_down := false
var invuln_until := 0
var combo := 0
var last_attack_ms := 0
var kills := 0
var deaths := 0
var last_report := ""
var hud: Hud
var nav_region: NavigationRegion3D
var occluders: Array = []  # {nodes, center, radius, fade, applied}
var _prompt := ""
var pois: Array = []  # Places.POIS with their label nodes
var _menu: Array = []  # affordances shown in the action menu
var npc_nodes := {}  # entity id -> Actor, driven by view.others
var region := "vila"
var last_seq := 0
var _scenes := {}
var _rng := RandomNumberGenerator.new()
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
	for r in String(_args.get("threat", "")).split(",", false):  # dev: force a threat on
		threat_on[r] = true
		threat_forced[r] = true
	for r in THREATS:
		if THREATS[r].get("always", false):
			threat_on[r] = true
	client = WorldClient.new()
	client.base_url = _args.get("server", "http://127.0.0.1:8095")
	client.player_id = _args.get("player", "godot-1")
	client.player_name = _args.get("name", "Viajante")
	add_child(client)
	client.view_changed.connect(_on_view)
	client.start()
	if _args.has("autotest"):
		match String(_args.autotest):
			"wolves":
				_autotest_wolves()
			"zoo":
				_autotest_zoo()
			"hud":
				_autotest_hud()
			"places":
				_autotest_places()
			_:
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
	body.add_to_group("nav_source")
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
	plane.size = Vector2(260, 140)
	ground.mesh = plane
	ground.position = Vector3(55, 0, 5)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.26)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(260, 1, 140)
	fcs.shape = fbox
	floor_body.add_child(fcs)
	floor_body.position = Vector3(55, -0.5, 5)
	floor_body.add_to_group("nav_source")
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
	var road2 := MeshInstance3D.new()  # on through the forest to the mine and the ruins
	var rm2 := BoxMesh.new()
	rm2.size = Vector3(96, 0.03, 3.0)
	road2.mesh = rm2
	road2.position = Vector3(89, 0.015, 0)
	road2.material_override = rmat
	add_child(road2)

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
	_solid(Vector3(21.0, 0, 3.0), Vector3(16.4, 1.0, 0.25))
	_solid(Vector3(21.0, 0, -3.0), Vector3(16.4, 1.0, 0.25))

	# Trees: sparse around the village, dense in the forest.
	for i in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(34, 52)
		_tree(Vector3(cos(a) * r * 1.2 - 12, 0, sin(a) * r * 0.9))
	for i in 90:
		var p := Vector3(_rng.randf_range(34, 92), 0, _rng.randf_range(-38, 38))
		if abs(p.z) < 3.4 and p.x < 56:
			continue
		_tree(p)
	for i in 160:  # grass tufts
		var gp := Vector3(_rng.randf_range(-40, 150), 0, _rng.randf_range(-35, 48))
		if abs(gp.x) < 8 and abs(gp.z) < 8:
			continue
		_spawn("nature/Grass_Common_Short" if _rng.randf() < 0.6 else "nature/Grass_Common_Tall", gp, _rng.randf() * 360.0)

	# Bandit camp props on the road.
	_spawn("village/Prop_Wagon", Vector3(30, 0, 7), 25.0)
	_solid(Vector3(30, 0, 7), Vector3(4.0, 1.5, 2.0), 25.0)
	_spawn("village/Prop_Crate", Vector3(21, 0, -6.5))
	_spawn("village/Prop_Crate", Vector3(22.2, 0, -6.8), 30.0)
	_solid(Vector3(21.6, 0, -6.6), Vector3(2.2, 1.1, 1.2))

	Places.build(self)
	for poi in Places.POIS:
		var l := Label3D.new()
		l.text = poi.label
		l.position = poi.at + Vector3(0, 1.9, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.006
		l.font_size = 34
		l.outline_size = 8
		l.modulate = Color(1.0, 0.92, 0.7, 0.85)
		add_child(l)
		var entry: Dictionary = poi.duplicate()
		entry["node"] = l
		pois.append(entry)

	_build_nav()
	_region_zone("vila", Vector3(-6, 0, 0), Vector3(40, 6, 70))
	_region_zone("estrada", Vector3(24, 0, 0), Vector3(20, 6, 70))
	_region_zone("floresta", Vector3(64, 0, 0), Vector3(60, 6, 70))
	_region_zone("mina", Vector3(109, 0, 0), Vector3(30, 6, 70))
	_region_zone("ruinas", Vector3(139, 0, 0), Vector3(30, 6, 70))
	_region_zone("toca", Vector3(66, 0, 43), Vector3(22, 6, 14))


func _tree(p: Vector3, kind := "") -> void:
	if p.length() < 24 and abs(p.z) < 22:
		return
	if absf(p.z) < 10.0 and p.x > 8.0 and p.x < 160.0:
		return  # keep the road, the camp, the mine and the ruins visible from the fixed camera
	if Vector2(p.x - 66, p.z - 44).length() < 10.0 or Vector2(p.x - 80, p.z + 16).length() < 6.0:
		return  # the den and the seal stay open
	if kind == "":
		var kinds: Array[String] = ["nature/CommonTree_1", "nature/CommonTree_2", "nature/CommonTree_3", "nature/DeadTree_1"]
		kind = kinds[_rng.randi() % 4]
	var s := _rng.randf_range(0.8, 1.3)
	var tree := _spawn(kind, p, _rng.randf() * 360.0, s)
	_occluder(tree, p + Vector3(0, 3.2 * s, 0), 3.4 * s)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5 * s
	cyl.height = 3.0
	cs.shape = cyl
	body.add_child(cs)
	body.position = p + Vector3(0, 1.5, 0)
	body.add_to_group("nav_source")
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
	body.add_to_group("nav_source")
	root.add_child(body)
	_occluder(root, center + Vector3(0, 3.0, 0), maxf(w, d) * 2.0 + 2.5)
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
			client.move_region(id)
			_sync_enemies())


# --- navigation and occlusion ---------------------------------------------------

func _build_nav() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"nav_source"
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.agent_height = 1.8
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.3
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	nav_region.bake_finished.connect(func() -> void:
		Actor.nav_map = nav_region.get_navigation_map()
		print("NAV baked: polygons=", nav_region.navigation_mesh.get_polygon_count()))
	nav_region.bake_navigation_mesh(true)


func _occluder(node: Node3D, center: Vector3, radius: float) -> void:
	var meshes: Array = []
	for m in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
	occluders.append({"meshes": meshes, "center": center, "radius": radius, "fade": 0.0, "applied": 0.0})


## Things between the fixed camera and the player turn see-through.
func _update_occlusion(delta: float) -> void:
	var f := -cam.global_transform.basis.z
	var pp := player.global_position + Vector3(0, 1.0, 0)
	for o in occluders:
		var v: Vector3 = o.center - pp
		var along := v.dot(f)
		var perp := (v - f * along).length()
		var target := 0.0
		if along < -0.5 and perp < o.radius:
			target = 0.82
		o.fade = move_toward(o.fade, target, delta * 4.0)
		if absf(o.fade - o.applied) > 0.015:
			o.applied = o.fade
			for m in o.meshes:
				(m as GeometryInstance3D).transparency = o.fade


# --- player and camera -------------------------------------------------------

func _build_player() -> void:
	player = Actor.new()
	add_child(player)
	player.setup(_args.get("player", "godot-1"), _args.get("name", "Viajante"), false, true, "Ranger")
	player.idle_clip = "Sword_Idle"
	player.position = Vector3(0, 0, 3)


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
	if not _args.has("nopost"):
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		quad.mesh = qm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/toon_post.gdshader")
		mat.set_shader_parameter("cam_near", cam.near)
		mat.set_shader_parameter("cam_far", cam.far)
		mat.render_priority = 100
		quad.material_override = mat
		quad.extra_cull_margin = 16384.0
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cam.add_child(quad)


func _process(delta: float) -> void:
	if player == null:
		return
	cam_rig.global_position = cam_rig.global_position.lerp((cam_focus if cam_focus else player).global_position, clampf(delta * 6.0, 0.0, 1.0))
	_update_occlusion(delta)
	_update_hud_world()
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
				use_nearest()
			KEY_F:
				open_place_menu()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if hud.actions_open():
					_on_action_chosen(event.keycode - KEY_1)
			KEY_R:
				roll()
			KEY_Y:
				_answer_quest(true)
			KEY_N:
				_answer_quest(false)
			KEY_J:
				hud.toggle_journal()
			KEY_ESCAPE:
				if hud.actions_open():
					hud.hide_actions()
				elif hud.journal_panel.visible:
					hud.toggle_journal()


func click(screen: Vector2) -> void:
	hud.hide_actions()
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, 4)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.has_meta("actor"):
		var who: Actor = hit.collider.get_meta("actor")
		if who is Enemy:
			engage(who)
		else:
			interact(who)
		return
	if absf(dir.y) > 0.001:
		var t := -from.y / dir.y
		if t > 0.0:
			player.walk_to(from + dir * t)


func interact(npc: Actor) -> void:
	player.walk_to(npc.global_position + (player.global_position - npc.global_position).normalized() * 1.6)
	await player.arrived
	if player.global_position.distance_to(npc.global_position) > 2.8:
		return
	player.model.rotation.y = atan2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z)
	npc.model.rotation.y = atan2(player.global_position.x - npc.global_position.x, player.global_position.z - npc.global_position.z)
	await open_npc_menu(npc)


## The closest NPC or point of interest within reach, if any.
func _nearest_interactable() -> Dictionary:
	var best := {}
	var best_d := 3.2
	for n in npc_nodes.values():
		if n.has_meta("player"):
			continue
		var d: float = n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = {"npc": n}
	for poi in pois:
		if poi.region != region:
			continue
		var d: float = Vector2(poi.at.x - player.global_position.x, poi.at.z - player.global_position.z).length()
		if d < best_d:
			best_d = d
			best = {"poi": poi}
	return best


func use_nearest() -> void:
	var it := _nearest_interactable()
	if it.has("npc"):
		await open_npc_menu(it.npc)
	elif it.has("poi"):
		await open_poi_menu(it.poi)
	else:
		await open_place_menu()


func open_npc_menu(npc: Actor) -> void:
	await client.refresh_affordances()
	_show_menu(npc.label.text, client.affordances.filter(func(a): return a.get("with", "") == npc.entity_id))


func open_poi_menu(poi: Dictionary) -> void:
	await client.refresh_affordances()
	var target: String = poi.get("with", "")
	var acts: Array = poi.get("actions", [])
	_show_menu(poi.label, client.affordances.filter(func(a):
		return target != "" and a.get("with", "") == target or a.get("with", "") == "" and acts.has(a.action)))


## Everything that can be tried in this region that is not about a person or a landmark.
func open_place_menu() -> void:
	await client.refresh_affordances()
	_show_menu("Acoes aqui: %s" % REGION_NAMES.get(region, region), client.affordances.filter(func(a):
		return a.get("with", "") == "" and not COMBAT_REPORTED.has(a.action)))


func _show_menu(title: String, list: Array) -> void:
	_menu = list
	if list.is_empty():
		hud.hide_actions()
		_log("[color=#aaaaaa]%s: nada para fazer agora.[/color]" % title)
		return
	hud.show_actions(title, list.map(func(a): return a.title))


func _on_action_chosen(i: int) -> void:
	if i < 0 or i >= _menu.size():
		return
	hud.hide_actions()
	await _perform(_menu[i])


## An affordance becomes an intent (player) or, for what a game server would
## confirm, an occurrence (adapter). The engine accepts or refuses it.
func _perform(a: Dictionary) -> void:
	var target: String = a.get("with", "")
	if npc_nodes.has(target):
		var n: Actor = npc_nodes[target]
		player.model.rotation.y = atan2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z)
	player.play_once(Places.ANIM.get(a.action, "Interact"))
	var args: Dictionary = a.get("args", {})
	var res: Dictionary
	if a.origin == "adapter":
		res = await client.occur(a.action, args)
	else:
		res = await client.act(a.action, args)
	last_report = "%s:%s" % [a.action, "ok" if res.status == 200 else res.body.get("error", "sem resposta")]
	if res.status == 200:
		var lines: Array = []
		for ev in res.body.get("events", []):
			if ev.get("text", "") != "":
				lines.append(ev.text)
		_log("[color=#9fdc7a]%s[/color]: %s" % [a.title, " / ".join(lines) if lines.size() > 0 else "feito"])
	else:
		var why: String = res.body.get("error", "")
		_log("[color=#e8806a]%s[/color]: %s" % [a.title, "agora nao da (o mundo nao permite)" if why.contains("requirements") else why])
	client.refresh()


## Talk to an NPC directly (tests and the first meeting).
func _talk(npc: Actor) -> void:
	await _perform({"action": "conversar", "origin": "player", "args": {"npc": npc.entity_id}, "with": npc.entity_id, "title": "Conversar com %s" % npc.label.text})


func attack() -> void:
	if player.busy or player_down:
		return
	var now := Time.get_ticks_msec()
	if now - last_attack_ms > 1400:
		combo = 0
	var step: Dictionary = COMBO[combo % COMBO.size()]
	combo += 1
	last_attack_ms = now
	var near := _nearest_enemy(3.5)
	if near:  # aim assist: swing toward the closest enemy
		var to := near.global_position - player.global_position
		player.model.rotation.y = atan2(to.x, to.z)
	player.play_once(step.clip, step.speed)
	await get_tree().create_timer(step.hit).timeout
	if player_down or not player.busy:  # fell or walked away: the swing is cancelled
		return
	_strike(step.dmg)


func _strike(dmg: float) -> void:
	var yaw := player.model.rotation.y
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var hit_any := false
	for e in enemies:
		if not is_instance_valid(e) or e.state == Enemy.State.DEAD:
			continue
		var to := e.global_position - player.global_position
		to.y = 0
		if to.length() < 2.7 and fwd.dot(to.normalized()) > 0.3:
			e.take_hit(dmg, player.global_position)
			_burst(e.global_position + Vector3(0, 1.2, 0))
			hit_any = true
	if hit_any:
		_shake = 0.8
		_hitstop()
	else:
		_burst(player.global_position + fwd * 1.5 + Vector3(0, 1.1, 0))
		_shake = 0.3


func _nearest_enemy(radius: float) -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			var d := e.global_position.distance_to(player.global_position)
			if d < radius and (best == null or d < best.global_position.distance_to(player.global_position)):
				best = e
	return best


func _hitstop(sec := 0.06) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.08
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0


func roll() -> void:
	if player_down:
		return
	player.interrupt()
	var yaw := player.model.rotation.y
	invuln_until = Time.get_ticks_msec() + 550
	player.dash(Vector3(sin(yaw), 0, cos(yaw)), 0.45)
	player.play_once("Roll", 1.3)


func engage(e: Enemy) -> void:
	var to := e.global_position - player.global_position
	to.y = 0
	if to.length() > 2.2:
		player.walk_to(e.global_position - to.normalized() * 1.7)
		await player.arrived
	if is_instance_valid(e) and e.state != Enemy.State.DEAD:
		attack()


# --- enemies ----------------------------------------------------------------

func _sync_enemies() -> void:
	enemies.assign(enemies.filter(func(x): return is_instance_valid(x)))
	for e in enemies.duplicate():
		var t: Dictionary = THREATS.get(e.camp, {})
		if t.get("region", "") != region or not threat_on.get(e.camp, false) and e.state != Enemy.State.DEAD:
			e.queue_free()  # left the region, or the threat is over (they go away)
			enemies.erase(e)
	for camp in THREATS:
		var t: Dictionary = THREATS[camp]
		if t.region != region or not threat_on.get(camp, false) or camp_done.get(camp, false):
			continue
		var standing := false
		for e in enemies:
			standing = standing or e.camp == camp
		if standing:
			continue
		var origin: Vector3 = REGION_ORIGIN[region]
		for off in t.at:
			_spawn_enemy(t.kind, camp, origin + Vector3(off.x, 0, off.y))
		_log("[color=#ffb070]%s: %d inimigos a vista.[/color]" % [REGION_NAMES.get(region, region), t.at.size()])


func _spawn_enemy(kind: String, camp: String, at: Vector3) -> Enemy:
	if Actor.nav_map.is_valid():  # never start inside a tree or a wall
		at = NavigationServer3D.map_get_closest_point(Actor.nav_map, at)
	var e := Enemy.new()
	add_child(e)
	e.configure(kind, camp, at, player)
	e.damaged.connect(_on_enemy_damaged)
	e.hit_player.connect(_on_hit_player)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	return e


func _respawn_later(camp: String) -> void:
	var t: Dictionary = THREATS[camp]
	await get_tree().create_timer(float(_args.get("respawn", t.get("respawn", 25.0)))).timeout
	if region != t.region or player_down or not threat_on.get(camp, false):
		return  # leaving the region already cleared the camp; it refills on return
	var standing := 0
	for e in enemies:
		if is_instance_valid(e) and e.camp == camp and e.state != Enemy.State.DEAD:
			standing += 1
	if standing < t.at.size():
		var off: Vector2 = t.at[_rng.randi() % t.at.size()]
		_spawn_enemy(t.kind, camp, REGION_ORIGIN[t.region] + Vector3(off.x, 0, off.y))


func _on_enemy_damaged(e: Enemy, amount: float) -> void:
	_float_text(e.global_position + Vector3(0, 2.3, 0), str(int(amount)), Color(1, 0.9, 0.35))


func _on_enemy_died(e: Enemy) -> void:
	kills += 1
	var tk: Dictionary = THREATS[e.camp]
	if tk.get("per_kill", false):  # each animal is its own confirmed hunt
		var hunt := await client.occur(tk.action)
		_report("Servidor de jogo", tk.action, hunt)
		_respawn_later(e.camp)
		return
	for other in enemies:
		if is_instance_valid(other) and other.camp == e.camp and other.state != Enemy.State.DEAD:
			return
	camp_done[e.camp] = true  # last one down: the server confirms the outcome to the engine
	var t: Dictionary = THREATS[e.camp]
	var res := await client.occur(t.action)
	_report("Servidor de jogo", t.action, res)


func _on_hit_player(_e: Enemy, amount: float) -> void:
	if player_down:
		return
	if Time.get_ticks_msec() < invuln_until:
		_float_text(player.global_position + Vector3(0, 2.3, 0), "esquiva", Color(0.6, 0.9, 1.0))
		return
	player_hp = maxf(player_hp - amount, 0.0)
	_set_hp()
	_float_text(player.global_position + Vector3(0, 2.3, 0), str(int(amount)), Color(1, 0.35, 0.3))
	_shake = 0.7
	if player_hp <= 0.0:
		_player_fell()
		return
	if not player.busy:
		player.play_once("Hit_Chest", 1.3)


func _player_fell() -> void:
	player_down = true
	deaths += 1
	player.interrupt()
	player.has_goal = false
	player.busy = true
	player.anim.play("Death01", 0.1, 1.0)
	for e in enemies:
		if is_instance_valid(e):
			e.target_down = true
	_log("[color=#e8806a]Voce caiu. A vila te acolhe...[/color]")
	await get_tree().create_timer(2.8).timeout
	player_hp = player_max
	_set_hp()
	player_down = false
	player.busy = false
	player.global_position = REGION_ORIGIN["vila"] + Vector3(0, 0, 3)
	player.play(player.idle_clip)
	region = "vila"
	client.move_region("vila")
	for e in enemies:
		if is_instance_valid(e):
			e.target_down = false
	_sync_enemies()


func _set_hp() -> void:
	hud.set_hp(player_hp, player_max)


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = pos
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.3, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


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
	if hud.offered_key != "":
		await _answer_quest_key(hud.offered_key, accept)


func _answer_quest_key(key: String, accept: bool) -> void:
	var title := key
	for q in client.view.get("quests", []):
		if q.key == key:
			title = q.title
	var res: Dictionary
	if accept:
		res = await client.accept(key)
	else:
		res = await client.decline(key)
	_report(title, "accept" if accept else "decline", res)
	client.refresh()


func _abandon_quest(key: String) -> void:
	var res := await client._command("player", "abandon", {"quest": key})
	_report(key, "abandon", res)
	client.refresh()


func _report(who: String, what: String, res: Dictionary) -> void:
	last_report = "%s:%s" % [what, "ok" if res.status == 200 else res.body.get("error", "sem resposta")]
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
		player.global_position = REGION_ORIGIN.get(region, Vector3.ZERO) + Vector3(0, 0, 3)
		cam_rig.global_position = player.global_position
	var names := NPC_NAMES.duplicate()
	for o in v.get("others", []):
		names[o.id] = o.name
	hud.set_status(REGION_NAMES.get(me.get("region", ""), me.get("region", "?")), int(v.get("hour", -1)), int(v.get("tick", 0)))
	hud.set_quests(v.get("quests", []), int(v.get("tick", 0)), names, REGION_NAMES)
	hud.set_skills(v.get("skills", []))
	var givers := {}
	for q in v.get("quests", []):
		if q.state == "offered" and q.get("giver", "") != "":
			givers[q.giver] = true
	_sync_npcs(v)
	_sun(int(v.get("hour", -1)))
	for e in v.get("events", []):
		if int(e.seq) > last_seq:
			last_seq = int(e.seq)
			for r in THREATS:
				if e.kind == THREATS[r].get("event", "!"):
					threat_on[r] = true
					camp_done[r] = false
				elif e.kind == THREATS[r].get("end", "!") and not threat_forced.has(r):
					threat_on[r] = false
			if e.get("text", "") != "":
				_log("[color=#c9b3ff]%s[/color]" % e.text)
	_conditional_threats(v)
	_sync_enemies()
	for id in npc_nodes:
		npc_nodes[id].set_marker("!" if givers.has(id) else "")


func _conditional_threats(v: Dictionary) -> void:
	var hr := int(v.get("hour", -1))
	var night := hr >= 20 or hr >= 0 and hr < 4
	for camp in THREATS:
		var t: Dictionary = THREATS[camp]
		if threat_forced.has(camp):
			continue
		if t.has("belief"):
			threat_on[camp] = v.get("beliefs", []).any(func(b): return b.p == t.belief and b.holds)
		elif t.has("night_fact"):
			threat_on[camp] = night and _has_fact(v, t.night_fact) and not _has_fact(v, t.slain_fact)


func _has_fact(v: Dictionary, p: String) -> bool:
	return v.get("facts", []).any(func(f): return f.p == p)


func _sync_npcs(v: Dictionary) -> void:
	var here := {}
	var i := 0
	for o in v.get("others", []):
		if o.kind != "npc" and o.kind != "player" or o.id == client.player_id or o.get("region", "") != v.self.get("region", ""):
			continue
		here[o.id] = o
	for id in npc_nodes.keys():
		if not here.has(id):
			npc_nodes[id].queue_free()
			npc_nodes.erase(id)
	for id in here:
		if npc_nodes.has(id):
			continue
		var is_player: bool = here[id].kind == "player"
		var spec: Dictionary = NPCS.get(id, {})
		var at: Vector2 = spec.get("at", Vector2(-12 + (i % 5) * 6, 11))
		if is_player:  # the engine knows regions, not coordinates: a stable spot from the id
			var ang := float(hash(id) % 360) * PI / 180.0
			at = Vector2(cos(ang), sin(ang)) * 11.0
		i += 1
		var npc := Actor.new()
		add_child(npc)
		npc.setup(id, here[id].name.split(",")[0], spec.get("female", false), id == "orin" or id == "sora", "Ranger" if id == "orin" or id == "sora" or id == "kael" else "Peasant")
		npc.idle_clip = "Idle_Talking" if id == "tomas" else "Idle"
		if is_player:
			npc.set_meta("player", true)
			npc.label.modulate = Color(0.6, 0.82, 1.0)
		npc.play(npc.idle_clip)
		npc.position = REGION_ORIGIN.get(region, Vector3.ZERO) + Vector3(at.x, 0, at.y)
		npc.model.rotation.y = atan2(-at.x, -at.y)
		npc_nodes[id] = npc


func _sun(hour: int) -> void:
	if hour < 0:
		return
	var day := clampf(sin((hour - 6) / 12.0 * PI), 0.0, 1.0)
	sun.light_energy = lerpf(0.2, 1.3, day)
	env.background_color = Color(0.12, 0.15, 0.28).lerp(Color(0.55, 0.72, 0.9), day)
	env.ambient_light_energy = lerpf(0.3, 0.65, day)
	env.ambient_light_color = Color(0.45, 0.55, 0.9).lerp(Color(0.75, 0.8, 0.95), day)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = Hud.new()
	hud.region_names = REGION_NAMES
	add_child(hud)
	hud.accept_pressed.connect(func(k: String) -> void: _answer_quest_key(k, true))
	hud.decline_pressed.connect(func(k: String) -> void: _answer_quest_key(k, false))
	hud.abandon_pressed.connect(_abandon_quest)
	hud.action_chosen.connect(_on_action_chosen)
	hud.set_hp(player_hp, player_max)


func _update_hud_world() -> void:
	var npcs: Array = []
	var best: Actor = null
	for n in npc_nodes.values():
		npcs.append(n.global_position)
		if n.has_meta("player"):
			continue
		if best == null or n.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = n
	var foes: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			foes.append(e.global_position)
	hud.set_minimap(player.global_position, player.model.rotation.y, npcs, foes, region)
	var text := ""
	if not hud.journal_panel.visible and not hud.actions_open():
		var it := _nearest_interactable()
		if it.has("npc"):
			text = "[E] Falar com %s" % it.npc.label.text
		elif it.has("poi"):
			text = "[E] %s" % it.poi.label
	if text != _prompt:
		_prompt = text
		hud.set_prompt(text)


func _log(bb: String) -> void:
	hud.add_log(bb)
	print("LOG ", bb)


# --- automated check ---------------------------------------------------------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir: String = _args.get("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("SHOT ", name)


func _arrive(timeout := 20.0) -> void:
	var t := Time.get_ticks_msec()
	while player.has_goal and Time.get_ticks_msec() - t < timeout * 1000.0:
		await get_tree().create_timer(0.1).timeout


func _fight_all(max_ms: int, shot_name := "", max_kills := 0) -> void:
	var t_fight := Time.get_ticks_msec()
	var start_kills := kills
	var shot_done := shot_name == ""
	while Time.get_ticks_msec() - t_fight < max_ms:
		var alive := enemies.filter(func(e): return is_instance_valid(e) and e.state != Enemy.State.DEAD)
		if alive.is_empty() or (max_kills > 0 and kills - start_kills >= max_kills):
			break
		if player_down:
			await get_tree().create_timer(0.5).timeout
			continue
		alive.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
		var e: Enemy = alive[0]
		if player.global_position.distance_to(e.global_position) > 2.3:
			player.walk_to(e.global_position - (e.global_position - player.global_position).normalized() * 1.6)
		else:
			attack()
		await get_tree().create_timer(0.25).timeout
		if not shot_done and Time.get_ticks_msec() - t_fight > 5000:
			shot_done = true
			await _shot(shot_name)


## A real click through the input pipeline (motion, press, release) on a control.
func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	Input.parse_input_event(mm)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _quest_state(key: String) -> String:
	for q in client.view.get("quests", []):
		if q.key == key:
			return q.state
	return ""


func _wait_state(key: String, want: String, timeout := 6.0) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < timeout * 1000.0:
		if _quest_state(key) == want:
			return true
		await get_tree().create_timer(0.2).timeout
	return false


## Frames per second and draw calls over a few seconds (vsync off while sampling).
func _perf(seconds := 3.0) -> Dictionary:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.5).timeout
	var frames := 0
	var t := Time.get_ticks_usec()
	var worst := 0.0
	var last := t
	while Time.get_ticks_usec() - t < seconds * 1000000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var fps := frames / ((Time.get_ticks_usec() - t) / 1000000.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	return {"fps": snappedf(fps, 0.1), "worst_ms": snappedf(worst, 0.1),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}


## Synthetic quest states (no engine involved) to see every toast and journal group.
func _autotest_hud() -> void:
	await get_tree().create_timer(3.0).timeout
	client._timer.stop()  # the real view must not overwrite the synthetic one
	var names := {"mira": "Mira, a curandeira"}
	var q1 := {"key": "s1", "def": "ervas-mira", "state": "offered", "title": "Ervas para a curandeira", "rank": "E", "giver": "mira", "objective": "Colha ervas.", "reward": "Reputacao +1", "region": "floresta", "deadline": 120}
	var q2 := {"key": "s2", "def": "cenario-origem", "state": "active", "title": "Cenario Unico: A Origem", "rank": "S", "objective": "Siga o rastro.", "reward": "Titulo unico", "penalty": "Outro aventureiro chega primeiro", "region": "floresta", "deadline": 40}
	hud.set_quests([q1, q2], 10, names, REGION_NAMES)
	await get_tree().create_timer(0.3).timeout
	var a := q1.duplicate()
	a.state = "active"
	hud.set_quests([a, q2], 20, names, REGION_NAMES)
	await get_tree().create_timer(0.3).timeout
	var f := q2.duplicate()
	f.state = "failed"
	var x := a.duplicate()
	x.state = "expired"
	hud.set_quests([x, f], 130, names, REGION_NAMES)
	hud.set_skills([{"id": "andarilho", "name": "Andarilho", "rarity": "comum", "desc": "Seus pes conhecem cada atalho."}])
	await get_tree().create_timer(0.4).timeout
	await _shot("h1_toasts")
	hud.toggle_journal()
	await get_tree().create_timer(0.4).timeout
	await _shot("h2_journal")
	print("AUTOTEST ", JSON.stringify({"hud": true, "toasts": hud.toast_box.get_child_count()}))
	get_tree().quit()


## Every creature in a row, no AI: checks scale, facing and the idle pose.
func _autotest_zoo() -> void:
	await get_tree().create_timer(3.0).timeout
	var row := ["bandido", "lobo", "javali", "corrompido"]
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var toward := cam.global_transform.basis.z
	toward.y = 0
	toward = toward.normalized()
	for i in row.size():
		var z := Enemy.new()
		add_child(z)
		z.configure(row[i], "zoo", player.global_position + right * (-4.5 + i * 3.0) + toward * 3.0, null)
		z.model.rotation.y = atan2(toward.x, toward.z)  # face the camera
	cam.size = 6.5
	await get_tree().create_timer(1.0).timeout
	await _shot("z1_zoo")
	for e in get_children():
		if e is Enemy and e.kind == "javali":
			e.play("Run")
	await get_tree().create_timer(0.8).timeout
	await _shot("z2_zoo_run")
	cam.size = 3.2
	for e in get_children():
		if e is Enemy and (e.kind == "lobo" or e.kind == "javali"):
			cam_focus = e
			await get_tree().create_timer(0.8).timeout
			await _shot("z3_%s" % e.kind)
	print("AUTOTEST ", JSON.stringify({"zoo": row.size(), "other_players": npc_nodes.values().filter(func(n): return n.has_meta("player")).size()}))
	get_tree().quit()


func _autotest_wolves() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {"view": not client.view.is_empty(), "wolves_spawned": enemies.size()}
	await _shot("w1_wolves")
	await _fight_all(60000, "w2_fight")
	await get_tree().create_timer(2.5).timeout
	await _shot("w3_clear")
	ok["kills"] = kills
	ok["deaths"] = deaths
	ok["player_hp"] = int(player_hp)
	ok["report"] = last_report
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


func _menu_index(action: String) -> int:
	for i in _menu.size():
		if _menu[i].action == action:
			return i
	return -1


## Walk there like a player would: a hit stops the walk, so click again.
func _go(target: Vector3, timeout := 40.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < timeout * 1000.0:
		var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if flat.length() < 1.5:
			break
		if not player.has_goal and not player.busy and not player_down:
			player.walk_to(target)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.2).timeout  # region move reaches the engine


func _poi(id: String) -> Dictionary:
	for p in pois:
		if p.id == id:
			return p
	return {}


## Walk to every place, open the menus the player would and do one thing each.
func _autotest_places() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {"view": not client.view.is_empty()}
	if npc_nodes.has("orin"):  # the village gets to know the player
		var orin: Actor = npc_nodes["orin"]
		await _go(orin.global_position + Vector3(1.4, 0, 0))
		await _talk(orin)
	# Mine: open the vein's menu and click the option.
	var vein := _poi("veio1")
	await _go(vein.at + Vector3(-1.5, 0, 0))
	ok["region_mina"] = client.view.get("self", {}).get("region", "")
	await open_place_menu()
	ok["mina_actions"] = _menu.map(func(a): return a.action)
	await open_poi_menu(vein)
	await _shot("p1_mina_menu")
	var i := _menu_index("minerar")
	ok["minerar_offered"] = i >= 0
	if i >= 0:
		await _click(hud.action_buttons[i])
		await get_tree().create_timer(1.5).timeout
		ok["minerar"] = last_report
	await _shot("p2_mina")
	# Ruins: the stairs down to the inner hall.
	var hall := _poi("salao")
	await _go(hall.at + Vector3(-2.0, 0, 0))
	ok["region_ruinas"] = client.view.get("self", {}).get("region", "")
	await open_poi_menu(hall)
	i = _menu_index("explorar-ruinas")
	if i >= 0:
		_on_action_chosen(i)
		await get_tree().create_timer(1.5).timeout
		ok["explorar"] = last_report
	await _shot("p3_ruinas")
	# The den: talk to Pipo through his menu.
	await _go(REGION_ORIGIN["toca"] + Vector3(0, 0, -1))
	ok["region_toca"] = client.view.get("self", {}).get("region", "")
	await get_tree().create_timer(1.5).timeout
	ok["toca_npcs"] = npc_nodes.keys()
	if npc_nodes.has("pipo"):
		await _go(npc_nodes["pipo"].global_position + Vector3(0, 0, -1.4), 15.0)
		await open_npc_menu(npc_nodes["pipo"])
		ok["pipo_actions"] = _menu.map(func(a): return a.action)
		i = _menu_index("conversar")
		if i >= 0:
			_on_action_chosen(i)
			await get_tree().create_timer(1.5).timeout
			ok["pipo"] = last_report
	await _shot("p4_toca")
	# Back to the village: with ore, Brom's menu has the forge.
	await _go(REGION_ORIGIN["vila"] + Vector3(7.5, 0, 2.5), 60.0)
	if npc_nodes.has("brom"):
		await open_npc_menu(npc_nodes["brom"])
		ok["brom_actions"] = _menu.map(func(a): return a.action)
		await _shot("p5_brom_menu")
		i = _menu_index("forjar")
		if i >= 0:
			_on_action_chosen(i)
			await get_tree().create_timer(1.5).timeout
			ok["forjar"] = last_report
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


func _autotest() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {"view": not client.view.is_empty(), "npcs": npc_nodes.size()}
	ok["nav"] = Actor.nav_map.is_valid()
	ok["perf_plaza"] = await _perf()
	await _shot("01_plaza")
	if npc_nodes.has("orin"):
		var orin: Actor = npc_nodes["orin"]
		player.walk_to(orin.global_position + Vector3(1.4, 0, 0))
		await _arrive(15.0)
		await _talk(orin)
		await get_tree().create_timer(1.2).timeout
	ok["markers"] = npc_nodes.values().filter(func(n): return n.marker != null).size()
	await _shot("02_offer")
	var offered := false
	for q in client.view.get("quests", []):
		offered = offered or q.state == "offered"
	ok["quest_offered"] = offered
	if offered:
		var key := hud.offered_key
		await _click(hud.offer_buttons.accept)
		ok["click_accept"] = await _wait_state(key, "active")
		ok["quest_active"] = client.view.get("quests", []).any(func(q): return q.state == "active")
		# a second offer, if the world has one, is declined with its button
		await get_tree().create_timer(1.5).timeout
		if hud.offered_key != "" and hud.offer_panel.visible:
			var k2 := hud.offered_key
			await _click(hud.offer_buttons.decline)
			ok["click_decline"] = await _wait_state(k2, "declined")
		await _shot("03_tracker")
	# Pathfinding: the straight line to the target crosses a house.
	player.walk_to(Vector3(-8, 0, -12))
	await _arrive(25.0)
	var from := player.global_position
	var target := Vector3(-24, 0, -12)
	var t_path := Time.get_ticks_msec()
	player.walk_to(target)
	await get_tree().create_timer(2.0).timeout
	await _shot("04_path")
	await _arrive(30.0)
	ok["path_reached"] = player.global_position.distance_to(target) < 2.0
	ok["path_seconds"] = snappedf((Time.get_ticks_msec() - t_path) / 1000.0, 0.1)
	ok["path_direct_m"] = snappedf(from.distance_to(target), 0.1)
	print("STEP walking to estrada")
	player.walk_to(REGION_ORIGIN["estrada"])
	await _arrive(25.0)
	print("STEP arrived estrada, enemies=", enemies.size())
	await get_tree().create_timer(1.2).timeout
	ok["enemies_spawned"] = enemies.size()
	await _shot("04b_estrada")
	print("STEP fight start")
	await _fight_all(60000, "05b_fight")
	await get_tree().create_timer(2.5).timeout
	await _shot("05_clear")
	ok["bandit_report"] = last_report
	cam.size = 3.5
	await get_tree().create_timer(0.6).timeout
	await _shot("06_closeup")
	cam.size = 14.0
	player.walk_to(REGION_ORIGIN["floresta"] + Vector3(6, 0, 0))
	await _arrive(30.0)
	await get_tree().create_timer(1.5).timeout
	await _shot("07_forest")
	ok["perf_forest"] = await _perf()
	var flat := -cam.global_transform.basis.z
	flat.y = 0
	flat = flat.normalized()
	for o in occluders:
		if o.radius < 5.0 and Vector2(o.center.x - player.global_position.x, o.center.z - player.global_position.z).length() < 20.0:
			player.has_goal = false
			player.global_position = Vector3(o.center.x, 0, o.center.z) + flat * 4.0  # behind the tree, seen from the camera
			cam_rig.global_position = player.global_position
			await get_tree().create_timer(1.0).timeout
			ok["tree_fade"] = snappedf(o.applied, 0.01)
			await _shot("07c_tree_occlusion")
			break
	var kills_before := kills
	ok["boars_spawned"] = enemies.filter(func(e): return is_instance_valid(e) and e.kind == "javali").size()
	await _fight_all(45000, "07b_boar", 3)
	await get_tree().create_timer(2.0).timeout
	ok["boar_kills"] = kills - kills_before
	ok["boar_report"] = last_report
	if _args.has("respawn"):
		await get_tree().create_timer(float(_args.respawn) + 2.0).timeout
		ok["boar_respawned"] = enemies.filter(func(x): return is_instance_valid(x) and x.kind == "javali" and x.state != Enemy.State.DEAD).size()
	ok["occluders_faded"] = occluders.filter(func(o): return o.applied > 0.5).size()
	hud.toggle_journal()
	await get_tree().create_timer(0.4).timeout
	await _shot("08_journal")
	# Journal buttons, clicked for real: accept an offer, decline another, abandon an active quest.
	var acc := get_tree().get_nodes_in_group("journal_accept_btn")
	if acc.size() > 0:
		var k_acc: String = acc[0].get_meta("quest")
		await _click(acc[0])
		ok["click_journal_accept"] = await _wait_state(k_acc, "active")
		await get_tree().create_timer(1.2).timeout  # the journal rebuilds from the new view
	var dec := get_tree().get_nodes_in_group("journal_decline_btn")
	if dec.size() > 0:
		var k_dec: String = dec[0].get_meta("quest")
		await _click(dec[0])
		ok["click_journal_decline"] = await _wait_state(k_dec, "declined")
		await get_tree().create_timer(1.2).timeout
	var ab := get_tree().get_nodes_in_group("abandon_btn")
	if ab.size() > 0:
		var k_ab: String = ab[0].get_meta("quest")
		await _click(ab[0])
		ok["click_abandon"] = await _wait_state(k_ab, "abandoned")
	hud.toggle_journal()
	ok["kills"] = kills
	ok["deaths"] = deaths
	ok["player_hp"] = int(player_hp)
	ok["report"] = last_report
	ok["region_local"] = region
	ok["region_server"] = client.view.get("self", {}).get("region", "")
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()
