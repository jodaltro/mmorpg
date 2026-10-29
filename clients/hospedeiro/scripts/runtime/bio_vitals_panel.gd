class_name BioVitalsPanel
extends CanvasLayer
## The vital signs of the host: a small always-on strip (temperature, pulse, oxygen) and, on Tab, the full panel with a bar for each
## vital (its healthy range marked) and a few lines that say what is going on and why. Reads a BioBodyState and draws it.

var _state: BioBodyState
var _strip: Label
var _modal: BioModal


func configure(state: BioBodyState) -> void:
	_state = state
	layer = 11
	_strip = Label.new()
	_strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_strip.offset_left = -300
	_strip.offset_right = 300
	_strip.offset_top = 112  # under the GPS card of the guide (58 + 48)
	_strip.offset_bottom = 136
	_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.add_theme_font_size_override("font_size", 14)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_modal = BioModal.new()
	var holder := CanvasLayer.new()
	holder.layer = 14
	add_child(holder)
	holder.add_child(_modal)
	_modal.build("SINAIS VITAIS")
	_modal.dismissed.connect(close)



func is_open() -> bool:
	return _modal.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		_modal.present(self)
		_rebuild()

func close() -> void:
	_modal.hide_modal()



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
	if is_open():
		_update_values()

var _values: Dictionary = {}
var _gauges: Dictionary = {}
var _explanations: Label

func _rebuild() -> void:
	for child in _modal.content.get_children():
		_modal.content.remove_child(child)
		child.queue_free()
	_values.clear()
	_gauges.clear()
	for id in _state.order:
		var reading: Dictionary = _state.readings[id]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 36
		_modal.content.add_child(row)
		var title := BioUi.label(str(reading.get("label", id)))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var gauge := ProgressBar.new()
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.custom_minimum_size = Vector2(100, 6)
		gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gauge.show_percentage = false
		row.add_child(gauge)
		_gauges[id] = gauge
		var value := BioUi.label("")
		value.custom_minimum_size.x = 92
		row.add_child(value)
		_values[id] = value
	_explanations = BioUi.wrapped("", BioUi.FS_BODY, BioUi.WARN)
	_modal.content.add_child(_explanations)
	_update_values()

func _update_values() -> void:
	for id in _values:
		var reading: Dictionary = _state.readings.get(id, {})
		var lo := float(reading.get("min", 0))
		var hi := float(reading.get("max", 100))
		_values[id].text = _state.display(id)
		_values[id].add_theme_color_override("font_color", BioUi.WARN if _state.is_off(id) else BioUi.TEXT)
		_gauges[id].value = 100 * clampf((float(reading.get("value", 0)) - lo) / maxf(hi - lo, 0.001), 0, 1)
	_explanations.text = "\n\n".join(_state.explain())
