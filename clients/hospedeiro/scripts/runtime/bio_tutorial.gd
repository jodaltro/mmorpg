class_name BioTutorial
extends CanvasLayer
## Non-modal coach: highlights the real controls and observes confirmed play.
const SAVE := "user://hospedeiro_tutorial_v1.json"
const STEPS := [
	["Bem-vindo ao Hospedeiro", "Você é uma célula em um corpo compartilhado. Proteja o Hospedeiro, conheça seus habitantes e descubra sua linhagem. A Medula é um refúgio sem inimigos.", "Você pode pausar e retomar pelo botão Tutorial."],
	["Explore o refúgio", "Arraste o controle azul à esquerda para andar. Percorra um pequeno trecho dentro da Medula.", "Use WASD ou as setas para andar pela Medula."],
	["Sua membrana e sua energia", "Membrana é sua vida. ATP alimenta ataques e habilidades e se recupera com o tempo. Observe também o tempo de recarga dos poderes.", ""],
	["Acerte o alvo de treino", "Chegue perto do alvo azul marcado. Segure o botão de ataque; arraste nele para mirar. Acerte um golpe de perto.", "Chegue perto do alvo azul. Mire com o mouse e ataque com clique esquerdo ou J."],
	["Toxina: ataque à distância", "Mire no mesmo alvo: arraste o botão verde de Toxina e solte para disparar. Sem arrastar, a mira escolhe um alvo próximo.", "Mire no alvo e dispare com clique direito ou K."],
	["Desvie com um impulso", "Toque no botão Pulo enquanto se move. O impulso gasta ATP e ajuda a escapar de ataques.", "Mova-se e pressione Espaço para impulsionar a célula."],
	["Skills e magias biológicas", "Além de ataque, Toxina e Pulo, sua classe desbloqueia poderes especiais: dano, cura, defesa e controle. Eles ocupam quatro espaços e usam ATP e recarga. Configure a ordem no menu Corpo → Habilidades.", "Os quatro espaços de habilidades usam Q, F, C e V. Configure a ordem em Corpo → Habilidades."],
	["Conheça um NPC", "Siga a marca até Estroma, a célula dourada. NPCs são habitantes do corpo: dão informações e missões. Não são alvos. Invasores ficam fora da Medula.", ""],
	["Converse e descubra ações", "Perto de Estroma, toque em Agir para ver as ações disponíveis. Leia as opções e feche a janela para continuar.", "Perto de Estroma, pressione E para ver as ações disponíveis. Depois feche a janela."],
	["Acompanhe suas missões", "Abra Menu → Missões. Veja ofertas e objetivos: eles indicam quem ajudar e quais invasores atacar. Feche a janela depois de explorar.", "Clique no quadro de missões no canto superior direito. Veja os objetivos e feche a janela."],
	["Construa sua célula", "Abra Corpo. Genes modificam seu organismo; a experiência de jogo permite diferenciar sua classe. Não há níveis nem XP. Fora de combate, você verá um convite quando puder evoluir.", "Pressione G para abrir Corpo e conhecer genes, classe e habilidades."],
	["Pronto para explorar", "Você já pode sair da Medula rumo ao Sangue, à direita no mapa. Ataque apenas invasores e alvos indicados nas missões. Estroma e os outros NPCs são seus vizinhos. O refúgio continua seguro para treinar.", "Reveja este guia quando quiser pelo botão Tutorial."]
]

var world: BioWorld
var active := false
var step := 0
var completed := false
var persistence_path := SAVE
var _auto := true
var _root: Control
var _card: PanelContainer
var _heading: Label
var _text: Label
var _status: Label
var _next: Button
var _back: Button
var _highlight := Rect2()
var _origin := Vector2.ZERO
var _fulfilled := false
var _baseline := 0
var _actions: Dictionary = {}
var _npc_demo: BioResident
var _waiting := false
var _pointer_until := 0
var _veil: ColorRect
var _ink: Control
var _material: ShaderMaterial
var _progress: ProgressBar
var _step_age := 0.0
var _success_age := -1.0
var _focus := Rect2()
var _closing: Tween

