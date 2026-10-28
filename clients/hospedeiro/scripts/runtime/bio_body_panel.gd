class_name BioBodyPanel
extends CanvasLayer
## The Body window (G): everything about what the cell has become, in one place, and where it is arranged. Four tabs:
##   FORMA        the class, its passive trade-offs, maturity and evolutionary pressure; the differentiation offer is chosen here.
##   GENES        the expressed genes, the library of silenced ones, the pending mutation offer, and a live comparison of what a swap
##                would do to the stats before it is made.
##   HABILIDADES  the four class abilities and the keys they sit on (swap by clicking two).
##   BUILDS       three saved sets of genes (and the order of the abilities) that can be applied in one click.
## It decides nothing: every change of genes is an intention sent to the engine, which validates it. Changes wait: not inside a
## combat-free moment, and not while the body is still settling from the last change (the engine says for how long).

signal closed

const TABS := ["FORMA", "GENES", "HABILIDADES", "BUILDS"]
const FORM := 0
const GENES := 1
const ABILITIES := 2
const BUILDS := 3
const TICK_SECONDS := 4.0  # the engine's tick (universe tickSeconds), only to show how long the body still has to settle
const KIND_NAMES := {"devour": "devora", "nova": "onda", "cone": "cone", "pierce": "perfura", "bolt": "projétil", "dash_strike": "investida", "zone": "zona"}
const KEYS := ["Q", "F", "C", "V"]

var tab := FORM

var _world: Node
var _dim: BioModal
var _window: PanelContainer
var _title: Label
var _subtitle: Label
var _lock_label: Label
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _content: VBoxContainer
var _footer: Label
var _swap_in := ""  # engine id of the library gene chosen to come in
var _swap_out := ""  # engine id of the expressed gene chosen to leave
var ability_slots: Array[BioLoadoutSlot] = []
var _ability_details := false
var _ability_moving := false
var _build_ability_pick := -1
var _rename_build := false
var _confirm_save := false
var _operation_note := ""
var _busy := false
var _ability_pick := -1
var _build_pick := 1
var _last_lock := ""
var _mutation_preview := ""
var _watch := 0.0


func configure(world: Node) -> void:
	_world = world
	layer = 14
	_dim = BioModal.new()
	if not BioPlatform.is_touch():
		_dim.max_size.x = 1100
	_dim.dismissed.connect(close)
	add_child(_dim)
	_window = _dim.card
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_window.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_title = BioUi.label("CORPO", BioUi.FS_HEAD if BioPlatform.is_touch() else BioUi.FS_TITLE, BioUi.ACCENT)
	names.add_child(_title)
	_subtitle = BioUi.label("", BioUi.FS_SMALL, BioUi.MUTED)
	_subtitle.clip_text = true
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(_subtitle)
	_lock_label = BioUi.label("", BioUi.FS_SMALL, BioUi.GOOD)
	_lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_lock_label)
	var close_button := BioUi.button("Fechar   G", "ghost")
	close_button.pressed.connect(close)
	head.add_child(close_button)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	column.add_child(main)
	var tabs: BoxContainer = VBoxContainer.new() if BioPlatform.is_touch() else HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	if BioPlatform.is_touch():
		main.add_child(tabs)
	else:
		column.add_child(tabs)
		column.move_child(tabs, main.get_index())
	for i in TABS.size():
		var b := BioUi.button(TABS[i], "ghost")
		b.custom_minimum_size = Vector2(110 if BioPlatform.is_touch() else 150, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		b.pressed.connect(func() -> void: show_tab(index))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.scroll_deadzone = 8
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_scroll)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)

	_footer = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.MUTED)
	column.add_child(_footer)
	column.move_child(_lock_label, column.get_child_count() - 1)
	_dim.visible = false
	get_viewport().size_changed.connect(func() -> void:
		if is_open():
			refresh()
			_fit.call_deferred())


func is_open() -> bool:
	return _dim.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Opens the window; with no tab given, on the one that has something waiting (a differentiation, a mutation), else on the last one.
func open(wanted: int = -1) -> void:
	if wanted < 0:
		wanted = _tab_with_offer()
	tab = wanted if wanted >= 0 else tab
	_fit()
	_dim.present(self)
	_swap_in = ""
	_swap_out = ""
	_ability_pick = -1
	_ability_moving = false
	_ability_details = false
	_rename_build = false
	_confirm_save = false
	_operation_note = ""
	refresh()


func close() -> void:
	if not is_open():
		return
	_dim.hide_modal()
	closed.emit()


