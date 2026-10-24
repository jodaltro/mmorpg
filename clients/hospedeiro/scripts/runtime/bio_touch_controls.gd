class_name BioTouchControls
extends CanvasLayer
## The controls for a finger: a stick on the left to move, a big attack button on the right that also aims when dragged, the toxin
## and the dash around it, the four class abilities on an arc above, and a row of windows at the top. Nothing here knows the game's
## rules: it presses the same input actions the keyboard does and reports where to move and aim. With no stick on the aim the cell
## aims at the nearest enemy, because a thumb that is busy running cannot also point.

const AUTO_AIM_UNITS := 13.0
const AUTO_AIM_EVERY := 0.1
const MARGIN := 30.0
const COLOR_MOVE := Color(0.35, 0.85, 1.0)
const COLOR_ATTACK := Color(1.0, 0.45, 0.5)
const COLOR_TOXIN := Color(0.62, 1.0, 0.45)
const COLOR_DASH := Color(0.55, 0.7, 1.0)
const COLOR_WINDOW := Color(0.62, 0.75, 0.95)

var world: Node
var move_stick: BioTouchStick
var attack_stick: BioTouchStick
var toxin: BioTouchButton
var dash: BioTouchButton
var interact: BioTouchButton
var leave: BioTouchButton
var respawn: BioTouchButton
var ability_buttons: Array[BioTouchButton] = []
var window_buttons: Array[BioTouchButton] = []
var fullscreen: BioTouchButton
var menu: BioTouchButton
var menu_open := false
var _drawer: PanelContainer
var missions_button: Button
var restart_button: Button
var scale_reset: Button
var _menu_back: ColorRect
var _target: BioCellActor
var _aim_overlay: Control
var minimap: BioTouchMinimap
var scale_slider: HSlider
var scale_label: Label
var _settings: Control

var _aim := Vector2.RIGHT
var _auto_timer := 0.0
var _root: Control
var _top_layer: CanvasLayer  # the window buttons stay above the windows, so the button that opened one also closes it
var _top: Control


