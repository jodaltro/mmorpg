class_name BioHud
extends CanvasLayer
## Minimal dark HUD built in code: membrane and ATP bars, three ability cooldown cells and a banner.

const ABILITIES := [BioAttackCatalog.FLAGELLUM_LASH, BioAttackCatalog.TOXIN_SPIT, BioAttackCatalog.MEMBRANE_DASH]
const ABILITY_LABELS := ["J / Clique\nChicote", "K / Direito\nToxina", "Espaço\nImpulso"]
const CELL_SIZE := Vector2(126, 58)
const CELL_STEP := 134.0
const BAR_SIZE := Vector2(396, 16)

var membrane_fraction := 0.0
var atp_fraction := 0.0

var _player: BioCombatant
var _membrane_fill: ColorRect
var _atp_fill: ColorRect
var _cooldowns: Array[ColorRect] = []
signal restart_requested

const CONFIRM_SECONDS := 4.0

var _title: Label
var _banner: Label
var _guide: Label
var _restart_button: Button
var _restart_armed_until := 0.0
var _abilities: BioAbilityRunner
var _cluster: Control  # the bars and ability cells, bottom-left on a desktop
var _bar_width := BAR_SIZE.x
var _ab_cells: Array[ColorRect] = []
var _ab_shades: Array[ColorRect] = []
var _ab_labels: Array[Label] = []
var pvp_result_text := ""
var _pvp_result_id := -1
var _pvp_result: Label
var _pvp_tween: Tween


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
		_ab_labels[i].text = "%s  %s" % [keys[i], a.get("name", "—")] if id != &"" else "%s  —" % keys[i]
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


## An arrow at the edge of the screen pointing at something far away (a lead of the chemical trail, a person to follow), with a short text.
func set_guide(on: bool, direction: Vector2, text: String) -> void:
	_guide.visible = on
	if not on:
		return
	var size := get_viewport().get_visible_rect().size
	var d := direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	var half := size * 0.5 - Vector2(90.0, 70.0)
	var scale := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	_guide.text = text
	_guide.position = size * 0.5 + d * scale - _guide.size * 0.5
	if BioPlatform.is_touch():
		_guide.position.x = clampf(_guide.position.x, 24.0, maxf(24.0, size.x - _guide.size.x - 24.0))
		_guide.position.y = clampf(_guide.position.y, 136.0, maxf(136.0, size.y - 200.0))


## On a touch screen the on-screen buttons take the place of the ability cells: only the two bars stay, under the title.
func set_touch(on: bool) -> void:
	if not on:
		return
	for shade in _cooldowns:
		shade.get_parent().visible = false
	for cell in _ab_cells:
		cell.visible = false
	_guide.add_theme_font_size_override("font_size", 12)
	_guide.add_theme_constant_override("outline_size", 3)
	_title.visible = false
	_bar_width = 144.0
	_cluster.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_cluster.offset_left = 130.0
	_cluster.offset_top = 18.0
	_cluster.offset_right = 130.0 + _bar_width
	_cluster.offset_bottom = 46.0
	for pair in [[_membrane_fill, 0.0], [_atp_fill, 12.0]]:
		var back := (pair[0] as Control).get_parent() as Control
		back.position = Vector2(0.0, pair[1])
		back.size = Vector2(_bar_width, 8)
		for child in back.get_children():
			if child is Label:
				child.visible = false
		(pair[0] as Control).size = Vector2(_bar_width - 4.0, 4)
	_restart_button.visible = false
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -220
	_banner.offset_right = 220
	_banner.offset_top = 90
	_banner.offset_bottom = 150
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## A public engine does not let anyone wipe the shared body: the button goes away.
func set_restart_allowed(allowed: bool) -> void:
	_restart_button.visible = allowed


func show_banner(text: String) -> void:
	_banner.text = text


func banner_text() -> String:
	return _banner.text