func show_tab(index: int) -> void:
	_scroll.scroll_vertical = 0
	tab = clampi(index, 0, TABS.size() - 1)
	_ability_details = false
	_ability_moving = false
	_rename_build = false
	_confirm_save = false
	_fit()
	_swap_in = ""
	_swap_out = ""
	_ability_pick = -1
	refresh()


func _tab_with_offer() -> int:
	var kind := _offer_kind()
	if kind == "lineage":
		return FORM
	if kind == "mutation":
		return GENES
	return -1


func _fit() -> void:
	_dim.max_size.y = 460 if tab == ABILITIES else 540 if tab == BUILDS else 620
	_dim.fit()


func _process(delta: float) -> void:
	if not is_open():
		return
	_watch -= delta
	if _watch > 0.0:
		return
	_watch = 0.4
	var now_lock := lock_reason()
	if now_lock != _last_lock:
		refresh()


# --- what the world says ---------------------------------------------------------------------------------------------------------

func _offer_kind() -> String:
	return _world.panel.offer_kind() if _world != null and _world.panel != null else ""


func _evolution() -> Dictionary:
	return _world.engine_evolution_view() if _world != null else {}


func _lineage_view() -> Dictionary:
	return _world.engine_lineage_view() if _world != null else {}


func _online() -> bool:
	return _world != null and _world.sync != null and _world.sync.link.online


## Why the genes cannot be changed right now ("" when they can). Reasons are in the order a player would fix them.
func lock_reason(for_rest := true) -> String:
	if not _online():
		return "Sem o motor, o corpo não se reconfigura."
	var rest := int(_evolution().get("restLeft", 0))
	if for_rest and rest > 0:
		return "O corpo ainda se acomoda: %d s." % ceili(rest * TICK_SECONDS)
	return ""


# --- drawing ---------------------------------------------------------------------------------------------------------------------

func refresh() -> void:
	if _content == null or not is_open():
		return
	if (_rename_build and BioUi.typing()) or (is_instance_valid(BioLoadoutSlot.active) and absi(BioLoadoutSlot.active.scope) == get_instance_id()):
		return  # background world updates must not interrupt editing or a held skill
	ability_slots.clear()
	_last_lock = lock_reason()
	_paint_header()
	for i in _tab_buttons.size():
		var b := _tab_buttons[i]
		var active := i == tab
		var waiting := (i == FORM and _offer_kind() == "lineage") or (i == GENES and _offer_kind() == "mutation")
		b.text = TABS[i] + ("  •" if waiting else "")
		b.add_theme_stylebox_override("normal", BioUi.style(Color(0.12, 0.34, 0.5) if active else Color(0.06, 0.1, 0.19), BioUi.LINE_STRONG if active else BioUi.LINE, 7, 10))
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match tab:
		FORM:
			_paint_form()
		GENES:
			_paint_genes()
		ABILITIES:
			_paint_abilities()
		BUILDS:
			_paint_builds()


## Every text on the current tab, for whoever wants to read what the window says (tests, captures).
func content_text() -> String:
	var out: Array[String] = []
	var stack: Array[Node] = [_content]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			out.append((node as Label).text)
		elif node is Button:
			out.append((node as Button).text)
		for child in node.get_children():
			stack.append(child)
	return "
".join(out)


func _paint_header() -> void:
	var lineage: StringName = _world.lineage_id
	var form := BioLineageCatalog.display_name(lineage) if lineage != &"" else "Esfera indiferenciada"
	_subtitle.text = form + ("  ·  " + _world.look_name if not str(_world.look_name).is_empty() else "")
	var reason := lock_reason()
	_lock_label.text = reason if not reason.is_empty() else "Pronto para ajustar"
	_lock_label.add_theme_color_override("font_color", BioUi.WARN if not reason.is_empty() else BioUi.GOOD)
	_footer.text = "Aguarde…" if _busy else _operation_note
	_footer.visible = not _footer.text.is_empty()


func _section(text: String) -> Label:
	return BioUi.label(text, BioUi.FS_SMALL, BioArt.with_alpha(BioUi.WARN, 0.95))


