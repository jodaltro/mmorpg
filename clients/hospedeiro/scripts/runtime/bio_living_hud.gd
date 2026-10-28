class_name BioLivingHud
extends CanvasLayer
## What is happening in the body, where, why it matters and how to help, without a stream of pop-ups: one followed crisis (up to two
## summaries beside it), a big alert only when a crisis changes phase (never for a percentage), a contextual call from a nearby cell,
## and a panel with every crisis, the open requests and the history. The player chooses what to follow; that never changes the crisis.
## Everything shown is the engine's view; the buttons only change the player's own attention.

signal focus_changed(conflict_id: String)
signal help_accepted(npc: String, region: String)
signal prefs_changed

const ALERT_SECONDS := 5.0
const CARD_WIDTH := 340.0

var model: BioLivingModel
var queue := BioAlertQueue.new()
var prefs: BioVisualPrefs
var sound: BioLivingSound
var chosen := ""  # the crisis the player follows; "" lets the engine's suggestion lead
var filter := "todos"
var player_region := ""
var stale := false  # no connection: what is shown may be out of date and is never presented as current

var _card: PanelContainer
var _card_box: VBoxContainer
var _expanded := true
var _alert: PanelContainer
var _alert_title: Label
var _alert_body: Label
var _alert_left := 0.0
var _alert_data := {}
var _help: PanelContainer
var _help_title: Label
var _help_text: Label
var _help_for := ""  # help id on screen
var _help_npc := ""
var _help_region := ""
var _dismissed := {}  # help ids the player put aside
var _modal: BioModal
var _panel_stamp := -1
var _fs := 1.0
var _wake := 0.0


func bind(living: BioLivingModel, visual: BioVisualPrefs, tones: BioLivingSound) -> void:
	model = living
	prefs = visual
	sound = tones
	layer = 11
	_build()


func focus_id() -> String:
	return BioConflictFocus.pick(model.ordered(), model.engine_focus, chosen)


func panel_open() -> bool:
	return _modal != null and _modal.visible


func help_visible() -> bool:
	return _help != null and _help.visible


func alert_visible() -> bool:
	return _alert != null and _alert.visible


func card_text() -> String:
	var out := ""
	for c in _card_box.get_children():
		if c is Label:
			out += (c as Label).text + "\n"
	return out


func _wrap(text: String, size: int, color: Color, width: float) -> Label:
	var l := BioUi.wrapped(text, size, color)
	l.custom_minimum_size.x = width  # a wrapping label with no width becomes one tall column
	return l


func _size(n: int) -> int:
	return roundi(n * (prefs.text_scale if prefs != null else 1.0))


func _build() -> void:
	_card = PanelContainer.new()
	_card.position = Vector2(24, 64 if BioPlatform.is_touch() else 134)
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE, 10, 10))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 4)
	_card.add_child(_card_box)
	_alert = PanelContainer.new()
	_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_left = -250
	_alert.offset_right = 250
	_alert.offset_top = 150
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE  # an alert never takes the controls
	_alert.visible = false
	add_child(_alert)
	var abox := VBoxContainer.new()
	abox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.add_child(abox)
	_alert_title = BioUi.label("", 26, BioUi.TEXT)
	_alert_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abox.add_child(_alert_title)
	_alert_body = BioUi.label("", 16, BioUi.MUTED)
	_alert_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abox.add_child(_alert_body)
	_help = PanelContainer.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_help.offset_left = -220
	_help.offset_right = 220
	_help.offset_top = -290
	_help.offset_bottom = -200
	_help.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioArt.with_alpha(BioUi.WARN, 0.6), 10, 10))
	_help.visible = false
	add_child(_help)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	_help.add_child(hbox)
	_help_title = BioUi.label("", 15, BioUi.WARN)
	hbox.add_child(_help_title)
	_help_text = _wrap("", 13, BioUi.TEXT, 400.0)
	hbox.add_child(_help_text)
	var row := HBoxContainer.new()
	hbox.add_child(row)
	var yes := BioUi.button("Ajudar   H", "primary")
	yes.pressed.connect(_accept_help)
	row.add_child(yes)
	var later := BioUi.button("Depois")
	later.pressed.connect(_dismiss_help)
	row.add_child(later)
	_modal = BioModal.new()
	var holder := CanvasLayer.new()
	holder.layer = 14
	add_child(holder)
	holder.add_child(_modal)
	_modal.max_size = Vector2(760, 640)
	_modal.build("CRISES DO HOSPEDEIRO")
	_modal.dismissed.connect(close)
	refresh()


func close() -> void:
	if _modal != null:
		_modal.hide_modal()


