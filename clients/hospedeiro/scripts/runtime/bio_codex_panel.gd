class_name BioCodexPanel
extends CanvasLayer
## The codex of the body (key B): what the cell has learned of the places, the invaders, the body itself and the secrets it found.
## Locked entries are only a "???" under their heading, so the player sees how much is still out there. Also lists the places the
## cell has adapted to by living in them. It scrolls with the mouse wheel.

const KINDS := [["regiao", "LUGARES"], ["patogeno", "INVASORES"], ["corpo", "O CORPO"], ["segredo", "SEGREDOS"]]

var entries: Array = []
var adapted: Array = []
var _panel: Control
var _scroll := 0
var _content_height := 0.0


func configure() -> void:
	layer = 13
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.draw.connect(_paint)
	add_child(_panel)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_scroll = 0
	_panel.queue_redraw()


func set_data(codex: Array, adapted_regions: Array) -> void:
	entries = codex
	adapted = adapted_regions
	if _panel.visible:
		_panel.queue_redraw()


func unlocked_count() -> int:
	return entries.filter(func(e: Dictionary) -> bool: return bool(e.get("unlocked", false))).size()


func scroll(by: int) -> void:
	_scroll = clampi(_scroll + by, 0, maxi(0, int(ceilf(_content_height / 18.0)) - 10))
	_panel.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open() or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll(3)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll(-3)


func _paint() -> void:
	var size := _panel.size
	_panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.005, 0.02, 0.62))
	var card := Rect2(Vector2((size.x - minf(size.x - 80.0, 980.0)) * 0.5, 36.0), Vector2(minf(size.x - 80.0, 980.0), size.y - 72.0))
	_panel.draw_style_box(BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 14, 0), card)
	var font := ThemeDB.fallback_font
	var x := card.position.x + 32.0
	var width := card.size.x - 64.0
	_panel.draw_string(font, Vector2(x, card.position.y + 44.0), "CÓDICE DO CORPO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, BioUi.FS_TITLE, BioUi.ACCENT)
	_panel.draw_string(font, Vector2(x, card.position.y + 44.0), "%d de %d entradas  ·  B fecha" % [unlocked_count(), entries.size()], HORIZONTAL_ALIGNMENT_RIGHT, width, BioUi.FS_SMALL + 1, BioUi.MUTED)
	_panel.draw_line(Vector2(x, card.position.y + 62.0), Vector2(x + width, card.position.y + 62.0), BioUi.LINE, 1.0)
	var top := card.position.y + 92.0
	var bottom := card.end.y - 24.0
	var y := top - _scroll * 18.0
	var wrap := int(width / 8.0)
	for group in KINDS:
		var items := entries.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == group[0])
		if items.is_empty():
			continue
		_draw_line(font, x, y, top, bottom, group[1], BioUi.FS_SMALL + 1, BioArt.with_alpha(BioUi.WARN, 0.95))
		y += 26.0
		for e in items:
			if bool(e.get("unlocked", false)):
				_draw_line(font, x + 12.0, y, top, bottom, str(e.get("title", "")), BioUi.FS_HEAD, BioUi.TEXT)
				y += 22.0
				for line in _wrap(str(e.get("text", "")), wrap):
					_draw_line(font, x + 12.0, y, top, bottom, line, BioUi.FS_BODY, Color(0.82, 0.88, 1.0, 0.82))
					y += 19.0
				y += 10.0
			else:
				_draw_line(font, x + 12.0, y, top, bottom, "???", BioUi.FS_HEAD, Color(0.6, 0.65, 0.75, 0.45))
				y += 26.0
		y += 14.0
	if not adapted.is_empty():
		var names := adapted.map(func(id: Variant) -> String: return str(BioBodyMap.NAMES.get(StringName(str(id)), str(id))))
		_draw_line(font, x, y, top, bottom, "ADAPTADO A: " + ", ".join(names) + "   (regenera energia mais depressa lá)", BioUi.FS_BODY, BioArt.with_alpha(BioUi.GOOD, 0.9))
		y += 24.0
	_content_height = y + _scroll * 18.0 - top


## A line of text, only when it falls inside the card (the rest is scrolled away).
func _draw_line(font: Font, x: float, y: float, top: float, bottom: float, text: String, size: int, color: Color) -> void:
	if y < top - 4.0 or y > bottom:
		return
	_panel.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _wrap(text: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var current := ""
	for word in text.split(" "):
		if current.length() + word.length() + 1 > width and not current.is_empty():
			out.append(current)
			current = word
		else:
			current = word if current.is_empty() else current + " " + word
	if not current.is_empty():
		out.append(current)
	return out