func _panel(bg: Color = BioUi.BG_RAISED, border: Color = BioUi.LINE, margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", BioUi.style(bg, border, 10, margin))
	return p


func _gauge_row(left: String, right: String, fraction: float, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	var l := BioUi.label(left, BioUi.FS_BODY, BioUi.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(BioUi.label(right, BioUi.FS_BODY, BioUi.MUTED))
	box.add_child(row)
	box.add_child(BioUi.gauge(fraction, color, 8.0))
	return box


# --- FORMA -----------------------------------------------------------------------------------------------------------------------

func _paint_form() -> void:
	var lin := _lineage_view()
	var lineage: StringName = _world.lineage_id
	var top := _responsive_row()
	top.add_theme_constant_override("separation", 16)
	_content.add_child(top)

	var left := _panel()
	left.custom_minimum_size.x = 0 if _narrow() else 340.0
	top.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 8)
	left.add_child(lbox)
	lbox.add_child(_section("FORMA ATUAL"))
	lbox.add_child(BioUi.label(BioLineageCatalog.display_name(lineage) if lineage != &"" else "Esfera", 20 if BioPlatform.is_touch() else 26, BioArt.with_alpha(BioArt.AMBER, 0.98)))
	lbox.add_child(BioUi.wrapped("Indiferenciada: ainda pode se tornar qualquer coisa." if lineage == &"" else "Uma forma é permanente. Muda o corpo todo, não só os números.", BioUi.FS_SMALL, BioUi.MUTED))
	var lore := BioLore.class_info(lineage if lineage != &"" else &"")
	if not lore.is_empty():
		lbox.add_child(_section("SOBRE A CLASSE · " + str(lore["role"]).to_upper()))
		lbox.add_child(BioUi.wrapped(str(lore["about"]), BioUi.FS_BODY, BioUi.TEXT))
		lbox.add_child(_section("COMO JOGAR"))
		lbox.add_child(BioUi.wrapped(str(lore["play"]), BioUi.FS_BODY, BioUi.TEXT))
	var lines := BioBuildPreview.lineage_lines(lineage)
	if not lines.is_empty():
		lbox.add_child(_section("O QUE ELA FAZ COM O CORPO"))
		for line in lines:
			lbox.add_child(BioUi.label(line, BioUi.FS_BODY, BioUi.TEXT))
	var nxt := int(lin.get("next", 0))
	if nxt > 0:
		lbox.add_child(_gauge_row("Maturidade", "%d / %d" % [int(lin.get("maturity", 0)), nxt], float(lin.get("maturity", 0)) / float(nxt), BioUi.ACCENT))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	top.add_child(right)
	if _offer_kind() == "lineage":
		right.add_child(_section(_world.panel.offer_title()))
		right.add_child(BioUi.wrapped("Escolha com calma: é permanente. O corpo pende para o marcado.", BioUi.FS_SMALL, BioUi.MUTED))
		right.add_child(_offer_row(true))
	else:
		var ev := _evolution()
		var threshold := maxf(1.0, float(ev.get("threshold", 1)))
		var pressure := float(ev.get("pressure", 0))
		var pressure_box := _panel()
		right.add_child(pressure_box)
		var pbox := VBoxContainer.new()
		pbox.add_theme_constant_override("separation", 8)
		pressure_box.add_child(pbox)
		pbox.add_child(_section("PRESSÃO EVOLUTIVA"))
		pbox.add_child(_gauge_row("Até a próxima mutação", "%d / %d" % [int(pressure), int(threshold)], pressure / threshold, BioArt.MAGENTA))
		pbox.add_child(BioUi.wrapped("Comer, derrotar invasores, esquivar e explorar empurram o corpo a mudar. Quando a barra enche, ele oferece três genes.", BioUi.FS_SMALL, BioUi.MUTED))
		if lin.get("next") != null and nxt > 0:
			pbox.add_child(BioUi.wrapped("Quando a maturidade chegar a %d, o corpo poderá se diferenciar em outra forma." % nxt, BioUi.FS_SMALL, BioUi.MUTED))


## The cards of the pending offer side by side; each one has its button and its key.
func _offer_row(lineage_offer: bool) -> Control:
	var row: Container = _responsive_row() if lineage_offer else GridContainer.new()
	if row is GridContainer:
		row.columns = 2 if _scroll.size.x >= 420 else 1
	row.add_theme_constant_override("separation", 8)
	for i in _world.panel.entries().size():
		row.add_child(_offer_card(i, lineage_offer))
	return row


func _offer_card(index: int, lineage_offer: bool) -> Control:
	var e: Dictionary = _world.panel.entries()[index]
	var card := _panel(BioUi.BG_RAISED, BioUi.LINE_STRONG if e.get("featured", false) else BioUi.LINE, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 170.0
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(BioUi.keycap(str(index + 1)))
	var name_label := BioUi.wrapped(str(e.get("name", "")), BioUi.FS_HEAD, BioUi.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	body.add_child(head)
	var description := BioUi.wrapped(str(e.get("text", "")), BioUi.FS_SMALL, BioUi.MUTED)
	if not lineage_offer:
		description.max_lines_visible = 2
	body.add_child(description)
	if e.get("featured", false):
		body.add_child(BioUi.label("Sugerido pelo corpo", BioUi.FS_SMALL, BioUi.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var choose := BioUi.button("Tornar-se" if lineage_offer else "Ver mudança", "primary")
	var reason := lock_reason(false)
	choose.disabled = lineage_offer and not reason.is_empty()
	choose.tooltip_text = reason
	choose.pressed.connect(func() -> void:
		if lineage_offer: pick(index)
		else: preview_mutation(index))
	body.add_child(choose)
	return card

func preview_mutation(index: int) -> void:
	if _offer_kind() != "mutation" or index < 0 or index >= _world.panel.entries().size(): return
	_mutation_preview = str(_world.panel.entries()[index].get("id", ""))
	_scroll.scroll_vertical = 0
	refresh()

func _paint_mutation_preview() -> bool:
	if _offer_kind() != "mutation" or _mutation_preview.is_empty(): return false
	var index := -1
	var entries: Array = _world.panel.entries()
	for i in entries.size():
		if str(entries[i].get("id", "")) == _mutation_preview: index = i
	if index < 0:
		_mutation_preview = ""
		return false
	var entry: Dictionary = entries[index]
	var back := BioUi.button("← Voltar às opções")
	back.pressed.connect(func() -> void: _mutation_preview = ""; refresh())
	_content.add_child(back)
	_content.add_child(BioUi.wrapped(str(entry.get("name", "")), BioUi.FS_HEAD, BioUi.ACCENT))
	_content.add_child(BioUi.wrapped(str(entry.get("text", "")), BioUi.FS_SMALL))
	var current := current_genes()
	var after := current.duplicate()
	var gene := _local_id(_mutation_preview)
	if not after.has(gene):
		if after.size() >= _slots(): after.pop_front()
		after.append(gene)
	_content.add_child(_result_panel(current, after, "SEU CORPO · AGORA → DEPOIS", "A mudança está no efeito da habilidade.", false))
	var confirm := BioUi.button("Expressar este gene", "primary")
	confirm.disabled = not lock_reason(false).is_empty()
	var choice_id := str(entry.get("id", ""))
	confirm.pressed.connect(func() -> void:
		var latest: Array = _world.panel.entries()
		for i in latest.size():
			if str(latest[i].get("id", "")) == choice_id:
				if pick(i): _mutation_preview = ""
				return
		refresh())
	_content.add_child(confirm)
	return true


## Chooses card `index` of the pending offer (the keys 1, 2, 3 and the buttons).
func pick(index: int) -> bool:
	if not is_open() or not lock_reason(false).is_empty() or _offer_kind().is_empty():
		return false
	if index < 0 or index >= _world.panel.entries().size():
		return false
	_world.pick_mutation(index)
	return true


func decline() -> bool:
	if _offer_kind() != "mutation" or not lock_reason(false).is_empty():
		return false
	_world.decline_mutation()
	return true


# --- GENES -----------------------------------------------------------------------------------------------------------------------

func _local_id(engine_id: String) -> StringName:
	return StringName(engine_id.replace("-", "_"))


func _expressed() -> Array:
	return _evolution().get("genes", [])


func _library() -> Array:
	return _evolution().get("library", [])


func _slots() -> int:
	return maxi(1, int(_evolution().get("slots", BioGenome.SLOTS)))


## The genes (local ids) that would be expressed after the swap that is being prepared.
func previewed_genes() -> Array:
	var out: Array = []
	for g in _expressed():
		if str(g.get("id", "")) != _swap_out:
			out.append(_local_id(str(g.get("id", ""))))
	if not _swap_in.is_empty() and (out.size() < _slots()):
		out.append(_local_id(_swap_in))
	return out


func current_genes() -> Array:
	return _expressed().map(func(g: Dictionary) -> StringName: return _local_id(str(g.get("id", ""))))


func _paint_genes() -> void:
	if _paint_mutation_preview(): return
	var kind := _offer_kind()
	if kind == "mutation":
		var box := _panel(BioUi.BG_RAISED, BioArt.with_alpha(BioUi.KIND_COLOR["mutation"], 0.6), 14)
		_content.add_child(box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		box.add_child(v)
		var head := HBoxContainer.new()
		v.add_child(head)
		var t := _section(_world.panel.offer_title())
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var refuse := BioUi.button("Recusar   X", "ghost")
		refuse.disabled = not lock_reason(false).is_empty()
		refuse.pressed.connect(decline)
		head.add_child(refuse)
		v.add_child(_offer_row(false))

	var split := _responsive_row()
	split.add_theme_constant_override("separation", 16)
	_content.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var expressed := _expressed()
	left.add_child(_section("EXPRESSOS   %d / %d" % [expressed.size(), _slots()]))
	var grid := GridContainer.new()
	grid.columns = 1 if _scroll.size.x < 420 else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for gene in expressed:
		var g: Dictionary = gene
		grid.add_child(_gene_cell(g, str(g.get("id", "")) == _swap_out, func() -> void:
			_swap_out = "" if _swap_out == str(g.get("id", "")) else str(g.get("id", ""))
			refresh()))
	var free := maxi(0, _slots() - expressed.size())
	if free > 0:
		left.add_child(BioUi.label("%d espaços livres" % free, BioUi.FS_SMALL, BioUi.MUTED))

	var library := _library()
	left.add_child(_section("BIBLIOTECA   %d" % library.size()))
	if library.is_empty():
		left.add_child(BioUi.wrapped("Os genes silenciados ficam guardados aqui.", BioUi.FS_SMALL, BioUi.MUTED))
	else:
		var lib_grid := GridContainer.new()
		lib_grid.columns = 1 if _scroll.size.x < 420 else 2
		lib_grid.add_theme_constant_override("h_separation", 8)
		lib_grid.add_theme_constant_override("v_separation", 8)
		left.add_child(lib_grid)
		for g in library:
			var gene: Dictionary = g
			lib_grid.add_child(_gene_cell(gene, str(gene.get("id", "")) == _swap_in, func() -> void:
				_swap_in = "" if _swap_in == str(gene.get("id", "")) else str(gene.get("id", ""))
				refresh()))

	var full := expressed.size() >= _slots()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	var reason := lock_reason()
	var can_swap := not _swap_in.is_empty() and (not full or not _swap_out.is_empty())
	var swap := BioUi.button("Trocar" if full else "Expressar", "primary")
	swap.disabled = _busy or not can_swap or not reason.is_empty()
	swap.tooltip_text = reason
	swap.pressed.connect(express_selected)
	actions.add_child(swap)
	var silence := BioUi.button("Silenciar", "ghost")
	silence.disabled = _busy or _swap_out.is_empty() or not _swap_in.is_empty() or not reason.is_empty()
	silence.tooltip_text = reason
	silence.pressed.connect(silence_selected)
	actions.add_child(silence)
	var hint := "Escolha um gene da biblioteca" + (" e o gene expresso que dá o lugar." if full else ".")
	left.add_child(BioUi.wrapped(hint if not can_swap and _swap_out.is_empty() else "Confira o resultado antes de confirmar.", BioUi.FS_SMALL, BioUi.MUTED))

	if not _swap_in.is_empty() or not _swap_out.is_empty():
		split.add_child(_result_panel(current_genes(), previewed_genes(), "RESULTADO DA TROCA", "Este gene não altera os atributos exibidos."))


## A gene as a clickable cell: name, rarity, what it does.
func _gene_cell(gene: Dictionary, selected: bool, on_click: Callable) -> Control:
	var cell := PanelContainer.new()
	var rarity_color := BioUi.rarity_color(str(gene.get("rarity", "")))
	cell.add_theme_stylebox_override("panel", BioUi.style(Color(0.1, 0.18, 0.3, 0.98) if selected else BioUi.BG_RAISED, BioUi.LINE_STRONG if selected else BioUi.LINE, 9, 10, 2 if selected else 1))
	cell.custom_minimum_size = Vector2(0, 40)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var dot := ColorRect.new()
	dot.color = rarity_color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(dot)
	var title := BioUi.label("  " + str(gene.get("name", "")), BioUi.FS_SMALL, BioUi.TEXT)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var local := _local_id(str(gene.get("id", "")))
	var summary := BioGeneCatalog.get_gene(local).summary() if BioGeneCatalog.all_ids().has(local) else str(gene.get("desc", ""))
	if selected:
		var summary_label := BioUi.wrapped(summary, BioUi.FS_SMALL, BioUi.MUTED)
		summary_label.max_lines_visible = 2
		v.add_child(summary_label)
	BioUi.bind_tap(cell, on_click)
	return cell


func _empty_cell(text: String) -> Control:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", BioUi.style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.1), 9, 10))
	cell.custom_minimum_size = Vector2(0, 40)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := BioUi.label(text, BioUi.FS_SMALL, Color(1, 1, 1, 0.3))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(l)
	return cell


## The comparison table: each stat that is not neutral, now → after, green when it gets better and red when it gets worse.
func _result_panel(current: Array, previewed: Array, title: String, empty_text: String, show_effects := true) -> Control:
	var box := _panel(BioUi.BG_SUNK, BioUi.LINE, 14)
	box.custom_minimum_size.x = 0 if _narrow() else 340.0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow() else Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	v.add_child(_section(title))
	for id in previewed:
		if not show_effects: break
		if current.has(id): continue
		if not BioGeneCatalog.all_ids().has(StringName(str(id))): continue
		var gene := BioGeneCatalog.get_gene(StringName(str(id)))
		if not gene.transformation.is_empty():
			v.add_child(BioUi.wrapped("NOVO EFEITO · " + str(gene.transformation.description), BioUi.FS_SMALL, BioUi.GOOD))
	for id in current:
		if not show_effects: break
		if previewed.has(id): continue
		if not BioGeneCatalog.all_ids().has(StringName(str(id))): continue
		var gene := BioGeneCatalog.get_gene(StringName(str(id)))
		if not gene.transformation.is_empty():
			v.add_child(BioUi.wrapped("PERDE EFEITO · " + str(gene.transformation.description), BioUi.FS_SMALL, BioUi.WARN))
	var rows := BioBuildPreview.rows(_world.lineage_id, current, previewed)
	var changes := 0
	for r in rows:
		if str(r["now"]) == str(r["then"]): continue
		changes += 1
		var row := HBoxContainer.new()
		var name_label := BioUi.label(str(r["label"]), BioUi.FS_SMALL + 1, BioUi.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var better := int(r["better"])
		var color := BioUi.GOOD if better > 0 else (BioUi.BAD if better < 0 else BioUi.MUTED)
		var text := str(r["then"]) if str(r["now"]) == str(r["then"]) else "%s  →  %s" % [r["now"], r["then"]]
		row.add_child(BioUi.label(text, BioUi.FS_SMALL + 1, color))
		v.add_child(row)
	if changes == 0:
		v.add_child(BioUi.wrapped(empty_text, BioUi.FS_SMALL, BioUi.MUTED))
	return box


func express_selected() -> void:
	if _swap_in.is_empty() or not lock_reason().is_empty():
		return
	var args := {"gene": _swap_in}
	if _expressed().size() >= _slots():
		if _swap_out.is_empty():
			return
		args["swap"] = _swap_out
	_send("expressar", args)


func silence_selected() -> void:
	if _swap_out.is_empty() or not lock_reason().is_empty():
		return
	_send("silenciar", {"gene": _swap_out})


func _send(action: String, args: Dictionary) -> bool:
	if _busy:
		return false
	_busy = true
	_operation_note = ""
	refresh()
	var res: Dictionary = await _world.sync.link.act(action, args)
	_busy = false
	if res.get("status", 0) != 200:
		_operation_note = "A mudança não foi aceita. Tente novamente."
		_world.sync.system.push_feed("O corpo não aceitou essa mudança agora.")
		refresh()
		return false
	_operation_note = {"salvar-build": "Preset salvo.", "aplicar-build": "Build aplicada."}.get(action, "Alteração confirmada.")
	_swap_in = ""
	_swap_out = ""
	for e in res.get("body", {}).get("events", []):
		_world.sync.system.push_feed(str(e.get("text", "")))
	if is_open():
		refresh()
	return true


# --- HABILIDADES -----------------------------------------------------------------------------------------------------------------

func _paint_abilities() -> void:
	_content.add_child(BioUi.wrapped("Segure e arraste para reorganizar. Toque para inspecionar." if BioPlatform.is_touch() else "Arraste para reorganizar. Clique para inspecionar.", BioUi.FS_SMALL, BioUi.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	for i in BioAbilityRunner.SLOTS:
		var card := BioLoadoutSlot.new()
		card.configure(i, _world.abilities.slot_id(i), get_instance_id(), i == _ability_pick)
		card.selected.connect(click_ability)
		card.reordered.connect(reorder_abilities)
		row.add_child(card)
		ability_slots.append(card)
	if _ability_pick < 0 or _world.abilities.slot_id(_ability_pick) == &"":
		_content.add_child(BioUi.wrapped("Selecione uma habilidade para ver custo e efeito." if not _world.abilities.slots.is_empty() else "As habilidades chegam ao se diferenciar e cumprir chamados.", BioUi.FS_SMALL, BioUi.MUTED))
		return
	var id: StringName = _world.abilities.slot_id(_ability_pick)
	var a: Dictionary = _world.genome.tune(id, BioAbilityCatalog.get_ability(id))
	var info := BioLore.ability_info(id)
	var detail := _panel(BioUi.BG_SUNK, BioUi.LINE, 10)
	_content.add_child(detail)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	detail.add_child(v)
	v.add_child(BioUi.label(str(a.get("name", id)), BioUi.FS_HEAD, BioUi.ACCENT))
	var definition := _world.player.combatant.actor.attack_def(id) as BioAttackDef
	var stats := "%d ATP · %.1f s de recarga" % [int(definition.atp_cost), definition.cooldown]
	if a.has("damage"):
		stats += " · %d dano" % int(definition.damage)
	v.add_child(BioUi.label(stats, BioUi.FS_SMALL, BioUi.MUTED))
	v.add_child(BioUi.wrapped(str(info.get("what", "")), BioUi.FS_SMALL))
	for effect in _world.genome.transformations(id):
		v.add_child(BioUi.wrapped("GENE ATIVO · " + str(effect.description), BioUi.FS_SMALL, BioUi.GOOD))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	v.add_child(actions)
	var more := BioUi.button("Menos detalhes" if _ability_details else "Como funciona")
	more.pressed.connect(func() -> void:
		_ability_details = not _ability_details
		refresh())
	actions.add_child(more)
	var move := BioUi.button("Cancelar troca" if _ability_moving else "Trocar posição")
	move.pressed.connect(func() -> void:
		_ability_moving = not _ability_moving
		refresh())
	actions.add_child(move)
	if _ability_moving:
		v.add_child(BioUi.wrapped("Escolha o espaço de destino.", BioUi.FS_SMALL, BioUi.ACCENT))
	if _ability_details:
		v.add_child(_section("COMO FUNCIONA"))
		v.add_child(BioUi.wrapped(str(info.get("how", "")), BioUi.FS_SMALL, BioUi.MUTED))


## Inspection never changes the bar. Moving is explicit, or uses a deliberate drag.
func click_ability(slot: int) -> void:
	if slot < 0 or slot >= BioAbilityRunner.SLOTS:
		return
	if _ability_moving and _ability_pick >= 0:
		if slot == _ability_pick:
			_ability_moving = false
			refresh()
		else:
			reorder_abilities(_ability_pick, slot)
		return
	_ability_pick = slot
	_ability_details = false
	refresh()


func reorder_abilities(source: int, target: int) -> void:
	if source < 0 or target < 0 or source >= BioAbilityRunner.SLOTS or target >= BioAbilityRunner.SLOTS or source == target or _world.abilities.slot_id(source) == &"" or _world.abilities.slot_id(target) == &"":
		return
	_world.swap_abilities(source, target)
	_ability_pick = target
	_ability_details = false
	_ability_moving = false
	refresh()


# --- BUILDS ----------------------------------------------------------------------------------------------------------------------

func _build_genes(slot: int) -> Array:
	var builds: Array = _evolution().get("builds", [])
	if slot - 1 < builds.size():
		return (builds[slot - 1] as Dictionary).get("genes", [])
	return []


func _paint_builds() -> void:
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	_content.add_child(presets)
	for slot in range(1, BioBuildStore.SLOTS + 1):
		var title: String = _world.build_store.name_of(slot)
		var genes := _build_genes(slot)
		var button := BioUi.button(title + (" · vazia" if genes.is_empty() else " · %d genes" % genes.size()), "primary" if slot == _build_pick else "ghost")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.pressed.connect(func() -> void: select_build(slot))
		presets.add_child(button)
	_content.add_child(_build_card(_build_pick))
	var saved := _build_genes(_build_pick).map(func(g: Dictionary) -> StringName: return _local_id(str(g.get("id", ""))))
	if not saved.is_empty():
		_content.add_child(_result_panel(current_genes(), saved, "AO APLICAR", "Os genes já são iguais aos atuais."))


func select_build(slot: int) -> void:
	if slot < 1 or slot > BioBuildStore.SLOTS:
		return
	_build_pick = slot
	_build_ability_pick = -1
	_rename_build = false
	_confirm_save = false
	_scroll.scroll_vertical = 0
	refresh()


func _build_card(slot: int) -> Control:
	var genes := _build_genes(slot)
	var card := _panel(BioUi.BG_RAISED, BioUi.LINE, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	if _rename_build:
		var edit := LineEdit.new()
		edit.text = _world.build_store.name_of(slot)
		edit.max_length = 18
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(edit)
		edit.focus_entered.connect(func() -> void: edit.select_all.call_deferred())
		edit.grab_focus.call_deferred()
		var finish := func(text: String) -> void:
			_world.build_store.set_name(slot, text)
			_rename_build = false
			refresh()
		edit.text_submitted.connect(finish)
		var done := BioUi.button("OK")
		done.pressed.connect(func() -> void: finish.call(edit.text))
		head.add_child(done)
	else:
		var title := BioUi.label(_world.build_store.name_of(slot), BioUi.FS_HEAD, BioUi.ACCENT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var rename := BioUi.button("Renomear")
		rename.pressed.connect(func() -> void:
			_rename_build = true
			refresh())
		head.add_child(rename)
	if genes.is_empty():
		v.add_child(BioUi.wrapped("Preset vazio. Salve os genes e a ordem de habilidades atuais.", BioUi.FS_SMALL, BioUi.MUTED))
	else:
		var names: Array = genes.map(func(g: Dictionary) -> String: return str(g.get("name", "")))
		v.add_child(BioUi.wrapped(" · ".join(names), BioUi.FS_SMALL))
		var order: Array = _world.build_store.order_of(slot)
		if not order.is_empty():
			v.add_child(_section("ORDEM SALVA · segure e arraste" if BioPlatform.is_touch() else "ORDEM SALVA · arraste para editar"))
			var bar := HBoxContainer.new()
			bar.add_theme_constant_override("separation", 6)
			v.add_child(bar)
			for i in BioAbilityRunner.SLOTS:
				var icon := BioLoadoutSlot.new()
				icon.configure(i, StringName(str(order[i])) if i < order.size() else &"", -get_instance_id(), i == _build_ability_pick)
				icon.reordered.connect(func(source: int, target: int) -> void: reorder_build_abilities(slot, source, target))
				icon.selected.connect(func(index: int) -> void:
					_build_ability_pick = index
					refresh())
				bar.add_child(icon)
			if _build_ability_pick >= 0 and _build_ability_pick < order.size():
				var id := StringName(str(order[_build_ability_pick]))
				var a := BioAbilityCatalog.get_ability(id)
				v.add_child(BioUi.wrapped(str(a.get("name", id)) + ": " + str(BioLore.ability_info(id).get("what", "")), BioUi.FS_SMALL, BioUi.MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	var save := BioUi.button("Confirmar" if _confirm_save else "Salvar aqui")
	save.disabled = _busy or not _online() or _expressed().is_empty()
	save.pressed.connect(func() -> void:
		if not genes.is_empty() and not _confirm_save:
			_confirm_save = true
			refresh()
		else:
			save_build(slot))
	buttons.add_child(save)
	var apply := BioUi.button("Aplicar", "primary")
	var saved := genes.map(func(g: Dictionary) -> StringName: return _local_id(str(g.get("id", ""))))
	apply.disabled = _busy or genes.is_empty() or not lock_reason().is_empty() or (_same_genes(saved) and not _build_order_differs(slot))
	apply.pressed.connect(func() -> void: apply_build(slot))
	buttons.add_child(apply)
	var edit_skills := BioUi.button("Habilidades")
	edit_skills.pressed.connect(func() -> void: show_tab(ABILITIES))
	buttons.add_child(edit_skills)
	if _confirm_save:
		v.add_child(BioUi.wrapped("Substituirá este preset pelos genes e habilidades atuais.", BioUi.FS_SMALL, BioUi.WARN))
		var cancel := BioUi.button("Cancelar")
		cancel.pressed.connect(func() -> void:
			_confirm_save = false
			refresh())
		v.add_child(cancel)
	return card


func reorder_build_abilities(build: int, source: int, target: int) -> void:
	var order: Array = _world.build_store.order_of(build).duplicate()
	if _busy or build < 1 or build > BioBuildStore.SLOTS or source < 0 or target < 0 or source >= order.size() or target >= order.size() or source == target:
		return
	var previous: Variant = order[source]
	order[source] = order[target]
	order[target] = previous
	_world.build_store.save_order(build, order)
	_build_ability_pick = target
	_operation_note = "Ordem do preset salva neste dispositivo. Aplicar equipa a build."
	refresh()


func _build_order_differs(slot: int) -> bool:
	var order: Array = _world.build_store.order_of(slot)
	return not order.is_empty() and order != _world.abilities.known().map(func(id: Variant) -> String: return str(id))


func _same_genes(ids: Array) -> bool:
	var a := ids.map(func(id: Variant) -> String: return str(id))
	var b := current_genes().map(func(id: Variant) -> String: return str(id))
	a.sort()
	b.sort()
	return a == b


func save_build(slot: int) -> void:
	if _busy or not _online() or _expressed().is_empty():
		return
	var order: Array = _world.abilities.known().duplicate()
	if await _send("salvar-build", {"slot": str(slot)}):
		_world.build_store.save_order(slot, order)
		_confirm_save = false
		refresh()


func apply_build(slot: int) -> void:
	if _busy or not lock_reason().is_empty() or _build_genes(slot).is_empty():
		return
	var order: Array = _world.build_store.order_of(slot).duplicate()
	if await _send("aplicar-build", {"slot": str(slot)}):
		if not order.is_empty():
			_world.arrange_abilities(order)
		refresh()


func _narrow() -> bool:
	return _scroll.size.x < 900.0


func _responsive_row() -> BoxContainer:
	return VBoxContainer.new() if _narrow() else HBoxContainer.new()
