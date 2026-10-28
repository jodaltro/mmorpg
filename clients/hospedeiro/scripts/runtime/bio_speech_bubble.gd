class_name BioSpeechBubble
extends PanelContainer
## A small balloon above a cell with one short line. It fades in and out by itself, never takes the mouse, and only a few exist at once
## (the preset says how many), so the screen reads as a body at work and not as a wall of text.

const SHOW_SECONDS := 3.4

static var live := 0

var _label: Label
var _left := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9
	visible = false
	add_theme_stylebox_override("panel", BioUi.style(Color(0.02, 0.05, 0.09, 0.82), BioArt.with_alpha(Color.WHITE, 0.35), 9, 6))
	_label = BioUi.wrapped("", 12, Color(0.95, 1.0, 1.0))
	_label.custom_minimum_size.x = 150.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## False when the screen already has as many balloons as the preset allows.
func say(text: String, limit: int, text_scale: float = 1.0) -> bool:
	if _left > 0.0 or live >= limit or text.is_empty():
		return false
	_label.text = text
	_label.add_theme_font_size_override("font_size", roundi(12.0 * text_scale))
	_left = SHOW_SECONDS
	live += 1
	visible = true
	modulate.a = 0.0
	reset_size()
	position = Vector2(-size.x * 0.5, position.y)
	return true


func is_speaking() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	modulate.a = clampf(minf(_left, SHOW_SECONDS - _left) / 0.4, 0.0, 1.0)
	if _left <= 0.0:
		visible = false
		live = maxi(0, live - 1)


func _exit_tree() -> void:
	if _left > 0.0:
		live = maxi(0, live - 1)
		_left = 0.0