func _ready() -> void:
	layer = 12
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top_layer = CanvasLayer.new()
	_top_layer.layer = 25
	add_child(_top_layer)
	_top = Control.new()
	_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer.add_child(_top)
	_menu_back = ColorRect.new()
	_menu_back.color = Color(0.0, 0.005, 0.02, 0.65)
	_menu_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_back.visible = false
	_top.add_child(_menu_back)
	BioUi.bind_tap(_menu_back, close)
	_drawer = PanelContainer.new()
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 0))
	_menu_back.add_child(_drawer)
	var interior := Control.new()
	interior.mouse_filter = Control.MOUSE_FILTER_PASS
	_drawer.add_child(interior)
	var help := Label.new()
	help.position = Vector2(20,20)
	help.text = "HOSPEDEIRO"
	help.add_theme_font_size_override("font_size",13)
	help.add_theme_color_override("font_color",Color(0.65,0.78,0.85))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(help)
	missions_button = BioUi.button("Missões")
	var missions := missions_button
	missions.position = Vector2(20, 62)
	missions.size = Vector2(296, 40)
	missions.pressed.connect(func() -> void:
		close()
		world.sync.system.open_missions())
	interior.add_child(missions)
	restart_button = BioUi.button("Reiniciar mundo · teste", "danger")
	var restart := restart_button
	restart.position = Vector2(20, 114)
	restart.size = Vector2(296, 40)
	restart.pressed.connect(func() -> void:
		close()
		world.reset_dialog.open())
	interior.add_child(restart)
	_settings = Control.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_settings.offset_left = 20
	_settings.offset_right = 320
	_settings.offset_top = -100
	_settings.offset_bottom = -12
	_settings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.add_child(_settings)
	scale_label = Label.new()
	scale_label.add_theme_font_size_override("font_size",13)
	_settings.add_child(scale_label)
	scale_slider = HSlider.new()
	scale_slider.name = "InterfaceScale"
	scale_slider.min_value = 75
	scale_slider.max_value = 125
	scale_slider.step = 5
	scale_slider.position = Vector2(0,30)
	scale_slider.size = Vector2(160,44)
	scale_slider.focus_mode = Control.FOCUS_NONE
	scale_slider.value_changed.connect(func(value: float) -> void:
		scale_label.text = "Tamanho da interface: %d%%" % roundi(value))
	scale_slider.drag_ended.connect(func(_changed: bool) -> void:
		if world != null:
			world.display.set_interface_scale(scale_slider.value/100.0))
	_settings.add_child(scale_slider)
	scale_reset = Button.new()
	var reset := scale_reset
	reset.text = "Restaurar 100%"
	reset.position = Vector2(180,30)
	reset.size = Vector2(116,44)
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size",12)
	reset.pressed.connect(func() -> void:
		if world != null:
			world.display.set_interface_scale(1.0))
	_settings.add_child(reset)
	move_stick = BioTouchStick.new()
	move_stick.floating = true
	move_stick.radius = 48.0
	move_stick.color = COLOR_MOVE
	move_stick.label = ""
	_root.add_child(move_stick)
	attack_stick = BioTouchStick.new()
	attack_stick.floating = false
	attack_stick.radius = 46.0
	attack_stick.attack_style = true
	attack_stick.dead_zone = 0.3
	attack_stick.relative_aim = true
	attack_stick.color = COLOR_ATTACK
	attack_stick.label = ""
	attack_stick.engaged_changed.connect(_on_attack_engaged)
	_root.add_child(attack_stick)
	toxin = _add(BioTouchButton.round_button(&"bio_spit", "Toxina", COLOR_TOXIN, 23.0))
	dash = _add(BioTouchButton.round_button(&"bio_dash", "Pulo", COLOR_DASH, 23.0))
	toxin.glyph = "toxin"
	toxin.tooltip_text = "Toxina"
	toxin.cast_on_release = true
	toxin.cast_requested.connect(_cast_toxin)
	dash.glyph = "dash"
	for i in 4:
		var b := _add(BioTouchButton.round_button(StringName("bio_ab_%d" % (i + 1)), "", COLOR_WINDOW, 27.0))
		b.cast_on_release = true
		b.cast_requested.connect(func(direction: Vector2) -> void: _cast_skill(i, direction))
		ability_buttons.append(b)
	interact = _add(BioTouchButton.round_button(&"bio_interact", "Agir", Color(1.0, 0.8, 0.35), 23.0))
	interact.glyph = "interact"
	leave = _add(BioTouchButton.pill(&"bio_leave", "Sair da sala", Color(1.0, 0.6, 0.4), Vector2(120, 38)))
	respawn = _add(BioTouchButton.pill(&"bio_respawn", "Renascer", Color(1.0, 0.5, 0.55), Vector2(150, 54)))
	for entry in [["Corpo", &"bio_body"], ["Códice", &"bio_codex"], ["Mapa", &"bio_map"], ["Sinais", &"bio_vitals"]]:
		var index := window_buttons.size()
		var button := _add_top(BioTouchButton.pill(&"", entry[0], COLOR_WINDOW, Vector2(74, 36)))
		button.tapped.connect(func() -> void: _navigate(index))
		window_buttons.append(button)
	fullscreen = _add_top(BioTouchButton.pill(&"", "Tela cheia", COLOR_WINDOW, Vector2(96, 36)))
	fullscreen.tapped.connect(func() -> void:
		close()
		BioPlatform.toggle_fullscreen())
	fullscreen.visible = false
	menu = _add_top(BioTouchButton.round_button(&"", "Menu", COLOR_WINDOW, 22.0))
	menu.glyph = "menu"
	menu.tapped.connect(func() -> void:
		if menu_open:
			close()
		else:
			BioUi.present(self)
			menu_open = true
			layout())
	_aim_overlay = Control.new()
	_aim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_overlay.draw.connect(_draw_aim)
	_root.add_child(_aim_overlay)
	get_viewport().size_changed.connect(func() -> void: layout())
	layout()


