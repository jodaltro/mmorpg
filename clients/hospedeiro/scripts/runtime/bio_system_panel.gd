class_name BioSystemPanel
extends CanvasLayer
## The "System" window: connection and region (top-left), the active quest (top-right), a call that is waiting for an answer, the
## body's states (fever, sleep), the feed of what happened and the action menu (E). Shows only what the engine's view says; decides
## nothing. A call (a quest offered by someone) is a compact card in the corner, answered with Y and N or a click.

signal offer_clicked(accepted: bool)
signal menu_chosen(index: int)

const FEED_LINES := 5
const FEED_SECONDS := 16.0
const MENU_SIZE := 9
const COLUMN_WIDTH := 300.0

var offer_key := ""
var menu_open := false
var menu_items: Array = []  # affordances as returned by the engine
var tray: BioCallTray

var _status: Label
var _region: Label
var _states: Label
var _column: VBoxContainer
var _tracker: PanelContainer
var _tracker_head: Label
var _tracker_title: Label
var _tracker_goal: Label
var _card: PanelContainer
var _card_head: Label
var _card_title: Label
var _card_goal: Label
var _card_reward: Label
var _offer: Dictionary = {}
var _caller := ""
var _feed_box: VBoxContainer
var _feed_width := 520.0
var _feed_max := FEED_LINES
var _touch := false
var _dim: ColorRect  # touch: the call is answered in a card at the centre, over a dimmed screen
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

	_column = VBoxContainer.new()
	_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_column.offset_left = -24.0 - COLUMN_WIDTH
	_column.offset_right = -24.0
	_column.offset_top = 92.0
	_column.add_theme_constant_override("separation", 10)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	_tracker = _surface(BioUi.BG, BioArt.with_alpha(BioUi.KIND_COLOR["quest"], 0.35))
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 3)
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.add_child(tbox)
	_tracker_head = BioUi.label("", BioUi.FS_SMALL, BioArt.with_alpha(BioUi.KIND_COLOR["quest"], 0.95))
	tbox.add_child(_tracker_head)
	_tracker_title = BioUi.wrapped("", BioUi.FS_BODY, BioUi.TEXT)
	tbox.add_child(_tracker_title)
	_tracker_goal = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.MUTED)
	tbox.add_child(_tracker_goal)
	_tracker.visible = false
	_column.add_child(_tracker)

	_card = _surface(BioUi.BG_RAISED, BioArt.with_alpha(BioUi.KIND_COLOR["quest"], 0.8))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 5)
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(cbox)
	_card_head = BioUi.label("", BioUi.FS_SMALL, BioArt.with_alpha(BioUi.KIND_COLOR["quest"], 0.98))
	cbox.add_child(_card_head)
	_card_title = BioUi.wrapped("", BioUi.FS_HEAD, BioUi.TEXT)
	cbox.add_child(_card_title)
	_card_goal = BioUi.wrapped("", BioUi.FS_BODY, BioUi.MUTED)
	cbox.add_child(_card_goal)
	_card_reward = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.GOOD)
	cbox.add_child(_card_reward)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	cbox.add_child(buttons)
	var accept := BioUi.button("Aceitar   Y", "primary")
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(func() -> void: offer_clicked.emit(true))
	buttons.add_child(accept)
	var refuse := BioUi.button("Recusar   N", "ghost")
	refuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refuse.pressed.connect(func() -> void: offer_clicked.emit(false))
	buttons.add_child(refuse)
	_card.visible = false
	_column.add_child(_card)

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