## Independent of mission/death banners: unordered snapshots must not erase a victory.
func show_pvp_result(id: int, text: String) -> void:
	if id <= _pvp_result_id: return
	_pvp_result_id = id
	pvp_result_text = text
	if _pvp_result == null:
		_pvp_result = Label.new()
		_pvp_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_pvp_result.position = Vector2(-175, 175)
		_pvp_result.size = Vector2(350, 70)
		_pvp_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pvp_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_pvp_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pvp_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pvp_result.add_theme_font_size_override("font_size", 18)
		_pvp_result.add_theme_color_override("font_shadow_color", Color.BLACK)
		_pvp_result.add_theme_constant_override("shadow_outline_size", 8)
		var backdrop := StyleBoxFlat.new()
		backdrop.bg_color = Color(0.025, 0.09, 0.12, 0.96)
		backdrop.border_color = Color(0.3, 0.8, 0.65, 0.8)
		backdrop.set_border_width_all(1)
		backdrop.set_corner_radius_all(12)
		_pvp_result.add_theme_stylebox_override("normal", backdrop)
		add_child(_pvp_result)
	if _pvp_tween != null: _pvp_tween.kill()
	_pvp_result.text = text.replace(" · ", "\n")
	_pvp_result.modulate = Color(0.65, 1.0, 0.85, 0.0)
	_pvp_result.show()
	_pvp_tween = create_tween()
	_pvp_tween.tween_property(_pvp_result, "modulate:a", 1.0, 0.2)
	_pvp_tween.tween_interval(6.0)
	_pvp_tween.tween_property(_pvp_result, "modulate:a", 0.0, 0.5)


func _ready() -> void:
	layer = 10
	_add_vignette()

	var panel := Control.new()
	_cluster = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 40
	panel.offset_top = -190
	panel.offset_right = 500
	panel.offset_bottom = -30
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	for i in ABILITIES.size():
		_cooldowns.append(_ability_cell(panel, ABILITY_LABELS[i], Vector2(i * CELL_STEP, 0)))
	for i in BioAbilityRunner.SLOTS:
		var back := ColorRect.new()
		back.position = Vector2(i * CELL_STEP, -66)
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
		text.add_theme_font_size_override("font_size", 12)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		back.add_child(text)
		_ab_cells.append(back)
		_ab_shades.append(shade)
		_ab_labels.append(text)
	_membrane_fill = _bar(panel, "MEMBRANA", Vector2(0, 78), BioArt.CRIMSON)
	_atp_fill = _bar(panel, "ATP", Vector2(0, 102), BioArt.CYAN)

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
	_restart_button.position = Vector2(20, 80)
	_restart_button.size = Vector2(170, 22)
	_restart_button.flat = true
	_restart_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_restart_button.focus_mode = Control.FOCUS_NONE  # keys (space, enter) must never press it
	_restart_button.add_theme_font_size_override("font_size", 11)
	_restart_button.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.CRIMSON, 0.55))
	_restart_button.add_theme_color_override("font_hover_color", BioArt.with_alpha(BioArt.CRIMSON, 1.0))
	_restart_button.pressed.connect(press_restart)
	add_child(_restart_button)

	_guide = Label.new()
	_guide.visible = false
	_guide.add_theme_font_size_override("font_size", 18)
	_guide.add_theme_color_override("font_color", Color(0.85, 1.0, 0.6, 0.95))
	_guide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_guide.add_theme_constant_override("outline_size", 6)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)

	var title := Label.new()
	_title = title
	title.text = "HOSPEDEIRO"
	title.position = Vector2(28, 14)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", BioArt.with_alpha(BioArt.CYAN, 0.55))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_membrane_fill.size.x = (_bar_width - 4.0) * clampf(membrane_fraction, 0.0, 1.0)
	_atp_fill.size.x = (_bar_width - 4.0) * clampf(atp_fraction, 0.0, 1.0)
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
	text.position = Vector2(10, -2)
	text.add_theme_font_size_override("font_size", 11)
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
	text.add_theme_font_size_override("font_size", 12)
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
