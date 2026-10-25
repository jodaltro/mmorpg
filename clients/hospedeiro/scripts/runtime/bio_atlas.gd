class_name BioAtlas
extends CanvasLayer
## The atlas of the body (key M): the regions the cell has been to are drawn and named, the ones it has not are only a dim, unnamed
## outline, the vessels between them are lines, and a marker shows where the cell is. Discovery is remembered between sessions.

signal discovered(region: StringName)
signal destination_chosen(at: Vector2, title: String)

var known: Array[StringName] = []
var persist_path := ""  # empty: nothing is saved

var _modal: BioModal
var _legend: Label
var _panel: Control
var _player: Node2D
var _region: StringName = &"medula"
var _seed := 1337
var _hits: Array[Dictionary] = []
var _selected: Dictionary = {}
var _detail: Label
var _go: Button
var _info: BioModal
var _focus_known := true


func configure(player: Node2D, body_seed: int, save_path: String) -> void:
	_player = player
	_seed = body_seed
	persist_path = save_path
	layer = 13
	_modal = BioModal.new()
	add_child(_modal)
	_modal.build("ATLAS DO CORPO", false)
	_modal.dismissed.connect(close)
	_panel = Control.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	_panel.gui_input.connect(_select_input)
	_panel.draw.connect(_paint)
	_modal.content.add_child(_panel)
	_legend = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.MUTED)
	_modal.content.add_child(_legend)
	var row := HBoxContainer.new()
	_modal.content.add_child(row)
	var zoom := BioUi.button("Ver corpo inteiro")
	zoom.pressed.connect(func() -> void:
		_focus_known = not _focus_known
		zoom.text = "Ver corpo inteiro" if _focus_known else "Ampliar locais conhecidos"
		_panel.queue_redraw())
	row.add_child(zoom)
	var places := BioUi.button("Locais e masmorras · o que são?")
	places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	places.pressed.connect(show_places)
	row.add_child(places)
	_info = BioModal.new()
	_info.max_size = Vector2(540, 430)
	add_child(_info)
	_info.build("LOCAIS DO CORPO")
	_info.dismissed.connect(func() -> void: _info.hide_modal(); _modal.present(self))
	_detail = BioUi.wrapped("", 12, BioUi.TEXT)
	_info.content.add_child(_detail)
	_go = BioUi.button("Marcar caminho", "primary")
	_go.visible = false
	_go.pressed.connect(func() -> void: destination_chosen.emit(_selected.at, _selected.title))
	_info.content.add_child(_go)
	_load()
	for id in [BioBodyMap.MEDULA, BioBodyMap.SANGUE]:
		discover(id)


func is_open() -> bool:
	return _modal.visible or _info.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		_modal.present(self)
		_panel.queue_redraw()

func close() -> void:
	_modal.hide_modal()
	_info.hide_modal()


func knows(id: StringName) -> bool:
	return known.has(id)


func set_region(id: StringName) -> void:
	_region = id
	discover(id)


## Marks a region as visited. Returns true the first time.
func discover(id: StringName) -> bool:
	if known.has(id):
		return false
	known.append(id)
	_save()
	discovered.emit(id)
	return true


## Regions the engine remembers this cell visited (silent: it is history, not news).
func merge(ids: Array) -> void:
	var changed := false
	for id in ids:
		var key := StringName(str(id))
		if not known.has(key) and BioAnatomy.region_def(key).size() > 0:
			known.append(key)
			changed = true
	if changed:
		_save()


func forget_all() -> void:
	known.clear()
	_save()
	for id in [BioBodyMap.MEDULA, BioBodyMap.SANGUE]:
		discover(id)


func _process(_delta: float) -> void:
	if _modal.visible:
		_panel.queue_redraw()


func _save() -> void:
	if persist_path.is_empty():
		return
	var file := FileAccess.open(persist_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"known": known.map(func(id: StringName) -> String: return String(id))}))


func _load() -> void:
	if persist_path.is_empty() or not FileAccess.file_exists(persist_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(persist_path))
	if data is Dictionary:
		for id in data.get("known", []):
			var key := StringName(str(id))
			if not known.has(key) and BioAnatomy.region_def(key).size() > 0:
				known.append(key)


