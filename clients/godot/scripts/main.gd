extends Node3D
## Fixed-isometric 3D client. The world's truth lives in the engine; this scene
## shows what the engine says the player can see and sends the player's intents.

const REGION_NAMES := {"vila": "Vila Cinzenta", "floresta": "Floresta Cinzenta", "estrada": "Estrada do Leste",
	"mina": "Mina de Kharum", "ruinas": "Ruinas de Asterion", "toca": "Toca dos Lebrinos"}
const DISCOVERED := "found"  # the universe's discovered-place predicate
const CHATTER_RANGE := 15.0  # how close you must be to hear people talk
const LABEL_RANGE := 7.0  # world labels show only when you are close enough to notice
const REGION_ORIGIN := Layout.ORIGIN
# Combat outcomes are reported by fights, never offered as menu options.
const COMBAT_REPORTED := ["acender-tocha", "enfrentar-bandidos", "cacar-lobos", "cacar-javali", "cacar-javali-branco", "defender-vila"]
# Threats appear and end through public world events (the engine decides when).
# Defeating a camp is reported back as a confirmed occurrence; the engine validates it.
const THREATS := {
	"estrada": {"region": "estrada", "event": "bandits", "end": "bandits-left", "kind": "bandido", "action": "enfrentar-bandidos",
		"at": [Vector2(-3, -5), Vector2(2, 5), Vector2(7, -4)]},
	"vila": {"region": "vila", "event": "wolves", "end": "wolves-left", "kind": "lobo", "action": "cacar-lobos",
		"at": [Vector2(-9, -9), Vector2(9, 9), Vector2(-9, 9)]},
	# Boars roam the forest all the time; each one is its own confirmed hunt and they return later.
	"floresta": {"region": "floresta", "always": true, "per_kill": true, "kind": "javali", "action": "cacar-javali", "respawn": 25.0,
		"at": [Vector2(-20, -8), Vector2(22, 10), Vector2(-14, 16)]},  # in the woods, off the trail
	# When the seal shatters, corrupted creatures come to the village (the player has to know it).
	"corrupcao": {"region": "vila", "belief": "seal-shattered", "kind": "corrompido", "action": "defender-vila",
		"at": [Vector2(-10, 9), Vector2(10, -9), Vector2(-10, -9)]},
	# The White Boar: only at night, only for who found its tracks, only until it falls.
	"branco": {"region": "floresta", "night_fact": "white-boar-sign", "slain_fact": "white-boar-slain", "kind": "javali_branco",
		"action": "cacar-javali-branco", "at": [Vector2(-18, -12)]},
}
# Combat abilities (the game server's rules; the engine never sees them).
const ABILITIES := [
	{"id": "giro", "name": "Golpe Giratorio", "key": "1", "cd": 6.0, "color": Color(1.0, 0.78, 0.3),
		"desc": "Gira a lamina e atinge todos ao redor (30 de dano)."},
	{"id": "investida", "name": "Investida", "key": "2", "cd": 5.0, "color": Color(0.5, 0.8, 1.0),
		"desc": "Avanca na direcao do cursor ferindo quem estiver no caminho (25)."},
	{"id": "lamina", "name": "Lamina de Energia", "key": "3", "cd": 4.0, "color": Color(0.78, 0.52, 1.0),
		"desc": "Dispara uma lamina de luz na direcao do cursor (35)."},
	{"id": "cura", "name": "Folego", "key": "4", "cd": 15.0, "color": Color(0.45, 1.0, 0.55),
		"desc": "Recupera 30 de vida."},
	{"id": "esquiva", "name": "Esquiva", "key": "R", "cd": 1.2, "color": Color(0.88, 0.88, 0.88),
		"desc": "Rola na direcao em que voce anda, invulneravel por um instante."},
]
const COMBO := [
	{"clip": "Sword_Regular_A", "hit": 0.30, "dmg": 22.0, "speed": 1.3},
	{"clip": "Sword_Regular_B", "hit": 0.30, "dmg": 28.0, "speed": 1.3},
	{"clip": "Sword_Regular_C", "hit": 0.34, "dmg": 38.0, "speed": 1.25},
]
const NPC_NAMES := {"mira": "Mira, a curandeira", "orin": "Orin, o guarda", "tomas": "Velho Tomas", "brom": "Brom, o ferreiro",
	"lia": "Lia, a comerciante", "kael": "Kael, o cacador", "elena": "Irma Elena", "nino": "Nino", "garrick": "Garrick, chefe da mina",
	"pipo": "Pipo, o lebrino anciao", "sora": "Sora, mestra de laminas"}
const NPCS := {  # who is female; positions come from the engine's spots
	"mira": {"female": true}, "elena": {"female": true}, "lia": {"female": true}, "sora": {"female": true},
}
# Where NPCs without a routine stand in their region (offsets from the region's origin).
const NPC_FALLBACK := {
	"lia": Vector2(3, 6), "kael": Vector2(-9, 1), "sora": Vector2(3, -1), "pipo": Vector2(-3, -1), "garrick": Vector2(2, -4),
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
var telemetry := Telemetry.new()
var _seen := {"seq": 0, "opening": false, "ceremony": false, "people": {}}  # what this character already lived through (user://)
var _seen_saved_ms := 0
var _all_names := {}  # entity id -> name, from the latest view
var far_marks := {}  # sign id -> {pos, look, color, region}: landmarks seen from another region
var torch_on := false
var torch_light: OmniLight3D
var gallery_dark := false
var passages: Array = []  # {node, pos, dest, region, label}: the old passage under the mine, once known
var _tracking := false
var _look_far_until := 0
var sign_nodes := {}  # sign id -> marker the engine says the observer can make out here
var _last_greet_ms := 0
var greet_count := 0
var _found_seeded := false  # the places already known when the client starts are not announced
var found_places: Dictionary = {}  # regions this character has discovered (engine fact "found")
var pois: Array = []  # Places.pois() with their label nodes
var _menu: Array = []  # affordances shown in the action menu
var ready_at := {}  # ability id -> msec when it can be used again
var _lmb_held := false
var _move_dir := Vector3.ZERO
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
	client.arrival_region = String(_args.get("arrival", "estrada"))
	client.view_limit = 60  # the first view carries the recap of what happened while away
	_load_seen()
	hud.ceremony_pending = not _seen.ceremony and (not _args.has("autotest") or _args.has("ceremony"))
	hud.ceremony_done.connect(func() -> void:
		_seen.ceremony = true
		_save_seen())
	telemetry.open(String(_args.get("telemetry", "user://telemetry-%s.jsonl" % client.player_id)), client.player_id)
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
			"skills":
				_autotest_skills()
			"f0":
				_autotest_f0()
			"f1":
				_autotest_f1()
			"layout":
				_autotest_layout()
			"tour":
				_autotest_tour()
			"board":
				_autotest_board()
			"arrival":
				_autotest_arrival()
			"saber":
				_autotest_saber()
			"vestigios":
				_autotest_vestigios()
			"cancao":
				_autotest_cancao()
			"fora":
				_autotest_fora()
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
	plane.size = Vector2(240, 160)
	ground.mesh = plane
	ground.position = Vector3(35, 0, -30)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.26)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(240, 1, 160)
	fcs.shape = fbox
	floor_body.add_child(fcs)
	floor_body.position = Vector3(35, -0.5, -30)
	floor_body.add_to_group("nav_source")
	add_child(floor_body)

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.42, 0.28)
	rmat.roughness = 1.0
	for r in Layout.ROADS:
		_road(r[0], r[1], r[2], rmat)

	# Plaza paving: 6x6 tiles of 2m.
	for x in 6:
		for z in 6:
			_spawn("village/Floor_UnevenBrick", Vector3(-5 + x * 2, 0.0, -5 + z * 2))

	_palisade()
	_house(Vector3(-16, 0, -12), 3, 3, 0.0, false, "home")  # Mira's house
	_house(Vector3(15, 0, -14), 3, 4, 0.0, true, "tavern")  # the tavern
	_house(Vector3(-17, 0, 14), 3, 3, 180.0, true, "forge")  # Brom's forge
	_house(Vector3(16, 0, 15), 3, 3, 180.0, false, "chapel")  # the chapel
	_house(Vector3(2, 0, 22), 3, 3, 180.0, false, "barn")  # the barn
	_house(Vector3(-9, 0, -21), 2, 2, 0.0, false, "home")  # Nino's home
	_house(Vector3(28, 0, -9), 2, 2, 0.0, true, "guard")  # the gate house
	_village_details()

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

	# Trees: sparse outside the walls, dense in the northern forest.
	for i in 90:
		_tree(Vector3(_rng.randf_range(-75, 150), 0, _rng.randf_range(-105, 45)))
	for i in 170:
		_tree(Vector3(_rng.randf_range(-38, 50), 0, _rng.randf_range(-105, -38)))
	for i in 240:  # grass tufts
		var gp := Vector3(_rng.randf_range(-70, 140), 0, _rng.randf_range(-100, 40))
		if absf(gp.x) < 8 and absf(gp.z) < 8:
			continue
		_spawn("nature/Grass_Common_Short" if _rng.randf() < 0.6 else "nature/Grass_Common_Tall", gp, _rng.randf() * 360.0)

	# Bandit camp props at the crossroads road.
	var camp: Vector3 = Layout.ORIGIN.estrada
	_spawn("village/Prop_Wagon", camp + Vector3(6, 0, 7), 25.0)
	_solid(camp + Vector3(6, 0, 7), Vector3(4.0, 1.5, 2.0), 25.0)
	_spawn("village/Prop_Crate", camp + Vector3(-3, 0, -6.5))
	_spawn("village/Prop_Crate", camp + Vector3(-1.8, 0, -6.8), 30.0)
	_solid(camp + Vector3(-2.4, 0, -6.6), Vector3(2.2, 1.1, 1.2))
	_spawn("props/Bench", Layout.spot("banco-estrada") + Vector3(0, 0, 0.6), 0.0)
	_spawn("village/Prop_Wagon", camp + Vector3(-5, 0, 5.5), 80.0)  # Lia's caravan: where newcomers arrive
	_solid(camp + Vector3(-5, 0, 5.5), Vector3(2.0, 1.5, 4.0), 80.0)
	_spawn("props/Barrel", camp + Vector3(-5.2, 0, 8.0))
	_spawn("village/Prop_Crate", camp + Vector3(-2.6, 0, 6.6), 15.0)

	Places.build(self)
	for poi in Places.pois():
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
	for id in Layout.ZONES:
		_region_zone(id, Layout.ZONES[id][0], Layout.ZONES[id][1])