func configure(p_world: Node) -> void:
	world = p_world
	world.display.scale_changed.connect(_show_scale)
	_show_scale(world.display.interface_scale)
	minimap = BioTouchMinimap.new()
	minimap.configure(world)
	minimap.position = Vector2(24,16)
	_root.add_child(minimap)
	for child in world.player.get_children():
		if child is BioPlayerInput:
			(child as BioPlayerInput).touch = self


func _add(b: BioTouchButton) -> BioTouchButton:
	_root.add_child(b)
	return b


func _add_top(b: BioTouchButton) -> BioTouchButton:
	_top.add_child(b)
	return b


## Places everything from the size of the screen, so a rotation or a resized window never leaves a button out of reach.
func layout(size_override: Vector2 = Vector2.ZERO) -> void:
	var view := size_override if size_override != Vector2.ZERO else get_viewport().get_visible_rect().size
	var pad := Vector2(view.x - MARGIN - 62.0, view.y - MARGIN - 62.0)
	var side := attack_stick.radius * 2.5
	attack_stick.size = Vector2.ONE * side
	attack_stick.position = pad - attack_stick.size * 0.5
	var room := clampf((view.x-598.0)/149.0,0.0,1.0)
	toxin.position = pad + Vector2(-152,-92).lerp(Vector2(-183,-76),room) - toxin.size*0.5
	dash.position = pad + Vector2(-160,12).lerp(Vector2(-180,0),room) - dash.size*0.5
	var arc := [Vector2(-104,20),Vector2(-110,-48),Vector2(-66,-110),Vector2(12,-140)]
	for i in 4:
		ability_buttons[i].position = pad + arc[i] - ability_buttons[i].size*0.5
		ability_buttons[i].cancel_rect = Rect2(Vector2(view.x*0.72-30,40),Vector2(60,60))
	toxin.cancel_rect = Rect2(Vector2(view.x*0.72-30,40),Vector2(60,60))
	move_stick.position = Vector2(0.0, view.y*0.45)
	move_stick.size = Vector2(view.x*0.4,view.y*0.55)
	interact.position = pad + Vector2(-156,-160).lerp(Vector2(-180,-143),room) - interact.size*0.5
	leave.position = Vector2(view.x * 0.5 - leave.size.x * 0.5, view.y - 210.0)
	respawn.position = Vector2((view.x - respawn.size.x) * 0.5, view.y * 0.5 + 30.0)
	menu.position = Vector2(view.x - 86.0, 14.0)
	menu.caption = "Fechar" if menu_open else "Menu"
	menu.emphasis = menu_open
	menu.glyph = "close" if menu_open else "menu"
	_drawer.position = Vector2(view.x - 520, 54)
	_drawer.size = Vector2(500, view.y - 66)
	_menu_back.visible = menu_open
	if world != null:
		world.tray._box.visible = not BioUi.captures_input()
	for i in window_buttons.size():
		var button := window_buttons[i]
		button.size = Vector2(116, 44)
		button.position = Vector2(view.x - 136.0, 64.0 + i * 50.0)
		button.visible = menu_open
	fullscreen.position = Vector2(view.x - 136.0, 264.0)
	fullscreen.size = Vector2(116, 44)
	fullscreen.visible = menu_open and BioPlatform.fullscreen_available()


