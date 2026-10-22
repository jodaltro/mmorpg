class_name Hud
extends CanvasLayer
## Interface: status, minimap, quest tracker, offer popup, journal, toasts and log.
## It only shows what the engine's view says and emits the player's intents.

signal accept_pressed(key: String)
signal decline_pressed(key: String)
signal abandon_pressed(key: String)
signal action_chosen(index: int)
signal ability_pressed(index: int)
signal reset_world_requested
var reset_panel: PanelContainer

const GOLD := Color(0.86, 0.7, 0.36)
const RANK_COLORS := {"F": "9a9a9a", "E": "9a9a9a", "D": "7bc96f", "C": "5aa9e6", "B": "a97be0", "A": "f0a040", "S": "e8574a", "SS": "ffd060"}
const STATE_PT := {"done": "concluida", "failed": "falhou", "expired": "expirou", "declined": "recusada", "withdrawn": "retirada",
	"obsolete": "obsoleta", "superseded": "substituida", "abandoned": "abandonada"}
# Region colours on the minimap; the boxes themselves come from Layout.ZONES.
const REGION_COLORS := {"vila": Color(0.28, 0.45, 0.25), "estrada": Color(0.5, 0.38, 0.25), "floresta": Color(0.16, 0.3, 0.17),
	"mina": Color(0.38, 0.36, 0.36), "ruinas": Color(0.45, 0.42, 0.33), "toca": Color(0.3, 0.42, 0.2)}
const SHORT := {"vila": "Vila", "estrada": "Estr.", "floresta": "Floresta", "mina": "Mina", "ruinas": "Ruinas", "toca": "Toca"}

var root: Control
var region_label: Label
var time_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var minimap: Minimap
var landmarks: Landmarks
var tracker_box: VBoxContainer
var right_col: VBoxContainer
var log_panel: PanelContainer
var log_box: VBoxContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer
var offer_panel: PanelContainer
var offer_text: RichTextLabel
var offer_buttons := {}  # accept / decline / later
var notebook_panel: PanelContainer
var notebook_box: VBoxContainer
var _nb_tab := "pistas"
var _nb_data := {}
var journal_panel: PanelContainer
var action_panel: PanelContainer
var action_title: Label
var action_box: VBoxContainer
var action_buttons: Array = []
var slots: Array = []  # hotbar slots, one per ability
var skills_panel: PanelContainer
var skills_box: VBoxContainer
var abilities: Array = []
var journal_box: VBoxContainer
var quests: Array = []
var skills: Array = []
var names: Dictionary = {}
var region_names: Dictionary = {}
var tick := 0
var offered_key := ""
var _postponed := ""
var _known := {}
var _known_skills := {}
var _first := true
signal ceremony_done
var ceremony_pending := false  # the first system window gets a little ceremony
var _offer_hold := 0


class Minimap extends Control:
	var X0 := Layout.MAP_BOUNDS.position.x
	var X1 := Layout.MAP_BOUNDS.end.x
	var Z0 := Layout.MAP_BOUNDS.position.y
	var Z1 := Layout.MAP_BOUNDS.end.y
	var player_pos := Vector3.ZERO
	var player_yaw := 0.0
	var npcs: Array = []
	var enemies: Array = []
	var quest_regions: Array = []
	var current_region := ""
	var region_names := {}
	var known: Array = []  # regions on the map: it starts blank

	func _p(x: float, z: float) -> Vector2:
		return Vector2((x - X0) / (X1 - X0) * size.x, (z - Z0) / (Z1 - Z0) * size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06, 0.95))
		var font := ThemeDB.fallback_font
		for id in Layout.ZONES:
			if not known.has(id):
				continue
			var z: Array = Layout.ZONES[id]
			var a := _p(z[0].x - z[1].x / 2.0, z[0].z - z[1].z / 2.0)
			var c := _p(z[0].x + z[1].x / 2.0, z[0].z + z[1].z / 2.0)
			var r := Rect2(a, c - a)
			draw_rect(r, REGION_COLORS.get(id, Color(0.3, 0.3, 0.3)))
			if quest_regions.has(id):
				draw_rect(r.grow(-1.5), GOLD, false, 2.0)
			if current_region == id:
				draw_rect(r, Color(1, 1, 1, 0.12))
			draw_string(font, a + Vector2(3, 11), SHORT.get(id, id), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.8))
		for n in npcs:
			draw_circle(_p(n.x, n.z), 2.5, Color(1.0, 0.9, 0.4))
		for e in enemies:
			draw_circle(_p(e.x, e.z), 3.0, Color(0.95, 0.25, 0.25))
		var pp := _p(player_pos.x, player_pos.z)
		var d := Vector2(sin(player_yaw), cos(player_yaw))
		draw_colored_polygon(PackedVector2Array([pp + d * 7.0, pp + d.rotated(2.5) * 5.0, pp + d.rotated(-2.5) * 5.0]), Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.3, 0.9), false, 1.0)