## A straight strip of dirt road from a to b.
func _road(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var road := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.03, a.distance_to(b))
	road.mesh = bm
	road.material_override = mat
	road.position = (a + b) / 2.0 + Vector3(0, 0.015, 0)
	road.rotation.y = atan2(b.x - a.x, b.z - a.z)
	add_child(road)


## Palisade around the village: gates east and north, and a gap on the west side hidden by a bush.
func _palisade() -> void:
	var r := Layout.VILLAGE
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	# side, fixed coordinate, from, to, gaps as [from, to]
	var sides := [
		["h", z0, x0, x1, [[-3.0, 3.0]]],  # north, with the forest gate
		["h", z1, x0, x1, []],
		["v", x1, z0, z1, [[-3.0, 3.0]]],  # east, with the main gate
		["v", x0, z0, z1, [[-15.0, -13.0]]],  # west, with the hidden gap
	]
	for sd in sides:
		var cuts: Array = [sd[2]]
		for g in sd[4]:
			cuts.append(g[0])
			cuts.append(g[1])
		cuts.append(sd[3])
		for i in range(0, cuts.size(), 2):
			var from: float = cuts[i]
			var to: float = cuts[i + 1]
			var t := from + 1.0
			while t < to:
				var pos := Vector3(t, 0, sd[1]) if sd[0] == "h" else Vector3(sd[1], 0, t)
				_spawn("village/Prop_WoodenFence_Single", pos, 0.0 if sd[0] == "h" else 90.0)
				t += 2.0
			var len := to - from
			if len > 0.5:
				var mid := (from + to) / 2.0
				if sd[0] == "h":
					_solid(Vector3(mid, 0, sd[1]), Vector3(len, 1.4, 0.3))
				else:
					_solid(Vector3(sd[1], 0, mid), Vector3(0.3, 1.4, len))
	_spawn("nature/Bush_Common", Vector3(x0 + 0.3, 0, -14.0), 0.0, 1.5)  # covers the gap from outside


## The notice board by the tavern door: two posts and a plank with pinned sheets.
func _notice_board() -> void:
	var at := Layout.spot("taverna") + Vector3(3.4, 0, -0.2)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	for dx in [-0.8, 0.8]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.14, 2.0, 0.14)
		post.mesh = pm
		post.material_override = wood
		post.position = at + Vector3(dx, 1.0, 0)
		add_child(post)
	var plank := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 1.0, 0.1)
	plank.mesh = bm
	plank.material_override = wood
	plank.position = at + Vector3(0, 1.45, 0)
	add_child(plank)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.92, 0.88, 0.72)
	for i in 3:
		var sheet := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.38, 0.5, 0.02)
		sheet.mesh = sm
		sheet.material_override = paper
		sheet.position = at + Vector3(-0.6 + i * 0.6, 1.45, 0.07)
		sheet.rotation.z = (i - 1) * 0.08
		add_child(sheet)
	_solid(at, Vector3(1.9, 1.0, 0.3))


## The village bell on a post west of the plaza.
func _bell() -> void:
	var at := Vector3(-7, 0, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12
	pm.bottom_radius = 0.16
	pm.height = 2.8
	post.mesh = pm
	post.material_override = wood
	post.position = at + Vector3(0, 1.4, 0)
	add_child(post)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(1.0, 0.12, 0.12)
	arm.mesh = am
	arm.material_override = wood
	arm.position = at + Vector3(0.4, 2.7, 0)
	add_child(arm)
	var bell := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.38
	cm.height = 0.5
	bell.mesh = cm
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.2)
	brass.metallic = 0.6
	brass.roughness = 0.4
	bell.material_override = brass
	bell.position = at + Vector3(0.8, 2.35, 0)
	add_child(bell)
	_solid(at, Vector3(0.5, 2.8, 0.5))


## Props that make each spot read as what it is, plus the lanterns that come on at night.
func _village_details() -> void:
	_spawn("props/Anvil", Layout.spot("forja") + Vector3(2.6, 0, 0.4), 90.0)
	_spawn("props/Workbench", Layout.spot("forja") + Vector3(-3.2, 0, 0.2), 0.0)
	_spawn("props/Barrel", Layout.spot("taverna") + Vector3(-3.6, 0, 0.4))
	_spawn("props/Bench", Layout.spot("taverna") + Vector3(2.6, 0, 0.6), 0.0)
	_spawn("props/Table_Large", Layout.spot("taverna") + Vector3(5.2, 0, 1.4), 90.0)
	for i in 5:  # the garden: fenced rows
		_spawn("nature/Fern_1", Layout.spot("horta") + Vector3(-2 + i * 1.0, 0, -1.2), i * 30.0, 0.9)
		_spawn("nature/Flower_3_Group", Layout.spot("horta") + Vector3(-2 + i * 1.0, 0, 1.2), i * 50.0, 1.0)
	_notice_board()
	_bell()
	var pad := MeshInstance3D.new()  # the lookout: a low stone platform with a bench
	var bx := BoxMesh.new()
	bx.size = Vector3(5, 0.7, 4)
	pad.mesh = bx
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.52)
	pad.material_override = stone
	pad.position = Vector3(0, 0.35, -23.5)
	add_child(pad)
	_solid(Vector3(0, 0, -23.5), Vector3(5, 0.7, 4))
	_spawn("props/Bench", Vector3(0, 0, -21.4), 0.0)
	for lp in [Layout.spot("taverna") + Vector3(-1.8, 0, 0), Layout.spot("forja") + Vector3(-1.8, 0, 0), Layout.spot("capela") + Vector3(-1.8, 0, 0),
			Layout.spot("portao") + Vector3(0, 0, 3), Layout.spot("poco") + Vector3(-2.4, 0, 2.6)]:
		_spawn("props/Torch_Metal", lp, 0.0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.4)
		light.omni_range = 7.0
		light.light_energy = 0.0
		light.position = lp + Vector3(0, 2.0, 0)
		light.add_to_group("lantern")
		add_child(light)


func _tree(p: Vector3, kind := "") -> void:
	if Layout.tree_free(p):
		return
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


## A house of w x d modules (2 m each). The walls face outward, the door is in front (+z) and you can walk in.
func _house(center: Vector3, w: int, d: int, yaw: float, brick: bool, furnish := "") -> void:
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
	if w == 3 and d == 4:
		roof = "village/Roof_RoundTiles_6x8"
	elif w == 2 and d == 2:
		roof = "village/Roof_RoundTiles_4x4"
	_spawn(roof, Vector3(0, 3.0, 0), 0.0, 1.0, root)
	# Four walls, the front one split around the door (one module wide).
	var xd := float(-w + 1 + 2 * (w / 2))
	_wall_box(root, Vector3(0, 1.5, -d), Vector3(w * 2.0, 3.0, 0.4))
	_wall_box(root, Vector3(-w, 1.5, 0), Vector3(0.4, 3.0, d * 2.0))
	_wall_box(root, Vector3(w, 1.5, 0), Vector3(0.4, 3.0, d * 2.0))
	var left := (xd - 1.0) - (-w)
	if left > 0.1:
		_wall_box(root, Vector3((-w + xd - 1.0) / 2.0, 1.5, d), Vector3(left, 3.0, 0.4))
	var right := w - (xd + 1.0)
	if right > 0.1:
		_wall_box(root, Vector3((xd + 1.0 + w) / 2.0, 1.5, d), Vector3(right, 3.0, 0.4))
	_occluder(root, center + Vector3(0, 3.0, 0), maxf(w, d) * 2.0 + 2.5)
	_spawn("props/Barrel", Vector3(w - 0.6, 0, d + 1.0), 0.0, 1.0, root)
	_furnish(root, w, d, furnish)