func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world.player):
		return
	_aim_overlay.queue_redraw()
	restart_button.visible = world.engine_url.is_empty() or (world.sync.link.online and world.sync.link.reset_allowed)
	menu.visible = menu_open or not BioUi.captures_input()
	var covered := BioUi.captures_input() or _a_window_is_open() or menu_open
	world.panel._column.visible = false
	world.jev_panel._badge.visible = false
	world.vitals_panel._strip.visible = false
	world.tray._box.visible = not covered

	var alive: bool = world.player.is_active() and not covered
	var in_dungeon: bool = world.dungeon != null and world.dungeon.active
	minimap.visible = alive and not in_dungeon
	respawn.visible = not world.player.is_active() and not covered
	leave.visible = alive and in_dungeon
	interact.visible = alive
	toxin.visible = alive
	dash.visible = alive
	attack_stick.visible = alive
	move_stick.visible = alive
	var runner: BioAbilityRunner = world.abilities
	for i in 4:
		var b := ability_buttons[i]
		var id := runner.slot_id(i)
		var known := id != &""
		b.visible = alive and known
		if known:
			var a := BioAbilityCatalog.get_ability(id)
			var pretty := str(a.get("name", ""))
			var tint: Color = a.get("color", COLOR_WINDOW)
			b.color = tint.lerp(Color.WHITE, 0.25)
			b.glyph = _skill_glyph(str(a.get("kind", "")))
			b.directional = not ["stance","counter","phase","frenzy","empower","replay","turret","lastchance","convert","grow","cloak","recall","nova","allies","mines","cascade","overload"].has(str(a.get("kind", "")))
			b.tooltip_text = pretty
			var def: BioAttackDef = world.player.combatant.actor.attack_def(id)
			b.seconds = world.player.combatant.actor.cooldown_remaining(id, BioClock.now())
			b.sub = ""  # full names are in Corpo; keep combat clear
			b.set_cooldown(runner.cooldown_fraction(i))
	var now := BioClock.now()
	var vitals: BioVitals = world.player.combatant.actor.vitals
	for pair in [[toxin, BioAttackCatalog.TOXIN_SPIT], [dash, BioAttackCatalog.MEMBRANE_DASH]]:
		var def: BioAttackDef = world.player.combatant.actor.attack_def(pair[1])
		var remaining: float = world.player.combatant.actor.cooldown_remaining(pair[1], now)
		var fraction := clampf(remaining / def.cooldown, 0.0, 1.0) if def.cooldown > 0.0 else 0.0
		if vitals.atp < def.atp_cost:
			fraction = 1.0
		(pair[0] as BioTouchButton).seconds = remaining
		(pair[0] as BioTouchButton).set_cooldown(fraction)
	for pair in [[window_buttons[0], world.body_panel], [window_buttons[1], world.codex_panel], [window_buttons[2], world.atlas], [window_buttons[3], world.vitals_panel]]:
		(pair[0] as BioTouchButton).emphasis = pair[1] != null and pair[1].has_method("is_open") and pair[1].is_open()
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = AUTO_AIM_EVERY
		_refresh_aim()


func _a_window_is_open() -> bool:
	if world.sync != null and world.sync.system != null and world.sync.system.is_offer_visible():
		return true
	for window in [world.body_panel, world.codex_panel, world.atlas, world.vitals_panel]:
		if window != null and window.is_open():
			return true
	return false


func move_vector() -> Vector2:
	return move_stick.value()


## Where the cell aims: where the thumb drags the attack button, else at the nearest enemy, else where it last aimed.
func aim_vector() -> Vector2:
	var manual := attack_stick.value()
	if manual != Vector2.ZERO:
		_aim = manual.normalized()
	return _aim


func _refresh_aim() -> void:
	if attack_stick.value() != Vector2.ZERO:
		return
	var player: BioCellActor = world.player
	var near := BioTargeting.enemies(player.get_world_2d(), player.global_position, AUTO_AIM_UNITS * BioArt.UNIT, player.combatant.actor.team)
	var nearest: BioCellActor = null
	var best := INF
	# Keep a valid target until another is substantially closer.
	if is_instance_valid(_target) and near.has(_target) and _target.is_active():
		nearest = _target
		best = _target.global_position.distance_squared_to(player.global_position) * 0.64
	for e in near:
		var d := e.global_position.distance_squared_to(player.global_position)
		if e.is_active() and d < best:
			best = d
			nearest = e
	_target = nearest
	if nearest != null:
		_aim = (nearest.global_position - player.global_position).normalized()
	elif move_stick.value() != Vector2.ZERO:
		_aim = move_stick.value().normalized()


func _on_attack_engaged(engaged: bool) -> void:
	if engaged:
		_refresh_aim()
		Input.action_press(&"bio_lash")
	else:
		Input.action_release(&"bio_lash")


