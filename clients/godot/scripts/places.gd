class_name Places
extends RefCounted
## Places the client builds and the points of interest that anchor what can be
## done there. Positions are presentation only: the engine knows regions, not
## coordinates. What is actually possible comes from the engine's affordances;
## a point only says "these actions happen here" (or "about this landmark").

# id, region, position, label, landmark it stands for (affordance "with") and
# region-level actions it anchors.
const POIS := [
	{"id": "poco", "region": "vila", "at": Vector3(0, 0, 0), "label": "Poco Antigo", "with": "poco"},
	{"id": "carroca", "region": "vila", "at": Vector3(-9, 0, -4), "label": "Carroca da caravana", "actions": ["escoltar-caravana"]},
	{"id": "telhado", "region": "vila", "at": Vector3(-16, 0, -8.3), "label": "Casa de telhado velho", "actions": ["consertar-telhado"]},
	{"id": "banco", "region": "vila", "at": Vector3(-3, 0, 9.5), "label": "Banco da praca", "actions": ["descansar", "sonhar", "diagnosticar", "procurar-botoes", "acalmar-doentes", "trocar-magia"]},
	{"id": "carga", "region": "estrada", "at": Vector3(21.6, 0, -5.2), "label": "Carga revirada", "actions": ["recuperar-mercadorias"]},
	{"id": "selo", "region": "floresta", "at": Vector3(80, 0, -16), "label": "Selo da Floresta", "with": "selo", "actions": ["seguir-rastro", "recuperar-reliquia", "plantar-mudas"]},
	{"id": "ervas1", "region": "floresta", "at": Vector3(56, 0, 9), "label": "Ervas", "actions": ["colher-ervas-campo"]},
	{"id": "ervas2", "region": "floresta", "at": Vector3(72, 0, -5), "label": "Ervas", "actions": ["colher-ervas-campo"]},
	{"id": "arbusto", "region": "floresta", "at": Vector3(86, 0, 14), "label": "Arbusto que se mexe", "actions": ["achar-crianca"]},
	{"id": "veio1", "region": "mina", "at": Vector3(103, 0, -6), "label": "Veio de minerio", "actions": ["minerar"]},
	{"id": "veio2", "region": "mina", "at": Vector3(106, 0, 7), "label": "Veio de minerio", "actions": ["minerar"]},
	{"id": "escombros", "region": "mina", "at": Vector3(113, 0, -7), "label": "Escombros", "actions": ["resgatar-mineiro"]},
	{"id": "salao", "region": "ruinas", "at": Vector3(140, 0, 0), "label": "Escada para o salao", "actions": ["explorar-ruinas"]},
]

# Animation each kind of deed plays (Universal Animation Library clips).
const ANIM := {"minerar": "TreeChopping", "forjar": "TreeChopping", "consertar-telhado": "TreeChopping",
	"contribuir-obra": "TreeChopping", "forjar-lamina-proibida": "TreeChopping", "colher-ervas-campo": "Farm_Harvest",
	"plantar-mudas": "Farm_PlantSeed", "resgatar-mineiro": "PickUp_Table", "recuperar-mercadorias": "Chest_Open",
	"recuperar-reliquia": "Sword_Regular_C", "descansar": "Sitting_Enter", "sonhar": "Sitting_Enter",
	"purificar-poco": "Spell_Simple_Shoot", "acalmar-doentes": "Spell_Simple_Shoot", "usar-florescer": "Spell_Simple_Shoot",
	"trocar-magia": "Spell_Simple_Shoot", "receber-bencao": "Yes", "agradecer-elena": "Yes", "presentear-pipo": "Interact"}


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
	var c := Vector3(80, 0, -16)
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
	for p in [Vector3(56, 0, 9), Vector3(72, 0, -5)]:
		m._spawn("nature/Flower_3_Group", p, 0.0, 1.3)
		m._spawn("nature/Flower_4_Group", p + Vector3(0.8, 0, 0.5), 40.0, 1.3)
		m._spawn("nature/Fern_1", p + Vector3(-0.7, 0, -0.4), 10.0)
	m._spawn("nature/Bush_Common", Vector3(86, 0, 14), 0.0, 1.6)
	m._spawn("nature/Bush_Common_Flowers", Vector3(87.4, 0, 15), 50.0, 1.2)


## Mina de Kharum: a rocky slope north of the road with a braced entrance,
## ore veins and rubble. The road runs on to the ruins.
static func _mine(m) -> void:
	for i in 8:
		if i == 3:
			continue  # the entrance
		var p := Vector3(99.8 + i * 3.4, 0, -18.5 + (i % 2) * 1.2)
		var r: Node3D = m._spawn("nature/Rock_Medium_%d" % (1 + i % 3), p, i * 33.0, 3.6)
		m._occluder(r, r.position + Vector3(0, 2.5, 0), 4.0)
		m._solid(p, Vector3(3.4, 5.0, 3.4))
	var arch: Node3D = m._spawn("village/Wall_Arch", Vector3(110, 0, -15.6), 0.0, 1.2)
	m._occluder(arch, arch.position + Vector3(0, 2, 0), 3.0)
	m._spawn("village/Prop_Support", Vector3(108.4, 0, -15.0), 0.0)
	m._spawn("village/Prop_Support", Vector3(111.6, 0, -15.0), 0.0)
	var dark := MeshInstance3D.new()  # the black mouth of the mine
	var dm := BoxMesh.new()
	dm.size = Vector3(2.6, 3.0, 0.2)
	dark.mesh = dm
	dark.material_override = _stone(Color(0.02, 0.02, 0.03))
	dark.position = Vector3(110, 1.5, -16.4)
	m.add_child(dark)
	m._solid(Vector3(110, 0, -17), Vector3(2.8, 3.0, 1.0))
	for p in [Vector3(103, 0, -6), Vector3(106, 0, 7)]:  # ore veins
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
		m._spawn("nature/Pebble_Round_%d" % (1 + 2 * (i % 2)), Vector3(113 + i * 0.5, 0, -7 + (i % 3) * 0.6), i * 70.0, 2.2)
	m._spawn("props/Crate_Wooden", Vector3(108, 0, 4), 15.0)
	m._spawn("props/Pickaxe_Bronze", Vector3(108.8, 0.05, 2.8), 0.0)
	m._spawn("village/Prop_Wagon", Vector3(116, 0, -10), 20.0)
	m._solid(Vector3(116, 0, -10), Vector3(4.0, 1.5, 2.0), 20.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.omni_range = 6.0
	lamp.position = Vector3(110, 2.4, -13.5)
	m.add_child(lamp)


## Ruinas de Asterion: broken walls, a paved hall and the stairs down.
static func _ruins(m) -> void:
	var c := Vector3(140, 0, 0)
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
	var c := Vector3(66, 0, 44)
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