## Arrows on the screen border toward landmarks you can make out but have not visited.
class Landmarks extends Control:
	var items: Array = []  # {pos: Vector2 (screen, may be off-screen), label, color}

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var inset := 34.0
		var area := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		var center := size / 2.0
		var taken: Array = []  # label rectangles already drawn: stack below instead of overlapping
		for it in items:
			var p: Vector2 = it.pos
			if area.has_point(p):
				continue
			var d := (p - center).normalized()
			var t := 1e9
			if absf(d.x) > 0.001:
				t = minf(t, (area.size.x / 2.0) / absf(d.x))
			if absf(d.y) > 0.001:
				t = minf(t, (area.size.y / 2.0) / absf(d.y))
			var at := center + d * t
			var c: Color = it.color
			var tip := at + d * 12.0
			draw_colored_polygon(PackedVector2Array([tip, at + d.rotated(2.5) * 9.0, at + d.rotated(-2.5) * 9.0]), c)
			var label: String = it.label
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lp := at - d * 20.0 - Vector2(w * (0.5 + d.x * 0.5), -4.0)
			lp.x = clampf(lp.x, 6.0, size.x - w - 6.0)
			var rect := Rect2(lp + Vector2(0, -12), Vector2(w, 16))
			for _i in 4:
				var clash := false
				for r in taken:
					clash = clash or (r as Rect2).intersects(rect)
				if not clash:
					break
				rect.position.y += 17.0
				lp.y += 17.0
			taken.append(rect)
			draw_string(font, lp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.85))
			draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c.lightened(0.25))


