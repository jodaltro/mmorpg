class_name BioSignMarker
extends Node2D
## A trace of something hidden that the engine says this player can make out here (a hot capillary,
## a foreign glow). It shows the effect, never the cause; examining it is an intention sent to the engine.

var sign_id := ""
var _glow: Sprite2D
var _label: Label
var _seed := randf() * 10.0


func configure(id: String, look: String, pos_px: Vector2, tint: Color) -> void:
	sign_id = id
	position = pos_px
	_glow = BioArt.make_glow(BioArt.with_alpha(tint, 0.55), 3.2, 4)
	add_child(_glow)
	_label = Label.new()
	_label.text = look
	_label.position = Vector2(-170, 44)
	_label.size = Vector2(340, 40)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", BioArt.with_alpha(tint.lerp(Color.WHITE, 0.5), 0.75))
	add_child(_label)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	_glow.scale = Vector2.ONE * (3.2 * BioArt.UNIT / 128.0) * (1.0 + 0.18 * sin(t * 2.4))
