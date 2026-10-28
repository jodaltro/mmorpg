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
var _dismissed_for := ""  # the crisis whose offer the player put away
var _key := ""


func configure() -> void:
	layer = 12
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 12))
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.offset_left = -340.0
	_card.offset_right = 340.0
	_card.offset_bottom = -150.0
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
	_chip.offset_bottom = -150.0
	_chip.offset_top = -184.0
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


## Takes the engine's `calling` view of the player.
func apply(view: Dictionary) -> void:
	_view = view
	var conflict := str(view.get("conflict", ""))
	if conflict.is_empty():
		_dismissed_for = ""
	var key := JSON.stringify(view)
	if key == _key:
		return
	_key = key
	if BioCallingRules.is_held(view):
		_show_card(false)
		_chip.visible = true
		_chip.text = "CHAMADO: %s  ·  %s   (trocar)" % [_name_of(view), BioCallingRules.role_name(str(view.get("role", "")))]
	elif BioCallingRules.is_choosing(view) and _dismissed_for != conflict:
		_chip.visible = false
		_show_card(true)
	else:
		_show_card(false)
		_chip.visible = false


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
	var title := "A CRISE PEDE UM CHAMADO" if not BioCallingRules.is_held(_view) else "TROCAR DE CHAMADO"
	_box.add_child(BioUi.label(title, BioUi.FS_HEAD, BioUi.ACCENT))
	_box.add_child(BioUi.wrapped("Escolha a forma que mais ajuda aqui. Ela dura enquanto você estiver nesta crise.", BioUi.FS_SMALL, BioUi.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for o in _view.get("offer", []):
		row.add_child(_option_card(o))
	var later := BioUi.button("Agora não", "ghost")
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
	pick.pressed.connect(func() -> void: chosen.emit(id))
	col.add_child(pick)
	return card