func _skill_glyph(kind: String) -> String:
	match kind:
		"counter","phase","cloak","lastchance": return "shield"
		"heal","convert","grow": return "heal"
		"bolt","pierce","beam","sticky": return "projectile"
		"dash_strike","leap","roll","blink": return "dash"
		"devour","cone","execute": return "jaw"
		"zone","mines","crystal": return "net"
		"stance","replay","recall","portal": return "cycle"
		"mark","prey","sleep","decoy": return "eye"
		"link","tether","hold","complement","allies": return "link"
	return "burst"


func _prepare_cast(direction: Vector2) -> BioCellController:
	if direction == Vector2.ZERO:
		_refresh_aim()
	else:
		_aim = direction
	var controller := world.player.get_node("Controller") as BioCellController
	controller.set_aim(_aim)
	return controller


func _cast_skill(slot: int, direction: Vector2) -> void:
	if world == null or not world.player.is_active() or _a_window_is_open() or menu_open or BioUi.captures_input():
		return
	_prepare_cast(direction if ability_buttons[slot].directional else Vector2.ZERO)
	world.abilities.perform(slot)


func _cast_toxin(direction: Vector2) -> void:
	if world == null or not world.player.is_active() or _a_window_is_open() or menu_open or BioUi.captures_input():
		return
	_prepare_cast(direction).spit()


func _draw_aim() -> void:
	if world == null or menu_open or _a_window_is_open() or not world.player.is_active():
		return
	var aiming: BioTouchButton = null
	for button in ability_buttons + [toxin]:
		if button.is_down():
			aiming = button
	var camera_transform := get_viewport().get_canvas_transform()
	if aiming == null:
		if attack_stick.is_engaged() and attack_stick.value() != Vector2.ZERO:
			var start: Vector2 = camera_transform * world.player.global_position
			_aim_overlay.draw_line(start,start+attack_stick.value().normalized()*85,Color(0.5,0.95,1,0.7),2,true)
		if is_instance_valid(_target) and _target.is_active():
			var at := camera_transform * _target.global_position
			_aim_overlay.draw_arc(at,18,0,TAU,40,Color(1,0.7,0.35,0.8),1.5,true)
		return
	var view := get_viewport().get_visible_rect().size
	_aim_overlay.draw_string(ThemeDB.fallback_font,Vector2(view.x*0.5-120,28),aiming.tooltip_text,HORIZONTAL_ALIGNMENT_CENTER,240,12,Color(0.8,0.95,1))
	var origin: Vector2 = camera_transform * world.player.global_position
	var direction := aiming.aim_direction if aiming.aim_direction != Vector2.ZERO else _aim
	var tint := Color(1,0.3,0.35) if aiming.cancelled else Color(0.5,0.95,1,0.9)
	var end: Vector2 = origin + direction * 110.0
	if aiming.directional:
		_aim_overlay.draw_line(origin,end,tint,3,true)
		_aim_overlay.draw_arc(end,10,0,TAU,28,tint,2,true)
	else:
		_aim_overlay.draw_arc(origin,28,0,TAU,40,tint,2,true)
	var cancel := Vector2(get_viewport().get_visible_rect().size.x*0.72,70)
	_aim_overlay.draw_circle(cancel,28,Color(0.08,0.025,0.035,0.9))
	_aim_overlay.draw_arc(cancel,28,0,TAU,40,tint,2,true)
	_aim_overlay.draw_line(cancel-Vector2(7,7),cancel+Vector2(7,7),tint,2,true)
	_aim_overlay.draw_line(cancel-Vector2(-7,7),cancel+Vector2(-7,7),tint,2,true)
	_aim_overlay.draw_string(ThemeDB.fallback_font,cancel+Vector2(-28,43),"Cancelar",HORIZONTAL_ALIGNMENT_CENTER,56,10,tint)


func _show_scale(value: float) -> void:
	scale_slider.set_value_no_signal(roundi(value*100))
	scale_label.text = "Tamanho da interface: %d%%" % roundi(value*100)


func close() -> void:
	menu_open = false
	BioUi.set_modal(self, false)
	layout()

func _navigate(index: int) -> void:
	close()
	var windows := [world.body_panel, world.codex_panel, world.atlas, world.vitals_panel]
	windows[index].toggle()