func _paint() -> void:
	_hits.clear()
	var size := _panel.size
	_panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.88))
	var body := BioAnatomy.build(_seed)
	var box := BioAnatomy.bounds(_seed).grow(14.0)
	if _focus_known and not known.is_empty():
		var first := true
		for region in body["regions"]:
			if not known.has(region["id"]): continue
			var radius := Vector2.ONE * float(region["radius"])
			var extent := Rect2(region["center"] - radius, radius * 2)
			box = extent if first else box.merge(extent)
			first = false
		box = box.grow(6)
	var frame := Rect2(Vector2(20, 20), size - Vector2(40, 40))
	var scale := minf(frame.size.x / box.size.x, frame.size.y / box.size.y)
	var offset := frame.position + (frame.size - box.size * scale) * 0.5 - box.position * scale
	var font := ThemeDB.fallback_font
	_modal.heading.text = "ATLAS · %d/%d regiões" % [known.size(), (body["regions"] as Array).size()]
	var to_screen := func(p: Vector2) -> Vector2: return p * scale + offset
	for loop in body["loops"]:  # the whole body is one membrane: its shape is always there, only dim where the cell has not been
		var shape := PackedVector2Array()
		for p in loop:
			shape.append(to_screen.call(p))
		shape.remove_at(shape.size() - 1)
		if not Geometry2D.triangulate_polygon(shape).is_empty():
			_panel.draw_colored_polygon(shape, Color(0.35, 0.4, 0.55, 0.07))
	for l in body["links"]:  # the route of the vessels where both ends are known
		if known.has(l["from"]) and known.has(l["to"]):
			var line := PackedVector2Array()
			for p in l["path"]:
				line.append(to_screen.call(p))
			_panel.draw_polyline(line, Color(1.0, 0.45, 0.5, 0.4), 3.0, true)
	for run in body["walls"]:
		var pts := PackedVector2Array()
		for p in run["points"]:
			pts.append(to_screen.call(p))
		if known.has(run["region"]):
			var tint: Color = run["color"]
			_panel.draw_polyline(pts, BioArt.with_alpha(tint, 0.35), 7.0 if run["region"] != _region else 10.0, true)
			_panel.draw_polyline(pts, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.3), 0.95), 2.5, true)
		else:
			_panel.draw_polyline(pts, Color(0.55, 0.6, 0.7, 0.3), 2.0, true)
	var legends: Array[String] = []
	var number := 0
	for region in body["regions"]:
		var at: Vector2 = to_screen.call(region["center"])
		var visited := known.has(region["id"])
		var marker := "?"
		if visited:
			number += 1
			marker = str(number)
			legends.append("%d · %s" % [number, place_title(region)])
		var tint := BioUi.ACCENT if visited else BioUi.MUTED
		_panel.draw_circle(at, 10, BioUi.BG)
		_panel.draw_string(font, at + Vector2(-4, 4), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		if visited:
			_hits.append({"screen": at, "at": region["center"] * BioArt.UNIT, "title": place_title(region), "detail": "Medula · refúgio sem invasores. Treine e conheça Estroma, o NPC dourado." if region["id"] == BioBodyMap.MEDULA else "Sangue · primeira área de combate. Ataque vírions e absorva nutrientes para evoluir." if region["id"] == BioBodyMap.SANGUE else str(region["name"]) + " · região do corpo. Siga os vasos para chegar; membranas podem exigir adaptação."})
	var world := _player.get_parent() as BioWorld if is_instance_valid(_player) else null
	if world != null:
		for gate in world.gates.values():
			if not knows(BioBodyMap.region_of(gate.global_position)): continue
			var at: Vector2 = to_screen.call(gate.global_position / BioArt.UNIT)
			var diamond := PackedVector2Array([at + Vector2(0,-7), at + Vector2(7,0), at + Vector2(0,7), at + Vector2(-7,0), at + Vector2(0,-7)])
			_panel.draw_polyline(diamond, BioUi.GOOD if gate.eligible else BioUi.MUTED, 2, true)
			_hits.append({"screen": at, "at": gate.global_position, "title": "Masmorra: " + gate.title.capitalize(), "detail": dungeon_description(gate)})
	_legend.text = "    ".join(legends) + "\n● Você: azul pulsante · ○ Região · ◇ Masmorra · Linhas: vasos"
	if is_instance_valid(_player):
		var at := (_player.global_position / BioArt.UNIT) * scale + offset
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		_panel.draw_circle(at, 9.0 + 4.0 * pulse, Color(0.2, 0.9, 1.0, 0.25))
		_panel.draw_circle(at, 5.0, Color(0.7, 1.0, 1.0, 0.95))

static func dungeon_description(gate: BioGate) -> String:
	return "Desafio opcional em uma instância pessoal, com salas de combate e um chefe. Aproxime-se da entrada e use Agir para consultar as ações.\n" + ("Entrada disponível. Prepare genes e habilidades em Corpo antes de entrar." if gate.eligible else "Entrada indisponível: " + (gate.hint if not gate.hint.is_empty() else "consulte os requisitos em Agir quando estiver perto.")) + ("\n\n" + gate.details if not gate.details.is_empty() else "")

static func place_title(region: Dictionary) -> String:
	if region["id"] == BioBodyMap.MEDULA: return "MEDULA · REFÚGIO"
	if region["id"] == BioBodyMap.SANGUE: return "SANGUE · VÊNULA"
	return str(region["name"])

func _select_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		at = event.position
	else: return
	select_marker(at)

func select_marker(at: Vector2) -> void:
	var best := 25.0
	for hit in _hits:
		var distance := at.distance_to(hit.screen)
		if distance < best:
			best = distance
			_selected = hit
	if best < 25:
		_show_selected()

func _show_selected() -> void:
	_clear_place_buttons()
	_detail.text = str(_selected.title) + "\n\n" + str(_selected.detail)
	_go.visible = true
	_modal.hide_modal()
	_info.present(self)
	var world := _player.get_parent() as BioWorld
	if world == null: return
	for gate in world.gates.values():
		if gate.global_position != _selected.at: continue
		var preview := BioUi.button("Ver expedição e prêmios", "primary")
		preview.pressed.connect(func() -> void: close(); world.dungeon_panel.open_gate(gate))
		_info.content.add_child(preview)
		break

func _clear_place_buttons() -> void:
	for child in _info.content.get_children():
		if child == _detail or child == _go: continue
		_info.content.remove_child(child)
		child.queue_free()

func show_places() -> void:
	_clear_place_buttons()
	_detail.text = "NPC dourado: habitante aliado, não ataque.\nNutriente: absorva ao passar sobre ele.\nVírion: invasor para combater.\nMasmorra: desafio opcional em salas, separado do mapa aberto.\n\nEscolha um local conhecido para ver detalhes e marcar o caminho:"
	_go.visible = false
	for hit in _hits:
		var button := BioUi.button(str(hit.title))
		button.pressed.connect(func() -> void: _selected = hit; _show_selected())
		_info.content.add_child(button)
	_modal.hide_modal()
	_info.present(self)