func toggle_panel() -> void:
	if panel_open():
		close()
	else:
		_modal.present(self)
		_rebuild_panel()


# --- the followed crisis -----------------------------------------------------------------------------------------------------

## Call after each view.
func refresh() -> void:
	if model == null:
		return
	_fs = prefs.text_scale if prefs != null else 1.0
	_rebuild_card()
	_update_help()
	if panel_open() and _panel_stamp != model.revision + model.tick:
		_rebuild_panel()


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func set_stale(value: bool) -> void:
	if stale == value:
		return
	stale = value
	refresh()


func _rebuild_card() -> void:
	_clear(_card_box)
	if stale:
		_card_box.add_child(BioUi.label("Sem conexão: estes dados podem estar desatualizados.", _size(12), BioUi.WARN))
	var ordered := model.ordered()
	if ordered.is_empty():
		_card_box.add_child(BioUi.label("O corpo está em equilíbrio.", _size(13), BioUi.MUTED))
		var open := BioUi.button("Crises   L")
		open.pressed.connect(toggle_panel)
		_card_box.add_child(open)
		return
	var focus := focus_id()
	var c: Dictionary = {}
	for it in ordered:
		if str(it.get("id", "")) == focus:
			c = it
	var phase := str(c.get("phase", ""))
	var color: Color = BioConflictFocus.PHASE_COLOR.get(phase, BioUi.MUTED)
	_card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioArt.with_alpha(color, 0.65), 10, 10, 2))
	var head := HBoxContainer.new()
	_card_box.add_child(head)
	var tag := BioUi.label(BioConflictFocus.phase_label(c), _size(12), color)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	if ordered.size() > 1:
		var prev := BioUi.button("◀")
		prev.pressed.connect(func() -> void: _step_focus(-1))
		head.add_child(prev)
		var nxt := BioUi.button("▶")
		nxt.pressed.connect(func() -> void: _step_focus(1))
		head.add_child(nxt)
	var all := BioUi.button("Painel   L")
	all.pressed.connect(toggle_panel)
	head.add_child(all)
	_card_box.add_child(BioUi.label("%s · %s" % [str(c.get("title", "")), BioConflictFocus.organ(c)], _size(16), BioUi.TEXT))
	if not BioPlatform.is_touch() or _expanded:
		_card_box.add_child(_wrap(BioConflictFocus.effect(c), _size(12), BioUi.MUTED, CARD_WIDTH - 30.0))
		var headline := BioConflictFocus.headline(c)
		if headline != "":
			_card_box.add_child(BioUi.label(headline, _size(12), BioUi.TEXT))
		var peak := maxf(1.0, float(c.get("peak", 1)))
		_card_box.add_child(BioUi.gauge(clampf(float(c.get("severity", 0)) / peak, 0.0, 1.0), color, 6.0))
		_card_box.add_child(_wrap("Próximo passo: " + BioConflictFocus.suggestion(c), _size(12), BioUi.ACCENT, CARD_WIDTH - 30.0))
		var mine: Variant = c.get("mine")
		if mine is Dictionary and not (mine as Dictionary).is_empty():
			var total := 0
			for k in mine:
				total += int(mine[k])
			_card_box.add_child(BioUi.label("Sua ajuda confirmada: %d" % total, _size(12), BioUi.GOOD))
		for s in BioConflictFocus.secondaries(ordered, focus, 2):
			var sc: Color = BioConflictFocus.PHASE_COLOR.get(str(s.get("phase", "")), BioUi.MUTED)
			var b := BioUi.button("%s  %s" % [BioConflictFocus.phase_label(s), str(s.get("title", ""))])
			b.add_theme_color_override("font_color", sc)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var sid := str(s.get("id", ""))
			b.pressed.connect(func() -> void: follow(sid))
			_card_box.add_child(b)
		if ordered.size() > 3:
			_card_box.add_child(BioUi.label("+ %d no painel" % (ordered.size() - 3), _size(11), BioUi.MUTED))
	_card.size = Vector2(CARD_WIDTH, 0)


func _step_focus(direction: int) -> void:
	var ordered := model.ordered()
	if ordered.is_empty():
		return
	var ids: Array = ordered.map(func(c: Dictionary) -> String: return str(c["id"]))
	var i := ids.find(focus_id())
	follow(ids[posmod(i + direction, ids.size())])


## Following a crisis is the player's attention only.
func follow(id: String) -> void:
	chosen = id
	focus_changed.emit(id)
	refresh()


# --- alerts ------------------------------------------------------------------------------------------------------------------

## Notices from the model go through the queue (deduplicated, by priority, expiring).
func push_notices(notices: Array[Dictionary]) -> void:
	if stale:
		return
	var now := Time.get_ticks_msec() * 0.001
	for n in notices:
		queue.push(n, now)


