class_name Places
extends RefCounted
## Places the client builds and the points of interest that anchor what can be
## done there. Positions are presentation only: the engine knows regions, not
## coordinates. What is actually possible comes from the engine's affordances;
## a point only says "these actions happen here" (or "about this landmark").

static var _pois: Array = []
static var _anim: Dictionary = {}
static var _greet: Dictionary = {}
static var text: Dictionary = {}  # belief_text, clue_text, questions, source_text
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation.json"))
	if not d is Dictionary:
		push_error("data/presentation.json is missing or invalid")
		return
	_anim = d.get("anim", {})
	_greet = d.get("greet", {})
	for k in ["belief_text", "clue_text", "questions", "source_text"]:
		text[k] = d.get(k, {})
	for p in d.get("pois", []):
		var rel: Array = p.rel
		var e: Dictionary = p.duplicate()
		e["at"] = Layout.ORIGIN[p.region] + Vector3(rel[0], rel[1], rel[2])
		_pois.append(e)


## Points of interest (data/presentation.json), placed relative to their region's origin.
static func pois() -> Array:
	_load()
	return _pois


## "Poco Antigo esta envenenado": a belief in words, from the presentation templates.
static func belief_label(b: Dictionary, names: Dictionary) -> String:
	_load()
	var tpl: String = text.get("belief_text", {}).get(b.get("p", ""), "%s: %s" % [b.get("p", "?"), "{s}"])
	var subject: String = names.get(b.get("s", ""), b.get("s", ""))
	return tpl.replace("{s}", subject).replace("{o}", names.get(b.get("o", ""), b.get("o", "")))


## A short hello from someone who knows you (empty if they have none).
static func greeting(npc: String, salt: int) -> String:
	_load()
	var lines: Array = _greet.get(npc, [])
	return "" if lines.is_empty() else lines[salt % lines.size()]


## The animation clip (Universal Animation Library) a deed plays.
static func anim(action: String) -> String:
	_load()
	return _anim.get(action, "Interact")


static func build(m) -> void:
	_well(m)
	_seal(m)
	_forest_spots(m)
	_mine(m)
	_ruins(m)
	_den(m)


static func _stone(color := Color(0.5, 0.5, 0.52)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


static func _well(m) -> void:
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.1
	cm.height = 0.9
	ring.mesh = cm
	ring.material_override = _stone()
	ring.position = Vector3(0, 0.45, 0)
	m.add_child(ring)
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.82
	wm.bottom_radius = 0.82
	wm.height = 0.05
	water.mesh = wm
	water.material_override = _stone(Color(0.12, 0.2, 0.18))  # the dark water of the old well
	water.position = Vector3(0, 0.88, 0)
	m.add_child(water)
	m._spawn("props/Bucket_Wooden_1", Vector3(0.9, 0.9, 0.2), 30.0)
	m._solid(Vector3(0, 0, 0), Vector3(2.2, 1.0, 2.2))
	m._spawn("props/Bench", Vector3(-3, 0, 10.2), 0.0)


static func _seal(m) -> void:
	var c: Vector3 = Layout.ORIGIN.floresta + Vector3(16, 0, -16)
	for i in 7:
		var a := TAU * i / 7.0
		var r: Node3D = m._spawn("nature/Rock_Medium_%d" % (1 + i % 3), c + Vector3(cos(a), 0, sin(a)) * 3.4, i * 47.0, 0.9)
		m._occluder(r, r.position + Vector3(0, 1, 0), 1.6)
	var core := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.25
	pm.bottom_radius = 0.45
	pm.height = 2.4
	core.mesh = pm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.45, 0.3, 0.7)
	glow.emission_enabled = true
	glow.emission = Color(0.6, 0.35, 1.0)
	glow.emission_energy_multiplier = 1.6
	core.material_override = glow
	core.position = c + Vector3(0, 1.2, 0)
	m.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(0.65, 0.4, 1.0)
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = c + Vector3(0, 2.0, 0)
	m.add_child(light)
	m._solid(c, Vector3(1.0, 2.4, 1.0))


static func _forest_spots(m) -> void:
	var f: Vector3 = Layout.ORIGIN.floresta
	for p in [f + Vector3(-8, 0, 9), f + Vector3(8, 0, -5)]:
		m._spawn("nature/Flower_3_Group", p, 0.0, 1.3)
		m._spawn("nature/Flower_4_Group", p + Vector3(0.8, 0, 0.5), 40.0, 1.3)
		m._spawn("nature/Fern_1", p + Vector3(-0.7, 0, -0.4), 10.0)
	m._spawn("nature/Bush_Common", f + Vector3(22, 0, 14), 0.0, 1.6)
	m._spawn("nature/Bush_Common_Flowers", f + Vector3(23.4, 0, 15), 50.0, 1.2)


