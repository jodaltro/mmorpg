class_name BioResident
extends Node2D
## A resident cell of the body seen through the engine (a quest giver, a neighbour). Purely visual:
## who it is and what it does come from the engine's view, never from this node.

const LOOKS := {
	"estroma": [BioArt.AMBER, Color(0.85, 0.5, 0.2), 0.75, 0],
	"neva": [Color(0.92, 0.95, 1.0), Color(0.6, 0.7, 0.95), 0.6, 0],
	"rubra": [Color(1.0, 0.25, 0.25), Color(0.7, 0.05, 0.12), 0.55, 0],
	"dendra": [Color(0.75, 0.45, 1.0), Color(0.45, 0.2, 0.9), 0.65, 7],
}

var resident_id := ""
var _label: Label
var _body: BioCellBody
var _home := Vector2.ZERO
var _seed := randf() * 10.0


func configure(id: String, display_name: String, home_px: Vector2) -> void:
	resident_id = id
	_home = home_px
	position = home_px
	var look: Array = LOOKS.get(id, [BioArt.JADE, BioArt.DEEP_BLUE, 0.6, 0])
	_body = BioCellBody.new()
	_body.configure(float(look[2]), look[0], look[1], int(look[3]), 0.25, 0.2, 7)
	add_child(_body)
	_label = Label.new()
	_label.text = display_name
	_label.position = Vector2(-120, -float(look[2]) * BioArt.UNIT - 34)
	_label.size = Vector2(240, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", BioArt.with_alpha(look[0], 0.85))
	add_child(_label)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	position = _home + Vector2(sin(t * 0.4), cos(t * 0.33)) * 0.6 * BioArt.UNIT
