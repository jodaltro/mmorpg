class_name BioCallTray
extends CanvasLayer
## What asks for the player's attention, without taking it: small chips in the bottom-right corner (a mutation to choose, a body ready to
## differentiate, a call that arrived in the middle of a fight). A chip never opens a window by itself. While the cell is fighting
## the chips wait, dimmed, and say so; when it is calm, a click (or the key shown on the chip) opens what they are about.

signal chip_activated(key: String)

const CHIP_WIDTH := 300.0

var _box: VBoxContainer
var _chips := {}  # key -> {root, title, detail, calm_detail, hint}
var _calm := true


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


## Puts a chip up (or updates it). `hint` is the key that opens it; `waiting` is what it says while the cell is fighting.
func set_call(key: String, kind: String, title: String, detail: String, hint: String = "", waiting: String = "disponível após o combate") -> void:
	if _chips.has(key):
		var c: Dictionary = _chips[key]
		c["title"].text = title
		c["detail_text"] = detail
		c["waiting_text"] = waiting
		_paint(key)
		return
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CHIP_WIDTH, 0)
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
	dot.custom_minimum_size = Vector2(4, 34)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title_label := BioUi.label(title, BioUi.FS_BODY, BioUi.TEXT)
	texts.add_child(title_label)
	var detail_label := BioUi.label(detail, BioUi.FS_SMALL, BioUi.MUTED)
	texts.add_child(detail_label)
	if not hint.is_empty():
		row.add_child(BioUi.keycap(hint))
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			chip_activated.emit(key))
	_box.add_child(root)
	_chips[key] = {"root": root, "title": title_label, "detail": detail_label, "detail_text": detail, "waiting_text": waiting, "kind": kind}
	_paint(key)
	root.modulate.a = 0.0  # arrives quietly
	var tween := root.create_tween()
	tween.tween_property(root, "modulate:a", 1.0 if _calm else 0.62, 0.35)


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


## What a chip says right now (the waiting text while the cell fights).
func chip_text(key: String) -> String:
	if not _chips.has(key):
		return ""
	var c: Dictionary = _chips[key]
	return "%s\n%s" % [c["title"].text, c["detail"].text]


## While the cell fights the chips wait, dimmed.
func set_calm(calm: bool) -> void:
	if calm == _calm:
		return
	_calm = calm
	for key in _chips:
		_paint(key)
		var root: Control = _chips[key]["root"]
		root.modulate.a = 1.0 if calm else 0.62


func _paint(key: String) -> void:
	var c: Dictionary = _chips[key]
	c["detail"].text = c["detail_text"] if _calm else c["waiting_text"]