func _show_alert(a: Dictionary) -> void:
	_alert_data = a
	_alert_left = ALERT_SECONDS
	var text := BioConflictFocus.alert_text(a).split("\n")
	var color: Color = BioConflictFocus.PHASE_COLOR.get(str(a.get("phase", "")), BioUi.TEXT)
	_alert_title.text = "%s  %s" % [BioConflictFocus.PHASE_GLYPH.get(str(a.get("phase", "")), ""), text[0]]
	_alert_title.add_theme_font_size_override("font_size", _size(26))
	_alert_title.add_theme_color_override("font_color", color)
	_alert_body.text = text[1] if text.size() > 1 else ""
	_alert_body.add_theme_font_size_override("font_size", _size(16))
	_alert.add_theme_stylebox_override("panel", BioUi.style(Color(0.02, 0.035, 0.08, 0.86), BioArt.with_alpha(color, 0.8), 14, 14, 2))
	_alert.modulate.a = 0.0
	_alert.visible = true
	if sound != null and prefs.sound:
		sound.play(StringName(str(a.get("kind", ""))))
	if prefs.vibration and int(a.get("priority", 0)) >= 5 and BioPlatform.is_touch():
		Input.vibrate_handheld(180)


func _process(delta: float) -> void:
	if model == null:
		return
	if _alert_left > 0.0:
		_alert_left -= delta
		var fade_in := 0.6 if prefs.reduce_flash else 0.25
		var shown := ALERT_SECONDS - _alert_left
		_alert.modulate.a = clampf(minf(shown / fade_in, _alert_left / 0.6), 0.0, 1.0)
		if _alert_left <= 0.0:
			_alert.visible = false
			_update_help()
	else:
		var next := queue.next(Time.get_ticks_msec() * 0.001)
		if not next.is_empty():
			_show_alert(next)
	if not BioUi.typing():
		if Input.is_action_just_pressed("bio_conflicts"):
			toggle_panel()
		if Input.is_action_just_pressed("bio_help") and help_visible():
			_accept_help()


# --- help from a nearby cell -------------------------------------------------------------------------------------------------

## The call of a cell near the player. It never competes with an emergency banner, and is never a quest to accept.
func _update_help() -> void:
	if _help == null:
		return
	var best := {}
	for r in model.open_requests():
		var h: Dictionary = r["help"]
		if _dismissed.has(str(h.get("id", ""))):
			continue
		if str(h.get("region", "")) == player_region or player_region == "":
			best = r
			break
	var blocked := alert_visible() or panel_open()
	if best.is_empty() or blocked:
		if best.is_empty():
			_help_for = ""
		_help.visible = false
		return
	var h2: Dictionary = best["help"]
	var id := str(h2.get("id", ""))
	if _help_for != id:
		_help_for = id
		if sound != null and prefs.sound:
			sound.play(&"help")
	_help_npc = str(best["npc"])
	_help_region = str(h2.get("region", ""))
	_help_title.text = "%s pede ajuda" % str(best["name"]).get_slice(",", 0)
	_help_title.add_theme_font_size_override("font_size", _size(15))
	_help_text.text = str(h2.get("text", "")).replace(str(best["name"]).get_slice(",", 0) + ": ", "")
	_help_text.add_theme_font_size_override("font_size", _size(13))
	_help.visible = true


func _accept_help() -> void:
	if _help_for == "":
		return
	_dismissed[_help_for] = true
	_help.visible = false
	help_accepted.emit(_help_npc, _help_region)


func _dismiss_help() -> void:
	if _help_for != "":
		_dismissed[_help_for] = true
	_help.visible = false


func set_player_region(region: String) -> void:
	player_region = region
	_update_help()


# --- the panel ---------------------------------------------------------------------------------------------------------------

