class_name BioCodexPanel
extends CanvasLayer
## The codex of the body (key B): what the cell has learned of the places, the invaders, the body itself and the secrets it found.
## Locked entries are only a "???" under their heading, so the player sees how much is still out there. Also lists the places the
## cell has adapted to by living in them.

const KINDS := [["regiao", "LUGARES"], ["patogeno", "INVASORES"], ["corpo", "O CORPO"], ["segredo", "SEGREDOS"]]

var entries: Array = []
var adapted: Array = []
var _panel: Control
var _scroll := 0


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
	_scroll = maxi(0, _scroll + by)
	_panel.queue_redraw()


func _paint() -> void:
	var size := _panel.size
	_panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.9))
	var font := ThemeDB.fallback_font
	_panel.draw_string(font, Vector2(80, 60), "CÓDICE DO CORPO   ·   %d de %d entradas   ·   B para fechar" % [unlocked_count(), entries.size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.8, 0.95, 1.0, 0.95))
	var x := 80.0
	var y := 110.0 - _scroll * 18.0
	var width := (size.x - 160.0)
	for group in KINDS:
		var items := entries.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == group[0])
		if items.is_empty():
			continue
		_panel.draw_string(font, Vector2(x, y), group[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 0.75, 0.4, 0.95))
		y += 24.0
		for e in items:
			if bool(e.get("unlocked", false)):
				_panel.draw_string(font, Vector2(x + 12.0, y), str(e.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1, 1, 1, 0.95))
				y += 20.0
				for line in _wrap(str(e.get("text", "")), int(width / 8.0)):
					_panel.draw_string(font, Vector2(x + 12.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.85, 0.9, 1.0, 0.82))
					y += 18.0
				y += 8.0
			else:
				_panel.draw_string(font, Vector2(x + 12.0, y), "???", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.6, 0.65, 0.75, 0.5))
				y += 24.0
		y += 12.0
	if not adapted.is_empty():
		var names := adapted.map(func(id: Variant) -> String: return str(BioBodyMap.NAMES.get(StringName(str(id)), str(id))))
		_panel.draw_string(font, Vector2(x, y), "ADAPTADO A: " + ", ".join(names) + "   (regenera energia mais depressa lá)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.6, 1.0, 0.8, 0.9))


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
