class_name BioPortalPair
extends Node2D
## Two openings in the tissue, a vessel of lymph between them: the cell that steps into one comes out of the other. They close after a
## while, and a new pair closes the old one. (Only the cell uses them: the enemies do not know where they lead.)

const REACH_UNITS := 0.9

static var current: BioPortalPair

var host: BioCellActor
var a := Vector2.ZERO
var b := Vector2.ZERO
var color := Color(0.8, 0.6, 1.0)
var seconds := 10.0

var _age := 0.0
var _ready_a := false  # a door works only after the cell has left it once
var _ready_b := false


static func open(parent: Node, owner: BioCellActor, at_a: Vector2, at_b: Vector2, p_seconds: float, p_color: Color) -> BioPortalPair:
	if is_instance_valid(current):
		current.queue_free()
	var p := BioPortalPair.new()
	p.host = owner
	p.a = at_a
	p.b = at_b
	p.seconds = p_seconds
	p.color = p_color
	p.z_index = 6
	p.material = BioArt.additive()
	parent.add_child(p)
	current = p
	BioPfx.ring_burst(BioFx.root, at_a, p_color, 50.0, 18, 0.4, 8.0)
	BioPfx.ring_burst(BioFx.root, at_b, p_color, 50.0, 18, 0.4, 8.0)
	return p


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= seconds or not is_instance_valid(host):
		queue_free()
		return
	var reach := REACH_UNITS * BioArt.UNIT
	var near_a := host.global_position.distance_to(a) <= reach
	var near_b := host.global_position.distance_to(b) <= reach
	if not near_a:
		_ready_a = true  # a door only works once the cell has stepped out of it: opening one under the cell's feet must not throw it
	if not near_b:
		_ready_b = true
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	if near_a and _ready_a:
		from = a
		to = b
		_ready_a = false
		_ready_b = false
	elif near_b and _ready_b:
		from = b
		to = a
		_ready_a = false
		_ready_b = false
	else:
		return
	var leaving := (host.global_position - from).normalized() if host.global_position.distance_to(from) > 4.0 else host.velocity.normalized()
	host.global_position = to + leaving * (reach + 6.0)
	BioPfx.burst(BioFx.root, from, color, 12, 160.0, 0.4, 8.0)
	BioPfx.burst(BioFx.root, to, color.lerp(Color.WHITE, 0.4), 14, 200.0, 0.45, 9.0)
	BioFx.shake(0.06)


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fade := clampf((seconds - _age) / 0.6, 0.0, 1.0) * clampf(_age / 0.2, 0.0, 1.0)
	var la := to_local(a)
	var lb := to_local(b)
	var mid := (la + lb) * 0.5 + (lb - la).orthogonal().normalized() * 30.0
	var pts := PackedVector2Array()
	for k in 25:  # a thread of light between them, the vessel
		var f := k / 24.0
		pts.append(la.lerp(mid, f).lerp(mid.lerp(lb, f), f))
	draw_polyline(pts, BioArt.with_alpha(color, 0.14 * fade), 3.0, true)
	for end in [la, lb]:
		var r := REACH_UNITS * BioArt.UNIT
		draw_circle(end, r, BioArt.with_alpha(color, 0.10 * fade))
		for k in 3:
			var ph := fposmod(_age * 0.9 + k / 3.0, 1.0)
			draw_arc(end, r * (1.0 - ph * 0.85), _age * 2.0 + k, _age * 2.0 + k + 4.0, 18, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), (1.0 - ph) * 0.9 * fade), 2.0, true)
		draw_circle(end, 4.0, BioArt.with_alpha(Color.WHITE, 0.9 * fade))
