class_name BioMutationPanel
extends CanvasLayer
## The body's growth, in the corner of the screen and without getting in the way: the form (class), a thin pressure gauge and one dot per
## gene slot. It also keeps the pending offer (a mutation to choose, or a differentiation) as data: the offer is chosen in the Body
## window (BioBodyPanel), never in the middle of the screen, and a chip in the call tray says that it is waiting.

signal offer_changed

const WIDTH := 300.0

var _kind := ""  # "", "mutation" or "lineage"
var _title := ""
var _entries: Array = []  # {name, text, featured, id}
var _lineage_label: Label
var _pressure_back: Control
var _pressure_fraction := 0.0
var _pips: Control
var _pips_key := ""
var _genome: BioGenome
var _keys_hint: Label
var _column: Control


func is_offer_visible() -> bool:
	return not _entries.is_empty()


func offer_kind() -> String:
	return _kind


func offer_title() -> String:
	return _title


func entries() -> Array:
	return _entries


func offer_text(index: int) -> String:
	var e: Dictionary = _entries[index]
	var lean := "\n\n◆ o corpo pende para cá" if e.get("featured", false) else ""
	return "[%d]  %s\n\n%s%s" % [index + 1, e["name"], e["text"], lean]


## `featured` is where the body leans (chosen by the engine's advisor from how the player lives).
func show_offer(ids: Array, featured: StringName = &"") -> void:
	var entries_in: Array = []
	for id in ids:
		var gene := BioGeneCatalog.get_gene(id)
		var tag := "  (classe)" if gene.requires_lineage != &"" else ""
		var text := gene.summary().replace(" · ", "\n")
		if _genome != null and _genome.equipped.size() >= BioGenome.SLOTS and not _genome.has_gene(id):  # say it, never swap silently
			text += "\n\nSem espaço: %s vai para a biblioteca." % BioGeneCatalog.get_gene(_genome.equipped[0]).display_name
		entries_in.append({"id": String(id), "name": gene.display_name + tag, "text": text, "featured": id == featured})
	show_cards("mutation", "MUTAÇÃO DISPONÍVEL: escolha uma ou recuse", entries_in)


## The lineage offer: the body is ready to differentiate (permanent). `featured` is where the advisor says it leans.
func show_lineage_offer(options: Array, featured: String) -> void:
	var entries_in: Array = []
	for o in options:
		entries_in.append({"id": str(o.get("id", "")), "name": str(o.get("name", "")), "text": str(o.get("desc", "")), "featured": str(o.get("id", "")) == featured})
	show_cards("lineage", "DIFERENCIAÇÃO: seu corpo está pronto para se tornar outra coisa", entries_in)


func show_cards(kind: String, title: String, entries_in: Array) -> void:
	_kind = kind
	_title = title
	_entries = entries_in
	offer_changed.emit()


func set_lineage_text(text: String) -> void:
	_lineage_label.text = text


func hide_offer() -> void:
	if _entries.is_empty() and _kind.is_empty():
		return
	_kind = ""
	_title = ""
	_entries = []
	offer_changed.emit()


func refresh(genome: BioGenome, tracker: BioMutationTracker) -> void:
	var fraction := 1.0 if tracker.has_offer() else float(tracker.pressure) / BioMutationTracker.THRESHOLD
	refresh_values(genome, fraction)


func refresh_values(genome: BioGenome, fraction: float) -> void:
	_genome = genome
	if not is_equal_approx(fraction, _pressure_fraction):
		_pressure_fraction = fraction
		_pressure_back.queue_redraw()
	var key := str(genome.equipped)
	if key != _pips_key:
		_pips_key = key
		_pips.queue_redraw()


func _ready() -> void:
	layer = 11
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.offset_left = -24.0 - WIDTH
	column.offset_right = -24.0
	column.offset_top = 18.0
	_column = column
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_lineage_label = BioUi.label("", BioUi.FS_HEAD, BioArt.with_alpha(BioArt.AMBER, 0.95))
	_lineage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lineage_label.custom_minimum_size.x = WIDTH
	_lineage_label.clip_text = true
	column.add_child(_lineage_label)

	_pressure_back = Control.new()
	_pressure_back.custom_minimum_size = Vector2(WIDTH, 5)
	_pressure_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pressure_back.draw.connect(func() -> void:
		_pressure_back.draw_rect(Rect2(Vector2.ZERO, _pressure_back.size), Color(1, 1, 1, 0.08))
		var full := _pressure_fraction >= 0.999
		var color := BioArt.with_alpha(BioArt.MAGENTA, 0.95 if full else 0.7)
		_pressure_back.draw_rect(Rect2(Vector2.ZERO, Vector2(_pressure_back.size.x * clampf(_pressure_fraction, 0.0, 1.0), _pressure_back.size.y)), color))
	column.add_child(_pressure_back)

	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(WIDTH, 14)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	column.add_child(_pips)
	_keys_hint = BioUi.label("G corpo  ·  B códice  ·  M mapa  ·  Tab sinais", 11, Color(1, 1, 1, 0.32))
	_keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_keys_hint)


## A touch screen has the buttons themselves, so the list of keys goes.
func set_touch(on: bool) -> void:
	_keys_hint.visible = not on
	if on:  # the window buttons take the top row
		_column.offset_top = 56.0


## One dot per gene slot, lit with the colour of the gene's mark on the body.
func _draw_pips() -> void:
	var slots := BioGenome.SLOTS
	var gap := 22.0
	var x := _pips.size.x - gap * slots + gap * 0.5
	for i in slots:
		var centre := Vector2(x + gap * i, 7.0)
		var id: StringName = _genome.equipped[i] if _genome != null and i < _genome.equipped.size() else &""
		if id == &"":
			_pips.draw_arc(centre, 4.5, 0.0, TAU, 20, Color(1, 1, 1, 0.22), 1.2, true)
		else:
			var mark := BioGeneCatalog.get_gene(id).mark
			var color := Color.html(str(mark.get(&"color", "#9fe8ff")))
			_pips.draw_circle(centre, 5.5, BioArt.with_alpha(color, 0.9))