func _ready() -> void:
	layer = 31
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/runtime/bio_tutorial_spotlight.gdshader")
	_veil.material = _material
	_root.add_child(_veil)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_ink)
	_ink.draw.connect(_draw_guide)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.ACCENT, 12, 12))
	_root.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 3
	_progress.show_percentage = false
	_progress.max_value = STEPS.size()
	_progress.add_theme_stylebox_override("background", BioUi.style(BioUi.LINE, Color.TRANSPARENT, 2, 0, 0))
	_progress.add_theme_stylebox_override("fill", BioUi.style(BioUi.ACCENT, Color.TRANSPARENT, 2, 0, 0))
	column.add_child(_progress)
	_heading = BioUi.label("", 15, BioUi.ACCENT)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_heading)
	_text = BioUi.wrapped("", 12, BioUi.TEXT)
	column.add_child(_text)
	_status = BioUi.wrapped("", 11, BioUi.MUTED)
	column.add_child(_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_back = BioUi.button("Voltar")
	_back.pressed.connect(func() -> void: _enter(maxi(0, step - 1)))
	row.add_child(_back)
	var pause := BioUi.button("Pausar")
	pause.pressed.connect(stop)
	row.add_child(pause)
	_next = BioUi.button("Continuar")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(advance)
	row.add_child(_next)
	var replay := BioUi.button("Tutorial")
	replay.position = Vector2(16, 94)
	replay.pressed.connect(func() -> void: start(completed))
	add_child(replay)
	replay.visible = world.touch == null
	for child in world.player.get_children():
		if child is BioAttackExecutor:
			child.performed.connect(func(id: StringName, _direction: Vector2) -> void:
				_actions[str(id)] = int(_actions.get(str(id), 0)) + 1)
	_load_progress()
	_root.hide()
	_auto = DisplayServer.get_name() != "headless" and not world.save_path.is_empty() and not completed
	get_viewport().size_changed.connect(_layout)

func start(replay := false) -> void:
	if _closing != null and _closing.is_valid(): _closing.kill()
	_root.modulate.a = 1
	if replay:
		step = 0
		completed = false
	if world.online_client == null: world.ensure_training_target()
	if world.evolution_presentation != null:
		world.evolution_presentation.modal.hide_modal()
	_auto = false
	active = true
	_enter(step)

func stop() -> void:
	_pointer_until = Time.get_ticks_msec() + 180
	active = false
	if _closing != null and _closing.is_valid(): _closing.kill()
	_closing = create_tween()
	_closing.tween_property(_root, "modulate:a", 0.0, 0.18)
	_closing.tween_callback(_root.hide)
	_save_progress()

func blocks_pointer() -> bool:
	return Time.get_ticks_msec() < _pointer_until or (active and _card.get_global_rect().has_point(_card.get_global_mouse_position()))

func advance() -> void:
	if not active or not _fulfilled or _waiting: return
	if step == STEPS.size() - 1:
		completed = true
		stop()
	else:
		_enter(step + 1)

func _enter(index: int) -> void:
	step = clampi(index, 0, STEPS.size() - 1)
	_step_age = 0
	_success_age = -1
	_progress.value = step + 1
	_fulfilled = false
	_origin = world.player.global_position
	_baseline = _practice_count(_attack_id()) if step == 3 or step == 4 else int(_actions.get(str(BioAttackCatalog.MEMBRANE_DASH), 0))
	_heading.text = "%d/%d · %s" % [step + 1, STEPS.size(), STEPS[step][0]]
	_text.text = STEPS[step][1]
	if world.touch == null and not str(STEPS[step][2]).is_empty():
		_text.text = STEPS[step][2] if step in [1, 3, 4, 5, 8, 9] else str(STEPS[step][1]) + " " + str(STEPS[step][2])
	_back.disabled = step == 0
	_next.text = "Começar" if step == 0 else "Concluir" if step == STEPS.size() - 1 else "Continuar"
	_save_progress()
	_layout()

func _layout() -> void:
	if _card == null: return
	var view := get_viewport().get_visible_rect().size
	var width := minf(350, view.x - 24)
	_card.custom_minimum_size.x = width
	_card.size = Vector2(width, _card.get_combined_minimum_size().y)
	var x := (view.x - width) * 0.5
	if world.touch != null and world.touch.menu_open: x = 12
	_card.position = Vector2(x, 12 if view.x > view.y else 96)
	if world.touch != null and world.touch.menu_open and x + width + 12 > world.touch._drawer.position.x:
		_card.position.y = view.y - _card.size.y - 12

func _process(delta: float) -> void:
	var ready_to_play := world.online_client == null or world.online_client.is_ready
	if _auto and ready_to_play: start()
	if not active: return
	_step_age += delta
	if _success_age >= 0: _success_age += delta
	_waiting = not ready_to_play or not BioSanctuary.contains(world.seed_value, world.player.global_position / BioArt.UNIT) or world.dungeon.active
	_root.visible = true
	_card.visible = not ((step == 9 and world.sync.system._missions.visible) or (step == 10 and world.body_panel.is_open()) or (step == 8 and world.sync.system.menu_open))
	_veil.visible = _card.visible
	_ink.visible = _card.visible
	if _waiting:
		_status.text = "Aguardando o mundo carregar…" if not ready_to_play else "Volte à Medula para continuar com segurança."
		_next.disabled = true
		_highlight = Rect2()
		_material.set_shader_parameter("opacity", 0.25)
		_material.set_shader_parameter("hole_count", 0)
		_ink.queue_redraw()
		return
	var previously_fulfilled := _fulfilled
	match step:
		1: _fulfilled = _fulfilled or world.player.global_position.distance_to(_origin) >= 2.0 * BioArt.UNIT
		3, 4: _fulfilled = _fulfilled or _practice_count(_attack_id()) > _baseline
		5: _fulfilled = _fulfilled or int(_actions.get(str(BioAttackCatalog.MEMBRANE_DASH), 0)) > _baseline
		7: _fulfilled = _fulfilled or world.player.global_position.distance_to(BioBodyMap.RESIDENTS["estroma"] * BioArt.UNIT) < 3.0 * BioArt.UNIT
		8: _fulfilled = _fulfilled or world.sync.system.menu_open or not world.sync.link.online
		9: _fulfilled = _fulfilled or world.sync.system._missions.visible
		10: _fulfilled = _fulfilled or world.body_panel.is_open()
		_: _fulfilled = true
	if _fulfilled and not previously_fulfilled and step in [1, 3, 4, 5, 7, 8, 9, 10]: _success_age = 0
	_status.text = "Pronto! Continue quando quiser." if _fulfilled else "Faça a ação indicada para continuar."
	if step in [0, 2, 6, 11]: _status.text = "Avance no seu ritmo. Você pode pausar."
	_status.modulate = BioUi.GOOD if _fulfilled and step not in [0, 2, 6, 11] else Color.WHITE
	if step == 8 and not world.sync.link.online:
		_status.text = "Modo offline: conversas e missões precisam do motor conectado."
	_next.disabled = not _fulfilled
	_highlight = _target_rect()
	if not _card.visible: _highlight = Rect2()
	_layout()
	_animate_focus(delta)
	_ink.queue_redraw()

func _world_target() -> Vector2:
	var point := BioBodyMap.TRAINING_POINT if step in [3, 4] else Vector2(BioBodyMap.RESIDENTS["estroma"])
	return world.get_global_transform_with_canvas() * (point * BioArt.UNIT)

func _animate_focus(delta: float) -> void:
	var blend := 1.0 - exp(-delta * 16.0)
	if _focus.size == Vector2.ZERO: _focus = _highlight
	_focus = Rect2(_focus.position.lerp(_highlight.position, blend), _focus.size.lerp(_highlight.size, blend))
	var holes := PackedVector4Array()
	var primary := _focus.grow(12)
	holes.append(Vector4(primary.get_center().x, primary.get_center().y, primary.size.x * 0.5, primary.size.y * 0.5))
	if step in [3, 4, 7, 8]:
		var destination := _world_target()
		holes.append(Vector4(destination.x, destination.y, 54, 54))
	if step in [1, 3, 4, 5, 7]:
		var player_point := world.player.get_global_transform_with_canvas().origin
		holes.append(Vector4(player_point.x, player_point.y, 65, 65))
		if world.touch != null:
			var stick := world.touch.move_stick
			var rect := stick.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, stick.size)
			holes.append(Vector4(rect.get_center().x, rect.get_center().y, rect.size.x * 0.6, rect.size.y * 0.6))
	_material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	_material.set_shader_parameter("hole_count", holes.size())
	while holes.size() < 4: holes.append(Vector4.ZERO)
	_material.set_shader_parameter("holes", holes)
	var fade := smoothstep(0.0, 0.32, _step_age)
	_material.set_shader_parameter("opacity", (0.65 if step in [1, 3, 4, 5, 7] else 0.8) * fade)
	_card.modulate.a = fade
	_card.position.y += (1.0 - fade) * 10.0

