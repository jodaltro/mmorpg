class_name BioAtlas
extends CanvasLayer
## The atlas of the body (key M): the whole body is drawn and named from the start (a crisis can be anywhere, so the player must
## always see where to go), the vessels between the regions are lines, a marker shows where the cell is, and every crisis that asks
## for attention is ringed on its organ with what to do there.

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
	var places := BioUi.button("Locais · o que são?")
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
	reveal_all()


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
	reveal_all()


## No fog of war: every region is known from the start.
func reveal_all() -> void:
	known.clear()
	for region in BioAnatomy.build(_seed)["regions"]:
		known.append(StringName(region["id"]))


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
	_modal.heading.text = "ATLAS · o corpo inteiro"
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
	var placed: Array[Rect2] = []  # the names already on the map, so two never overlap
	for region in body["regions"]:
		var at: Vector2 = to_screen.call(region["center"])
		var visited := known.has(region["id"])
		var tint := BioUi.ACCENT if visited else BioUi.TEXT
		_panel.draw_circle(at, 7, BioUi.BG)
		_panel.draw_arc(at, 7, 0.0, TAU, 20, tint, 2.0, true)
		var label := str(BioBodyMap.SHORT.get(region["id"], region["name"]))  # every place is named: the whole body is open
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var label_at := at + Vector2(-label_size.x * 0.5, -16)
		for below in [Vector2(0, 0), Vector2(0, 32), Vector2(0, -16)]:  # above the marker; below it when a neighbour's name is in the way
			var name_box := Rect2(label_at + below + Vector2(0, -label_size.y), label_size).grow(2.0)
			if not placed.any(func(r: Rect2) -> bool: return r.intersects(name_box)):
				label_at += below
				placed.append(name_box)
				break
		_panel.draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.01, 0.02, 0.05, 0.95))
		_panel.draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
		if visited:
			_hits.append({"screen": at, "at": region["center"] * BioArt.UNIT, "title": place_title(region), "detail": "Medula · refúgio sem invasores. Treine e conheça Estroma, o NPC dourado." if region["id"] == BioBodyMap.MEDULA else "Sangue · primeira área de combate. Ataque vírions e absorva nutrientes para evoluir." if region["id"] == BioBodyMap.SANGUE else str(region["name"]) + " · região do corpo. Siga os vasos para chegar; membranas podem exigir adaptação."})
	var world := _player.get_parent() as BioWorld if is_instance_valid(_player) else null
	if world != null:
		_paint_crises(world, body, to_screen, font)
		if world.journey != null and world.journey.has_target:
			var gps := PackedVector2Array()
			for point in world.journey.navigation_path(): gps.append(to_screen.call(point / BioArt.UNIT))
			if gps.size() > 1:
				_panel.draw_polyline(gps, Color(0.01, 0.04, 0.08, 0.95), 7, true)
				_panel.draw_polyline(gps, Color(0.35, 1, 1, 0.95), 3, true)
			var end: Vector2 = to_screen.call(world.journey.goal / BioArt.UNIT)
			_panel.draw_circle(end, 7, BioUi.BG)
			_panel.draw_arc(end, 7, 0, TAU, 32, BioUi.ACCENT, 2, true)
	_legend.text = "● Você · ◎ Crise que pede ajuda · Linha azul: GPS\nToque em um local para ver detalhes e marcar destino."
	if world != null and world.journey != null and world.journey.navigation_state != "none":
		_legend.text += "\nGPS · " + world.journey.gps_label()
	if is_instance_valid(_player):
		var at := (_player.global_position / BioArt.UNIT) * scale + offset
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		_panel.draw_circle(at, 9.0 + 4.0 * pulse, Color(0.2, 0.9, 1.0, 0.25))
		_panel.draw_circle(at, 5.0, Color(0.7, 1.0, 1.0, 0.95))

## A ring on the organ of every crisis that asks for attention, named, with what to do there when it is tapped.
func _paint_crises(world: BioWorld, body: Dictionary, to_screen: Callable, font: Font) -> void:
	if world.sync == null or world.sync.presenter == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var focus := world.sync.living_hud.focus_id() if world.sync.living_hud != null else ""
	for c in world.sync.presenter.model.ordered():
		if not BioConflictFocus.demanding(c):
			continue
		for region in body["regions"]:
			if str(region["id"]) != str(c.get("region", "")):
				continue
			var at: Vector2 = to_screen.call(region["center"])
			var color: Color = BioConflictFocus.PHASE_COLOR.get(str(c.get("phase", "")), Color.WHITE)
			var big := str(c.get("id", "")) == focus
			_panel.draw_arc(at, (20.0 if big else 15.0) + 4.0 * pulse, 0.0, TAU, 32, color, 3.0 if big else 2.0, true)
			_panel.draw_string(font, at + Vector2(24, -6), str(c.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 220, 12, color)
			_hits.append({"screen": at, "at": region["center"] * BioArt.UNIT, "title": "%s · %s" % [str(c.get("title", "")), BioConflictFocus.organ(c)],
				"detail": "%s\n\nO QUE FAZER: %s" % [BioConflictFocus.effect(c), BioConflictFocus.suggestion(c)]})


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
func _clear_place_buttons() -> void:
	for child in _info.content.get_children():
		if child == _detail or child == _go: continue
		_info.content.remove_child(child)
		child.queue_free()

func show_places() -> void:
	_clear_place_buttons()
	_detail.text = "NPC dourado: habitante aliado, não ataque.\nNutriente: absorva ao passar sobre ele.\nVírion: invasor para combater.\n\nEscolha um local conhecido para ver detalhes e marcar o caminho:"
	_go.visible = false
	for hit in _hits:
		var button := BioUi.button(str(hit.title))
		button.pressed.connect(func() -> void: _selected = hit; _show_selected())
		_info.content.add_child(button)
	_modal.hide_modal()
	_info.present(self)
