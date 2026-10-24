class_name BioChargeRing
extends Node2D
## What the mast cell shows while it bleeds into a blast: the ring the blast will have, growing with what has been spent, and granules
## leaking out of the membrane. `fraction` (0..1) is how far the charge is; `radius_px` is the blast at the full charge.

var host: BioCellActor
var color := Color(1.0, 0.62, 0.2)
var radius_px := 200.0
var fraction := 0.0

var _age := 0.0


static func over(cell: BioCellActor, p_color: Color, full_radius_px: float) -> BioChargeRing:
	var r := BioChargeRing.new()
	r.host = cell
	r.color = p_color
	r.radius_px = full_radius_px
	r.z_index = 11
	r.material = BioArt.additive()
	cell.get_parent().add_child(r)
	r.global_position = cell.global_position
	return r


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(host):
		queue_free()
		return
	global_position = host.global_position
	queue_redraw()


func _draw() -> void:
	var shown := radius_px * (0.25 + 0.75 * fraction)
	var flick := 0.5 + 0.5 * sin(_age * (10.0 + 24.0 * fraction))
	draw_circle(Vector2.ZERO, shown, BioArt.with_alpha(color, 0.05 + 0.08 * fraction))
	draw_arc(Vector2.ZERO, shown, 0.0, TAU, 48, BioArt.with_alpha(color.lerp(Color.WHITE, 0.3), 0.35 + 0.4 * flick * fraction), 2.0 + 2.0 * fraction, true)
	for k in 12:  # the granules straining outwards
		var a := k * TAU / 12.0 + _age * 0.6
		var out := 24.0 + shown * 0.5 * fraction * (0.5 + 0.5 * sin(_age * 7.0 + k))
		draw_circle(Vector2.from_angle(a) * out, 3.0 + 2.0 * fraction, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.9))