func _draw_gesture(center: Vector2) -> void:
	if world.touch == null or _fulfilled or step not in [1, 3, 4, 5, 8, 9, 10]: return
	var phase := fmod(_step_age, 2.4) / 2.4
	var slide := Vector2(-32, -18) if step == 4 else Vector2(27, -17) if step == 1 else Vector2.ZERO
	var finger := center + slide * smoothstep(0.1, 0.65, phase)
	var alpha := smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.72, 1.0, phase))
	if slide != Vector2.ZERO: _ink.draw_line(center, finger, Color(1, 1, 1, alpha * 0.5), 2, true)
	_ink.draw_circle(finger, 8, Color(1, 1, 1, alpha * 0.18))
	_ink.draw_arc(finger, 8, 0, TAU, 24, Color(1, 1, 1, alpha), 2, true)
	_ink.draw_arc(finger, 10 + phase * 18, 0, TAU, 32, Color(0.4, 1, 0.85, alpha * (1 - phase)), 2, true)

func _draw_trail(destination: Vector2) -> void:
	var origin := world.player.get_global_transform_with_canvas().origin
	if origin.distance_to(destination) < 70: return
	var end := origin.lerp(destination, minf(1, 450.0 / origin.distance_to(destination)))
	for i in 12:
		var fraction := fmod(float(i) / 12 + _step_age * 0.22, 1.0)
		var point := origin.lerp(end, fraction)
		_ink.draw_circle(point, 2.0 + fraction * 1.2, Color(0.4, 1, 0.85, sin(fraction * PI) * 0.55))

