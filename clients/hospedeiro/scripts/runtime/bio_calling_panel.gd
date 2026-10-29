class_name BioCallingPanel
extends CanvasLayer
## The calling the crisis asks of the player. When they stand in a crisis the engine offers up to three classes; this shows them as
## cards at the bottom of the screen (what the class does, whether its role is the one missing) and the player taps one. Once a calling
## is held it shrinks to a small chip with a way to change. "Agora não" hides the offer until the player is somewhere else.

signal chosen(calling_id: String)

var _card: PanelContainer
var _box: VBoxContainer
var _chip: Button
var _view: Dictionary = {}
var dwell := 2.5  # seconds in a crisis before it offers anything: passing through a corridor asks nothing of you
var _dismissed_for := ""  # the crisis whose offer the player put away
var _key := ""
var _pending := ""  # the calling just chosen, until the engine confirms it (or PENDING_SECONDS pass)
var _pending_until := 0.0
const PENDING_SECONDS := 4.0
var _here_for := ""  # the crisis the player is standing in, and since when
var _here_since := 0.0


func configure() -> void:
	layer = 12
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 12))
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.offset_left = -310.0
	_card.offset_right = 310.0
	_card.offset_bottom = -120.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	add_child(_card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_card.add_child(_box)
	_chip = BioUi.button("", "ghost")
	_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_chip.offset_left = -170.0
	_chip.offset_right = 170.0
	_chip.offset_bottom = -120.0
	_chip.offset_top = -154.0
	_chip.visible = false
	_chip.pressed.connect(func() -> void:
		_dismissed_for = ""
		_show_card(true)
		_chip.visible = false)
	add_child(_chip)


func is_card_visible() -> bool:
	return _card != null and _card.visible


func chip_text() -> String:
	return _chip.text if _chip != null and _chip.visible else ""


func option_ids() -> Array:
	var out: Array = []
	for o in _view.get("offer", []):
		out.append(str(o.get("id", "")))
	return out


## The offer waits `dwell` seconds, so the view is looked at again while it is pending.
func _process(_delta: float) -> void:
	if not _view.is_empty() and (_pending != "" or (not _card.visible and BioCallingRules.is_choosing(_view))):
		apply(_view)


## Takes the engine's `calling` view of the player.
func apply(view: Dictionary) -> void:
	_view = view
	var conflict := str(view.get("conflict", ""))
	if conflict.is_empty():
		_dismissed_for = ""
	if conflict != _here_for:
		_here_for = conflict
		_here_since = Time.get_ticks_msec() * 0.001
	var waited := Time.get_ticks_msec() * 0.001 - _here_since >= dwell
	var now := Time.get_ticks_msec() * 0.001
	if _pending != "" and (BioCallingRules.is_held(view) or now >= _pending_until or conflict.is_empty()):
		_pending = ""
	var key := JSON.stringify(view) + str(waited) + _pending
	if key == _key:
		return
	_key = key
	if _pending != "":  # chosen: the cards go away at once and say so, while the engine confirms
		_show_card(false)
		_chip.visible = true
		_chip.text = "ASSUMINDO: %s…" % _name_of_option(_pending)
	elif BioCallingRules.is_held(view):
		_show_card(false)
		_chip.visible = true
		_chip.text = "CHAMADO: %s  ·  %s   (trocar)" % [_name_of(view), BioCallingRules.role_name(str(view.get("role", "")))]
	elif BioCallingRules.is_choosing(view) and _dismissed_for != conflict and waited:
		_chip.visible = false
		_show_card(true)
	else:
		_show_card(false)
		_chip.visible = false


## The player takes a calling of the offer: one press is enough, the cards close until the engine answers.
func choose(id: String) -> void:
	if _pending != "":
		return
	_pending = id
	_pending_until = Time.get_ticks_msec() * 0.001 + PENDING_SECONDS
	chosen.emit(id)
	apply(_view)


func _name_of_option(id: String) -> String:
	for o in _view.get("offer", []):
		if str(o.get("id", "")) == id:
			return str(o.get("name", id))
	return id.capitalize()


func held_name() -> String:
	return _name_of(_view) if BioCallingRules.is_held(_view) else ""


func _name_of(view: Dictionary) -> String:
	var id := str(view.get("current", ""))
	for o in view.get("offer", []):
		if str(o.get("id", "")) == id:
			return str(o.get("name", id))
	return id.capitalize()


func _show_card(on: bool) -> void:
	if _card == null:
		return
	_card.visible = on
	if not on:
		return
	for c in _box.get_children():
		c.queue_free()
	var routine := str(_view.get("conflict", "")).begins_with("organ:")  # no crisis here: the organ's own work asks
	var title := ("ESTE ÓRGÃO PEDE UM CHAMADO" if routine else "A CRISE PEDE UM CHAMADO") if not BioCallingRules.is_held(_view) else "TROCAR DE CHAMADO"
	_box.add_child(BioUi.label(title, BioUi.FS_HEAD, BioUi.ACCENT))
	_box.add_child(BioUi.label("Dura enquanto você estiver neste órgão." if routine else "Dura enquanto você estiver nesta crise.", BioUi.FS_SMALL, BioUi.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for o in _view.get("offer", []):
		row.add_child(_option_card(o))
	var later := BioUi.button("Agora não", "ghost")
	later.custom_minimum_size.y = 26.0
	later.pressed.connect(func() -> void:
		_dismissed_for = str(_view.get("conflict", ""))
		_show_card(false))
	_box.add_child(later)


func _option_card(o: Dictionary) -> Control:
	var role := str(o.get("role", ""))
	var color := BioCallingRules.role_color(role)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioArt.with_alpha(color, 0.7), 10, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	col.add_child(BioUi.label(str(o.get("name", "")), BioUi.FS_HEAD, color))
	col.add_child(BioUi.label("%s  ·  %s" % [BioCallingRules.role_name(role), BioCallingRules.need_text(o)], BioUi.FS_SMALL, BioUi.WARN if bool(o.get("gap", false)) else BioUi.MUTED))
	col.add_child(BioUi.wrapped(BioCallingRules.option_text(o), BioUi.FS_SMALL, BioUi.TEXT))
	var pick := BioUi.button("Assumir", "primary")
	var id := str(o.get("id", ""))
	pick.pressed.connect(func() -> void: choose(id))
	col.add_child(pick)
	return card
