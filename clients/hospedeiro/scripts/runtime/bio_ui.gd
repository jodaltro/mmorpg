class_name BioUi
extends RefCounted
## The look of every window: one palette, one scale of type, flat dark surfaces with a hairline border. Windows ask this for their
## styles instead of inventing colours, so the whole interface speaks with one voice. Also knows whether a window that takes the
## mouse is open, so the cell does not attack by clicking on a button.

const BG := Color(0.02, 0.035, 0.08, 0.93)
const BG_RAISED := Color(0.05, 0.08, 0.15, 0.96)
const BG_SUNK := Color(0.01, 0.02, 0.05, 0.7)
const LINE := Color(0.4, 0.75, 1.0, 0.22)
const LINE_STRONG := Color(0.4, 0.85, 1.0, 0.65)
const TEXT := Color(0.93, 0.97, 1.0, 0.96)
const MUTED := Color(0.62, 0.73, 0.86, 0.78)
const ACCENT := Color(0.35, 0.85, 1.0)
const GOOD := Color(0.42, 1.0, 0.7)
const WARN := Color(1.0, 0.74, 0.32)
const BAD := Color(1.0, 0.42, 0.48)

const KIND_COLOR := {"quest": Color(1.0, 0.76, 0.3), "mutation": Color(0.92, 0.35, 0.9), "lineage": Color(0.35, 0.85, 1.0), "info": Color(0.62, 0.73, 0.86)}

const FS_TITLE := 20
const FS_HEAD := 15
const FS_BODY := 14
const FS_SMALL := 12

static var _modals: Dictionary = {}  # instance id of an open window -> true


## A window that takes the mouse says so while it is open.
static func set_modal(window: Object, open: bool) -> void:
	if open:
		_modals[window.get_instance_id()] = true
	else:
		_modals.erase(window.get_instance_id())


## A text box has the focus: the keys are letters now, not commands.
static func typing() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var focus := (loop as SceneTree).root.gui_get_focus_owner()
		return focus is LineEdit or focus is TextEdit
	return false


static func captures_input() -> bool:
	for id in _modals.keys():
		if is_instance_id_valid(id):
			return true
		_modals.erase(id)
	return false


static func style(bg: Color = BG, border: Color = LINE, radius: int = 10, margin: int = 14, border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size: int = FS_BODY, color: Color = TEXT) -> Label:
	if BioPlatform.is_touch():
		size = maxi(10, roundi(size * 0.9))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrapped(text: String, size: int = FS_BODY, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10.0  # lets the container give it the width; without a width a wrapping label is one tall column
	return l


## A button in the house style. kind: "primary", "ghost" or "danger".
static func button(text: String, kind: String = "ghost") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keys (space, enter) must never press it
	b.add_theme_font_size_override("font_size", FS_BODY)
	b.custom_minimum_size = Vector2(0, 32)
	var base := {"primary": Color(0.12, 0.38, 0.55), "ghost": Color(0.08, 0.13, 0.24), "danger": Color(0.4, 0.1, 0.16)}.get(kind, Color(0.08, 0.13, 0.24)) as Color
	b.add_theme_stylebox_override("normal", style(base, LINE, 7, 10))
	b.add_theme_stylebox_override("hover", style(base.lightened(0.18), LINE_STRONG, 7, 10))
	b.add_theme_stylebox_override("pressed", style(base.lightened(0.32), LINE_STRONG, 7, 10))
	b.add_theme_stylebox_override("disabled", style(Color(0.05, 0.07, 0.11, 0.8), Color(1, 1, 1, 0.06), 7, 10))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))
	return b


## A key cap: the key to press, small and boxed ("Y", "G").
static func keycap(key: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.3), 4, 4))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(key, FS_SMALL, TEXT)
	box.add_child(l)
	return box


static func rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"rara", "rare":
			return Color(0.45, 0.7, 1.0)
		"epica", "épica", "epic":
			return Color(0.8, 0.5, 1.0)
		"lendaria", "lendária", "legendary":
			return Color(1.0, 0.75, 0.3)
		"incomum", "uncommon":
			return Color(0.5, 1.0, 0.65)
	return Color(0.75, 0.82, 0.92)


## A thin horizontal gauge (0..1) drawn by a plain Control.
static func gauge(fraction: float, color: Color, height: float = 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.08))
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * clampf(fraction, 0.0, 1.0), c.size.y)), color))
	return c