class Slot extends Control:
	var kind := ""
	var key := ""
	var color := Color.WHITE
	var left := 0.0
	var total := 1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.07, 0.1, 0.92))
		var c := size / 2.0
		var k := color if left <= 0.0 else color.darkened(0.55)
		match kind:
			"giro":
				draw_arc(c, 15, 0.3, TAU - 0.3, 24, k, 4.0)
				draw_arc(c, 8, 1.5, TAU + 1.0, 18, k, 3.0)
			"investida":
				draw_line(c + Vector2(-15, 8), c + Vector2(12, -8), k, 5.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(17, -11), c + Vector2(5, -12), c + Vector2(13, 0)]), k)
			"lamina":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17), c + Vector2(7, 0), c + Vector2(0, 17), c + Vector2(-7, 0)]), k)
			"cura":
				draw_rect(Rect2(c - Vector2(4, 14), Vector2(8, 28)), k)
				draw_rect(Rect2(c - Vector2(14, 4), Vector2(28, 8)), k)
			"esquiva":
				draw_arc(c + Vector2(0, 4), 13, PI, TAU, 18, k, 4.0)
				draw_circle(c + Vector2(13, 4), 4, k)
		if left > 0.0:  # cooldown: a dark sweep and the seconds left
			var frac := clampf(left / total, 0.0, 1.0)
			var pts := PackedVector2Array([c])
			for i in 25:
				var ang := -PI / 2.0 + TAU * frac * i / 24.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * size.x)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
			draw_string(ThemeDB.fallback_font, Vector2(0, c.y + 6), "%.0f" % ceilf(left), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
		draw_rect(r, Color(0.75, 0.6, 0.3, 0.9) if left <= 0.0 else Color(0.4, 0.35, 0.25), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(4, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_meta("hud").ability_pressed.emit(get_meta("index"))
			accept_event()


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status()
	_build_right_column()
	_build_log()
	_build_prompt()
	_build_toasts()
	_build_offer()
	_build_journal()
	_build_notebook()
	_build_world_button()
	landmarks = Landmarks.new()
	landmarks.set_anchors_preset(Control.PRESET_FULL_RECT)
	landmarks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(landmarks)
	_build_actions()
	_build_skills_panel()
	var slot := _slot(Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_END, 10)
	var help := _label("WASD mover   Mouse esq. golpe   Mouse dir. ir/usar   [E] Usar/Falar   [F] Acoes   [K] Habilidades   [J] Diario   [C] Caderno   [T] Tocha   [M] Marca   [Z] Olhar longe   [Shift] Rastrear", 12, Color(1, 1, 1, 0.55))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.size_flags_horizontal = Control.SIZE_SHRINK_END
	help.size_flags_vertical = Control.SIZE_SHRINK_END
	slot.add_child(help)


func _process(_delta: float) -> void:
	log_panel.visible = log_box.get_child_count() > 0


# --- building blocks ---------------------------------------------------------

## A full-screen margin box that pins its child to a corner or edge.
func _slot(h: int, v: int, margin := 12, top := -1, bottom := -1) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", margin)
	m.add_theme_constant_override("margin_right", margin)
	m.add_theme_constant_override("margin_top", margin if top < 0 else top)
	m.add_theme_constant_override("margin_bottom", margin if bottom < 0 else bottom)
	root.add_child(m)
	m.set_meta("h", h)
	m.set_meta("v", v)
	return m


func _pin(slot: MarginContainer, c: Control) -> void:
	c.size_flags_horizontal = slot.get_meta("h")
	c.size_flags_vertical = slot.get_meta("v")


func _panel(parent: Control, alpha := 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, alpha)
	sb.border_color = Color(0.75, 0.6, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	if parent is MarginContainer and parent.has_meta("h"):
		_pin(parent, p)
	return p


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rich(width: float, size := 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = width
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	return r


func _ignore(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control:
			_ignore(ch)


func _build_status() -> void:
	var slot := _slot(Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_BEGIN)
	var p := _panel(slot)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 250
	p.add_child(v)
	region_label = _label("", 20, GOLD)
	v.add_child(region_label)
	time_label = _label("", 13, Color(0.8, 0.85, 1.0))
	v.add_child(time_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(250, 18)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	hp_bar.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.04, 0.05)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.2, 0.22)
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(hp_bar)
	hp_text = _label("", 12, Color(1, 1, 1, 0.9))
	hp_bar.add_child(hp_text)
	_ignore(p)


## A small button under the status that starts the world over (the old world is archived, never deleted).
func _build_world_button() -> void:
	var slot := _slot(Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_BEGIN, 12, 118)
	var b := _button("Reiniciar mundo", func() -> void: reset_panel.visible = true, 12)
	b.modulate = Color(1, 1, 1, 0.75)
	_pin(slot, b)
	slot.add_child(b)
	var cslot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_CENTER)
	reset_panel = _panel(cslot, 0.97)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	reset_panel.add_child(v)
	v.add_child(_label("Reiniciar o mundo?", 20, GOLD))
	var t := _label("O mundo atual e arquivado (nada e apagado) e todos os personagens recomecam do zero, numa Valdoria nova.", 14)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 420
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(_button("Sim, reiniciar", func() -> void:
		reset_panel.visible = false
		reset_world_requested.emit()))
	row.add_child(_button("Cancelar", func() -> void: reset_panel.visible = false))
	reset_panel.visible = false


func _build_right_column() -> void:
	var slot := _slot(Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_BEGIN)
	var col := VBoxContainer.new()
	right_col = col
	col.custom_minimum_size.x = 246
	col.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 8)
	slot.add_child(col)
	var mp := _panel(col)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(226, 160)
	mp.add_child(minimap)
	var tp := _panel(col)
	tracker_box = VBoxContainer.new()
	tracker_box.custom_minimum_size.x = 226
	tracker_box.add_theme_constant_override("separation", 8)
	tp.add_child(tracker_box)
	_ignore(col)


func _build_log() -> void:
	var slot := _slot(Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_END)
	log_panel = _panel(slot, 0.7)
	log_box = VBoxContainer.new()
	log_box.custom_minimum_size.x = 420
	log_box.add_theme_constant_override("separation", 2)
	log_panel.add_child(log_box)
	log_panel.visible = false
	_ignore(log_panel)


func _build_prompt() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END, 12, 12, 92)
	prompt_panel = _panel(slot, 0.85)
	prompt_label = _label("", 16, Color.WHITE)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	_ignore(prompt_panel)


func _build_toasts() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_BEGIN, 12, 14)
	toast_box = VBoxContainer.new()
	toast_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
	slot.add_child(toast_box)
	_ignore(toast_box)


func _build_offer() -> void:
	offer_panel = _panel(right_col, 0.94)  # compact card under the tracker, never over the action
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	offer_panel.add_child(v)
	v.add_child(_label("Nova missao", 12, GOLD))
	offer_text = _rich(226, 12)
	v.add_child(offer_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	offer_buttons.accept = _button("Aceitar [Y]", func(): accept_pressed.emit(offered_key), 12)
	offer_buttons.decline = _button("Recusar [N]", func(): decline_pressed.emit(offered_key), 12)
	offer_buttons.later = _button("Depois", postpone_offer, 12)
	for b in [offer_buttons.accept, offer_buttons.decline, offer_buttons.later]:
		row.add_child(b)
	offer_panel.visible = false


func _build_journal() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_CENTER)
	journal_panel = _panel(slot, 0.96)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	journal_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("Diario", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Fechar [J]", toggle_journal))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 430)
	v.add_child(scroll)
	journal_box = VBoxContainer.new()
	journal_box.custom_minimum_size.x = 680
	journal_box.add_theme_constant_override("separation", 10)
	scroll.add_child(journal_box)
	journal_panel.visible = false


func _build_notebook() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_CENTER)
	notebook_panel = _panel(slot, 0.96)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	notebook_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var title := _label("Caderno", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for t in [["pistas", "Pistas"], ["pessoas", "Pessoas"], ["lugares", "Lugares"]]:
		head.add_child(_button(t[1], func() -> void:
			_nb_tab = t[0]
			_rebuild_notebook()))
	head.add_child(_button("Fechar [C]", toggle_notebook))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 430)
	v.add_child(scroll)
	notebook_box = VBoxContainer.new()
	notebook_box.custom_minimum_size.x = 680
	notebook_box.add_theme_constant_override("separation", 8)
	scroll.add_child(notebook_box)
	notebook_panel.visible = false


## data: {pistas: [{text, source}], perguntas: [text], pessoas: [{name, know, where}], lugares: [name]}
func set_notebook(data: Dictionary) -> void:
	_nb_data = data
	if notebook_panel.visible:
		_rebuild_notebook()


func toggle_notebook() -> void:
	notebook_panel.visible = not notebook_panel.visible
	if notebook_panel.visible:
		journal_panel.visible = false
		_rebuild_notebook()


func _rebuild_notebook() -> void:
	for c in notebook_box.get_children():
		notebook_box.remove_child(c)
		c.queue_free()
	match _nb_tab:
		"pistas":
			var qs: Array = _nb_data.get("perguntas", [])
			if not qs.is_empty():
				notebook_box.add_child(_label("Perguntas em aberto", 16, Color(0.7, 0.85, 1.0)))
				for q in qs:
					var l := _rich(660, 14)
					l.text = "[color=#9ec5ff]?[/color]  %s" % q
					notebook_box.add_child(l)
			notebook_box.add_child(_label("O que voce sabe", 16, GOLD))
			var cl: Array = _nb_data.get("pistas", [])
			if cl.is_empty():
				notebook_box.add_child(_label("Ainda nada. Examine o que parecer estranho.", 13, Color(1, 1, 1, 0.55)))
			for c in cl:
				var l := _rich(660, 14)
				l.text = "%s\n[color=#999999]%s[/color]" % [c.text, c.source]
				notebook_box.add_child(l)
		"pessoas":
			var ps: Array = _nb_data.get("pessoas", [])
			if ps.is_empty():
				notebook_box.add_child(_label("Voce ainda nao conheceu ninguem.", 13, Color(1, 1, 1, 0.55)))
			for p in ps:
				var l := _rich(660, 14)
				l.text = "[b]%s[/b]  %s\n[color=#999999]%s[/color]" % [p.name, "[color=#ffe08a][te conhece][/color]" if p.know else "[color=#888888][nao te conhece][/color]", p.where]
				notebook_box.add_child(l)
		"lugares":
			for n in _nb_data.get("lugares", []):
				notebook_box.add_child(_label(n, 15))


func _build_actions() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END, 12, 12, 140)
	action_panel = _panel(slot, 0.95)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	action_panel.add_child(v)
	action_title = _label("", 14, GOLD)
	v.add_child(action_title)
	action_box = VBoxContainer.new()
	action_box.custom_minimum_size.x = 360
	action_box.add_theme_constant_override("separation", 3)
	v.add_child(action_box)
	v.add_child(_label("[1-9] escolher   [Esc] fechar", 11, Color(1, 1, 1, 0.5)))
	action_panel.visible = false


