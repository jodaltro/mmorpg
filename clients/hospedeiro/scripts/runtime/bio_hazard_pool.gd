class_name BioHazardPool
extends Area2D
## A pool on the floor of a dungeon (necrotic tissue, spilled bile): it does not go away, and it hurts the membrane of whoever stands in it.
## Enemies walk through it unharmed, so it is a place to pull them across, not a place to stand.

const DPS := 3.2

var radius_units := 1.0
var color := Color(0.6, 0.95, 0.3)

var _seed := randf() * 10.0
var _inside: Array[BioCellActor] = []


func configure(p_radius_units: float, p_color: Color) -> void:
	radius_units = p_radius_units
	color = p_color


func _ready() -> void:
	collision_layer = 0
	collision_mask = BioCellActor.LAYER_COMBATANT
	z_index = -4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_units * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(body: Node) -> void:
		var cell := body as BioCellActor
		if cell != null and cell.combatant.actor.team == BioActor.Team.CELL and not _inside.has(cell):
			_inside.append(cell))
	body_exited.connect(func(body: Node) -> void: _inside.erase(body as BioCellActor))
	material = BioArt.additive()


func _process(delta: float) -> void:
	for cell in _inside:
		if is_instance_valid(cell) and cell.is_active() and cell.combatant.actor.vitals.is_alive():
			cell.combatant.actor.vitals.take_damage(DPS * delta)
	queue_redraw()


func _draw() -> void:
	var r := radius_units * BioArt.UNIT
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003 + _seed)
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r * 1.25, Vector2.ONE * r * 2.5), false, Color(color.r, color.g, color.b, 0.22 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, r * (0.92 + 0.04 * pulse), 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.55), 2.0, true)