func _attack_id() -> StringName:
	return BioAttackCatalog.TOXIN_SPIT if step == 4 else BioAttackCatalog.FLAGELLUM_LASH

func _practice_count(id: StringName) -> int:
	var key := str(world.player.combatant.actor.id)
	if world.online_client != null: key = "nk-" + world.online_client.transport.user_id
	for node in get_tree().get_nodes_in_group("training_targets"):
		if node.get_parent() == world:
			var counts: Dictionary = (node.combatant as BioTrainingCombatant).practice.get(key, {})
			return int(counts.get(str(id), 0))
	return 0

func _target_rect() -> Rect2:
	var target: Control
	if world.touch != null:
		match step:
			1: target = world.touch.move_stick
			3: target = world.touch.attack_stick
			4: target = world.touch.toxin
			5: target = world.touch.dash
			6, 10: target = world.touch.window_buttons[0] if world.touch.menu_open else world.touch.menu
			8: target = world.touch.interact
			9: target = world.touch.missions_button if world.touch.menu_open else world.touch.menu
	if step == 2: target = world.hud._cluster
	if step == 9 and world.touch == null: target = world.sync.system._tracker
	if step == 9 and world.sync.system._missions.visible: target = null
	if step == 10 and world.body_panel.is_open(): target = null
	if target != null and target.is_visible_in_tree():
		return target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size)
	var point := world.player.global_position
	if step in [3, 4]: point = BioBodyMap.TRAINING_POINT * BioArt.UNIT
	if step in [7, 8]:
		point = BioBodyMap.RESIDENTS["estroma"] * BioArt.UNIT
		if not world.sync.link.online and not is_instance_valid(_npc_demo):
			_npc_demo = BioResident.new()
			_npc_demo.configure("estroma", "Estroma · NPC (demonstração offline)", point)
			world.add_child(_npc_demo)
	var screen := world.get_global_transform_with_canvas() * point
	var view := get_viewport().get_visible_rect().size
	screen = screen.clamp(Vector2(42, 42), view - Vector2(42, 42))
	return Rect2(screen - Vector2(34, 34), Vector2(68, 68))