## Options from the engine's affordances; the engine still decides.
## Hotbar: one slot per combat ability (1-4, R), with tooltip and cooldown.
func build_hotbar(list: Array) -> void:
	abilities = list
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END, 12, 12, 26)
	var p := _panel(slot, 0.8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	for i in list.size():
		var ab: Dictionary = list[i]
		var s := Slot.new()
		s.custom_minimum_size = Vector2(54, 54)
		s.clip_contents = true  # the cooldown sweep stays inside the icon
		s.kind = ab.id
		s.key = ab.key
		s.color = ab.color
		s.total = ab.cd
		s.tooltip_text = "%s [%s]\n%s\nRecarga: %.1f s" % [ab.name, ab.key, ab.desc, ab.cd]
		s.set_meta("hud", self)
		s.set_meta("index", i)
		row.add_child(s)
		slots.append(s)


func set_cooldowns(left: Array) -> void:
	for i in slots.size():
		var v: float = left[i]
		if absf(v - slots[i].left) > 0.02 or (v <= 0.0) != (slots[i].left <= 0.0):
			slots[i].left = v
			slots[i].queue_redraw()


func _build_skills_panel() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_CENTER)
	skills_panel = _panel(slot, 0.96)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	skills_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("Habilidades", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Fechar [K]", toggle_skills))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 420)
	v.add_child(scroll)
	skills_box = VBoxContainer.new()
	skills_box.custom_minimum_size.x = 620
	skills_box.add_theme_constant_override("separation", 8)
	scroll.add_child(skills_box)
	skills_panel.visible = false


func toggle_skills() -> void:
	skills_panel.visible = not skills_panel.visible
	if skills_panel.visible:
		_rebuild_skills()


func _rebuild_skills() -> void:
	for c in skills_box.get_children():
		skills_box.remove_child(c)
		c.queue_free()
	skills_box.add_child(_label("Combate", 15, GOLD))
	for ab in abilities:
		var r := _rich(600, 13)
		r.text = "[color=#%s][b]%s[/b][/color]  [color=#999999][%s] recarga %.1f s[/color]\n%s" % [ab.color.to_html(false), ab.name, ab.key, ab.cd, ab.desc]
		skills_box.add_child(r)
	skills_box.add_child(_label("Aprendidas no mundo (%d)" % skills.size(), 15, GOLD))
	if skills.is_empty():
		skills_box.add_child(_label("Nenhuma ainda. O mundo aprende o que voce faz: habitos, sorte e lugares escondidos ensinam.", 13, Color(1, 1, 1, 0.55)))
	for s in skills:
		var r := _rich(600, 13)
		r.text = "[b]%s[/b] [color=#999999](%s)[/color]\n%s" % [s.name, s.rarity, s.get("desc", "")]
		skills_box.add_child(r)


func show_actions(title: String, labels: Array) -> void:
	for b in action_buttons:
		b.queue_free()
	action_buttons.clear()
	action_title.text = title
	for i in labels.size():
		var b := _button("%d. %s" % [i + 1, labels[i]], func(): action_chosen.emit(i), 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action_box.add_child(b)
		action_buttons.append(b)
	action_panel.visible = true


func hide_actions() -> void:
	action_panel.visible = false


func actions_open() -> bool:
	return action_panel.visible


func _button(text: String, cb: Callable, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


# --- updates ----------------------------------------------------------------

func set_status(region_name: String, hour: int, tick_now: int) -> void:
	tick = tick_now
	region_label.text = region_name
	if hour >= 0:
		time_label.text = "%02d:00  %s" % [hour, "Dia" if hour >= 6 and hour < 19 else "Noite"]
	else:
		time_label.text = "tick %d" % tick_now


func set_hp(cur: float, maxv: float) -> void:
	hp_bar.max_value = maxv
	hp_bar.value = cur
	hp_text.text = "%d / %d" % [int(cur), int(maxv)]
	hp_text.position = Vector2((hp_bar.size.x - hp_text.size.x) / 2.0, 0)


func set_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = text


func add_log(bb: String) -> void:
	var r := _rich(420, 13)
	r.text = bb
	log_box.add_child(r)
	log_panel.visible = true
	while log_box.get_child_count() > 7:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()
	var tw := r.create_tween()  # dies with the line, so no dangling captures
	tw.tween_interval(14.0)
	tw.tween_property(r, "modulate:a", 0.0, 1.5)
	tw.tween_callback(r.queue_free)


func toast(text: String, color := Color.WHITE) -> void:
	while toast_box.get_child_count() >= 4:  # bursts of world events stay readable
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var p := _panel(toast_box, 0.9)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(_label(text, 16, color))
	_ignore(p)
	var tw := p.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


## A full-screen title card: fades in, holds, fades out. dim is how dark the screen gets (1 = black).
func card(lines: Array, hold := 2.4, dim := 1.0, size := 30) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(box)
	for i in lines.size():
		var l := _label(lines[i], size if i == 0 else int(size * 0.62), GOLD if i == 0 else Color(0.9, 0.88, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		box.add_child(l)
		var lt := l.create_tween()
		lt.tween_interval(0.5 + i * 0.9)
		lt.tween_property(l, "modulate:a", 1.0, 0.7)
	var tw := shade.create_tween()
	tw.tween_interval(hold + lines.size() * 0.9)
	tw.tween_property(shade, "modulate:a", 0.0, 1.2)
	tw.tween_callback(shade.queue_free)


## "While you were away": what happened in the world since the last visit.
func recap(lines: Array) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(520, 0)
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	box.add_child(_label("Enquanto voce esteve fora", 20, GOLD))
	for t in lines:
		var l := _label("- " + t, 14, Color(0.88, 0.88, 0.92))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 480
		box.add_child(l)
	var b := Button.new()
	b.text = "Continuar"
	b.pressed.connect(center.queue_free)
	box.add_child(b)


func set_landmarks(list: Array) -> void:
	landmarks.items = list
	landmarks.queue_redraw()


func set_known(list: Array) -> void:
	minimap.known = list
	minimap.queue_redraw()


func set_minimap(player_pos: Vector3, yaw: float, npc_pos: Array, enemy_pos: Array, region: String) -> void:
	minimap.player_pos = player_pos
	minimap.player_yaw = yaw
	minimap.npcs = npc_pos
	minimap.enemies = enemy_pos
	minimap.current_region = region
	minimap.region_names = region_names
	minimap.queue_redraw()


func set_skills(list: Array) -> void:
	skills = list
	for s in list:
		if not _known_skills.has(s.id):
			_known_skills[s.id] = true
			if not _first:
				toast("Habilidade aprendida: %s (%s)" % [s.name, s.rarity], Color(1.0, 0.85, 0.4))
	if journal_panel.visible:
		_rebuild_journal()
	if skills_panel.visible:
		_rebuild_skills()


func set_quests(list: Array, tick_now: int, who: Dictionary, regions: Dictionary) -> void:
	quests = list
	tick = tick_now
	names = who
	region_names = regions
	for q in list:
		var before: String = _known.get(q.key, "")
		if before != q.state and not _first:
			_quest_toast(q, before)
		_known[q.key] = q.state
	_first = false
	_rebuild_tracker()
	_rebuild_offer()
	if journal_panel.visible:
		_rebuild_journal()
	var regs := []
	for q in list:
		if q.state == "active" and q.get("region", "") != "":
			regs.append(q.region)
	minimap.quest_regions = regs


func _quest_toast(q: Dictionary, before: String) -> void:
	match q.state:
		"offered":
			if ceremony_pending:
				ceremony_pending = false
				_offer_hold = Time.get_ticks_msec() + 2800
				card(["O Sistema percebeu voce."], 2.0, 0.45, 34)
				get_tree().create_timer(2.9).timeout.connect(_rebuild_offer)
				ceremony_done.emit()
			toast("Nova missao: %s" % q.title, GOLD)
		"active":
			toast("Missao aceita: %s" % q.title, Color(0.6, 0.85, 1.0))
		"done":
			toast("Missao concluida: %s" % q.title, Color(0.55, 0.9, 0.5))
		"failed":
			toast("Missao falhou: %s" % q.title, Color(0.95, 0.45, 0.4))
		"expired", "withdrawn", "obsolete", "superseded":
			if before == "active" or before == "offered":
				toast("Missao encerrada: %s" % q.title, Color(0.75, 0.75, 0.75))


func _rank_hex(q: Dictionary) -> String:
	return RANK_COLORS.get(q.get("rank", ""), "9a9a9a")


func _is_unique(q: Dictionary) -> bool:
	return String(q.get("def", "")).begins_with("cenario-")


func _quest_head(q: Dictionary) -> String:
	var s := "[color=#%s][b][%s][/b][/color] [b]%s[/b]" % [_rank_hex(q), q.get("rank", "?"), q.title]
	if _is_unique(q):
		s += "  [color=#ffd060]Cenario Unico[/color]"
	return s


func _quest_body(q: Dictionary, full: bool) -> String:
	var s := ""
	var giver: String = names.get(q.get("giver", ""), "")
	if full and giver != "":
		s += "[color=#aaaaaa]De %s[/color]\n" % giver
	if full and q.get("desc", "") != "":
		s += "%s\n" % q.desc
	if q.get("objective", "") != "":
		s += "[color=#dddddd]%s[/color]\n" % q.objective
	var reg: String = region_names.get(q.get("region", ""), "")
	if reg != "":
		s += "[color=#e0c070]Local: %s[/color]\n" % reg
	if q.get("reward", "") != "":
		s += "[color=#8fd880]Recompensa: %s[/color]\n" % q.reward
	if full and q.get("penalty", "") != "":
		s += "[color=#e08070]Se falhar: %s[/color]\n" % q.penalty
	if q.get("deadline", 0) != 0 and q.state in ["active", "offered"]:
		var left := int(q.deadline) - tick
		s += "[color=#c0a0e0]Prazo: %s[/color]\n" % ("esgotado" if left <= 0 else "%d ticks" % left)
	return s.strip_edges()


func _rebuild_tracker() -> void:
	for c in tracker_box.get_children():
		tracker_box.remove_child(c)
		c.queue_free()
	tracker_box.add_child(_label("Missoes", 12, GOLD))
	var n := 0
	for q in quests:
		if q.state != "active":
			continue
		var r := _rich(222, 12)
		r.text = _quest_head(q) + "\n" + _quest_body(q, false)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tracker_box.add_child(r)
		n += 1
		if n >= 4:
			break
	if n == 0:
		var e := _label("Nenhuma missao ativa", 12, Color(1, 1, 1, 0.5))
		tracker_box.add_child(e)


func _rebuild_offer() -> void:
	offered_key = ""
	var shown: Dictionary = {}
	for q in quests:
		if q.state == "offered" and q.key != _postponed:
			shown = q
			break
	if shown.is_empty():
		offer_panel.visible = false
		return
	offered_key = shown.key
	offer_text.text = _quest_head(shown) + "\n" + _quest_body(shown, false)
	offer_panel.visible = not journal_panel.visible and Time.get_ticks_msec() >= _offer_hold


func postpone_offer() -> void:
	_postponed = offered_key
	_rebuild_offer()


func toggle_journal() -> void:
	if not journal_panel.visible:
		notebook_panel.visible = false
	journal_panel.visible = not journal_panel.visible
	if journal_panel.visible:
		_rebuild_journal()
	_rebuild_offer()


func _rebuild_journal() -> void:
	for c in journal_box.get_children():
		journal_box.remove_child(c)
		c.queue_free()
	var groups := [["Ativas", ["active"]], ["Ofertas", ["offered"]], ["Concluidas", ["done"]],
		["Encerradas", ["failed", "expired", "declined", "withdrawn", "obsolete", "superseded", "abandoned"]]]
	for g in groups:
		var items := quests.filter(func(q): return q.state in g[1])
		if items.is_empty():
			continue
		journal_box.add_child(_label("%s (%d)" % [g[0], items.size()], 15, GOLD))
		for q in items:
			var row := VBoxContainer.new()
			var r := _rich(660, 13)
			var tag := ""
			if q.state in STATE_PT:
				tag = "  [color=#999999](%s)[/color]" % STATE_PT[q.state]
			r.text = _quest_head(q) + tag + "\n" + _quest_body(q, true)
			row.add_child(r)
			var key: String = q.key
			if q.state == "active":
				var ab := _button("Abandonar", func(): abandon_pressed.emit(key))
				ab.add_to_group("abandon_btn")
				ab.set_meta("quest", key)
				row.add_child(ab)
			elif q.state == "offered":
				var btns := HBoxContainer.new()
				btns.add_theme_constant_override("separation", 6)
				var ja := _button("Aceitar", func(): accept_pressed.emit(key))
				ja.add_to_group("journal_accept_btn")
				ja.set_meta("quest", key)
				var jd := _button("Recusar", func(): decline_pressed.emit(key))
				jd.add_to_group("journal_decline_btn")
				jd.set_meta("quest", key)
				btns.add_child(ja)
				btns.add_child(jd)
				row.add_child(btns)
			journal_box.add_child(row)
	journal_box.add_child(_label("Habilidades (%d)" % skills.size(), 15, GOLD))
	if skills.is_empty():
		journal_box.add_child(_label("Nenhuma ainda. O mundo aprende o que voce faz.", 13, Color(1, 1, 1, 0.55)))
	for s in skills:
		var r := _rich(660, 13)
		r.text = "[b]%s[/b] [color=#999999](%s)[/color]\n%s" % [s.name, s.rarity, s.get("desc", "")]
		journal_box.add_child(r)
