class_name BioBodyPanel
extends CanvasLayer
## The Body window (G): everything about what the cell has become, in one place, and where it is arranged. Four tabs:
##   FORMA        the class, its passive trade-offs, maturity and evolutionary pressure; the differentiation offer is chosen here.
##   GENES        the expressed genes, the library of silenced ones, the pending mutation offer, and a live comparison of what a swap
##                would do to the stats before it is made.
##   HABILIDADES  the four class abilities and the keys they sit on (swap by clicking two).
##   BUILDS       three saved sets of genes (and the order of the abilities) that can be applied in one click.
## It decides nothing: every change of genes is an intention sent to the engine, which validates it. Changes wait: not inside a
## dungeon, and not while the body is still settling from the last change (the engine says for how long).

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
var _dim: ColorRect
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
var _ability_pick := -1
var _build_pick := 1
var _last_lock := ""
var _watch := 0.0


func configure(world: Node) -> void:
	_world = world
	layer = 14
	_dim = ColorRect.new()
	_dim.color = Color(0, 0.005, 0.02, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_dim)
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 14, 20))
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_window.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_title = BioUi.label("CORPO", BioUi.FS_TITLE, BioUi.ACCENT)
	names.add_child(_title)
	_subtitle = BioUi.label("", BioUi.FS_SMALL, BioUi.MUTED)
	names.add_child(_subtitle)
	_lock_label = BioUi.label("", BioUi.FS_SMALL, BioUi.GOOD)
	_lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_lock_label)
	var close_button := BioUi.button("Fechar   G", "ghost")
	close_button.pressed.connect(close)
	head.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for i in TABS.size():
		var b := BioUi.button(TABS[i], "ghost")
		b.custom_minimum_size = Vector2(150, 34)
		var index := i
		b.pressed.connect(func() -> void: show_tab(index))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)

	_footer = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.MUTED)
	column.add_child(_footer)
	_dim.visible = false


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
	_dim.visible = true
	BioUi.set_modal(self, true)
	_swap_in = ""
	_swap_out = ""
	_ability_pick = -1
	refresh()


func close() -> void:
	if not is_open():
		return
	_dim.visible = false
	BioUi.set_modal(self, false)
	closed.emit()


func show_tab(index: int) -> void:
	tab = clampi(index, 0, TABS.size() - 1)
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
	var viewport := _window.get_viewport().get_visible_rect().size
	var size := Vector2(minf(1100.0, viewport.x - 48.0), minf(720.0, viewport.y - 48.0))
	_window.custom_minimum_size = size
	_window.size = size
	_window.position = (viewport - size) * 0.5


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
	if _world.dungeon.active:
		return "Dentro de uma masmorra o corpo não muda."
	var rest := int(_evolution().get("restLeft", 0))
	if for_rest and rest > 0:
		return "O corpo ainda se acomoda: %d s." % ceili(rest * TICK_SECONDS)
	return ""


# --- drawing ---------------------------------------------------------------------------------------------------------------------

func refresh() -> void:
	if _content == null or not is_open():
		return
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
	_lock_label.text = reason if not reason.is_empty() else "● pronto para ajustar"
	_lock_label.add_theme_color_override("font_color", BioUi.WARN if not reason.is_empty() else BioUi.GOOD)
	_footer.text = ""


func _section(text: String) -> Label:
	return BioUi.label(text, BioUi.FS_SMALL, BioArt.with_alpha(BioUi.WARN, 0.95))


