class_name BioClot
extends StaticBody2D
## A clot of platelets and fibrin raised by an ability: a solid disc that enemies and shots cannot cross, that glows while it holds and
## crumbles when its time is up.

var radius_px := 0.8 * 48.0
var color := Color(0.6, 1.0, 0.85)
var duration := 6.0

var _age := 0.0
var _seed := randf() * 10.0


static func spawn(parent: Node, pos: Vector2, p_radius_units: float, p_duration: float, p_color: Color) -> BioClot:
	var c := BioClot.new()
	c.radius_px = p_radius_units * BioArt.UNIT
	c.duration = p_duration
	c.color = p_color
	c.position = pos
	parent.add_child(c)
	return c


func _ready() -> void:
	collision_layer = BioCellActor.LAYER_WALL
	collision_mask = 0
	z_index = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px
	shape.shape = circle
	add_child(shape)
	material = BioArt.additive()
	BioFx.burst(global_position, color, 8, 2.0, 0.3, 0.4)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var grow := clampf(_age / 0.2, 0.0, 1.0)
	var fade := clampf((duration - _age) / 0.8, 0.0, 1.0)
	var r := radius_px * grow
	var pulse := 0.5 + 0.5 * sin(_age * 3.0 + _seed)
	draw_circle(Vector2.ZERO, r * 1.35, BioArt.with_alpha(color, 0.08 * fade))
	draw_circle(Vector2.ZERO, r, BioArt.with_alpha(color.darkened(0.6), 0.85 * fade))
	for k in 7:  # platelets and the threads of fibrin that hold them
		var a := k * TAU / 7.0 + _seed
		var tip := Vector2.from_angle(a) * r * (0.55 + 0.12 * sin(_age * 2.0 + k))
		draw_line(Vector2.ZERO, tip, BioArt.with_alpha(color, 0.55 * fade), 1.5, true)
		draw_circle(tip, 3.0, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.9 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, BioArt.with_alpha(color.lerp(Color.WHITE, 0.3), (0.55 + 0.35 * pulse) * fade), 2.4, true)
