class_name BioHalo
extends Node2D
## A ring of glowing granules that circles a cell while one of its states lasts (the mast cell's cascade). It follows the cell and goes
## when `until` says so; `fuller` makes it denser as the state grows.

var host: BioCellActor
var color := Color(1.0, 0.62, 0.2)
var radius_px := 46.0
var until := Callable()  # returns true while the halo should stay
var count_source := Callable()  # optional: how many granules to show (e.g. charges left)

var _age := 0.0


static func ring(cell: BioCellActor, p_color: Color, while_true: Callable) -> BioHalo:
	var h := BioHalo.new()
	h.host = cell
	h.color = p_color
	h.until = while_true
	h.z_index = 11
	h.material = BioArt.additive()
	cell.get_parent().add_child(h)
	h.global_position = cell.global_position
	return h


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(host) or not until.is_valid() or not bool(until.call()):
		queue_free()
		return
	global_position = host.global_position
	queue_redraw()


func _draw() -> void:
	var r := radius_px * host.scale.x
	var n := int(count_source.call()) if count_source.is_valid() else 9
	for k in n:
		var a := _age * 1.8 + k * TAU / float(maxi(n, 1))
		var wobble := 1.0 + 0.12 * sin(_age * 5.0 + k * 2.0)
		var p := Vector2.from_angle(a) * r * wobble
		draw_circle(p, 5.0, BioArt.with_alpha(color, 0.3))
		draw_circle(p, 2.6, BioArt.with_alpha(color.lerp(Color.WHITE, 0.6), 0.95))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, BioArt.with_alpha(color, 0.18), 1.4, true)
