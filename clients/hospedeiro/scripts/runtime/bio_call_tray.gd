class_name BioCallTray
extends CanvasLayer
## What asks for the player's attention, without taking it: small chips in the bottom-right corner (a mutation to choose, a body ready to
## differentiate). A chip never opens a window by itself: the player opens what it is about when they choose, with a click or the key
## shown on the chip.

signal chip_activated(key: String)

const CHIP_WIDTH := 300.0

var _box: VBoxContainer
var _chips := {}  # key -> {root, title, detail, hint}


func _ready() -> void:
	layer = 11
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_box.offset_left = -24.0 - CHIP_WIDTH
	_box.offset_right = -24.0
	_box.offset_bottom = -196.0  # above the feed
	_box.offset_top = -196.0
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.add_theme_constant_override("separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


## On a touch screen the corner belongs to the controls: the chips wait at the top, in the middle.
func set_touch(on: bool) -> void:
	if not on:
		return
	layer = 13
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_box.offset_left = 130
	_box.offset_right = 326
	_box.offset_top = 65.0
	_box.offset_bottom = 65.0
	_box.grow_vertical = Control.GROW_DIRECTION_END
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN


## Puts a chip up (or updates it). `hint` is the key that opens it; The player opens it when they choose.
func set_call(key: String, kind: String, title: String, detail: String, hint: String = "") -> void:
	if _chips.has(key):
		var c: Dictionary = _chips[key]
		c["title"].text = title
		c["detail_text"] = detail
		_paint(key)
		return
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(196 if BioPlatform.is_touch() else CHIP_WIDTH, 0)
	var color: Color = BioUi.KIND_COLOR.get(kind, BioUi.KIND_COLOR["info"])
	root.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioArt.with_alpha(color, 0.5), 9, 10))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(3, 14 if BioPlatform.is_touch() else 34)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title_label := BioUi.label(title, BioUi.FS_BODY, BioUi.TEXT)
	if BioPlatform.is_touch():
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.custom_minimum_size.x = 140
		title_label.add_theme_font_size_override("font_size", 10)

	texts.add_child(title_label)
	var detail_label := BioUi.label(detail, BioUi.FS_SMALL, BioUi.MUTED)
	texts.add_child(detail_label)
	detail_label.visible = not BioPlatform.is_touch()
	if not hint.is_empty():
		row.add_child(BioUi.keycap(hint))
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			chip_activated.emit(key))
	_box.add_child(root)
	_chips[key] = {"root": root, "title": title_label, "detail": detail_label, "detail_text": detail, "kind": kind}
	_paint(key)
	root.modulate.a = 0.0  # arrives quietly
	var tween := root.create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.35)


func clear_call(key: String) -> void:
	if not _chips.has(key):
		return
	var root: Control = _chips[key]["root"]
	_chips.erase(key)
	root.queue_free()


func has_call(key: String) -> bool:
	return _chips.has(key)


func call_keys() -> Array:
	return _chips.keys()


## What a chip says right now.
func chip_text(key: String) -> String:
	if not _chips.has(key):
		return ""
	var c: Dictionary = _chips[key]
	return "%s\n%s" % [c["title"].text, c["detail"].text]


func _paint(key: String) -> void:
	var c: Dictionary = _chips[key]
	c["detail"].text = c["detail_text"]
