class_name BioSystemPanel
extends CanvasLayer
## The "System" window: connection, region, the active quest, a pending call (accept Y / decline N),
## the body's states (fever, sleep), a feed of what happened and the action menu (E). Shows only what
## the engine's view says; decides nothing.

const FEED_LINES := 5
const MENU_SIZE := 9

var offer_key := ""
var menu_open := false
var menu_items: Array = []  # affordances as returned by the engine

var _status: Label
var _region: Label
var _active: Label
var _states: Label
var _offer_root: ColorRect
var _offer_text: Label
var _feed: Label
var _feed_lines: Array[String] = []
var _menu_root: ColorRect
var _menu_text: Label


func _ready() -> void:
	layer = 12
	_status = _label(Vector2(40, 58), Vector2(520, 22), 14, BioArt.with_alpha(Color.WHITE, 0.6))
	_region = _label(Vector2(40, 80), Vector2(520, 22), 13, BioArt.with_alpha(BioArt.AMBER, 0.75))

	_active = _label(Vector2(0, 0), Vector2(900, 52), 16, BioArt.with_alpha(Color.WHITE, 0.9))
	_active.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_active.offset_left = -450
	_active.offset_right = 450
	_active.offset_top = 20
	_active.offset_bottom = 72
	_active.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_states = _label(Vector2.ZERO, Vector2(400, 24), 15, BioArt.with_alpha(BioArt.CRIMSON.lerp(Color.WHITE, 0.3), 0.95))
	_states.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_states.offset_left = -200
	_states.offset_right = 200
	_states.offset_top = 74
	_states.offset_bottom = 98
	_states.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_offer_root = _box(Vector2(560, 196))
	_offer_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_offer_root.offset_left = -280
	_offer_root.offset_right = 280
	_offer_root.offset_top = 110
	_offer_root.offset_bottom = 306
	_offer_text = _inner_label(_offer_root, 15)
	_offer_root.visible = false

	_feed = _label(Vector2.ZERO, Vector2(560, 130), 13, BioArt.with_alpha(Color.WHITE, 0.7))
	_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.offset_left = -600
	_feed.offset_right = -40
	_feed.offset_top = -170
	_feed.offset_bottom = -40
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_menu_root = _box(Vector2(520, 300))
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu_root.offset_left = -260
	_menu_root.offset_right = 260
	_menu_root.offset_top = -150
	_menu_root.offset_bottom = 150
	_menu_text = _inner_label(_menu_root, 15)
	_menu_root.visible = false
	set_status(false, 0)


func set_status(online: bool, tick: int) -> void:
	_status.text = ("● CONECTADO AO HOSPEDEIRO  ·  tick %d" % tick) if online else "○ OFFLINE  ·  o corpo segue sem o motor"


func set_region(region: StringName) -> void:
	_region.text = BioBodyMap.NAMES.get(region, String(region))


func set_active(quest: Dictionary) -> void:
	if quest.is_empty():
		_active.text = ""
		return
	_active.text = "[%s] %s\n%s" % [quest.get("rank", "-"), quest.get("title", ""), quest.get("objective", quest.get("desc", ""))]


func set_states(states: Array[String]) -> void:
	_states.text = "  ·  ".join(states)


func show_offer(quest: Dictionary, giver_name: String) -> void:
	offer_key = str(quest.get("key", ""))
	var caller := "SISTEMA" if giver_name.is_empty() else "%s chama" % giver_name
	_offer_text.text = "%s  ·  rank %s\n%s\n\n%s\nRecompensa: %s\n\n[Y] aceitar      [N] recusar" % [
		caller, quest.get("rank", "-"), quest.get("title", ""),
		quest.get("objective", quest.get("desc", "")), quest.get("reward", "-")]
	_offer_root.visible = true


func hide_offer() -> void:
	offer_key = ""
	_offer_root.visible = false


func is_offer_visible() -> bool:
	return _offer_root.visible


func offer_text() -> String:
	return _offer_text.text


func push_feed(text: String) -> void:
	if text.is_empty() or _feed_lines.has(text):
		return  # rumours repeat; the feed keeps one copy
	_feed_lines.append(text)
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()
	_feed.text = "\n".join(_feed_lines)


func feed_text() -> String:
	return _feed.text


func open_menu(items: Array) -> void:
	menu_items = items.slice(0, MENU_SIZE)
	var lines: Array[String] = ["O QUE FAZER?   (E fecha)", ""]
	if menu_items.is_empty():
		lines.append("Nada a fazer aqui agora.")
	for i in menu_items.size():
		lines.append("%d.  %s" % [i + 1, menu_items[i].get("title", menu_items[i].get("action", "?"))])
	_menu_text.text = "\n".join(lines)
	_menu_root.visible = true
	menu_open = true


func close_menu() -> void:
	_menu_root.visible = false
	menu_open = false
	menu_items = []


func _label(pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _box(size: Vector2) -> ColorRect:
	var box := ColorRect.new()
	box.color = Color(0.03, 0.05, 0.11, 0.96)
	box.size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	return box


func _inner_label(box: ColorRect, font_size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 18
	l.offset_top = 14
	l.offset_right = -18
	l.offset_bottom = -14
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l