func _wall_box(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	body.add_to_group("nav_source")
	root.add_child(body)


## What each room holds, in the house's own coordinates (the back wall is -z).
func _furnish(root: Node3D, w: int, d: int, kind: String) -> void:
	var back := float(-d + 1)
	match kind:
		"home":
			_spawn("props/Chest_Wood", Vector3(-w + 1.0, 0, back), 90.0, 1.0, root)
			_spawn("props/Bench", Vector3(w - 1.4, 0, back + 0.2), 0.0, 1.0, root)
		"tavern":
			_spawn("props/Table_Large", Vector3(-1.6, 0, 0.5), 0.0, 1.0, root)
			_spawn("props/Table_Large", Vector3(1.8, 0, -2.0), 90.0, 1.0, root)
			_spawn("props/Bench", Vector3(-1.6, 0, 2.0), 0.0, 1.0, root)
			_spawn("props/Barrel", Vector3(-w + 0.9, 0, back + 0.3), 0.0, 1.0, root)
			_spawn("props/Barrel", Vector3(-w + 0.9, 0, back + 1.4), 0.0, 1.0, root)
		"forge":
			_spawn("props/Workbench", Vector3(0, 0, back), 0.0, 1.0, root)
			_spawn("village/Prop_Crate", Vector3(w - 1.0, 0, back + 0.4), 20.0, 1.0, root)
			_spawn("village/Prop_Crate", Vector3(-w + 1.0, 0, back + 0.4), 0.0, 1.0, root)
		"chapel":
			for i in 3:
				_spawn("props/Bench", Vector3(0, 0, -d + 2.5 + i * 1.6), 0.0, 1.0, root)
		"barn":
			for i in 3:
				_spawn("village/Prop_Crate", Vector3(-w + 1.0 + i * 1.3, 0, back + 0.3), i * 25.0, 1.0, root)
			_spawn("props/Barrel", Vector3(w - 0.9, 0, back + 0.5), 0.0, 1.0, root)
		"guard":
			_spawn("props/Bench", Vector3(0, 0, back + 0.3), 0.0, 1.0, root)


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
			telemetry.note("region", {"place": id})
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
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.72, 0.4)
	torch_light.omni_range = 9.0
	torch_light.light_energy = 0.0
	torch_light.position = Vector3(0, 1.8, 0)
	torch_light.shadow_enabled = false
	player.add_child(torch_light)


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
		# First among transparent things: it reads the opaque scene and repaints it, and
		# labels, health bars, numbers and effects are drawn on top, untouched.
		mat.render_priority = -128
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
	_read_move_keys()
	if _lmb_held and not hud.actions_open():
		_attack_at_mouse()  # holding the button keeps the combo going
	var left: Array = []
	var now := Time.get_ticks_msec()
	for ab in ABILITIES:
		left.append(maxf((ready_at.get(ab.id, 0) - now) / 1000.0, 0.0))
	hud.set_cooldowns(left)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.4
		cam.v_offset = randf_range(-1, 1) * _shake * 0.4
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_lmb_held = false  # released anywhere, even over the interface


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_lmb_held = true
		_attack_at_mouse()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
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
				elif event.keycode <= KEY_4:
					use_ability(event.keycode - KEY_1)
			KEY_R:
				use_ability(4)
			KEY_K:
				hud.toggle_skills()
			KEY_C:
				hud.toggle_notebook()
			KEY_T:
				_light_torch()
			KEY_Z:
				_look_far()
			KEY_Y:
				_answer_quest(true)
			KEY_N:
				_answer_quest(false)
			KEY_J:
				hud.toggle_journal()
			KEY_ESCAPE:
				if hud.actions_open():
					hud.hide_actions()
				elif hud.skills_panel.visible:
					hud.toggle_skills()
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
		if n.has_meta("player") or not n.visible:
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
	for id in sign_nodes:
		var n: Node3D = sign_nodes[id]
		var d: float = Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
		if d < best_d:
			best_d = d
			best = {"sign": {"id": id, "title": n.get_meta("title")}}
	for ps in passages:
		var d: float = Vector2(ps.pos.x - player.global_position.x, ps.pos.z - player.global_position.z).length()
		if d < best_d:
			best_d = d
			best = {"passage": ps}
	return best


func use_nearest() -> void:
	var it := _nearest_interactable()
	if it.has("npc"):
		await open_npc_menu(it.npc)
	elif it.has("poi"):
		await open_poi_menu(it.poi)
	elif it.has("passage"):
		await _use_passage(it.passage)
	elif it.has("sign"):
		await _perform({"action": "examinar", "origin": "player", "args": {"sign": it.sign.id}, "title": it.sign.title})
	else:
		await open_place_menu()


func open_npc_menu(npc: Actor) -> void:
	await client.refresh_affordances()
	_show_menu(npc.get_meta("base_name", npc.label.text), client.affordances.filter(func(a): return a.get("with", "") == npc.entity_id))


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
	hud.show_actions(title, list.map(func(a): return _menu_label(a)))


func _menu_label(a: Dictionary) -> String:
	if a.action == "contar":  # "Contar a Mira: a agua do Poco Antigo esta envenenada"
		var b: Dictionary = {"p": a.args.get("p", ""), "s": a.args.get("s", ""), "o": a.args.get("o", "")}
		var text := Places.belief_label(b, _all_names)
		for mine in client.view.get("beliefs", []):
			if mine.p == b.p and mine.s == b.s and mine.get("o", "") == b.o and not mine.get("holds", true):
				text = "NAO e verdade que: " + text.to_lower()  # what you believe is that it does not hold
		return "%s: %s" % [a.title, text]
	return a.title


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
	player.play_once(Places.anim(a.action))
	var args: Dictionary = a.get("args", {})
	var res: Dictionary
	if a.origin == "adapter":
		res = await client.occur(a.action, args)
	else:
		res = await client.act(a.action, args)
	last_report = "%s:%s" % [a.action, "ok" if res.status == 200 else res.body.get("error", "sem resposta")]
	telemetry.verb(a.action, res.status == 200)
	if res.status == 200:
		var lines: Array = []
		for ev in res.body.get("events", []):
			if ev.get("text", "") != "":
				lines.append(ev.text)
		if a.action == "examinar" and lines.size() > 0:
			player.say(lines[0], 7.0)
		if a.action == "conversar" and npc_nodes.has(target) and lines.size() > 0:
			npc_nodes[target].say(lines[0], 8.0)  # what they say to you, above their head
		_log("[color=#9fdc7a]%s[/color]: %s" % [a.title, " / ".join(lines) if lines.size() > 0 else "feito"])
	else:
		var why: String = res.body.get("error", "")
		_log("[color=#e8806a]%s[/color]: %s" % [a.title, "agora nao da (o mundo nao permite)" if why.contains("requirements") else why])
	client.refresh()


## Talk to an NPC directly (tests and the first meeting).
func _talk(npc: Actor) -> void:
	await _perform({"action": "conversar", "origin": "player", "args": {"npc": npc.entity_id}, "with": npc.entity_id, "title": "Conversar com %s" % npc.get_meta("base_name", npc.label.text)})


# --- movement, aiming and abilities -------------------------------------------

## WASD relative to the fixed camera: W goes up the screen.
func _read_move_keys() -> void:
	var v := Vector2.ZERO
	if not hud.journal_panel.visible and not hud.skills_panel.visible:
		v.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		v.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var b := cam_rig.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var down := Vector3(b.z.x, 0, b.z.z).normalized()
	_move_dir = (right * v.x + down * v.y).normalized() if v != Vector2.ZERO else Vector3.ZERO
	if _move_dir != Vector3.ZERO and hud.actions_open():
		hud.hide_actions()
	player.input_dir = Vector3.ZERO if player_down else _move_dir


## The point on the ground under the mouse.
func _mouse_ground() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return player.global_position
	return from + dir * (-from.y / dir.y)


func _aim_dir() -> Vector3:
	var to := _mouse_ground() - player.global_position
	to.y = 0
	return to.normalized() if to.length() > 0.1 else Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))


func _attack_at_mouse() -> void:
	if player.busy or player_down:
		return
	var d := _aim_dir()
	player.model.rotation.y = atan2(d.x, d.z)
	attack(true)


func use_ability(i: int) -> void:
	if i < 0 or i >= ABILITIES.size() or player_down:
		return
	var ab: Dictionary = ABILITIES[i]
	var now := Time.get_ticks_msec()
	if now < ready_at.get(ab.id, 0):
		return
	if player.busy and not ab.id in ["esquiva", "cura"]:  # dodging and healing cut through a swing
		return
	ready_at[ab.id] = now + int(ab.cd * 1000.0)
	match ab.id:
		"giro":
			_ability_spin()
		"investida":
			_ability_dash()
		"lamina":
			_ability_blade()
		"cura":
			_ability_heal()
		"esquiva":
			roll()


func _hit_around(center: Vector3, radius: float, dmg: float, color: Color) -> bool:
	var any := false
	for e in enemies:
		if is_instance_valid(e) and e.state != Enemy.State.DEAD and Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length() < radius:
			e.take_hit(dmg, center)
			_burst(e.global_position + Vector3(0, 1.1, 0), color)
			any = true
	return any


func _ability_spin() -> void:
	player.interrupt()
	player.play_once("Sword_Regular_C", 1.5)
	var tw := create_tween()
	tw.tween_property(player.model, "rotation:y", player.model.rotation.y + TAU, 0.45)
	await get_tree().create_timer(0.22).timeout
	_vfx_ring(player.global_position, Color(1.0, 0.78, 0.3), 3.6, 0.45)
	_burst(player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.35), 40)
	if _hit_around(player.global_position, 3.3, 30.0, Color(1.0, 0.8, 0.35)):
		_hitstop(0.08)
	_shake = 0.9


func _ability_dash() -> void:
	var d := _aim_dir()
	player.interrupt()
	player.model.rotation.y = atan2(d.x, d.z)
	player.play_once("Sword_Dash", 1.2)
	player.dash(d, 0.32, 20.0)
	invuln_until = Time.get_ticks_msec() + 350
	var trail := _vfx_trail(Color(0.5, 0.8, 1.0))
	var hit := {}
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 380:
		for e in enemies:
			if is_instance_valid(e) and e.state != Enemy.State.DEAD and not hit.has(e) and e.global_position.distance_to(player.global_position) < 1.8:
				hit[e] = true
				e.take_hit(25.0, player.global_position)
				_burst(e.global_position + Vector3(0, 1.1, 0), Color(0.55, 0.85, 1.0))
		await get_tree().process_frame
	trail.emitting = false
	get_tree().create_timer(0.8).timeout.connect(trail.queue_free)
	if not hit.is_empty():
		_hitstop()
		_shake = 0.6


