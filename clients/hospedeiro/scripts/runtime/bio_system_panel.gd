class_name BioSystemPanel
extends CanvasLayer
## The "System" window: connection and region (top-left), the body's states (fever, sleep), the feed of what happened and the action
## menu (E). Shows only what the engine's view says; decides nothing. There are no missions in the Hospedeiro: what the player has to
## do is the crisis the body is living (see BioLivingHud).

signal menu_chosen(index: int)

const FEED_LINES := 5
const FEED_SECONDS := 16.0
const MENU_SIZE := 9

var menu_open := false
var menu_items: Array = []  # affordances as returned by the engine
var tray: BioCallTray

var _status: Label
var _region: Label
var _states: Label
var _feed_box: VBoxContainer
var _feed_width := 520.0
var _feed_max := FEED_LINES
var _touch := false
var _action_modal: BioModal
var _feed_lines: Array[String] = []
var _feed_born: Array[float] = []
var _feed_labels: Array[Label] = []
var _menu_root: PanelContainer
var _menu_rows: VBoxContainer


func _ready() -> void:
	layer = 12
	_status = BioUi.label("", 11, BioArt.with_alpha(Color.WHITE, 0.5))
	_status.position = Vector2(28, 42)
	add_child(_status)
	_region = BioUi.label("", 14, BioArt.with_alpha(BioArt.AMBER, 0.85))
	_region.position = Vector2(28, 58)
	add_child(_region)

	_states = BioUi.label("", 14, BioArt.with_alpha(BioArt.CRIMSON.lerp(Color.WHITE, 0.3), 0.95))
	_states.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_states.offset_left = -200
	_states.offset_right = 200
	_states.offset_top = 76
	_states.offset_bottom = 98
	_states.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_states)

	_feed_box = VBoxContainer.new()
	_feed_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed_box.offset_left = -24.0 - 520.0
	_feed_box.offset_right = -24.0
	_feed_box.offset_bottom = -32.0
	_feed_box.offset_top = -32.0
	_feed_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed_box.alignment = BoxContainer.ALIGNMENT_END
	_feed_box.add_theme_constant_override("separation", 3)
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed_box)

	_menu_root = PanelContainer.new()
	_menu_root.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 18))
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu_root.custom_minimum_size = Vector2(460, 0)
	_menu_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 6)
	_menu_root.add_child(mbox)
	var head := HBoxContainer.new()
	mbox.add_child(head)
	var mtitle := BioUi.label("O QUE FAZER?", BioUi.FS_HEAD, BioUi.ACCENT)
	mtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(mtitle)
	head.add_child(BioUi.keycap("E"))
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 5)
	mbox.add_child(_menu_rows)
	_menu_root.visible = false
	add_child(_menu_root)
	set_status(false, 0)


## On a touch screen the corners belong to the controls: the feed is three short lines between them.
func set_touch(on: bool) -> void:
	if not on:
		return
	_touch = true
	_status.visible = false
	_region.position = Vector2(130, 42)
	_region.add_theme_font_size_override("font_size", 12)
	_states.offset_top = 14
	_states.offset_bottom = 36
	layer = 13
	var modal := CanvasLayer.new()
	modal.layer = 24
	add_child(modal)
	_action_modal = BioModal.new()
	_action_modal.max_size = Vector2(560, 430)
	modal.add_child(_action_modal)
	_action_modal.build("O QUE FAZER?")
	_action_modal.dismissed.connect(close_menu)
	_menu_rows.reparent(_action_modal.content)
	_feed_max = 3
	_feed_width = 260.0
	_feed_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_feed_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	get_viewport().size_changed.connect(_layout_touch)
	_layout_touch()


func _layout_touch() -> void:
	var w := get_viewport().get_visible_rect().size.x
	_feed_box.offset_left = w * 0.30
	_feed_box.offset_right = w * 0.30 + _feed_width
	_feed_box.offset_top = -104.0
	_feed_box.offset_bottom = -104.0


func _process(_delta: float) -> void:
	_fade_feed()
	if _touch:
		_feed_box.visible = false


func set_status(online: bool, tick: int) -> void:
	_status.text = ("● conectado ao Hospedeiro  ·  tick %d" % tick) if online else "○ offline  ·  o corpo segue sem o motor"
	_status.add_theme_color_override("font_color", BioArt.with_alpha(BioUi.GOOD if online else BioUi.WARN, 0.6))


func set_region(region: StringName) -> void:
	_region.text = BioBodyMap.NAMES.get(region, String(region))


func set_states(states: Array[String]) -> void:
	_states.text = "  ·  ".join(states)


func push_feed(text: String) -> void:
	if text.is_empty() or _feed_lines.has(text):
		return  # rumours repeat; the feed keeps one copy
	_feed_lines.append(text)
	_feed_born.append(BioClock.now())
	var l := BioUi.wrapped(text, BioUi.FS_SMALL + 1, Color(1, 1, 1, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = _feed_width
	if _touch:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 4)
	_feed_box.add_child(l)
	_feed_labels.append(l)
	while _feed_lines.size() > _feed_max:
		_drop_feed(0)


func feed_text() -> String:
	return "\n".join(_feed_lines)


func _drop_feed(index: int) -> void:
	_feed_lines.remove_at(index)
	_feed_born.remove_at(index)
	_feed_labels.pop_at(index).queue_free()


## Old lines fade away by themselves: the feed is a trace, not a log.
func _fade_feed() -> void:
	var now := BioClock.now()
	var i := 0
	while i < _feed_lines.size():
		var age := now - _feed_born[i]
		if age > FEED_SECONDS:
			_drop_feed(i)
			continue
		_feed_labels[i].modulate.a = clampf((FEED_SECONDS - age) / 3.0, 0.0, 1.0)
		i += 1


func open_menu(items: Array) -> void:
	menu_items = items.slice(0, MENU_SIZE)
	for child in _menu_rows.get_children():
		_menu_rows.remove_child(child)
		child.queue_free()
	if menu_items.is_empty():
		_menu_rows.add_child(BioUi.label("Nada a fazer aqui agora.", BioUi.FS_BODY, BioUi.MUTED))
	for i in menu_items.size():
		var b := BioUi.button("%d   %s" % [i + 1, menu_items[i].get("title", menu_items[i].get("action", "?"))], "ghost")
		if _touch:
			b.text = str(menu_items[i].get("title", menu_items[i].get("action", "?")))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		b.pressed.connect(func() -> void:
			menu_chosen.emit(index)
			close_menu())
		_menu_rows.add_child(b)
	menu_open = true
	if _action_modal != null:
		_action_modal.present(self)
		_action_modal.scroll.scroll_vertical = 0
	else:
		_menu_root.visible = true
		BioUi.present(self)


func close_menu() -> void:
	_menu_root.visible = false
	menu_open = false
	menu_items = []
	if _action_modal != null:
		_action_modal.hide_modal()
	BioUi.set_modal(self, false)


func close() -> void:
	close_menu()
