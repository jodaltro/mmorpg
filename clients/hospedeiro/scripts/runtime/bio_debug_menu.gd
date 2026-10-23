class_name BioDebugMenu
extends CanvasLayer
## The test menu (Esc): buttons that take you straight to what you want to test, with the mouse. Places of the body, each room of the
## granuloma, any class (with its abilities), enemies to fight, full health, god mode, and shortcuts to the designs and to the panels of
## what Jev is doing. Every button calls a method of the world, so the same shortcuts are tested without a screen.

var _world: Node
var _panel: PanelContainer
var _buttons := {}  # label -> Button


func configure(world: Node) -> void:
	_world = world
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.position = Vector2(60, 60)
	_panel.custom_minimum_size = Vector2(980, 0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.015, 0.025, 0.06, 0.99)
	back.border_color = Color(0.3, 0.7, 1.0, 0.8)
	back.set_border_width_all(2)
	back.set_corner_radius_all(8)
	back.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", back)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "MENU DE TESTE  ·  Esc fecha  ·  o jogo continua rodando por trás"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	for section in _sections():
		var head := Label.new()
		head.text = section["title"]
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		box.add_child(head)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		box.add_child(flow)
		for item in section["items"]:
			var b := Button.new()
			b.text = item[0]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 30)
			for state in ["normal", "hover", "pressed"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = {"normal": Color(0.1, 0.17, 0.3), "hover": Color(0.2, 0.38, 0.6), "pressed": Color(0.3, 0.6, 0.9)}[state]
				sb.set_corner_radius_all(5)
				sb.set_content_margin_all(8)
				b.add_theme_stylebox_override(state, sb)
			b.pressed.connect(item[1])
			flow.add_child(b)
			_buttons[item[0]] = b


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible


func close() -> void:
	_panel.visible = false


func button_labels() -> Array:
	return _buttons.keys()


## Presses a button by its label (what a click does).
func press(label: String) -> bool:
	if not _buttons.has(label):
		return false
	(_buttons[label] as Button).pressed.emit()
	return true


func _sections() -> Array:
	var w := _world
	var places: Array = []
	var place_names := {BioBodyMap.MEDULA: "Nicho da medula", BioBodyMap.SANGUE: "Vênula", BioBodyMap.CORACAO: "Endocárdio", BioBodyMap.PULMAO: "Alvéolos", BioBodyMap.AORTA: "Artéria"}
	for id in place_names:
		places.append([place_names[id], func() -> void: w.debug_goto(id)])
	var rooms: Array = []
	for i in BioWorld.DEBUG_ROOMS.size():
		rooms.append(["Granuloma: " + (str(BioWorld.DEBUG_ROOMS[i]["name"])), func() -> void: w.debug_dungeon_room(i)])
	rooms.append(["Sair do granuloma", func() -> void: w.debug_leave_dungeon()])
	var classes: Array = []
	for id in BioWorld.DEBUG_CLASSES:
		classes.append([BioLineageCatalog.display_name(id), func() -> void: w.debug_become(id)])
	return [
		{"title": "IR PARA UM LUGAR DO CORPO", "items": places},
		{"title": "GRANULOMA (masmorra): direto para uma sala", "items": rooms},
		{"title": "CLASSE (com as 4 habilidades dela; ligado ao motor ele pode desfazer)", "items": classes},
		{"title": "TESTAR", "items": [
			["5 vírions à frente", func() -> void: w.debug_spawn_virions(5)],
			["15 vírions", func() -> void: w.debug_spawn_virions(15)],
			["Limpar vírions", func() -> void: w.debug_clear_virions()],
			["Vida e ATP cheios", func() -> void: w.debug_refill()],
			["Zerar recargas", func() -> void: w.debug_reset_cooldowns()],
			["Invulnerável (liga/desliga)", func() -> void: w.debug_toggle_god()],
		]},
		{"title": "DESIGN DO JEV", "items": [
			["Sortear um design completo", func() -> void: w.debug_random_design()],
			["Voltar ao design do motor", func() -> void: w.debug_engine_design()],
			["Próximo estilo de efeito", func() -> void: w.debug_cycle("efeito")],
			["Próxima trajetória", func() -> void: w.debug_cycle("trajetoria")],
			["Próximo impacto", func() -> void: w.debug_cycle("impacto")],
			["Próximo calibre", func() -> void: w.debug_cycle("calibre")],
			["Próximo foco", func() -> void: w.debug_cycle("foco")],
		]},
		{"title": "PAINÉIS", "items": [
			["Painel do Jev (F2)", func() -> void: w.jev_panel.toggle()],
			["Painel do design (F3)", func() -> void: w.design_debug.toggle()],
			["Sinais vitais (Tab)", func() -> void: w.vitals_panel.toggle()],
			["Códice (B)", func() -> void: w.codex_panel.toggle()],
			["Atlas (M)", func() -> void: w.atlas.toggle()],
			["Fechar menu", func() -> void: close()],
		]},
	]