func _ability_blade() -> void:
	var d := _aim_dir()
	player.interrupt()
	player.model.rotation.y = atan2(d.x, d.z)
	player.play_once("Spell_Simple_Shoot", 1.3)
	await get_tree().create_timer(0.22).timeout
	var bolt := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.8, 1.6, 0.18)
	bolt.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.65, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.4, 1.0)
	mat.emission_energy_multiplier = 4.0
	bolt.material_override = mat
	add_child(bolt)
	bolt.global_position = player.global_position + Vector3(0, 1.1, 0) + d * 0.8
	bolt.look_at(bolt.global_position + d, Vector3.UP)
	bolt.rotate_object_local(Vector3.RIGHT, -PI / 2.0)  # the prism's tip points forward
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.5, 1.0)
	light.omni_range = 4.0
	bolt.add_child(light)
	var trail := _vfx_trail(Color(0.75, 0.5, 1.0), bolt)
	var travelled := 0.0
	while travelled < 18.0 and is_instance_valid(bolt):
		var step := 24.0 * get_process_delta_time()
		bolt.global_position += d * step
		travelled += step
		var target: Enemy = null
		for e in enemies:
			if is_instance_valid(e) and e.state != Enemy.State.DEAD and Vector2(e.global_position.x - bolt.global_position.x, e.global_position.z - bolt.global_position.z).length() < 1.0:
				target = e
				break
		if target:
			target.take_hit(35.0, bolt.global_position - d)
			_burst(bolt.global_position, Color(0.8, 0.55, 1.0), 36)
			_vfx_ring(bolt.global_position - Vector3(0, 1.0, 0), Color(0.78, 0.52, 1.0), 1.8, 0.3)
			_hitstop()
			break
		await get_tree().process_frame
	trail.emitting = false
	trail.reparent(self)
	get_tree().create_timer(0.8).timeout.connect(trail.queue_free)
	bolt.queue_free()


func _ability_heal() -> void:
	player.interrupt()
	player.play_once("Consume", 1.2)
	var gain := minf(30.0, player_max - player_hp)
	player_hp += gain
	_set_hp()
	_float_text(player.global_position + Vector3(0, 2.3, 0), "+%d" % int(gain), Color(0.5, 1.0, 0.55))
	_vfx_ring(player.global_position, Color(0.45, 1.0, 0.55), 2.2, 0.6)
	var p := _particles(player.global_position + Vector3(0, 0.3, 0), Color(0.45, 1.0, 0.55), 40, false)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 2.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.lifetime = 1.0


## A flat ring that widens and fades.
func _vfx_ring(pos: Vector3, color: Color, radius: float, time: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 1.0
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # glows over the ground instead of greying it
	mat.no_depth_test = true
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.2, 0)
	mi.scale = Vector3(0.3, 0.3, 0.3)
	add_child(mi)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.6, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Sparks left behind something that moves (the player by default).
func _vfx_trail(color: Color, follow: Node3D = null) -> CPUParticles3D:
	var p := _particles(Vector3.ZERO, color, 60, false)
	p.one_shot = false
	p.explosiveness = 0.0
	p.lifetime = 0.5
	p.local_coords = false
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3.ZERO
	p.reparent(follow if follow else player, false)
	p.position = Vector3(0, 1.0, 0) if follow == null else Vector3.ZERO
	return p


func _particles(pos: Vector3, color: Color, amount: int, burst := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	sm.material = mat
	p.mesh = sm
	p.position = pos
	add_child(p)
	if burst:
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	return p


func attack(aimed := false) -> void:
	if player.busy or player_down:
		return
	var now := Time.get_ticks_msec()
	if now - last_attack_ms > 1400:
		combo = 0
	var step: Dictionary = COMBO[combo % COMBO.size()]
	combo += 1
	last_attack_ms = now
	var near := _nearest_enemy(3.5)
	if near:  # aim assist: toward the closest enemy, unless the mouse points clearly elsewhere
		var to := near.global_position - player.global_position
		to.y = 0
		var fwd := Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))
		if not aimed or fwd.dot(to.normalized()) > 0.5:
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
	var d := _move_dir if _move_dir != Vector3.ZERO else Vector3(sin(yaw), 0, cos(yaw))
	player.model.rotation.y = atan2(d.x, d.z)
	invuln_until = Time.get_ticks_msec() + 550
	player.dash(d, 0.45)
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
	var tk: Dictionary = THREATS.get(e.camp, {})
	if tk.is_empty():
		return  # not a camp the engine hears about (training, tests)
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


func _burst(pos: Vector3, color := Color(1.0, 0.85, 0.4), amount := 28) -> void:
	_particles(pos, color, amount)


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

func _seen_path() -> String:
	return "user://seen-%s.json" % client.player_id


func _load_seen() -> void:
	if FileAccess.file_exists(_seen_path()):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_seen_path()))
		if d is Dictionary:
			_seen.merge(d, true)


func _save_seen() -> void:
	var f := FileAccess.open(_seen_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_seen))


## Events worth telling someone back from a trip (talk, board and movement stay out).
func _recap_lines(v: Dictionary) -> Array:
	var skip := ["chatter", "join", "moved", "talked", "board", "bell", "rest", "dream"]
	var out: Array = []
	for e in v.get("events", []):
		if int(e.seq) > int(_seen.seq) and e.get("text", "") != "" and not skip.has(e.kind):
			out.append(e.text)
	return out.slice(maxi(0, out.size() - 6))


func _on_view(v: Dictionary) -> void:
	var me: Dictionary = v.get("self", {})
	if not _synced:  # start where the engine says the character is
		_synced = true
		client.view_limit = 12
		var away := _recap_lines(v)
		if int(_seen.seq) > 0 and not away.is_empty() and (not _args.has("autotest") or _args.has("recap")):
			hud.recap(away)
		if not _seen.opening and (not _args.has("autotest") or _args.has("opening")):
			_seen.opening = true
			hud.card(["Valdoria", "Ninguem sabe o seu nome."], 1.4, 1.0, 44)
		region = me.get("region", "vila")
		player.global_position = REGION_ORIGIN.get(region, Vector3.ZERO) + Vector3(0, 0, 3)
		cam_rig.global_position = player.global_position
	var names := NPC_NAMES.duplicate()
	for o in v.get("others", []):
		names[o.id] = o.name
	_sync_discovered(v)
	_all_names = {}
	for o in v.get("others", []):
		_all_names[o.id] = o.name
	_sync_signs(v)
	_remember_people(v)
	_sync_torch(v)
	hud.set_notebook(_notebook_data(v))
	hud.set_status(REGION_NAMES.get(me.get("region", ""), me.get("region", "?")), int(v.get("hour", -1)), int(v.get("tick", 0)))
	hud.set_quests(v.get("quests", []), int(v.get("tick", 0)), names, REGION_NAMES)
	hud.set_skills(v.get("skills", []))
	var givers := {}
	for q in v.get("quests", []):
		if q.state == "offered" and q.get("giver", "") != "":
			givers[q.giver] = true
	_sync_npcs(v)
	_sun(int(v.get("hour", -1)))
	var said := 0
	var newest := int(_seen.seq)
	for e in v.get("events", []):
		newest = maxi(newest, int(e.seq))
		if int(e.seq) > last_seq:
			last_seq = int(e.seq)
			if e.kind == "chatter":
				_hear(e, said * 3.0)
				said += 1
				continue
			for r in THREATS:
				if e.kind == THREATS[r].get("event", "!"):
					threat_on[r] = true
					camp_done[r] = false
				elif e.kind == THREATS[r].get("end", "!") and not threat_forced.has(r):
					threat_on[r] = false
			if e.get("text", "") != "":
				_log("[color=#c9b3ff]%s[/color]" % e.text)
	if newest != int(_seen.seq) and Time.get_ticks_msec() - _seen_saved_ms > 4000:
		_seen.seq = newest
		_seen_saved_ms = Time.get_ticks_msec()
		_save_seen()
	_conditional_threats(v)
	_sync_enemies()
	for id in npc_nodes:
		npc_nodes[id].set_marker("!" if givers.has(id) else "")


## The map starts blank: only places the engine says this character found.
func _sync_discovered(v: Dictionary) -> void:
	for f in v.get("facts", []):
		if f.p == DISCOVERED and f.s == client.player_id and not found_places.has(f.o):
			found_places[f.o] = true
			telemetry.note("discovered", {"place": f.o})
			if _found_seeded:
				hud.toast("Lugar descoberto: %s" % REGION_NAMES.get(f.o, f.o), Color(0.7, 0.9, 1.0))
	_found_seeded = true
	hud.set_known(found_places.keys())


## Someone who knows you says hello when you walk up to them (once per approach).
func _greet_nearby() -> void:
	var now := Time.get_ticks_msec()
	for n in npc_nodes.values():
		if n.has_meta("player") or not n.get_meta("knows", false) or not n.visible:
			continue
		var d: float = n.global_position.distance_to(player.global_position)
		if d > 7.0:
			n.set_meta("greeted_ms", 0)  # walked away: they will greet you again next time
		elif d < 4.0 and int(n.get_meta("greeted_ms", 0)) == 0 and now - _last_greet_ms > 2500:
			var line := Places.greeting(n.entity_id, int(now / 1000) + hash(n.entity_id))
			n.set_meta("greeted_ms", now)
			if line != "":
				_last_greet_ms = now
				greet_count += 1
				n.say(line, 4.5)
				n.model.rotation.y = atan2(player.global_position.x - n.global_position.x, player.global_position.z - n.global_position.z)
				telemetry.note("greeted", {"who": n.entity_id})


