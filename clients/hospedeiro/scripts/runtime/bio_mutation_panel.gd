class_name BioMutationPanel
extends CanvasLayer
## Shows the pending mutation offer (pick 1-3 or decline with X), the equipped genes and the pressure gauge.

const CARD_SIZE := Vector2(330, 200)

var _offer_root: Control
var _title: Label
var _lineage_label: Label
var _cards: Array[Label] = []
var _genes_label: Label
var _pressure_fill: ColorRect
var _pressure_width := 240.0
var _genome: BioGenome


func is_offer_visible() -> bool:
	return _offer_root.visible


func offer_text(index: int) -> String:
	return _cards[index].text


## `featured` is where the body leans (chosen by the engine's advisor from how the player lives).
func show_offer(ids: Array, featured: StringName = &"") -> void:
	var entries: Array = []
	for id in ids:
		var gene := BioGeneCatalog.get_gene(id)
		var tag := "  (classe)" if gene.requires_lineage != &"" else ""
		var text := gene.summary().replace(" · ", "
")
		if _genome != null and _genome.equipped.size() >= BioGenome.SLOTS and not _genome.has_gene(id):  # say it, never swap silently
			text += "

Sem espaço: reabsorve %s." % BioGeneCatalog.get_gene(_genome.equipped[0]).display_name
		entries.append({"name": gene.display_name + tag, "text": text, "featured": id == featured})
	show_cards("MUTAÇÃO DISPONÍVEL — escolha uma (1 / 2 / 3) ou recuse (X)", entries)


## The lineage offer: the body is ready to differentiate (permanent). `featured` is where the advisor says it leans.
func show_lineage_offer(options: Array, featured: String) -> void:
	var entries: Array = []
	for o in options:
		entries.append({"name": str(o.get("name", "")), "text": str(o.get("desc", "")), "featured": str(o.get("id", "")) == featured})
	show_cards("DIFERENCIAÇÃO — seu corpo está pronto para se tornar outra coisa (1 / 2 / 3)", entries)


func show_cards(title: String, entries: Array) -> void:
	_title.text = title
	for i in _cards.size():
		if i < entries.size():
			var e: Dictionary = entries[i]
			var lean := "\n\n◆ o corpo pende para cá" if e.get("featured", false) else ""
			_cards[i].text = "[%d]  %s\n\n%s%s" % [i + 1, e["name"], e["text"], lean]
			_cards[i].get_parent().visible = true
		else:
			_cards[i].get_parent().visible = false
	_offer_root.visible = true


func set_lineage_text(text: String) -> void:
	_lineage_label.text = text


func hide_offer() -> void:
	_offer_root.visible = false


func refresh(genome: BioGenome, tracker: BioMutationTracker) -> void:
	var fraction := 1.0 if tracker.has_offer() else float(tracker.pressure) / BioMutationTracker.THRESHOLD
	refresh_values(genome, fraction)


func refresh_values(genome: BioGenome, fraction: float) -> void:
	_genome = genome
	var lines: Array[String] = ["GENES  (%d/%d)" % [genome.equipped.size(), BioGenome.SLOTS]]
	for id in genome.equipped:  # names only: the details are on the offer cards
		var gene := BioGeneCatalog.get_gene(id)
		lines.append("◆ %s%s" % [gene.display_name, "  (classe)" if gene.requires_lineage != &"" else ""])
	if genome.equipped.is_empty():
		lines.append("nenhum — coma e derrote vírus")
	_genes_label.text = "\n".join(lines)
	_pressure_fill.size.x = _pressure_width * clampf(fraction, 0.0, 1.0)


func _ready() -> void:
	layer = 11

	_lineage_label = Label.new()
	_lineage_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lineage_label.offset_left = -560
	_lineage_label.offset_right = -30
	_lineage_label.offset_top = 4
	_lineage_label.offset_bottom = 28
	_lineage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lineage_label.add_theme_font_size_override("font_size", 17)
	_lineage_label.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.AMBER, 0.95))
	_lineage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lineage_label)

	_genes_label = Label.new()
	_genes_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_genes_label.offset_left = -560
	_genes_label.offset_right = -30
	_genes_label.offset_top = 32
	_genes_label.offset_bottom = 160
	_genes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_genes_label.add_theme_font_size_override("font_size", 14)
	_genes_label.add_theme_color_override("font_color", BioArt.with_alpha(Color.WHITE, 0.8))
	_genes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_genes_label)

	var back := ColorRect.new()
	back.color = Color(0.02, 0.04, 0.08, 0.75)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -30 - _pressure_width
	back.offset_right = -30
	back.offset_top = 170
	back.offset_bottom = 184
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_pressure_fill = ColorRect.new()
	_pressure_fill.color = BioArt.with_alpha(BioArt.MAGENTA, 0.9)
	_pressure_fill.position = Vector2.ZERO
	_pressure_fill.size = Vector2(0, 14)
	_pressure_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_pressure_fill)
	var tag := Label.new()
	tag.text = "PRESSÃO EVOLUTIVA"
	tag.position = Vector2(8, -2)
	tag.add_theme_font_size_override("font_size", 11)
	back.add_child(tag)

	_offer_root = Control.new()
	_offer_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_offer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_root.visible = false
	add_child(_offer_root)
	var title := Label.new()
	_title = title
	title.text = "MUTAÇÃO DISPONÍVEL — escolha uma (1 / 2 / 3) ou recuse (X)"
	title.position = Vector2(-CARD_SIZE.x * 1.5 - 20, -CARD_SIZE.y * 0.5 - 56)
	title.size = Vector2(CARD_SIZE.x * 3 + 40, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.MAGENTA.lerp(Color.WHITE, 0.4), 0.95))
	_offer_root.add_child(title)
	for i in 3:
		var card := ColorRect.new()
		card.color = Color(0.06, 0.09, 0.18, 1.0)
		card.size = CARD_SIZE
		card.position = Vector2((i - 1.5) * (CARD_SIZE.x + 20) + 10, -CARD_SIZE.y * 0.5)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_offer_root.add_child(card)
		var text := Label.new()
		text.position = Vector2(16, 14)
		text.size = CARD_SIZE - Vector2(32, 28)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 17)
		card.add_child(text)
		_cards.append(text)
