class_name BioTouchControls
extends CanvasLayer
## The controls for a finger: a stick on the left to move, a big attack button on the right that also aims when dragged, the toxin
## and the dash around it, the four class abilities on an arc above, and a row of windows at the top. Nothing here knows the game's
## rules: it presses the same input actions the keyboard does and reports where to move and aim. With no stick on the aim the cell
## aims at the nearest enemy, because a thumb that is busy running cannot also point.

const AUTO_AIM_UNITS := 13.0
const AUTO_AIM_EVERY := 0.1
const ARC_NEAR := 98.0
const ARC_FAR := 172.0
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
var _menu_back: ColorRect
var _target: BioCellActor

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
	_menu_back.color = Color(0.01, 0.025, 0.055, 0.94)
	_menu_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_back.visible = false
	_top.add_child(_menu_back)
	move_stick = BioTouchStick.new()
	move_stick.floating = true
	move_stick.radius = 62.0
	move_stick.color = COLOR_MOVE
	move_stick.label = "MOVER"
	_root.add_child(move_stick)
	attack_stick = BioTouchStick.new()
	attack_stick.floating = false
	attack_stick.radius = 58.0
	attack_stick.dead_zone = 0.3
	attack_stick.relative_aim = true
	attack_stick.color = COLOR_ATTACK
	attack_stick.label = "ATACAR"
	attack_stick.engaged_changed.connect(_on_attack_engaged)
	_root.add_child(attack_stick)
	toxin = _add(BioTouchButton.round_button(&"bio_spit", "Toxina", COLOR_TOXIN, 33.0))
	dash = _add(BioTouchButton.round_button(&"bio_dash", "Pulo", COLOR_DASH, 33.0))
	for i in 4:
		var b := _add(BioTouchButton.round_button(StringName("bio_ab_%d" % (i + 1)), "", COLOR_WINDOW, 31.0))
		ability_buttons.append(b)
	interact = _add(BioTouchButton.round_button(&"bio_interact", "Agir", Color(1.0, 0.8, 0.35), 23.0))
	leave = _add(BioTouchButton.pill(&"bio_leave", "Sair da sala", Color(1.0, 0.6, 0.4), Vector2(120, 38)))
	respawn = _add(BioTouchButton.pill(&"bio_respawn", "Renascer", Color(1.0, 0.5, 0.55), Vector2(150, 54)))
	for entry in [["Corpo", &"bio_body"], ["Códice", &"bio_codex"], ["Mapa", &"bio_map"], ["Sinais", &"bio_vitals"]]:
		window_buttons.append(_add_top(BioTouchButton.pill(entry[1], entry[0], COLOR_WINDOW, Vector2(74, 36))))
	fullscreen = _add_top(BioTouchButton.pill(&"", "Tela cheia", COLOR_WINDOW, Vector2(96, 36)))
	fullscreen.tapped.connect(BioPlatform.toggle_fullscreen)
	fullscreen.visible = false
	menu = _add_top(BioTouchButton.pill(&"", "Menu", COLOR_WINDOW, Vector2(88, 48)))
	menu.tapped.connect(func() -> void:
		menu_open = not menu_open
		layout())
	get_viewport().size_changed.connect(func() -> void: layout())
	layout()


func configure(p_world: Node) -> void:
	world = p_world
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
	_around(toxin, pad, ARC_NEAR, 118.0)
	_around(dash, pad, ARC_NEAR, 178.0)
	for i in 4:
		ability_buttons[i].position = Vector2(view.x * 0.5 - 142.0 + i * 74.0, view.y - 78.0)
	move_stick.position = Vector2(0.0, view.y * 0.2)
	move_stick.size = Vector2(view.x * 0.42, view.y * 0.8)
	interact.position = Vector2(view.x * 0.5 - 23.0, view.y - 142.0)
	leave.position = Vector2(view.x * 0.5 - leave.size.x * 0.5, view.y - 210.0)
	respawn.position = Vector2((view.x - respawn.size.x) * 0.5, view.y * 0.5 + 30.0)
	menu.position = Vector2(view.x - 108.0, 12.0)
	menu.caption = "Fechar" if menu_open else "Menu"
	menu.emphasis = menu_open
	_menu_back.visible = menu_open
	for i in window_buttons.size():
		var button := window_buttons[i]
		button.size = Vector2(116, 48)
		button.position = Vector2(view.x - 136.0, 72.0 + i * 56.0)
		button.visible = menu_open
	fullscreen.position = Vector2(view.x - 260.0, 72.0)
	fullscreen.size = Vector2(116, 48)
	fullscreen.visible = menu_open and BioPlatform.fullscreen_available()


## A button on a circle around `center`, at an angle (degrees, counter-clockwise from the right, like on paper).
func _around(button: BioTouchButton, center: Vector2, distance: float, degrees: float) -> void:
	var dir := Vector2(cos(deg_to_rad(degrees)), -sin(deg_to_rad(degrees)))
	button.position = center + dir * distance - button.size * 0.5


func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world.player):
		return
	var covered := _a_window_is_open() or menu_open
	world.panel._column.visible = menu_open
	world.jev_panel._badge.visible = false
	world.vitals_panel._strip.visible = menu_open
	world.tray._box.visible = not covered

	var alive: bool = world.player.is_active() and not covered
	var in_dungeon: bool = world.dungeon != null and world.dungeon.active
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
			b.caption = str(i + 1)
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