## On a touch screen the corners belong to the controls: the feed is three short lines between them, and the card of a call sits above
## them (so its buttons can be pressed where the controls overlap it).
func set_touch(on: bool) -> void:
	if not on:
		return
	_touch = true
	_status.visible = false
	_region.position = Vector2(28, 90)
	_region.add_theme_font_size_override("font_size", 12)
	_states.offset_top = 14
	_states.offset_bottom = 36
	layer = 13
	_column.remove_child(_card)  # the card of a call would sit on the attack button: here it is a chip, and opens at the centre
	var modal := CanvasLayer.new()
	modal.layer = 24
	add_child(modal)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_show_card(false))  # a tap outside is "later": the chip stays
	modal.add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(centre)
	_card.custom_minimum_size.x = 420.0
	centre.add_child(_card)
	_feed_max = 3
	_feed_width = 260.0
	_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)  # the mission under the bars, out of the way of the right thumb
	_column.offset_left = 28.0
	_column.offset_right = 28.0 + 260.0
	_column.offset_top = 180.0
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
		var world := get_parent().get_parent() as BioWorld
		_feed_box.visible = world.touch != null and world.touch.menu_open
		_column.visible = world.touch != null and world.touch.menu_open


func _surface(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", BioUi.style(bg, border, 10, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func set_status(online: bool, tick: int) -> void:
	_status.text = ("● conectado ao Hospedeiro  ·  tick %d" % tick) if online else "○ offline  ·  o corpo segue sem o motor"
	_status.add_theme_color_override("font_color", BioArt.with_alpha(BioUi.GOOD if online else BioUi.WARN, 0.6))


func set_region(region: StringName) -> void:
	_region.text = BioBodyMap.NAMES.get(region, String(region))


func set_active(quest: Dictionary) -> void:
	_tracker.visible = not quest.is_empty()
	if quest.is_empty():
		return
	_tracker_head.text = "MISSÃO  ·  rank %s" % str(quest.get("rank", "-"))
	_tracker_title.text = str(quest.get("title", ""))
	_tracker_goal.text = str(quest.get("objective", quest.get("desc", "")))


func set_states(states: Array[String]) -> void:
	_states.text = "  ·  ".join(states)


func show_offer(quest: Dictionary, giver_name: String) -> void:
	offer_key = str(quest.get("key", ""))
	_offer = quest
	_caller = "SISTEMA" if giver_name.is_empty() else "%s chama" % giver_name
	_refresh_offer()


func hide_offer() -> void:
	offer_key = ""
	_offer = {}
	_refresh_offer()


## True when the card is on screen: only then do Y and N answer.
func is_offer_visible() -> bool:
	return _card.visible


func has_offer() -> bool:
	return not offer_key.is_empty()


func offer_text() -> String:
	return "%s\n%s\n%s\n%s" % [_card_head.text, _card_title.text, _card_goal.text, _card_reward.text]


func _show_card(on: bool) -> void:
	_card.visible = on
	if _dim != null:
		_dim.visible = on


## Touch: the chip was tapped, the call opens at the centre.
func open_offer() -> void:
	if not offer_key.is_empty():
		_show_card(true)


func _refresh_offer() -> void:
	if _card == null:
		return
	if offer_key.is_empty():
		_show_card(false)
		if tray != null:
			tray.clear_call("quest")
		return
	var rank := str(_offer.get("rank", "-"))
	_card_head.text = "%s  ·  rank %s" % [_caller, rank]
	_card_title.text = str(_offer.get("title", ""))
	_card_goal.text = str(_offer.get("objective", _offer.get("desc", "")))
	_card_reward.text = "Recompensa: %s" % str(_offer.get("reward", "-"))
	if _touch:
		if tray != null:
			tray.set_call("quest", "quest", "Chamado: %s" % str(_offer.get("title", "")), "toque para responder")
		return
	_card.visible = true
	if tray != null:
		tray.clear_call("quest")


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
		child.queue_free()
	if menu_items.is_empty():
		_menu_rows.add_child(BioUi.label("Nada a fazer aqui agora.", BioUi.FS_BODY, BioUi.MUTED))
	for i in menu_items.size():
		var b := BioUi.button("%d   %s" % [i + 1, menu_items[i].get("title", menu_items[i].get("action", "?"))], "ghost")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		b.pressed.connect(func() -> void: menu_chosen.emit(index))
		_menu_rows.add_child(b)
	_menu_root.visible = true
	menu_open = true
	BioUi.set_modal(self, true)


func close_menu() -> void:
	_menu_root.visible = false
	menu_open = false
	menu_items = []
	BioUi.set_modal(self, false)