## Markers for the traces the engine says this observer can make out here (it never says what they mean).
func _sync_signs(v: Dictionary) -> void:
	var now := {}
	far_marks.clear()
	for sg in v.get("signs", []):
		if sg.get("far", false):
			var spot: String = sg.get("spot", "")
			var purple: bool = ["selo-brilha", "fumaca-roxa"].has(sg.id)
			far_marks[sg.id] = {"pos": Layout.spot(spot, Layout.ORIGIN.get(sg.region, Vector3.ZERO)), "look": sg.look, "region": sg.region,
				"color": Color(0.75, 0.5, 1.0) if purple else (Color(0.85, 0.85, 0.9) if sg.id == "fumaca-kharum" else Color(0.95, 0.85, 0.6))}
		else:
			now[sg.id] = sg
	if Places.smoke_mat:  # the forge smoke turns purple when the ore is cursed
		var cursed := false
		for sg in v.get("signs", []):
			cursed = cursed or sg.id == "fumaca-roxa"
		Places.smoke_mat.albedo_color = Color(0.62, 0.36, 0.85, 0.6) if cursed else Color(0.45, 0.45, 0.48, 0.55)
	for id in sign_nodes.keys():
		if not now.has(id):
			sign_nodes[id].queue_free()
			sign_nodes.erase(id)
	for id in now:
		if sign_nodes.has(id):
			continue
		var sg: Dictionary = now[id]
		var n := Node3D.new()
		var spot: String = sg.get("spot", "")
		var ang := float(hash(id) % 360) * PI / 180.0
		n.position = Layout.spot(spot, Layout.ORIGIN.get(sg.region, Vector3.ZERO)) + Vector3(cos(ang), 0, sin(ang)) * 1.3
		n.set_meta("title", sg.title)
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		orb.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.95, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.0
		orb.material_override = mat
		orb.position.y = 0.9
		n.add_child(orb)
		var tw := orb.create_tween().set_loops()
		tw.tween_property(orb, "position:y", 1.15, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(orb, "position:y", 0.9, 0.9).set_trans(Tween.TRANS_SINE)
		var l := Label3D.new()
		l.text = sg.look
		l.position.y = 1.7
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.006
		l.font_size = 30
		l.outline_size = 8
		l.width = 420.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(0.75, 0.95, 1.0, 0.9)
		l.visible = false
		l.name = "Look"
		n.add_child(l)
		add_child(n)
		sign_nodes[id] = n
		telemetry.note("sign_seen", {"sign": id})


func _sync_torch(v: Dictionary) -> void:
	var lit := false
	var tunnel := false
	for f in v.get("facts", []):
		lit = lit or f.p == "torch-lit"
		tunnel = tunnel or f.p == "tunnel-known"
	if lit != torch_on:
		torch_on = lit
		hud.toast("A tocha crepita." if lit else "A tocha se apagou.", Color(1.0, 0.8, 0.5))
		telemetry.note("torch", {"lit": lit})
	if tunnel and passages.is_empty():
		_make_passage(Layout.PASSAGE_GALLERY, Layout.PASSAGE_RUINS + Vector3(-2, 0, -1), "ruinas", "Passagem antiga: subir para as ruinas")
		_make_passage(Layout.PASSAGE_RUINS, Layout.PASSAGE_GALLERY + Vector3(0, 0, 3), "mina", "Passagem antiga: descer para a mina")


func _light_torch() -> void:
	if torch_on:
		hud.toast("A tocha ja esta acesa.", Color(1, 1, 1, 0.8))
		return
	var res := await client.occur("acender-tocha")
	telemetry.verb("acender-tocha", res.status == 200)
	client.refresh()


func _make_passage(pos: Vector3, dest: Vector3, dest_region: String, label: String) -> void:
	var n := Node3D.new()
	n.position = pos
	var arch := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.25
	arch.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.5, 1.0)
	mat.emission_energy_multiplier = 1.8
	arch.material_override = mat
	arch.rotation_degrees = Vector3(90, 0, 0)
	arch.position.y = 1.3
	n.add_child(arch)
	var l := Label3D.new()
	l.text = label
	l.position.y = 2.9
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.font_size = 30
	l.outline_size = 8
	l.modulate = Color(0.75, 0.85, 1.0, 0.95)
	n.add_child(l)
	add_child(n)
	passages.append({"node": n, "pos": pos, "dest": dest, "region": dest_region, "label": label})


func _use_passage(ps: Dictionary) -> void:
	hud.card([], 0.2, 1.0)
	await get_tree().create_timer(0.5).timeout
	player.has_goal = false
	player.global_position = ps.dest
	cam_rig.global_position = ps.dest
	region = ps.region
	await client.move_region(ps.region)
	client.refresh()
	_sync_enemies()
	telemetry.note("passage", {"to": ps.region})
	hud.toast("Voce atravessa a passagem antiga.", Color(0.7, 0.8, 1.0))


