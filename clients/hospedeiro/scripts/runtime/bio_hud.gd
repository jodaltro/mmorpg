class_name BioHud
extends CanvasLayer
## Minimal dark HUD built in code: membrane and ATP bars, three ability cooldown cells and a banner.

const ABILITIES := [BioAttackCatalog.FLAGELLUM_LASH, BioAttackCatalog.TOXIN_SPIT, BioAttackCatalog.MEMBRANE_DASH]
const ABILITY_LABELS := ["J / Clique\nChicote", "K / Direito\nToxina", "Espaço\nImpulso"]
const CELL_SIZE := Vector2(120, 62)
const BAR_SIZE := Vector2(420, 22)

var membrane_fraction := 0.0
var atp_fraction := 0.0

var _player: BioCombatant
var _membrane_fill: ColorRect
var _atp_fill: ColorRect
var _cooldowns: Array[ColorRect] = []
signal restart_requested

const CONFIRM_SECONDS := 4.0

var _banner: Label
var _dungeon_label: Label
var _restart_button: Button
var _restart_armed_until := 0.0
var _abilities: BioAbilityRunner
var _ab_cells: Array[ColorRect] = []
var _ab_shades: Array[ColorRect] = []
var _ab_labels: Array[Label] = []


func bind(combatant: BioCombatant) -> void:
	_player = combatant


func bind_abilities(runner: BioAbilityRunner) -> void:
	_abilities = runner
	runner.learned.connect(func(_id: StringName) -> void: _refresh_abilities())
	_refresh_abilities()


func _refresh_abilities() -> void:
	for i in BioAbilityRunner.SLOTS:
		var id := _abilities.slot_id(i)
		var keys := ["Q", "F", "C", "V"]
		var a := BioAbilityCatalog.get_ability(id)
		_ab_labels[i].text = "%s
%s" % [keys[i], a.get("name", "—")] if id != &"" else "%s
—" % keys[i]
		var c: Color = a.get("color", Color(0.3, 0.4, 0.5))
		_ab_cells[i].color = Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, 0.9) if id != &"" else Color(0.05, 0.08, 0.12, 0.6)


## First press arms it (it wipes the body and the story), the second one within a few seconds confirms.
func press_restart() -> void:
	var now := BioClock.now()
	if now < _restart_armed_until:
		_restart_armed_until = 0.0
		_restart_button.text = "REINICIAR MUNDO"
		restart_requested.emit()
		return
	_restart_armed_until = now + CONFIRM_SECONDS
	_restart_button.text = "CONFIRMAR? apaga tudo"


func set_dungeon_text(text: String) -> void:
	_dungeon_label.text = text


func show_banner(text: String) -> void:
	_banner.text = text


func banner_text() -> String:
	return _banner.text


func _ready() -> void:
	layer = 10
	_add_vignette()

	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 40
	panel.offset_top = -190
	panel.offset_right = 500
	panel.offset_bottom = -30
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	for i in ABILITIES.size():
		_cooldowns.append(_ability_cell(panel, ABILITY_LABELS[i], Vector2(i * 130, 0)))
	for i in BioAbilityRunner.SLOTS:
		var back := ColorRect.new()
		back.position = Vector2(i * 130, -70)
		back.size = CELL_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(back)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.7)
		shade.position = Vector2(0, CELL_SIZE.y)
		shade.size = Vector2(CELL_SIZE.x, 0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(shade)
		var text := Label.new()
		text.size = CELL_SIZE
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 13)
		back.add_child(text)
		_ab_cells.append(back)
		_ab_shades.append(shade)
		_ab_labels.append(text)
	_membrane_fill = _bar(panel, "MEMBRANA", Vector2(0, 80), BioArt.CRIMSON)
	_atp_fill = _bar(panel, "ATP", Vector2(0, 118), BioArt.CYAN)

	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -600
	_banner.offset_right = 600
	_banner.offset_top = -260
	_banner.offset_bottom = -140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	_restart_button = Button.new()
	_restart_button.text = "REINICIAR MUNDO"
	_restart_button.position = Vector2(40, 100)
	_restart_button.size = Vector2(230, 30)
	_restart_button.focus_mode = Control.FOCUS_NONE  # keys (space, enter) must never press it
	_restart_button.add_theme_font_size_override("font_size", 15)
	_restart_button.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.CRIMSON, 0.9))
	_restart_button.pressed.connect(press_restart)
	add_child(_restart_button)

	_dungeon_label = Label.new()
	_dungeon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_dungeon_label.offset_left = -400
	_dungeon_label.offset_right = 400
	_dungeon_label.offset_top = 24
	_dungeon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dungeon_label.add_theme_font_size_override("font_size", 20)
	_dungeon_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.45, 0.9))
	_dungeon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dungeon_label)

	var title := Label.new()
	title.text = "HOSPEDEIRO"
	title.position = Vector2(40, 28)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.CYAN, 0.6))
	add_child(title)


func _process(_delta: float) -> void:
	if _restart_armed_until > 0.0 and BioClock.now() >= _restart_armed_until:
		_restart_armed_until = 0.0
		_restart_button.text = "REINICIAR MUNDO"
	if _player == null or _player.actor == null:
		return
	var vitals := _player.actor.vitals
	membrane_fraction = vitals.membrane / vitals.max_membrane
	atp_fraction = vitals.atp / vitals.max_atp if vitals.max_atp > 0.0 else 0.0
	_membrane_fill.size.x = (BAR_SIZE.x - 4.0) * clampf(membrane_fraction, 0.0, 1.0)
	_atp_fill.size.x = (BAR_SIZE.x - 4.0) * clampf(atp_fraction, 0.0, 1.0)
	if _abilities != null:
		for i in BioAbilityRunner.SLOTS:
			var f := _abilities.cooldown_fraction(i)
			_ab_shades[i].size.y = CELL_SIZE.y * f
			_ab_shades[i].position.y = CELL_SIZE.y - _ab_shades[i].size.y
	var now := BioClock.now()
	for i in ABILITIES.size():
		var def := _player.actor.attack_def(ABILITIES[i])
		var remaining := _player.actor.cooldown_remaining(ABILITIES[i], now)
		var frac := clampf(remaining / def.cooldown, 0.0, 1.0) if def.cooldown > 0.0 else 0.0
		if vitals.atp < def.atp_cost:
			frac = 1.0
		_cooldowns[i].size.y = CELL_SIZE.y * frac
		_cooldowns[i].position.y = CELL_SIZE.y - _cooldowns[i].size.y


func _bar(parent: Control, label: String, pos: Vector2, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.04, 0.08, 0.75)
	back.position = pos
	back.size = BAR_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = BioArt.with_alpha(color, 0.9)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(BAR_SIZE.x - 4.0, BAR_SIZE.y - 4.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	var text := Label.new()
	text.text = label
	text.position = Vector2(10, -1)
	text.add_theme_font_size_override("font_size", 14)
	back.add_child(text)
	return fill


func _ability_cell(parent: Control, label: String, pos: Vector2) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.08, 0.16, 0.26, 0.85)
	back.position = pos
	back.size = CELL_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.position = Vector2(0, CELL_SIZE.y)
	shade.size = Vector2(CELL_SIZE.x, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(shade)
	var text := Label.new()
	text.text = label
	text.size = CELL_SIZE
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 14)
	back.add_child(text)
	return shade


func _add_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
