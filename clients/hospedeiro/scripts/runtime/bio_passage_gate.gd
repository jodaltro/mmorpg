class_name BioPassageGate
extends StaticBody2D
## A vessel that is closed to a cell without the gene that is its key: a membrane across the vessel that holds, and says what it
## asks for when the cell is near. It is removed the moment the engine says the passage is open.

var passage_id := ""
var hint := ""
var player: BioCellActor
var _half := 4.0  # px
var _dir := Vector2.RIGHT
var _t := 0.0


func configure(id: String, point: Vector2, dir: Vector2, half_width_units: float, requirement: String, who: BioCellActor) -> void:
	passage_id = id
	hint = requirement
	player = who
	position = point * BioArt.UNIT
	_dir = dir
	_half = (half_width_units + 1.4) * BioArt.UNIT
	collision_layer = BioCellActor.LAYER_WALL
	collision_mask = 0
	z_index = -2
	material = BioArt.additive()
	var shape := CollisionShape2D.new()
	var segment := SegmentShape2D.new()
	var n := dir.orthogonal()
	segment.a = -n * _half
	segment.b = n * _half
	shape.shape = segment
	add_child(shape)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var n := _dir.orthogonal()
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	var col := Color(1.0, 0.55, 0.3)
	draw_line(-n * _half, n * _half, BioArt.with_alpha(col, 0.18 + 0.1 * pulse), 26.0, true)
	draw_line(-n * _half, n * _half, BioArt.with_alpha(col, 0.7), 5.0, true)
	for i in 7:
		var f := (i + 0.5) / 7.0 * 2.0 - 1.0
		draw_circle(n * _half * f, 6.0 + 3.0 * pulse, BioArt.with_alpha(col, 0.5))
	if player != null and player.global_position.distance_to(global_position) < 14.0 * BioArt.UNIT:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-190.0, -_half - 26.0), hint, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 16, Color(1.0, 0.85, 0.7, 0.95))
