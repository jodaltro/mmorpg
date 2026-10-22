class_name Hud
extends CanvasLayer
## Interface: status, minimap, quest tracker, offer popup, journal, toasts and log.
## It only shows what the engine's view says and emits the player's intents.

signal accept_pressed(key: String)
signal decline_pressed(key: String)
signal abandon_pressed(key: String)
signal action_chosen(index: int)

const GOLD := Color(0.86, 0.7, 0.36)
const RANK_COLORS := {"F": "9a9a9a", "E": "9a9a9a", "D": "7bc96f", "C": "5aa9e6", "B": "a97be0", "A": "f0a040", "S": "e8574a", "SS": "ffd060"}
const STATE_PT := {"done": "concluida", "failed": "falhou", "expired": "expirou", "declined": "recusada", "withdrawn": "retirada",
	"obsolete": "obsoleta", "superseded": "substituida", "abandoned": "abandonada"}
# id, x0, x1, z0, z1, color: where each region sits in the client's world.
const REGION_RECTS := [["vila", -26.0, 14.0, -35.0, 35.0, Color(0.28, 0.45, 0.25)], ["estrada", 14.0, 34.0, -35.0, 35.0, Color(0.5, 0.38, 0.25)],
	["floresta", 34.0, 94.0, -35.0, 35.0, Color(0.16, 0.3, 0.17)], ["mina", 94.0, 124.0, -35.0, 35.0, Color(0.38, 0.36, 0.36)],
	["ruinas", 124.0, 154.0, -35.0, 35.0, Color(0.45, 0.42, 0.33)], ["toca", 55.0, 77.0, 36.0, 50.0, Color(0.3, 0.42, 0.2)]]
const SHORT := {"vila": "Vila", "estrada": "Estr.", "floresta": "Floresta", "mina": "Mina", "ruinas": "Ruinas", "toca": "Toca"}

var root: Control
var region_label: Label
var time_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var minimap: Minimap
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
var journal_panel: PanelContainer
var action_panel: PanelContainer
var action_title: Label
var action_box: VBoxContainer
var action_buttons: Array = []
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


class Minimap extends Control:
	const X0 := -30.0
	const X1 := 158.0
	const Z0 := -36.0
	const Z1 := 52.0
	var player_pos := Vector3.ZERO
	var player_yaw := 0.0
	var npcs: Array = []
	var enemies: Array = []
	var quest_regions: Array = []
	var current_region := ""
	var region_names := {}

	func _p(x: float, z: float) -> Vector2:
		return Vector2((x - X0) / (X1 - X0) * size.x, (z - Z0) / (Z1 - Z0) * size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06, 0.95))
		var font := ThemeDB.fallback_font
		for b in REGION_RECTS:
			var a := _p(b[1], b[3])
			var c := _p(b[2], b[4])
			var r := Rect2(a, c - a)
			draw_rect(r, b[5])
			if quest_regions.has(b[0]):
				draw_rect(r.grow(-1.5), GOLD, false, 2.0)
			if current_region == b[0]:
				draw_rect(r, Color(1, 1, 1, 0.12))
			draw_string(font, a + Vector2(3, 11), SHORT.get(b[0], b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.8))
		for n in npcs:
			draw_circle(_p(n.x, n.z), 2.5, Color(1.0, 0.9, 0.4))
		for e in enemies:
			draw_circle(_p(e.x, e.z), 3.0, Color(0.95, 0.25, 0.25))
		var pp := _p(player_pos.x, player_pos.z)
		var d := Vector2(sin(player_yaw), cos(player_yaw))
		draw_colored_polygon(PackedVector2Array([pp + d * 7.0, pp + d.rotated(2.5) * 5.0, pp + d.rotated(-2.5) * 5.0]), Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.3, 0.9), false, 1.0)


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
	_build_actions()
	var slot := _slot(Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_END, 10)
	var help := _label("[E] Usar/Falar   [F] Acoes aqui   [J] Diario   [Espaco] Golpe   [R] Rolar", 12, Color(1, 1, 1, 0.55))
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
	minimap.custom_minimum_size = Vector2(226, 100)
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
	log_box.custom_minimum_size.x = 520
	log_box.add_theme_constant_override("separation", 2)
	log_panel.add_child(log_box)
	log_panel.visible = false
	_ignore(log_panel)


func _build_prompt() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END, 12, 12, 30)
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


func _build_actions() -> void:
	var slot := _slot(Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END, 12, 12, 80)
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
	var r := _rich(520, 13)
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
	offer_panel.visible = not journal_panel.visible


func postpone_offer() -> void:
	_postponed = offered_key
	_rebuild_offer()


func toggle_journal() -> void:
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
