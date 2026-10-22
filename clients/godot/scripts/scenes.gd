class_name Scenes
extends RefCounted
## What the world looks like while something happens in it. Each scene belongs to a sign the engine
## shows the observer (a caravan at the market, a storm over the village...) and is built once while
## the sign lasts and removed when it goes. Presentation only: what is true comes from the engine.

const BUILDERS := {
	"caravana-no-mercado": "_caravan", "festival-de-lanternas": "_festival", "feira-dos-magos": "_fair",
	"peregrinos-na-capela": "_pilgrims", "poeira-da-mina": "_dust", "tempestade-sobre-a-vila": "_storm",
}


static func has(sign_id: String) -> bool:
	return BUILDERS.has(sign_id)


static func build(m, sign_id: String) -> Node3D:
	var root := Node3D.new()
	m.add_child(root)
	match sign_id:
		"caravana-no-mercado":
			_caravan(m, root)
		"festival-de-lanternas":
			_festival(m, root)
		"feira-dos-magos":
			_fair(m, root)
		"peregrinos-na-capela":
			_pilgrims(m, root)
		"poeira-da-mina":
			_dust(m, root)
		"tempestade-sobre-a-vila":
			_storm(m, root)
	return root


static func _mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = yaw
	root.add_child(mi)
	return mi


static func _glow(root: Node3D, pos: Vector3, color: Color, radius := 0.16, energy := 1.1, range_m := 5.0) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _mat(color, 2.5)
	mi.position = pos
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.position = pos
	root.add_child(l)


## Lia's caravan at the market: wagons, crates, striped awnings and lanterns.
static func _caravan(m, root: Node3D) -> void:
	var c: Vector3 = Layout.spot("mercado")
	for i in 2:
		m._spawn("village/Prop_Wagon", c + Vector3(-2 + i * 7.0, 0, 3.5), 100.0 - i * 40.0, 1.0, root)
	for i in 5:
		m._spawn("village/Prop_Crate", c + Vector3(-3 + i * 2.4, 0, 6.2 + (i % 2) * 0.8), i * 31.0, 1.0, root)
	m._spawn("props/Barrel", c + Vector3(4.8, 0, 1.2), 0.0, 1.0, root)
	var colors := [Color(0.8, 0.25, 0.2), Color(0.9, 0.8, 0.3), Color(0.25, 0.5, 0.8)]
	for i in 3:
		_box(root, Vector3(2.4, 0.12, 1.6), c + Vector3(-3 + i * 3.0, 2.2, 0.3), _mat(colors[i]), 4.0 * (i - 1))
		for dx in [-1.1, 1.1]:
			_box(root, Vector3(0.1, 2.2, 0.1), c + Vector3(-3 + i * 3.0 + dx, 1.1, 0.3), _mat(Color(0.4, 0.28, 0.16)))
		_glow(root, c + Vector3(-3 + i * 3.0, 1.9, 1.2), Color(1.0, 0.8, 0.45))


## Ribbons across the plaza and paper lanterns.
static func _festival(m, root: Node3D) -> void:
	var colors := [Color(0.9, 0.3, 0.3), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.9), Color(0.4, 0.8, 0.45)]
	for i in 8:
		var col: Color = colors[i % 4]
		var y := 3.3 + 0.15 * (i % 2)
		_box(root, Vector3(0.08, 0.2, 12.0), Vector3(-5.5 + i * 1.6, y, 0.0), _mat(col))
		_glow(root, Vector3(-5.5 + i * 1.6, y - 0.55, -3.0 + (i % 3) * 3.0), col, 0.22, 0.8, 4.0)
	for dx in [-6.5, 6.5]:
		for dz in [-6.0, 6.0]:
			_box(root, Vector3(0.15, 3.4, 0.15), Vector3(dx, 1.7, dz), _mat(Color(0.4, 0.28, 0.16)))


## Wizards' stalls: cone tents that shimmer and drifting lights.
static func _fair(m, root: Node3D) -> void:
	var c: Vector3 = Layout.spot("praca") + Vector3(0, 0, 0)
	var palette := [Color(0.6, 0.3, 0.9), Color(0.25, 0.7, 0.8), Color(0.9, 0.5, 0.7), Color(0.9, 0.8, 0.3)]
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := c + Vector3(cos(a), 0, sin(a)) * 7.2
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 1.5
		cm.height = 2.4
		cone.mesh = cm
		cone.material_override = _mat(palette[i], 0.5)
		cone.position = p + Vector3(0, 1.2, 0)
		root.add_child(cone)
		m._spawn("props/Table_Large", p + Vector3(-cos(a) * 1.9, 0, -sin(a) * 1.9), rad_to_deg(a) + 90.0, 1.0, root)
		_glow(root, p + Vector3(0, 3.0, 0), palette[i], 0.2, 1.2, 6.0)
		var tw := root.create_tween().set_loops()
		tw.tween_property(cone.material_override, "emission_energy_multiplier", 1.5, 1.2 + i * 0.2)
		tw.tween_property(cone.material_override, "emission_energy_multiplier", 0.3, 1.2 + i * 0.2)


## Candles in rows in front of the chapel.
static func _pilgrims(m, root: Node3D) -> void:
	var c: Vector3 = Layout.spot("capela") + Vector3(0, 0, -0.6)  # in front of the door (the chapel faces north)
	for row in 3:
		for i in 9:
			var p := c + Vector3(-4.8 + i * 1.2, 0, -row * 1.2)
			var candle := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.06
			cm.height = 0.3
			candle.mesh = cm
			candle.material_override = _mat(Color(0.95, 0.92, 0.8))
			candle.position = p + Vector3(0, 0.15, 0)
			root.add_child(candle)
			var flame := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.12
			flame.mesh = sm
			flame.material_override = _mat(Color(1.0, 0.75, 0.3), 3.0)
			flame.position = p + Vector3(0, 0.34, 0)
			root.add_child(flame)
	_glow(root, c + Vector3(0, 0.8, -1.2), Color(1.0, 0.75, 0.4), 0.0, 1.6, 9.0)


## Dust over the collapsed gallery, and rubble.
static func _dust(m, root: Node3D) -> void:
	var at: Vector3 = Layout.ORIGIN.mina + Vector3(4.0, 0, -13.0)
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 6.0
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.3, 0.2, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.48, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	p.position = at + Vector3(0, 1.5, 0)
	root.add_child(p)
	for i in 7:
		m._spawn("nature/Rock_Medium_%d" % (1 + i % 3), at + Vector3(-3 + i * 1.0, 0, 1.0 + (i % 3) * 0.8), i * 53.0, 1.2, root)


## Rain around the player, a darker sky and now and then lightning. The root follows the player.
static func _storm(m, root: Node3D) -> void:
	var rain := CPUParticles3D.new()
	rain.amount = 400
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(14, 0.2, 14)
	rain.direction = Vector3(0.25, -1, 0)
	rain.spread = 3.0
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 26.0
	rain.gravity = Vector3.ZERO
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	rain.mesh = qm
	rain.position = Vector3(0, 11, 0)
	rain.name = "Rain"
	root.add_child(rain)
	root.set_meta("follow_player", true)
	root.set_meta("storm", true)