## Mina de Kharum: a rocky slope north of the road with a braced entrance,
## ore veins and rubble. The road runs on to the ruins.
static func _mine(m) -> void:
	var o: Vector3 = Layout.ORIGIN.mina - Vector3(106, 0, 0)  # laid out around x=106 and shifted
	for i in 8:
		if i == 3:
			continue  # the entrance
		var p := o + Vector3(99.8 + i * 3.4, 0, -18.5 + (i % 2) * 1.2)
		var r: Node3D = m._spawn("nature/Rock_Medium_%d" % (1 + i % 3), p, i * 33.0, 3.6)
		m._occluder(r, r.position + Vector3(0, 2.5, 0), 4.0)
		m._solid(p, Vector3(3.4, 5.0, 3.4))
	var arch: Node3D = m._spawn("village/Wall_Arch", o + Vector3(110, 0, -15.6), 0.0, 1.2)
	m._occluder(arch, arch.position + Vector3(0, 2, 0), 3.0)
	m._spawn("village/Prop_Support", o + Vector3(108.4, 0, -15.0), 0.0)
	m._spawn("village/Prop_Support", o + Vector3(111.6, 0, -15.0), 0.0)
	var dark := MeshInstance3D.new()  # the black mouth of the mine
	var dm := BoxMesh.new()
	dm.size = Vector3(2.6, 3.0, 0.2)
	dark.mesh = dm
	dark.material_override = _stone(Color(0.02, 0.02, 0.03))
	dark.position = o + Vector3(110, 1.5, -16.4)
	m.add_child(dark)
	m._solid(o + Vector3(110, 0, -17), Vector3(2.8, 3.0, 1.0))
	for p in [o + Vector3(103, 0, -6), o + Vector3(106, 0, 7)]:  # ore veins
		var v: Node3D = m._spawn("nature/Rock_Medium_2", p, 20.0, 1.3)
		var t := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		t.mesh = sm
		var ore := StandardMaterial3D.new()
		ore.albedo_color = Color(0.85, 0.55, 0.2)
		ore.emission_enabled = true
		ore.emission = Color(0.9, 0.5, 0.15)
		ore.emission_energy_multiplier = 0.8
		t.material_override = ore
		t.position = p + Vector3(0.3, 1.0, 0.5)
		m.add_child(t)
		m._solid(p, Vector3(1.6, 1.4, 1.6))
	for i in 5:  # rubble
		m._spawn("nature/Pebble_Round_%d" % (1 + 2 * (i % 2)), o + Vector3(113 + i * 0.5, 0, -7 + (i % 3) * 0.6), i * 70.0, 2.2)
	m._spawn("props/Crate_Wooden", o + Vector3(108, 0, 4), 15.0)
	m._spawn("props/Pickaxe_Bronze", o + Vector3(108.8, 0.05, 2.8), 0.0)
	m._spawn("village/Prop_Wagon", o + Vector3(116, 0, -10), 20.0)
	m._solid(o + Vector3(116, 0, -10), Vector3(4.0, 1.5, 2.0), 20.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.omni_range = 6.0
	lamp.position = o + Vector3(110, 2.4, -13.5)
	m.add_child(lamp)


## Ruinas de Asterion: broken walls, a paved hall and the stairs down.
static func _ruins(m) -> void:
	var c: Vector3 = Layout.ORIGIN.ruinas + Vector3(4, 0, 0)
	for x in 4:
		for z in 4:
			if (x + z) % 3 != 0:
				m._spawn("village/Floor_UnevenBrick", c + Vector3(-3 + x * 2, 0.0, -3 + z * 2))
	var walls := [[Vector3(-4, 0, -6), 0.0, 4.0], [Vector3(2, 0, -6), 0.0, -6.0], [Vector3(6, 0, -2), 90.0, 3.0],
		[Vector3(-6, 0, 2), 90.0, -8.0], [Vector3(0, 0, 6), 180.0, 5.0], [Vector3(5, 0, 5), 135.0, -4.0]]
	for w in walls:
		var n: Node3D = m._spawn("village/Wall_UnevenBrick_Straight", c + w[0], w[1])
		n.rotation_degrees.z = w[2]  # leaning, half fallen
		m._occluder(n, n.position + Vector3(0, 1.6, 0), 2.2)
		m._solid(c + w[0], Vector3(2.0, 3.0, 0.5), w[1])
	var arch: Node3D = m._spawn("village/Wall_Arch", c + Vector3(-2, 0, 6), 180.0)
	m._occluder(arch, arch.position + Vector3(0, 1.6, 0), 2.2)
	m._spawn("village/HoleCover_90Stairs", c, 0.0)
	for i in 6:
		m._spawn("village/Prop_Brick%d" % (1 + i % 2), c + Vector3(-5 + i * 2, 0, 4 - i), i * 50.0)
	m._spawn("village/Prop_Vine1", c + Vector3(-4, 0, -5.6), 0.0)
	m._spawn("props/Vase_Rubble_Medium", c + Vector3(3, 0, 2), 0.0)
	for i in 5:
		m._tree(c + Vector3(-12 + i * 6, 0, 16 + (i % 2) * 4), "nature/DeadTree_1")


## Toca dos Lebrinos: an enormous root at the forest's southern edge.
static func _den(m) -> void:
	var c: Vector3 = Layout.ORIGIN.toca + Vector3(0, 0, 3)
	var root: Node3D = m._spawn("nature/DeadTree_3", c + Vector3(0, 0, 4), 0.0, 3.0)
	m._occluder(root, root.position + Vector3(0, 5, 0), 7.0)
	m._solid(c + Vector3(0, 0, 4), Vector3(3.0, 4.0, 3.0))
	for i in 7:
		m._spawn("nature/Mushroom_%s" % ("Common" if i % 2 == 0 else "Laetiporus"), c + Vector3(-5 + i * 1.6, 0, 1 + (i % 3)), i * 40.0, 1.5)
	m._spawn("nature/Bush_Common_Flowers", c + Vector3(-6, 0, -2), 0.0, 1.4)
	m._spawn("nature/Bush_Common", c + Vector3(6, 0, -1), 0.0, 1.4)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.omni_range = 7.0
	lamp.position = c + Vector3(0, 2.0, 1)
	m.add_child(lamp)