func _rebuild_panel() -> void:
	_panel_stamp = model.revision + model.tick
	_clear(_modal.content)
	var box := _modal.content
	var row := HBoxContainer.new()
	box.add_child(row)
	for f in BioConflictFocus.FILTERS:
		var b := BioUi.button(("● " if f == filter else "") + str(f).capitalize())
		b.pressed.connect(func() -> void:
			filter = f
			_rebuild_panel())
		row.add_child(b)
	var list := BioConflictFocus.filtered(model.ordered(), model.recent, filter)
	if list.is_empty():
		box.add_child(BioUi.label("Nenhuma crise neste filtro.", _size(13), BioUi.MUTED))
	for c in list:
		box.add_child(_conflict_row(c))
	var requests := model.open_requests()
	box.add_child(BioUi.label("PEDIDOS DE AJUDA", _size(12), BioUi.ACCENT))
	if requests.is_empty():
		box.add_child(BioUi.label("Nenhuma célula pede ajuda agora.", _size(12), BioUi.MUTED))
	for r in requests:
		var h: Dictionary = r["help"]
		box.add_child(_wrap("%s · %s: %s" % [str(r["name"]).get_slice(",", 0), str(h.get("region", "")), str(h.get("text", ""))], _size(12), BioUi.TEXT, 600.0))
	box.add_child(BioUi.label("AVISOS RECENTES", _size(12), BioUi.ACCENT))
	if queue.history.is_empty():
		box.add_child(BioUi.label("Nada novo desde que você entrou.", _size(12), BioUi.MUTED))
	for a in queue.history.slice(0, 8):
		box.add_child(BioUi.label(BioConflictFocus.alert_text(a).replace("\n", " · "), _size(12), BioConflictFocus.PHASE_COLOR.get(str(a.get("phase", "")), BioUi.MUTED)))
	box.add_child(BioUi.label("VISUAL E ACESSIBILIDADE", _size(12), BioUi.ACCENT))
	box.add_child(_prefs_row())


func _conflict_row(c: Dictionary) -> Control:
	var phase := str(c.get("phase", ""))
	var color: Color = BioConflictFocus.PHASE_COLOR.get(phase, BioUi.MUTED)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_SUNK, BioArt.with_alpha(color, 0.5), 8, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := BioUi.label("%s  %s · %s" % [BioConflictFocus.phase_label(c), str(c.get("title", "")), BioConflictFocus.organ(c)], _size(14), color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if phase != "resolved":
		var follow_button := BioUi.button("Acompanhando" if str(c.get("id", "")) == focus_id() else "Acompanhar", "primary" if str(c.get("id", "")) != focus_id() else "ghost")
		var id := str(c.get("id", ""))
		follow_button.pressed.connect(func() -> void:
			follow(id)
			_rebuild_panel())
		head.add_child(follow_button)
		var peak := maxf(1.0, float(c.get("peak", 1)))
		v.add_child(BioUi.gauge(clampf(float(c.get("severity", 0)) / peak, 0.0, 1.0), color, 6.0))
	v.add_child(_wrap(BioConflictFocus.effect(c), _size(12), BioUi.MUTED, 600.0))
	for m in c.get("metrics", []):
		v.add_child(BioUi.label("%s: %d" % [str(m.get("label", "")), int(m.get("value", 0))], _size(12), BioUi.TEXT))
	var fronts: Variant = c.get("frontRegions")
	if fronts is Dictionary and not (fronts as Dictionary).is_empty():
		v.add_child(BioUi.label("Espalhou-se para: %s" % ", ".join((fronts as Dictionary).values().map(func(r: Variant) -> String: return str(r))), _size(12), BioUi.WARN))
	if int(c.get("reopened", 0)) > 0:
		v.add_child(BioUi.label("Já voltou %d vez(es)." % int(c.get("reopened", 0)), _size(12), BioUi.MUTED))
	if phase != "resolved":
		v.add_child(_wrap("Próximo passo: " + BioConflictFocus.suggestion(c), _size(12), BioUi.ACCENT, 600.0))
	var mine: Variant = c.get("mine")
	if mine is Dictionary and not (mine as Dictionary).is_empty():
		var parts: Array[String] = []
		for k in mine:
			parts.append("%s %d" % [k, int(mine[k])])
		v.add_child(BioUi.label("Sua ajuda confirmada: " + ", ".join(parts), _size(12), BioUi.GOOD))
	return pc


func _prefs_row() -> Control:
	var grid := HFlowContainer.new()
	var preset := BioUi.button("Qualidade: %s" % prefs.preset)
	preset.pressed.connect(func() -> void:
		prefs.cycle_preset()
		_prefs_changed())
	grid.add_child(preset)
	for entry in [["Menos movimento", "reduced_motion"], ["Menos brilho", "reduce_flash"], ["Som", "sound"], ["Vibração", "vibration"]]:
		var key: String = entry[1]
		var on: bool = prefs.get(key)
		var b := BioUi.button("%s: %s" % [entry[0], "sim" if on else "não"])
		b.pressed.connect(func() -> void:
			prefs.set(key, not bool(prefs.get(key)))
			_prefs_changed())
		grid.add_child(b)
	var scale := BioUi.button("Texto: %d%%" % roundi(prefs.text_scale * 100.0))
	scale.pressed.connect(func() -> void:
		prefs.cycle_text_scale()
		_prefs_changed())
	grid.add_child(scale)
	return grid


func _prefs_changed() -> void:
	prefs.save()
	prefs_changed.emit()
	refresh()
	_rebuild_panel()
