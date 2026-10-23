class_name BioPfx
extends RefCounted
## Particle effects. Everything is a CPUParticles2D with the additive glow texture, shaped by colour ramps
## and size curves, so bursts bloom, fade and shrink instead of just disappearing. Short effects free
## themselves; persistent ones (auras, zones) are returned so their owner can stop them.

const Z := 22


static func _base(parent: Node, pos: Vector2, color: Color, amount: int, life: float, size_px: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = BioArt.glow_texture()
	p.material = BioArt.additive()
	p.amount = maxi(1, roundi(amount * density))
	p.lifetime = life * linger
	p.local_coords = false
	p.z_index = Z
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(color.lerp(Color.WHITE, 0.55), 0.95), Color(color, 0.8), Color(color.darkened(0.3), 0.0)])
	p.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = size_px * 0.6 / 128.0
	p.scale_amount_max = size_px / 128.0
	_shape(p, color)
	parent.add_child(p)
	p.global_position = pos
	emitted += 1
	if style != &"":
		emitted_styled += 1
	return p


static func _free_after(p: CPUParticles2D, seconds: float) -> void:
	if p.is_inside_tree():
		var id := p.get_instance_id()  # an id, not the node: the node may be gone when the timer fires
		p.get_tree().create_timer(seconds).timeout.connect(func() -> void:
			var node := instance_from_id(id) as CPUParticles2D
			if node != null:
				node.queue_free())


## The feel Jev designed for this cell's effects: how many particles, how long they linger, how fast they go, and the style
## (chama, cristal, nevoa, eletrico, organico) that gives every particle its own shape and motion.
static var style: StringName = &""
static var emitted := 0  # counters for the debug overlay
static var emitted_styled := 0
static var density := 1.0
static var linger := 1.0
static var tempo := 1.0


## An explosion of glowing motes. `spread_deg` 180 is all around; a small one fires in `direction`.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 28, speed: float = 220.0, life: float = 0.7, size_px: float = 14.0, direction: Vector2 = Vector2.RIGHT, spread_deg: float = 180.0, damping: float = 2.5) -> void:
	if parent == null:
		return
	var p := _base(parent, pos, color, amount, life, size_px)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = direction
	p.spread = spread_deg
	var pace := tempo * float({&"nevoa": 0.55, &"eletrico": 1.7, &"cristal": 1.2, &"chama": 0.9}.get(style, 1.0))
	p.initial_velocity_min = speed * 0.4 * pace
	p.initial_velocity_max = speed * pace
	p.damping_min = damping * 0.6
	p.damping_max = damping
	p.emitting = true
	_free_after(p, life + 0.3)


## Motes born on a circle of `radius` that rush outwards (or inwards when `inward`): shock rings and suction.
static func ring_burst(parent: Node, pos: Vector2, color: Color, radius: float, amount: int = 48, life: float = 0.6, size_px: float = 12.0, inward: bool = false) -> void:
	if parent == null:
		return
	var p := _base(parent, pos, color, amount, life, size_px)
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	var accel := radius * (-2.4 if inward else 2.4)
	p.radial_accel_min = accel * 0.8
	p.radial_accel_max = accel
	p.emitting = true
	_free_after(p, life + 0.3)


## A continuous emitter child of `parent` (an aura, a zone, a trail). The caller stops it with `stop()`.
static func stream(parent: Node, color: Color, amount: int = 24, life: float = 0.9, size_px: float = 10.0, emission_radius: float = 30.0, rising: float = 0.0, speed: float = 20.0) -> CPUParticles2D:
	var origin := (parent as Node2D).global_position if parent is Node2D else Vector2.ZERO
	var p := _base(parent, origin, color, amount, life, size_px)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = emission_radius
	p.direction = Vector2.UP
	p.spread = 180.0 if rising == 0.0 else 35.0
	p.gravity = Vector2(0.0, -rising)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.emitting = true
	return p


## Stops an emitter softly: no new motes, the existing ones fade, then it frees itself.
static func stop(p: CPUParticles2D) -> void:
	if is_instance_valid(p):
		p.emitting = false
		_free_after(p, p.lifetime + 0.2)


## A short comet trail behind a moving node.
static func trail(parent: Node2D, color: Color, size_px: float = 12.0, amount: int = 30) -> CPUParticles2D:
	var p := _base(parent, parent.global_position, color, amount, 0.45, size_px)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 26.0
	p.emitting = true
	return p


## Each style changes what the particles are, not only their colour: a flame rises and flickers, crystal is angular shards that
## spin, mist is big and soft and slow, electricity is thin quick flashes, the organic is wet blobs that swell and sag.
static func _shape(p: CPUParticles2D, color: Color) -> void:
	match style:
		&"chama":
			p.gravity = Vector2(0.0, -260.0)
			p.scale_amount_min *= 1.3
			p.scale_amount_max *= 1.5
			p.amount = roundi(p.amount * 1.4)
			var flicker := Curve.new()
			flicker.add_point(Vector2(0.0, 0.5))
			flicker.add_point(Vector2(0.15, 1.0))
			flicker.add_point(Vector2(0.4, 0.55))
			flicker.add_point(Vector2(0.6, 0.9))
			flicker.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = flicker
		&"cristal":
			p.texture = BioArt.shard_texture()
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -300.0
			p.angular_velocity_max = 300.0
			p.scale_amount_min *= 1.1
			p.scale_amount_max *= 1.4
			p.amount = roundi(p.amount * 0.8)
		&"nevoa":
			p.scale_amount_min *= 2.4
			p.scale_amount_max *= 3.0
			p.lifetime *= 1.5
			p.amount = maxi(1, roundi(p.amount * 0.6))
			var ramp := Gradient.new()
			ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			ramp.colors = PackedColorArray([Color(color.lerp(Color.WHITE, 0.3), 0.32), Color(color, 0.26), Color(color.darkened(0.2), 0.0)])
			p.color_ramp = ramp
		&"eletrico":
			p.texture = BioArt.shard_texture()
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.scale_amount_min *= 0.7
			p.scale_amount_max *= 1.1
			p.lifetime *= 0.5
			p.amount = roundi(p.amount * 1.8)
		&"organico":
			p.gravity = Vector2(0.0, 140.0)
			p.scale_amount_min *= 1.5
			p.scale_amount_max *= 1.9
			var swell := Curve.new()
			swell.add_point(Vector2(0.0, 0.3))
			swell.add_point(Vector2(0.35, 1.2))
			swell.add_point(Vector2(0.65, 0.8))
			swell.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = swell
