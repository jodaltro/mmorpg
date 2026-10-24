class_name BioAnchor
extends Node2D
## The place the NK cell remembers. It stays where it was dropped, with a ghost of the cell and the life it had then, and a ring that
## closes as the time runs out; the runner calls the cell back to it (see BioKitNk).

var color := Color(0.7, 0.9, 1.0)
var life_fraction := 1.0  # the share of its membrane the cell had when it left the anchor
var delay := 3.2

var _age := 0.0
var _seed := randf() * 10.0


static func drop(parent: Node, pos: Vector2, p_color: Color, p_delay: float, life: float) -> BioAnchor:
	var a := BioAnchor.new()
	a.position = pos
	a.color = p_color
	a.delay = p_delay
	a.life_fraction = life
	parent.add_child(a)
	return a


func _ready() -> void:
	z_index = 4
	material = BioArt.additive()
	BioPfx.ring_burst(BioFx.root, global_position, color, 50.0, 18, 0.4, 8.0)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var left := clampf(1.0 - _age / maxf(delay, 0.1), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * (4.0 + 10.0 * (1.0 - left)))
	draw_circle(Vector2.ZERO, 26.0, BioArt.with_alpha(color, 0.10 + 0.06 * pulse))
	draw_arc(Vector2.ZERO, 34.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), 0.9), 2.6, true)  # the time left
	draw_arc(Vector2.ZERO, 22.0, _age, _age + 2.4, 18, BioArt.with_alpha(color, 0.55), 1.6, true)
	for k in 4:  # the ghost of the cell: four marks where it stood
		var a := k * TAU / 4.0 + PI * 0.25
		draw_line(Vector2.from_angle(a) * 12.0, Vector2.from_angle(a) * (17.0 + 3.0 * pulse), BioArt.with_alpha(Color.WHITE, 0.8), 1.8, true)
	draw_arc(Vector2.ZERO, 11.0, -PI * 0.5, -PI * 0.5 + TAU * life_fraction, 24, BioArt.with_alpha(Color(0.5, 1.0, 0.6), 0.9), 3.0, true)  # the life it had