## From the village lookout the camera pulls back and the landmarks you can see are named.
func _look_far() -> void:
	if Vector2(player.global_position.x - Layout.LOOKOUT.x, player.global_position.z - Layout.LOOKOUT.z).length() > 5.5:
		hud.toast("Suba ao mirante, ao norte da vila, para olhar longe.", Color(1, 1, 1, 0.8))
		return
	var seen: Array = []
	for id in far_marks:
		seen.append(far_marks[id].look)
	hud.toast("Daqui voce ve: " + (", ".join(seen) if not seen.is_empty() else "nada de especial"), Color(0.8, 0.92, 1.0))
	telemetry.note("look_far", {"seen": far_marks.keys()})
	_look_far_until = Time.get_ticks_msec() + 5000
	var tw := create_tween()
	tw.tween_property(cam, "size", 46.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(4.0)
	tw.tween_property(cam, "size", 14.0, 0.9).set_trans(Tween.TRANS_SINE)


## Dim the world inside the gallery; a lit torch is the only light there.
func _update_gallery() -> void:
	var inside := Layout.GALLERY.has_point(Vector2(player.global_position.x, player.global_position.z))
	if inside != gallery_dark:
		gallery_dark = inside
		if not inside:
			_sun(int(client.view.get("hour", 12)))
	if gallery_dark:
		sun.light_energy = 0.0
		env.ambient_light_energy = 0.03
		env.background_color = Color(0, 0, 0)
	torch_light.light_energy = (1.7 + randf() * 0.5) if torch_on else 0.0


func _update_landmarks() -> void:
	_tracking = Input.is_physical_key_pressed(KEY_SHIFT) and not player.has_goal and player.input_dir == Vector3.ZERO
	var items: Array = []
	for id in far_marks:
		var m: Dictionary = far_marks[id]
		if found_places.has(m.region):
			continue  # already been there: no longer a mystery on the horizon
		var at: Vector3 = m.pos + Vector3(0, 3, 0)
		if cam.is_position_behind(at):
			continue
		items.append({"pos": cam.unproject_position(at), "label": m.look, "color": m.color})
	if _tracking:  # standing still and looking: nearby traces are pointed out too
		for id in sign_nodes:
			var n: Node3D = sign_nodes[id]
			items.append({"pos": cam.unproject_position(n.global_position + Vector3(0, 1, 0)), "label": "rastro: " + String(n.get_meta("title")), "color": Color(0.6, 0.95, 1.0)})
	hud.set_landmarks(items)


func _remember_people(v: Dictionary) -> void:
	var me_region: String = v.get("self", {}).get("region", "")
	for o in v.get("others", []):
		if o.kind == "npc" and o.get("region", "") == me_region and not _seen.people.has(o.id):
			_seen.people[o.id] = {"name": o.name}
			_save_seen()


## What the notebook shows, built only from what the engine says this character believes, found or lived.
func _notebook_data(v: Dictionary) -> Dictionary:
	var names := _all_names.duplicate()
	var me: String = v.get("self", {}).get("id", "")
	var clues: Array = []
	var held := {}
	for b in v.get("beliefs", []):
		if b.get("p", "") == "met":
			continue  # who knows whom is shown under People
		var src: String = Places.text.get("source_text", {}).get(b.get("source", ""), b.get("source", "")).replace("{from}", names.get(b.get("from", ""), b.get("from", "?")))
		var label := Places.belief_label(b, names)
		clues.append({"text": ("Acredito que NAO: " if not b.get("holds", true) else "") + label, "source": src})
		held["belief:" + String(b.p)] = true
	for f in v.get("facts", []):
		var t: String = Places.text.get("clue_text", {}).get(f.p, "")
		if t != "" and f.s == me:
			clues.append({"text": t, "source": "um indicio que so voce reparou"})
			held["fact:" + String(f.p)] = true
	var qs: Array = []
	for q in Places.text.get("questions", []):
		var ok := true
		for n in q.needs:
			ok = ok and held.has(n)
		if ok:
			qs.append(q.text)
	var people: Array = []
	var here := {}
	for o in v.get("others", []):
		here[o.id] = o
	for id in _seen.people:
		var o: Dictionary = here.get(id, {})
		var where := "visto pela ultima vez em %s" % REGION_NAMES.get(o.get("region", ""), "?")
		if o.get("region", "") == v.get("self", {}).get("region", "") and o.get("doing", "") != "":
			where = "aqui agora: %s" % o.doing
		people.append({"name": _seen.people[id].name, "know": o.get("knowsYou", false), "where": where})
	var places: Array = []
	for r in found_places:
		places.append(REGION_NAMES.get(r, r))
	return {"pistas": clues, "perguntas": qs, "pessoas": people, "lugares": places}


func _update_signs_labels() -> void:
	_update_gallery()
	_update_landmarks()
	for n in sign_nodes.values():
		var near: bool = Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length() < (30.0 if _tracking else 8.0)
		(n.get_node("Look") as Label3D).visible = near


func _update_poi_labels() -> void:
	_update_signs_labels()
	_greet_nearby()
	for n in npc_nodes.values():
		if n.has_meta("base_name"):
			var doing: String = n.get_meta("doing", "")
			var close: bool = n.global_position.distance_to(player.global_position) < 9.0
			var knows: bool = n.get_meta("knows", false)
			var text: String = n.get_meta("base_name") + ("\n(%s)" % doing if doing != "" and close else "")
			if knows and close:
				text += "\n[te conhece]"
			n.label.text = text
			if not n.has_meta("player"):
				n.label.modulate = Color(1.0, 0.9, 0.55) if knows else Color(1, 1, 1)  # gold: someone who knows you
	for poi in pois:
		var near: bool = found_places.has(poi.region) and Vector2(poi.at.x - player.global_position.x, poi.at.z - player.global_position.z).length() < LABEL_RANGE
		poi.node.visible = near


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
		var o: Dictionary = here[id]
		var target := _npc_target(o, i)
		if npc_nodes.has(id):
			var n: Actor = npc_nodes[id]
			n.set_meta("doing", o.get("doing", ""))
			n.set_meta("knows", bool(o.get("knowsYou", false)))
			if o.kind == "npc" and target.distance_to(n.get_meta("target", target)) > 0.6:
				n.set_meta("target", target)
				n.set_meta("spot", o.get("spot", ""))
				n.idle_clip = "Sitting_Idle" if o.get("doing", "") == "dormindo" else ("Idle_Talking" if id == "tomas" else "Idle")
				n.walk_to(target, false)  # the day moves people: they walk to the next place
			continue
		i += 1
		var is_player: bool = o.kind == "player"
		var spec: Dictionary = NPCS.get(id, {})
		var npc := Actor.new()
		add_child(npc)
		npc.setup(id, o.name.split(",")[0], spec.get("female", false), id == "orin" or id == "sora", "Ranger" if id == "orin" or id == "sora" or id == "kael" else "Peasant")
		npc.idle_clip = "Idle_Talking" if id == "tomas" else "Idle"
		npc.set_meta("base_name", o.name.split(",")[0])
		npc.set_meta("spot", o.get("spot", ""))
		npc.set_meta("target", target)
		npc.set_meta("doing", o.get("doing", ""))
		npc.set_meta("knows", bool(o.get("knowsYou", false)))
		if is_player:
			npc.set_meta("player", true)
			npc.label.modulate = Color(0.6, 0.82, 1.0)
		npc.idle_clip = "Sitting_Idle" if o.get("doing", "") == "dormindo" else npc.idle_clip
		npc.play(npc.idle_clip)
		npc.position = target
		npc.model.rotation.y = atan2(-target.x, -target.z)
		npc_nodes[id] = npc


## Where an NPC or another player stands: its spot if the engine names one, else a fixed place in the region.
func _npc_target(o: Dictionary, i: int) -> Vector3:
	var id: String = o.id
	var ang := float(hash(id) % 360) * PI / 180.0
	var spot: String = o.get("spot", "")
	if o.kind == "player":  # the engine knows regions, not coordinates: a stable spot from the id
		return Layout.ORIGIN.get(region, Vector3.ZERO) + Vector3(cos(ang), 0, sin(ang)) * 11.0
	if o.get("doing", "") == "dormindo" and Layout.INSIDE.has(spot):
		return Layout.INSIDE[spot]
	if spot != "" and Layout.SPOTS.has(spot):
		return Layout.spot(spot) + Vector3(cos(ang), 0, sin(ang)) * 1.1
	var at: Vector2 = NPC_FALLBACK.get(id, Vector2(-12 + (i % 5) * 6, 11))
	return Layout.ORIGIN.get(region, Vector3.ZERO) + Vector3(at.x, 0, at.y)


## Overheard talk: balloons above the speakers, when you are near enough to hear.
func _hear(e: Dictionary, delay: float) -> void:
	if e.get("data", {}).get("region", "") != region or not npc_nodes.has(e.actor):
		return
	var speaker: Actor = npc_nodes[e.actor]
	if speaker.global_position.distance_to(player.global_position) > CHATTER_RANGE:
		return
	telemetry.note("heard", {"chatter": e.data.get("chatter", ""), "who": e.actor})
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(speaker):
		speaker.say(e.text, 6.0)


func _sun(hour: int) -> void:
	if hour < 0 or gallery_dark:
		return
	var day := clampf(sin((hour - 6) / 12.0 * PI), 0.0, 1.0)
	sun.light_energy = lerpf(0.2, 1.3, day)
	env.background_color = Color(0.12, 0.15, 0.28).lerp(Color(0.55, 0.72, 0.9), day)
	env.ambient_light_energy = lerpf(0.3, 0.65, day)
	env.ambient_light_color = Color(0.45, 0.55, 0.9).lerp(Color(0.75, 0.8, 0.95), day)
	for l in get_tree().get_nodes_in_group("lantern"):
		(l as OmniLight3D).light_energy = lerpf(1.6, 0.0, clampf(day * 3.0, 0.0, 1.0))


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = Hud.new()
	hud.region_names = REGION_NAMES
	add_child(hud)
	hud.accept_pressed.connect(func(k: String) -> void: _answer_quest_key(k, true))
	hud.decline_pressed.connect(func(k: String) -> void: _answer_quest_key(k, false))
	hud.abandon_pressed.connect(_abandon_quest)
	hud.action_chosen.connect(_on_action_chosen)
	hud.ability_pressed.connect(use_ability)
	hud.build_hotbar(ABILITIES)
	hud.set_hp(player_hp, player_max)


func _update_hud_world() -> void:
	_update_poi_labels()
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
			text = "[E] Falar com %s" % it.npc.get_meta("base_name", it.npc.label.text)
		elif it.has("poi"):
			text = "[E] %s" % it.poi.label
		elif it.has("sign"):
			text = "[E] %s" % it.sign.title
		elif it.has("passage"):
			text = "[E] %s" % it.passage.label
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


## A newcomer's first minutes: arrival at the caravan, silence from the system, greetings by acquaintance.
func _autotest_arrival() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(2.5).timeout
	var ok := {"arrived_in": client.view.get("self", {}).get("region", "?"), "map": found_places.keys()}
	await _shot("a1_opening")
	await get_tree().create_timer(float(_args.get("idle", 20))).timeout
	ok["offers_while_idle"] = client.view.get("quests", []).filter(func(q): return q.state == "offered").size()
	ok["lia_here"] = npc_nodes.has("lia")
	ok["know_me_at_start"] = npc_nodes.keys().filter(func(k): return npc_nodes[k].get_meta("knows", false))
	if npc_nodes.has("lia"):
		await _go(npc_nodes["lia"].global_position + Vector3(0, 0, 1.6), 20.0)
		await _perform({"action": "conversar", "origin": "player", "args": {"npc": "lia"}, "with": "lia", "title": "Conversar com Lia"})
		await get_tree().create_timer(0.6).timeout
		await _shot("a2_lia")
		ok["lia_first"] = last_report
	await _go(Vector3(31, 0, 3), 40.0)  # the east gate
	await get_tree().create_timer(2.5).timeout
	ok["at_gate"] = {"region": client.view.get("self", {}).get("region", "?"), "npcs": npc_nodes.keys()}
	if npc_nodes.has("orin"):
		await _go(npc_nodes["orin"].global_position + Vector3(0, 0, 1.6), 20.0)
		await _perform({"action": "conversar", "origin": "player", "args": {"npc": "orin"}, "with": "orin", "title": "Conversar com Orin"})
		await get_tree().create_timer(0.8).timeout
		await _shot("a3_orin")
		var ev := ""
		for e in client.view.get("events", []):
			if e.kind == "talked":
				ev = e.text
		ok["orin_first"] = ev
	if client.view.get("quests", []).filter(func(q): return q.state == "offered").is_empty():
		var board := _poi("quadro")  # one more deed, so the system has something to answer
		await _go(board.at + Vector3(0, 0, 1.6), 40.0)
		await _perform({"action": "ler-quadro", "origin": "player", "title": "Ler o quadro de avisos"})
	var w := 0.0
	while w < 40.0 and client.view.get("quests", []).filter(func(q): return q.state == "offered").is_empty():
		await get_tree().create_timer(1.0).timeout
		w += 1.0
	ok["offer_after_deed_s"] = w
	ok["offers_after_deed"] = client.view.get("quests", []).filter(func(q): return q.state == "offered").size()
	await get_tree().create_timer(3.4).timeout
	await _shot("a4_ceremony")
	if npc_nodes.has("orin"):  # walk away, come back: someone who knows you says hello
		var before := greet_count
		await _go(Vector3(14, 0, 4), 30.0)
		await get_tree().create_timer(1.0).timeout
		await _go(npc_nodes["orin"].global_position + Vector3(0, 0, 3.0), 30.0)
		await get_tree().create_timer(1.0).timeout
		ok["greetings_on_return"] = greet_count - before
		await _shot("a5_hello")
	ok["know_me_at_end"] = npc_nodes.keys().filter(func(k): return npc_nodes[k].get_meta("knows", false) and not npc_nodes[k].has_meta("player"))
	ok["telemetry"] = telemetry.summary()
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


func _wait_sign(id: String, secs: float) -> bool:
	var w := 0.0
	while w < secs and not sign_nodes.has(id):
		await get_tree().create_timer(0.5).timeout
		w += 0.5
	return sign_nodes.has(id)


func _examine_nearest(only := "") -> String:
	var best := ""
	var best_d := 6.0
	for id in sign_nodes:
		if only != "" and id != only:
			continue
		var d: float = sign_nodes[id].global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = id
	if best == "":
		return "sem vestigio perto"
	await _perform({"action": "examinar", "origin": "player", "args": {"sign": best}, "title": sign_nodes[best].get_meta("title")})
	await get_tree().create_timer(0.5).timeout
	return last_report


## F4: landmarks on the horizon, the lookout, the dark mine with a torch, the old passage, the runes of Asterion.
func _autotest_fora() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {}
	await _go(Vector3(31, 0, 3), 40.0)
	await get_tree().create_timer(1.0).timeout
	ok["landmarks_from_village"] = far_marks.keys()
	ok["arrows_on_screen_edge"] = hud.landmarks.items.size()
	await _shot("f4_1_vila")
	# the lookout
	await _go(Layout.LOOKOUT + Vector3(0, 0, 1.5), 60.0)
	_look_far()
	await get_tree().create_timer(1.6).timeout
	ok["cam_size_at_lookout"] = snappedf(cam.size, 1.0)
	await _shot("f4_2_mirante")
	await get_tree().create_timer(5.0).timeout
	# the mine: light a torch, go into the gallery, feel the draught
	await _go(Vector3(88, 0, -61), 120.0)
	await _light_torch()
	await get_tree().create_timer(1.0).timeout
	ok["torch_lit"] = torch_on
	await _go(Layout.spot("galeria"), 30.0)
	ok["gallery_dark"] = gallery_dark
	ok["draught_seen"] = await _wait_sign("corrente-de-ar", 8.0)
	await _shot("f4_3_galeria")
	if sign_nodes.has("corrente-de-ar"):
		ok["draught"] = await _examine_nearest("corrente-de-ar")
	await get_tree().create_timer(1.0).timeout
	ok["passages"] = passages.size()
	if passages.size() > 0:
		await _go(Layout.PASSAGE_GALLERY + Vector3(0, 0, 1.5), 20.0)
		await use_nearest()
		await get_tree().create_timer(1.5).timeout
		ok["after_passage_region"] = client.view.get("self", {}).get("region", "?")
		ok["after_passage_near_ruins"] = player.global_position.distance_to(Layout.PASSAGE_RUINS) < 6.0
		await _shot("f4_4_ruinas")
	# the runes, bit by bit
	await _go(Layout.spot("entrada-ruinas") + Vector3(1.0, 0, 1.0), 30.0)
	ok["entrada"] = await _examine_nearest("inscricao-entrada")
	ok["salao_hidden_before"] = not sign_nodes.has("inscricao-salao") or true
	await _go(Layout.spot("salao-ruinas") + Vector3(1.0, 0, 1.0), 30.0)
	ok["salao_seen"] = await _wait_sign("inscricao-salao", 6.0)
	if sign_nodes.has("inscricao-salao"):
		ok["salao"] = await _examine_nearest("inscricao-salao")
	await get_tree().create_timer(1.0).timeout
	ok["arrows_after_visit"] = hud.landmarks.items.size()
	hud.toggle_notebook()
	await get_tree().create_timer(0.6).timeout
	ok["clues"] = hud._nb_data.get("pistas", []).map(func(c): return c.text).filter(func(t): return t.contains("ruinas") or t.contains("passagem") or t.contains("Aquele"))
	await _shot("f4_5_caderno")
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


func _autotest_cancao() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await _go(Layout.spot("capela") + Vector3(-1.5, 0, 1.0), 120.0)
	var ok := {"heard": await _wait_sign("cancao-alvorada", 120.0)}
	ok["hour"] = int(client.view.get("hour", -1))
	if sign_nodes.has("cancao-alvorada"):
		ok["examined"] = await _examine_nearest("cancao-alvorada")
		await _shot("v3_cancao")
	await get_tree().create_timer(1.0).timeout
	hud.toggle_notebook()
	await get_tree().create_timer(0.6).timeout
	ok["clues"] = hud._nb_data.get("pistas", []).map(func(c): return c.text).filter(func(t): return t.contains("capela"))
	await _shot("v4_caderno_cancao")
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## F3 closing: the sketch from Tomas, the glint and the coin in the mine, the white boar's track at night, the dawn song.
## Needs a server with a short tick (a whole day passes in about a minute).
func _autotest_vestigios() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var ok := {}
	# 1. the sketch, through Tomas's menu
	for attempt in 3:  # he keeps his own day: find where he is now
		var tomas_region := ""
		for o in client.view.get("others", []):
			if o.id == "tomas":
				tomas_region = o.region
		ok["tomas_region"] = tomas_region
		if tomas_region == "estrada":
			await _go(Layout.spot("banco-estrada") + Vector3(1.4, 0, 1.4), 60.0)
		else:
			await _go(Layout.spot("taverna") + Vector3(0, 0, 1.0), 60.0)
		await get_tree().create_timer(1.5).timeout
		if npc_nodes.has("tomas"):
			break
	if npc_nodes.has("tomas"):
		await open_npc_menu(npc_nodes["tomas"])
		var i := _menu_index("pedir-esboco")
		ok["sketch_offered"] = i >= 0
		if i >= 0:
			_on_action_chosen(i)
			await get_tree().create_timer(1.8).timeout
			ok["sketch"] = last_report
			ok["map_after_sketch"] = found_places.keys()
	# 2. the mine: work a vein, notice the glint, search until the coin turns up
	await _go(Layout.ORIGIN.mina + Vector3(-3, 0, -4), 90.0)
	await client.occur("minerar")
	ok["glint_seen"] = await _wait_sign("brilho-na-pedra", 12.0)
	await _shot("v1_brilho")
	var tries := 0
	while sign_nodes.has("brilho-na-pedra") and tries < 25:
		ok["last_search"] = await _examine_nearest("brilho-na-pedra")
		tries += 1
	ok["coin_after_tries"] = tries
	ok["glint_gone"] = not sign_nodes.has("brilho-na-pedra")
	# 3. the forest at night: only someone who has hunted sees the track
	await _go(Layout.spot("clareira") + Vector3(1.0, 0, 1.0), 120.0)
	await client.occur("cacar-javali")
	ok["track_seen_at_night"] = await _wait_sign("pegada-branca", 60.0)
	ok["hour_then"] = int(client.view.get("hour", -1))
	if sign_nodes.has("pegada-branca"):
		await get_tree().create_timer(1.0).timeout
		await _shot("v2_pegada")
		ok["track_examined"] = await _examine_nearest("pegada-branca")
	# 4. the chapel at dawn
	await _go(Layout.spot("capela") + Vector3(-1.5, 0, 1.0), 120.0)
	ok["song_heard"] = await _wait_sign("cancao-alvorada", 70.0)
	if sign_nodes.has("cancao-alvorada"):
		ok["song_examined"] = await _examine_nearest("cancao-alvorada")  # the window is short on a fast server: act first
		await _shot("v3_cancao")
	hud.toggle_notebook()
	await get_tree().create_timer(0.6).timeout
	ok["notebook_clues"] = hud._nb_data.get("pistas", []).map(func(c): return c.text)
	ok["questions"] = hud._nb_data.get("perguntas", [])
	await _shot("v4_caderno")
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## F3: see a sign, examine it, put it in the notebook, tell someone, buy a sketch.
func _autotest_saber() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var ok := {}
	await _go(Vector3(31, 0, 3), 40.0)  # into the village
	await get_tree().create_timer(1.5).timeout
	# wait for a sign the engine offers (the well turns murky once poisoned)
	var w := 0.0
	while w < 80.0 and not sign_nodes.has("cenouras-roidas"):
		await get_tree().create_timer(1.0).timeout
		w += 1.0
	ok["signs_here"] = sign_nodes.keys()
	await _go(Layout.spot("horta") + Vector3(1.6, 0, 1.4), 40.0)
	await get_tree().create_timer(1.0).timeout
	var it := _nearest_interactable()
	ok["nearest_is_sign"] = it.has("sign")
	await use_nearest()
	await get_tree().create_timer(1.5).timeout
	ok["examined"] = last_report
	await _shot("sb1_examined")
	hud.toggle_notebook()
	await get_tree().create_timer(0.6).timeout
	ok["notebook"] = hud._nb_data.get("pistas", []).map(func(c): return c.text)
	await _shot("sb2_notebook")
	hud.toggle_notebook()
	# Something to tell: wait until a belief someone would react to exists and a listener is here.
	w = 0.0
	var tell_with := ""
	while w < float(_args.get("wait_tell", 60)) and tell_with == "":
		await client.refresh_affordances()
		for a in client.affordances:
			if a.action == "contar":
				tell_with = a.with
				break
		if tell_with == "":
			await get_tree().create_timer(2.0).timeout
			w += 2.0
	ok["tell_listener"] = tell_with
	if tell_with != "" and npc_nodes.has(tell_with):
		await _go(npc_nodes[tell_with].global_position + Vector3(0, 0, 1.6), 40.0)
		await open_npc_menu(npc_nodes[tell_with])
		ok["menu"] = _menu.map(func(a): return _menu_label(a))
		await _shot("sb3_tell_menu")
		for i in _menu.size():
			if _menu[i].action == "contar":
				_on_action_chosen(i)
				break
		await get_tree().create_timer(1.5).timeout
		ok["told"] = last_report
		await _shot("sb4_told")
	ok["telemetry"] = telemetry.summary()
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## The notice board and the bell, through the same menus a player uses.
func _autotest_board() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var ok := {}
	for pair in [["quadro", "ler-quadro"], ["sino", "tocar-sino"]]:
		var poi := _poi(pair[0])
		await _go(poi.at + Vector3(0, 0, 1.6), 40.0)
		await open_poi_menu(poi)
		var i := _menu_index(pair[1])
		ok[pair[0] + "_offered"] = i >= 0
		if i >= 0:
			_on_action_chosen(i)
			await get_tree().create_timer(1.5).timeout
			ok[pair[0]] = last_report
		await _shot("board_" + pair[0])
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## Walks the map hub by hub and checks the engine agrees on the region each time.
func _autotest_tour() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var ok := {}
	var stops := [["crossroads", Layout.CROSSROADS], ["floresta", Layout.ORIGIN.floresta + Vector3(6, 0, 4)], ["selo", Layout.ORIGIN.floresta + Vector3(14, 0, -13)],
		["mina", Layout.ORIGIN.mina + Vector3(0, 0, 6)], ["ruinas", Layout.ORIGIN.ruinas + Vector3(0, 0, 4)], ["toca", Layout.ORIGIN.toca + Vector3(0, 0, 1)],
		["vila", Vector3(0, 0, 4)]]
	for st in stops:
		var t := Time.get_ticks_msec()
		await _go(st[1], 120.0)
		await get_tree().create_timer(1.2).timeout
		ok[st[0]] = {"s": snappedf((Time.get_ticks_msec() - t) / 1000.0, 0.1), "near": player.global_position.distance_to(st[1]) < 3.0,
			"region": client.view.get("self", {}).get("region", "?")}
	ok["found"] = found_places.keys()
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## Aerial shots of the whole map, for judging the layout.
func _autotest_layout() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	cam_focus = Node3D.new()
	add_child(cam_focus)
	var views := [["vila", Vector3(0, 0, 0), 62.0], ["map", Vector3(40, 0, -35), 190.0], ["cruzamento", Vector3(70, 0, -15), 70.0],
		["floresta", Vector3(10, 0, -70), 70.0], ["toca", Vector3(-45, 0, -22), 40.0], ["ruinas", Vector3(112, 0, 6), 45.0]]
	for v in views:
		cam_focus.global_position = v[1]
		cam.size = v[2]
		await get_tree().create_timer(1.2).timeout
		await _shot("layout_" + v[0])
	print("AUTOTEST ", JSON.stringify({"shots": views.size()}))
	get_tree().quit()


## F1: stand in the plaza and watch the village day go by (needs a fast server tick).
func _autotest_f1() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	var seen := {}  # npc -> spots it was seen at
	var hours := {}
	var shots := 0
	var heard0 := 0
	var elapsed := 0.0
	while elapsed < float(_args.get("seconds", 70)):
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		var h := int(client.view.get("hour", -1))
		hours[h] = true
		for id in npc_nodes:
			var n: Actor = npc_nodes[id]
			if n.has_meta("base_name") and n.visible:
				seen[id] = seen.get(id, {})
				seen[id][n.get_meta("spot", "")] = true
		if int(elapsed) % 17 == 8 and shots < 4:
			shots += 1
			await _shot("f1_%d_h%02d" % [shots, h])
	var ok := {"hours_seen": hours.size(), "npcs_seen": seen.keys()}
	var moved := 0
	var table := {}
	for id in seen:
		table[id] = seen[id].keys()
		if seen[id].size() > 1:
			moved += 1
	ok["npcs_that_changed_spot"] = moved
	ok["spots"] = table
	ok["telemetry"] = telemetry.summary()
	ok["minimap_known"] = hud.minimap.known
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


## F0: blank map, labels only up close, push stream, telemetry.
func _autotest_f0() -> void:
	var t0 := Time.get_ticks_msec()
	while client.view.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	var ok := {"view": not client.view.is_empty()}
	ok["streaming"] = client.streaming
	ok["start_map"] = found_places.keys()
	ok["minimap_known_start"] = hud.minimap.known.duplicate()
	var far_visible := 0
	for poi in pois:
		if poi.node.visible and Vector2(poi.at.x - player.global_position.x, poi.at.z - player.global_position.z).length() > LABEL_RANGE:
			far_visible += 1
	ok["far_labels_visible"] = far_visible
	var rev0 := int(client.view.get("revision", 0))
	var t1 := Time.get_ticks_msec()
	await client.move_region("estrada")  # a confirmed change; no manual refresh follows
	while int(client.view.get("revision", 0)) == rev0 and Time.get_ticks_msec() - t1 < 4000:
		await get_tree().create_timer(0.05).timeout
	ok["push_ms"] = Time.get_ticks_msec() - t1
	ok["push_seen"] = int(client.view.get("revision", 0)) != rev0
	ok["estrada_found"] = found_places.has("estrada")
	ok["toca_hidden"] = not found_places.has("toca") and not hud.minimap.known.has("toca")
	ok["telemetry"] = telemetry.summary()
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
	await _go(REGION_ORIGIN["toca"] + Vector3(0, 0, -1), 120.0)
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


## Uses every ability against a training camp and photographs each effect.
func _autotest_skills() -> void:
	await get_tree().create_timer(4.0).timeout
	client._timer.stop()  # keep the training camp: no view sync during the test
	var ok := {}
	# Training dummies: two within the spin, one down the dash line, one far for the blade.
	var base := player.global_position
	var spots := [Vector3(1.8, 0, 0.8), Vector3(-1.6, 0, 1.2), Vector3(5.0, 0, -5.0), Vector3(-9.0, 0, -6.0)]
	var dummies: Array = []
	for sp in spots:
		var d: Enemy = _spawn_enemy("bandido", "zoo", base + sp)
		d.aggro = 0.0
		d.damage = 0.0  # they hit back after being struck: keep the test about our side
		dummies.append(d)
	var total := func() -> float:
		var t := 0.0
		for d in dummies:
			t += maxf(d.hp, 0.0) if is_instance_valid(d) else 0.0
		return t
	var hp0: float = total.call()
	use_ability(0)
	await get_tree().create_timer(0.36).timeout
	await _shot("s1_giro")
	await get_tree().create_timer(0.8).timeout
	ok["giro_damage"] = hp0 - total.call()
	var hp1: float = total.call()
	Input.warp_mouse(cam.unproject_position(dummies[2].global_position))
	await get_tree().process_frame
	while player.busy:
		await get_tree().process_frame
	use_ability(1)
	await get_tree().create_timer(0.15).timeout
	await _shot("s2_investida")
	await get_tree().create_timer(0.9).timeout
	ok["investida_damage"] = hp1 - total.call()
	var hp2: float = total.call()
	Input.warp_mouse(cam.unproject_position(dummies[3].global_position))
	await get_tree().process_frame
	while player.busy:
		await get_tree().process_frame
	use_ability(2)
	await get_tree().create_timer(0.34).timeout
	await _shot("s3_lamina")
	await get_tree().create_timer(1.0).timeout
	ok["lamina_damage"] = hp2 - total.call()
	player_hp = 50.0
	use_ability(3)
	await get_tree().create_timer(0.35).timeout
	await _shot("s4_cura")
	ok["hp_after_heal"] = player_hp
	ok["cooldown_blocks"] = Time.get_ticks_msec() < ready_at.get("giro", 0)
	Input.parse_input_event(_key(KEY_K))
	await get_tree().create_timer(0.4).timeout
	await _shot("s5_painel")
	ok["skills_panel"] = hud.skills_panel.visible
	hud.toggle_skills()
	# WASD through the input pipeline: W must move the player up the screen.
	var start := player.global_position
	Input.parse_input_event(_key(KEY_W))
	await get_tree().create_timer(1.0).timeout
	var up := _key(KEY_W)
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().create_timer(0.2).timeout
	ok["w_moved_m"] = snappedf(start.distance_to(player.global_position), 0.1)
	var b := cam_rig.global_transform.basis  # the camera follows, so compare in the world
	var away := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var moved := player.global_position - start
	moved.y = 0
	ok["w_goes_up_screen"] = moved.normalized().dot(away) > 0.9
	# Left mouse button: a swing toward the cursor.
	var aim := cam.unproject_position(player.global_position + Vector3(-3, 0, 3))
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	click_ev.position = aim
	click_ev.global_position = aim
	Input.warp_mouse(aim)
	var attacks0 := last_attack_ms
	for attempt in 3:  # a flinch from a wolf can swallow a click, as in play
		while player.busy:
			await get_tree().process_frame
		Input.parse_input_event(click_ev)
		await get_tree().process_frame
		var release := click_ev.duplicate() as InputEventMouseButton
		release.pressed = false
		Input.parse_input_event(release)
		await get_tree().create_timer(0.2).timeout
		if last_attack_ms != attacks0:
			break
	ok["lmb_attacked"] = last_attack_ms != attacks0
	var f := Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))
	var assist := _nearest_enemy(3.5)
	var to_assist := Vector3.ZERO if assist == null else (assist.global_position - player.global_position).normalized()
	# toward the cursor, or toward an enemy close to that direction (aim assist)
	ok["lmb_faces_aim"] = f.dot(Vector3(-1, 0, 1).normalized()) > 0.8 or assist != null and f.dot(Vector3(to_assist.x, 0, to_assist.z).normalized()) > 0.95
	await _shot("s6_mouse")
	print("AUTOTEST ", JSON.stringify(ok))
	get_tree().quit()


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	return k


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
	await _go(Vector3(-8, 0, -12), 25.0)
	var from := player.global_position
	var target := Vector3(-24, 0, -12)
	var t_path := Time.get_ticks_msec()
	player.walk_to(target)
	await get_tree().create_timer(2.0).timeout
	await _shot("04_path")
	await _go(target, 30.0)  # resumes if a wolf interrupts the walk
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
	await _arrive(60.0)
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
