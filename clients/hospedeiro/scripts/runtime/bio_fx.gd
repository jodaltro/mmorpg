class_name BioFx
extends RefCounted
## Fire-and-forget bioluminescent effects. Nodes are short lived; pooling is a later optimisation.

static var root: Node2D


static func burst(pos: Vector2, color: Color, count: int, speed_units: float = 3.0, size_units: float = 0.35, life: float = 0.6) -> void:
	if root == null:
		return
	for i in count:
		var fx := BioFxLife.new()
		fx.kind = BioFxLife.Kind.MOTE
		fx.color = color
		fx.life = life * randf_range(0.6, 1.0)
		fx.velocity = Vector2.from_angle(randf() * TAU) * speed_units * BioArt.UNIT * randf_range(0.4, 1.0)
		fx.size_px = size_units * BioArt.UNIT * randf_range(0.6, 1.2)
		fx.end_scale = 0.05
		root.add_child(fx)
		fx.global_position = pos


static func arc(origin: Vector2, direction: Vector2, range_units: float, half_angle_degrees: float, color: Color) -> void:
	if root == null:
		return
	var fx := BioFxLife.new()
	fx.kind = BioFxLife.Kind.ARC
	fx.color = color
	fx.life = 0.22
	var base := direction.angle()
	var count := 18
	for i in count:
		var a := base + deg_to_rad(lerpf(-half_angle_degrees, half_angle_degrees, i / float(count - 1)))
		fx.points.append(origin + Vector2.from_angle(a) * range_units * BioArt.UNIT)
	root.add_child(fx)
	fx.global_position = Vector2.ZERO


static func ring(pos: Vector2, radius_units: float, color: Color) -> void:
	if root == null:
		return
	var fx := BioFxLife.new()
	fx.kind = BioFxLife.Kind.RING
	fx.color = color
	fx.life = 0.35
	fx.start_scale = 0.6
	fx.end_scale = 1.8
	var count := 28
	for i in count + 1:
		fx.points.append(Vector2.from_angle(i * TAU / count) * radius_units * BioArt.UNIT)
	root.add_child(fx)
	fx.global_position = pos