func _draw_guide() -> void:
	if _highlight.size == Vector2.ZERO: return
	var pulse := 0.65 + sin(_step_age * 3.0) * 0.18
	var rect := _focus if _focus.size != Vector2.ZERO else _highlight
	for i in range(3, 0, -1):
		_ink.draw_style_box(BioUi.style(Color.TRANSPARENT, Color(0.35, 1, 0.84, pulse * 0.12), 16, 0, 3), rect.grow(7 + i * 3))
	_ink.draw_style_box(BioUi.style(Color.TRANSPARENT, Color(0.45, 1, 0.88, pulse), 12, 0, 2), rect.grow(7))
	var bounce := sin(_step_age * 3) * 3
	_ink.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -12 + bounce), "▼ AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BioUi.ACCENT)
	_draw_gesture(rect.get_center())
	if _success_age >= 0 and _success_age < 0.8:
		var fraction := _success_age / 0.8
		var center := rect.get_center()
		_ink.draw_arc(center, 25 + fraction * 55, 0, TAU, 48, Color(0.4, 1, 0.7, 1.0 - fraction), 2, true)
		for i in 10:
			var direction := Vector2.from_angle(float(i) / 10.0 * TAU)
			_ink.draw_circle(center + direction * (25 + fraction * 55), 2 * (1 - fraction), Color(0.5, 1, 0.8, 1 - fraction))
	# World marker is independent of the highlighted attack control.
	if step in [3, 4, 7, 8]:
		var point := BioBodyMap.TRAINING_POINT if step in [3, 4] else Vector2(BioBodyMap.RESIDENTS["estroma"])
		var screen := world.get_global_transform_with_canvas() * (point * BioArt.UNIT)
		var view := get_viewport().get_visible_rect().size
		var clamped := screen.clamp(Vector2(38, 60), view - Vector2(38, 38))
		_draw_trail(screen)
		_ink.draw_arc(clamped, 35, 0, TAU, 48, Color(0.6, 1, 0.85, pulse), 2, true)
		if clamped.distance_to(screen) > 2:
			var direction := (screen - clamped).normalized()
			_ink.draw_line(clamped, clamped + direction * 26, BioUi.ACCENT, 3)
			_ink.draw_line(clamped + direction * 26, clamped + direction.rotated(0.6) * 16, BioUi.ACCENT, 3)
			_ink.draw_line(clamped + direction * 26, clamped + direction.rotated(-0.6) * 16, BioUi.ACCENT, 3)
		_ink.draw_string(ThemeDB.fallback_font, clamped + Vector2(-25, 53), "TREINO" if step in [3, 4] else "NPC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BioUi.ACCENT)

func _load_progress() -> void:
	if world.save_path.is_empty() or not FileAccess.file_exists(persistence_path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(persistence_path))
	if data is Dictionary and data.get("version") == 1:
		step = clampi(int(data.get("step", 0)), 0, STEPS.size() - 1)
		completed = bool(data.get("completed", false))

func _save_progress() -> void:
	if world.save_path.is_empty(): return
	var file := FileAccess.open(persistence_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"version": 1, "step": step, "completed": completed}))
