class_name BioVitalsPanel
extends CanvasLayer
## The vital signs of the host: a small always-on strip (temperature, pulse, oxygen) and, on Tab, the full panel with a bar for each
## vital (its healthy range marked) and a few lines that say what is going on and why. Reads a BioBodyState and draws it.

var _state: BioBodyState
var _strip: Label
var _panel: Control


func configure(state: BioBodyState) -> void:
	_state = state
	layer = 11
	_strip = Label.new()
	_strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_strip.offset_left = -300
	_strip.offset_right = 300
	_strip.offset_top = 104
	_strip.offset_bottom = 128
	_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.add_theme_font_size_override("font_size", 14)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
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
	_panel.queue_redraw()


func strip_text() -> String:
	return _strip.text


## Call after the state changed.
func refresh() -> void:
	if not _state.has_data():
		_strip.text = ""
		return
	_strip.text = "%s   ·   %s   ·   O₂ %s" % [_state.display("temperatura"), _state.display("pulso"), _state.display("oxigenio")]
	var off := _state.is_off("temperatura") or _state.is_off("oxigenio") or _state.is_off("pulso")
	_strip.add_theme_color_override("font_color", Color(1.0, 0.62, 0.3, 0.95) if off else BioArt.with_alpha(Color.WHITE, 0.6))
	if _panel.visible:
		_panel.queue_redraw()


func _paint() -> void:
	var size := _panel.size
	var box := Rect2(size.x - 470.0, 200.0, 430.0, 490.0)
	_panel.draw_style_box(BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 0), box)
	var font := ThemeDB.fallback_font
	_panel.draw_string(font, box.position + Vector2(18, 32), "SINAIS VITAIS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, BioUi.FS_HEAD, BioUi.ACCENT)
	_panel.draw_string(font, box.position + Vector2(18, 32), "Tab fecha", HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 36.0, BioUi.FS_SMALL, BioUi.MUTED)
	var y := box.position.y + 56.0
	for id in _state.order:
		var r: Dictionary = _state.readings[id]
		var lo := float(r.get("min", 0))
		var hi := float(r.get("max", 100))
		var width := 190.0
		var bar := Rect2(box.position.x + 150.0, y - 12.0, width, 12.0)
		_panel.draw_string(font, Vector2(box.position.x + 18.0, y), str(r.get("label", id)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1, 1, 1, 0.85))
		_panel.draw_rect(bar, Color(1, 1, 1, 0.08))
		var low := float(r.get("low", 0))
		var high := float(r.get("high", 0))
		if low != 0.0 or high != 0.0:
			var a := bar.position.x + width * clampf((low - lo) / (hi - lo), 0.0, 1.0)
			var b := bar.position.x + width * clampf((high - lo) / (hi - lo), 0.0, 1.0)
			_panel.draw_rect(Rect2(a, bar.position.y, b - a, bar.size.y), Color(0.3, 1.0, 0.6, 0.16))
		var fraction := clampf((float(r.get("value", 0)) - lo) / (hi - lo), 0.0, 1.0)
		var off := _state.is_off(id)
		_panel.draw_rect(Rect2(bar.position, Vector2(width * fraction, bar.size.y)), Color(1.0, 0.55, 0.25, 0.9) if off else Color(0.35, 0.9, 1.0, 0.85))
		_panel.draw_string(font, Vector2(bar.end.x + 12.0, y), _state.display(id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 0.7, 0.4, 1.0) if off else Color(1, 1, 1, 0.85))
		y += 25.0
	y += 14.0
	for line in _state.explain():
		for chunk in _wrap(line, 56):
			_panel.draw_string(font, Vector2(box.position.x + 18.0, y), chunk, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1, 0.92, 0.8, 0.92))
			y += 18.0
		y += 6.0


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