func _panel(bg: Color = BioUi.BG_RAISED, border: Color = BioUi.LINE, margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
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
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_content.add_child(top)

	var left := _panel()
	left.custom_minimum_size.x = 340.0
	top.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 8)
	left.add_child(lbox)
	lbox.add_child(_section("FORMA ATUAL"))
	lbox.add_child(BioUi.label(BioLineageCatalog.display_name(lineage) if lineage != &"" else "Esfera", 26, BioArt.with_alpha(BioArt.AMBER, 0.98)))
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
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
	for line in str(e.get("text", "")).split("\n"):
		if not line.strip_edges().is_empty():
			body.add_child(BioUi.wrapped(line, BioUi.FS_SMALL + 1, BioUi.MUTED))
	if e.get("featured", false):
		body.add_child(BioUi.label("◆ o corpo pende para cá", BioUi.FS_SMALL, BioUi.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var choose := BioUi.button("Tornar-se" if lineage_offer else "Expressar", "primary")
	var reason := lock_reason(false)
	choose.disabled = not reason.is_empty()
	choose.tooltip_text = reason
	choose.pressed.connect(func() -> void: pick(index))
	body.add_child(choose)
	return card


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

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	_content.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var expressed := _expressed()
	left.add_child(_section("EXPRESSOS   %d / %d" % [expressed.size(), _slots()]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for i in _slots():
		if i < expressed.size():
			var g: Dictionary = expressed[i]
			grid.add_child(_gene_cell(g, str(g.get("id", "")) == _swap_out, func() -> void:
				_swap_out = "" if _swap_out == str(g.get("id", "")) else str(g.get("id", ""))
				refresh()))
		else:
			grid.add_child(_empty_cell("espaço livre"))

	var library := _library()
	left.add_child(_section("BIBLIOTECA   %d" % library.size()))
	if library.is_empty():
		left.add_child(BioUi.wrapped("Genes silenciados ficam guardados aqui, sem se perder. Quando o corpo ganha um gene e os espaços estão cheios, o mais antigo vai para a biblioteca.", BioUi.FS_SMALL, BioUi.MUTED))
	else:
		var lib_grid := GridContainer.new()
		lib_grid.columns = 2
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
	swap.disabled = not can_swap or not reason.is_empty()
	swap.tooltip_text = reason
	swap.pressed.connect(express_selected)
	actions.add_child(swap)
	var silence := BioUi.button("Silenciar", "ghost")
	silence.disabled = _swap_out.is_empty() or not _swap_in.is_empty() or not reason.is_empty()
	silence.tooltip_text = reason
	silence.pressed.connect(silence_selected)
	actions.add_child(silence)
	var hint := "Escolha um gene da biblioteca" + (" e o gene expresso que dá o lugar." if full else ".")
	actions.add_child(BioUi.label(hint if not can_swap and _swap_out.is_empty() else "", BioUi.FS_SMALL, BioUi.MUTED))

	split.add_child(_result_panel(current_genes(), previewed_genes(), "RESULTADO DA TROCA", "Escolha uma troca para ver o que muda."))


## A gene as a clickable cell: name, rarity, what it does.
func _gene_cell(gene: Dictionary, selected: bool, on_click: Callable) -> Control:
	var cell := PanelContainer.new()
	var rarity_color := BioUi.rarity_color(str(gene.get("rarity", "")))
	cell.add_theme_stylebox_override("panel", BioUi.style(Color(0.1, 0.18, 0.3, 0.98) if selected else BioUi.BG_RAISED, BioUi.LINE_STRONG if selected else BioUi.LINE, 9, 10, 2 if selected else 1))
	cell.custom_minimum_size = Vector2(250, 66)
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
	head.add_child(BioUi.label("  " + str(gene.get("name", "")), BioUi.FS_BODY, BioUi.TEXT))
	var local := _local_id(str(gene.get("id", "")))
	var summary := BioGeneCatalog.get_gene(local).summary() if BioGeneCatalog.all_ids().has(local) else str(gene.get("desc", ""))
	var s := BioUi.wrapped(summary, BioUi.FS_SMALL, BioUi.MUTED)
	s.max_lines_visible = 3
	v.add_child(s)
	cell.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	return cell


func _empty_cell(text: String) -> Control:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", BioUi.style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.1), 9, 10))
	cell.custom_minimum_size = Vector2(250, 66)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := BioUi.label(text, BioUi.FS_SMALL, Color(1, 1, 1, 0.3))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(l)
	return cell


## The comparison table: each stat that is not neutral, now → after, green when it gets better and red when it gets worse.
func _result_panel(current: Array, previewed: Array, title: String, empty_text: String) -> Control:
	var box := _panel(BioUi.BG_SUNK, BioUi.LINE, 14)
	box.custom_minimum_size.x = 340.0
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	v.add_child(_section(title))
	var rows := BioBuildPreview.rows(_world.lineage_id, current, previewed)
	if rows.is_empty():
		v.add_child(BioUi.wrapped(empty_text, BioUi.FS_SMALL, BioUi.MUTED))
	for r in rows:
		var row := HBoxContainer.new()
		var name_label := BioUi.label(str(r["label"]), BioUi.FS_SMALL + 1, BioUi.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var better := int(r["better"])
		var color := BioUi.GOOD if better > 0 else (BioUi.BAD if better < 0 else BioUi.MUTED)
		var text := str(r["then"]) if str(r["now"]) == str(r["then"]) else "%s  →  %s" % [r["now"], r["then"]]
		row.add_child(BioUi.label(text, BioUi.FS_SMALL + 1, color))
		v.add_child(row)
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


func _send(action: String, args: Dictionary) -> void:
	var res: Dictionary = await _world.sync.link.act(action, args)
	if res.get("status", 0) != 200:
		_world.sync.system.push_feed("O corpo não aceitou essa mudança agora.")
		return
	_swap_in = ""
	_swap_out = ""
	for e in res.get("body", {}).get("events", []):
		_world.sync.system.push_feed(str(e.get("text", "")))
	if is_open():
		refresh()


# --- HABILIDADES -----------------------------------------------------------------------------------------------------------------

func _paint_abilities() -> void:
	_content.add_child(BioUi.wrapped("As habilidades da sua classe ficam em quatro teclas. Clique em uma e depois em outra para trocá-las de lugar; a ordem fica guardada nesta máquina.", BioUi.FS_BODY, BioUi.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for i in BioAbilityRunner.SLOTS:
		row.add_child(_ability_card(i))
	if _world.abilities.slots.is_empty():
		_content.add_child(BioUi.wrapped("Sua forma ainda não conhece habilidades. Elas chegam ao se diferenciar e ao cumprir chamados.", BioUi.FS_BODY, BioUi.MUTED))


func _ability_card(slot: int) -> Control:
	var id: StringName = _world.abilities.slot_id(slot)
	var picked := slot == _ability_pick
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 150)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var color := Color(0.3, 0.4, 0.5)
	if id != &"":
		color = BioAbilityCatalog.get_ability(id).get("color", color)
	card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioUi.LINE_STRONG if picked else BioArt.with_alpha(color, 0.35), 10, 14, 2 if picked else 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(BioUi.keycap(KEYS[slot]))
	if id == &"":
		v.add_child(BioUi.label("vazio", BioUi.FS_HEAD, Color(1, 1, 1, 0.3)))
	else:
		var a := BioAbilityCatalog.get_ability(id)
		var kind := str(a.get("kind", ""))
		head.add_child(BioUi.label("  " + str(KIND_NAMES.get(kind, BioLore.KIND_NAMES.get(kind, kind))), BioUi.FS_SMALL, BioUi.MUTED))
		v.add_child(BioUi.label(str(a.get("name", id)), BioUi.FS_HEAD, color.lightened(0.35)))
		v.add_child(BioUi.label("custo %d ATP" % int(a.get("cost", 0)), BioUi.FS_SMALL + 1, BioUi.TEXT))
		v.add_child(BioUi.label("recarga %.1f s" % float(a.get("cooldown", 0)), BioUi.FS_SMALL + 1, BioUi.TEXT))
		if a.has("damage"):
			v.add_child(BioUi.label("dano %d" % int(a.get("damage", 0)), BioUi.FS_SMALL + 1, BioUi.TEXT))
		var info := BioLore.ability_info(id)
		if not info.is_empty():
			v.add_child(_section("O QUE FAZ"))
			v.add_child(BioUi.wrapped(str(info["what"]), BioUi.FS_SMALL, BioUi.TEXT))
			v.add_child(_section("COMO FUNCIONA"))
			v.add_child(BioUi.wrapped(str(info["how"]), BioUi.FS_SMALL, BioUi.MUTED))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click_ability(slot))
	return card


## First click picks a slot, the second swaps it with the one clicked (a click on the same one lets go).
func click_ability(slot: int) -> void:
	if _ability_pick < 0:
		if _world.abilities.slot_id(slot) != &"":
			_ability_pick = slot
	elif _ability_pick == slot:
		_ability_pick = -1
	else:
		_world.swap_abilities(_ability_pick, slot)
		_ability_pick = -1
	refresh()


# --- BUILDS ----------------------------------------------------------------------------------------------------------------------

func _build_genes(slot: int) -> Array:
	var builds: Array = _evolution().get("builds", [])
	if slot - 1 < builds.size():
		return (builds[slot - 1] as Dictionary).get("genes", [])
	return []


func _paint_builds() -> void:
	if not _online():
		_content.add_child(BioUi.wrapped("Sem o motor, o corpo não guarda builds.", BioUi.FS_BODY, BioUi.WARN))
	_content.add_child(BioUi.wrapped("Uma build guarda os genes que estão expressos agora e a ordem das habilidades. Aplicar uma troca os genes de uma vez, respeitando o descanso do corpo. Clique em uma build para ver o que ela faria.", BioUi.FS_BODY, BioUi.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for slot in range(1, BioBuildStore.SLOTS + 1):
		row.add_child(_build_card(slot))
	var saved := _build_genes(_build_pick).map(func(g: Dictionary) -> StringName: return _local_id(str(g.get("id", ""))))
	_content.add_child(_result_panel(current_genes(), saved, "SE APLICAR A BUILD %d" % _build_pick, "Esta build está vazia ou igual ao que está expresso."))


func _build_card(slot: int) -> Control:
	var genes := _build_genes(slot)
	var picked := slot == _build_pick
	var card := _panel(BioUi.BG_RAISED, BioUi.LINE_STRONG if picked else BioUi.LINE, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _build_pick != slot:
			_build_pick = slot
			refresh())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = _world.build_store.name_of(slot)
	name_edit.max_length = 18
	name_edit.flat = true
	name_edit.add_theme_font_size_override("font_size", BioUi.FS_HEAD)
	name_edit.add_theme_color_override("font_color", BioUi.ACCENT)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = "Clique para renomear"
	name_edit.text_submitted.connect(func(text: String) -> void:
		_world.build_store.set_name(slot, text)
		name_edit.release_focus())
	name_edit.focus_exited.connect(func() -> void: _world.build_store.set_name(slot, name_edit.text))
	name_row.add_child(name_edit)
	if genes.is_empty():
		v.add_child(BioUi.label("vazia", BioUi.FS_BODY, Color(1, 1, 1, 0.3)))
	for g in genes:
		var gene: Dictionary = g
		var dot_row := HBoxContainer.new()
		dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := ColorRect.new()
		dot.color = BioUi.rarity_color(str(gene.get("rarity", "")))
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot_row.add_child(dot)
		dot_row.add_child(BioUi.label("  " + str(gene.get("name", "")), BioUi.FS_SMALL + 1, BioUi.TEXT))
		v.add_child(dot_row)
	var order: Array = _world.build_store.order_of(slot)
	if not order.is_empty():
		var names: Array = order.map(func(id: Variant) -> String: return str(BioAbilityCatalog.get_ability(StringName(str(id))).get("name", id)))
		v.add_child(BioUi.wrapped("Teclas: " + ", ".join(names), BioUi.FS_SMALL, BioUi.MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	var save := BioUi.button("Salvar aqui", "ghost")
	save.disabled = not _online() or _expressed().is_empty()
	save.pressed.connect(func() -> void: save_build(slot))
	buttons.add_child(save)
	var reason := lock_reason()
	var apply := BioUi.button("Aplicar", "primary")
	var saved_local := genes.map(func(g: Dictionary) -> StringName: return _local_id(str(g.get("id", ""))))
	apply.disabled = genes.is_empty() or not reason.is_empty() or BioBuildPreview.rows(_world.lineage_id, current_genes(), saved_local).is_empty() and _same_genes(saved_local)
	apply.tooltip_text = reason
	apply.pressed.connect(func() -> void: apply_build(slot))
	buttons.add_child(apply)
	return card


func _same_genes(ids: Array) -> bool:
	var a := ids.map(func(id: Variant) -> String: return str(id))
	var b := current_genes().map(func(id: Variant) -> String: return str(id))
	a.sort()
	b.sort()
	return a == b


func save_build(slot: int) -> void:
	if not _online() or _expressed().is_empty():
		return
	_world.build_store.save_order(slot, _world.abilities.known())
	_send("salvar-build", {"slot": str(slot)})


func apply_build(slot: int) -> void:
	if not lock_reason().is_empty() or _build_genes(slot).is_empty():
		return
	var order: Array = _world.build_store.order_of(slot)
	if not order.is_empty():
		_world.arrange_abilities(order)
	_send("aplicar-build", {"slot": str(slot)})
