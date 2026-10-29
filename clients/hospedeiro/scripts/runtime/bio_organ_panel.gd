class_name BioOrganPanel
extends CanvasLayer
## The organ the player stands in, always on screen: its health (the engine's numbers), what is wrong, who is working there; and under it a
## small panel with what the player did and what they can do. What the player does shows up here: the health moves when the engine
## confirms the work, and the player's own list grows at once (the engine's count of confirmed deeds is shown beside it).
## Presentation only: every number is the engine's.

const LOG_LINES := 4
const WIDTH := 252.0

var world: BioWorld
var _root: VBoxContainer
var _organ_card: PanelContainer
var _organ_box: VBoxContainer
var _work_card: PanelContainer
var _work_box: VBoxContainer
var _region := ""
var _entered_health := -1  # the organ's health when the player arrived
var _log: Array[Dictionary] = []  # {text, count}
var _key := ""
var _in := 0.0


func configure(p_world: BioWorld) -> void:
	world = p_world
	layer = 11
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 6)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_left = -24.0 - WIDTH
	_root.offset_right = -24.0
	_root.offset_top = 272.0
	_organ_card = _card()
	_organ_box = _organ_card.get_child(0) as VBoxContainer
	_work_card = _card()
	_work_box = _work_card.get_child(0) as VBoxContainer
	_root.add_child(_organ_card)
	_root.add_child(_work_card)
	_root.visible = false
	world.organ_deed.connect(_on_deed)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", BioUi.style(Color(0.03, 0.06, 0.11, 0.86), BioUi.LINE, 10, 9))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	return card


func is_shown() -> bool:
	return _root != null and _root.visible


func log_lines() -> Array[Dictionary]:
	return _log


func entered_health() -> int:
	return _entered_health


## A deed the game server was told of: the player's own list grows at once, repeated ones are counted.
func _on_deed(action: String) -> void:
	var text := BioOrganRules.deed_label(action)
	if world.terrain != null and action.begins_with("terreno-"):
		var verb := action.trim_prefix("terreno-").split("-")[0]
		text = "%s: %s" % [text, BioTerrainRules.prop_name(world.terrain.current_def(), verb)]
	if not _log.is_empty() and _log[0]["text"] == text:
		_log[0]["count"] = int(_log[0]["count"]) + 1
	else:
		_log.push_front({"text": text, "count": 1})
		if _log.size() > LOG_LINES:
			_log.resize(LOG_LINES)
	_key = ""


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.3
	_refresh()


func _refresh() -> void:
	var region := str(world.region)
	var organs := world.engine_organs()
	var o := BioOrganRules.entry(organs, region)
	var show := not o.is_empty() and world.tutorial != null and world.tutorial.completed and not BioUi.captures_input()
	_root.visible = show
	if not show:
		return
	if region != _region:  # a new organ: its health now is the starting point, and the list is about this one
		_region = region
		_entered_health = int(o.get("health", 0))
		_log.clear()
	var role := str(world.engine_calling_view().get("role", ""))
	var key := JSON.stringify(o) + role + JSON.stringify(_log) + str(_entered_health)
	if key == _key:
		return
	_key = key
	_build(o, role)


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _build(o: Dictionary, role: String) -> void:
	var health := int(o.get("health", 0))
	var color := BioOrganRules.health_color(health)
	_clear(_organ_box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := BioUi.label(str(o.get("name", "")).to_upper(), 13, BioUi.ACCENT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(BioUi.label("%d%%" % health, 14, color))
	_organ_box.add_child(head)
	_organ_box.add_child(BioUi.gauge(health / 100.0, color, 7.0))
	_organ_box.add_child(BioUi.label("Saúde %s · %s desde que chegou" % [BioOrganRules.health_word(health), BioOrganRules.delta_text(health, _entered_health)], 11, BioUi.MUTED))
	for m in o.get("metrics", []):
		var value := int(m.get("value", 0))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := BioUi.label(str(m.get("label", "")), 10, BioUi.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_organ_box.add_child(row)
		_organ_box.add_child(BioUi.gauge(value / 100.0, BioOrganRules.health_color(value), 4.0))
	var crisis := str(o.get("crisis", ""))
	if crisis != "":
		_organ_box.add_child(BioUi.wrapped("Crise em andamento: %s" % _crisis_title(crisis), 11, BioUi.WARN))
	_organ_box.add_child(BioUi.wrapped("Trabalhando aqui: %s" % BioOrganRules.crew_text(o.get("needs", [])), 10, BioUi.MUTED))
	_build_work(o, role)


func _crisis_title(def: String) -> String:
	if world.sync != null and world.sync.presenter != null:
		for c in world.sync.presenter.model.ordered():
			if str(c.get("def", "")) == def:
				return str(c.get("title", def))
	return def.replace("-", " ").capitalize()


func _build_work(o: Dictionary, role: String) -> void:
	_clear(_work_box)
	_work_box.add_child(BioUi.label("SUAS AÇÕES AQUI", 11, BioUi.MUTED))
	var mine := int(o.get("mine", 0))
	_work_box.add_child(BioUi.label("%d confirmadas pelo corpo neste órgão" % mine, 10, BioUi.GOOD if mine > 0 else BioUi.MUTED))
	if _log.is_empty() and (o.get("deeds", []) as Array).is_empty():
		_work_box.add_child(BioUi.wrapped("Nada ainda. Trabalhe nos adereços do órgão, derrote invasores ou leve cargas.", 10, BioUi.MUTED))
	for entry in _log:
		var text := str(entry["text"]) + ("  ×%d" % int(entry["count"]) if int(entry["count"]) > 1 else "")
		_work_box.add_child(BioUi.wrapped("· " + text, 10, BioUi.TEXT))
	var crisis_def := ""
	var crisis := str(o.get("crisis", ""))
	if crisis != "":
		crisis_def = crisis
	var can := BioOrganRules.can_do(str(o.get("id", "")), role, crisis_def != "", crisis_def)
	_work_box.add_child(BioUi.label("O QUE VOCÊ PODE FAZER", 11, BioUi.MUTED))
	if role == "":
		_work_box.add_child(BioUi.wrapped("Escolha um chamado: cada um faz um trabalho diferente neste órgão.", 10, BioUi.ACCENT))
	for line in can["mine"]:
		_work_box.add_child(BioUi.wrapped("✔ " + str(line), 10, BioUi.GOOD))
	for line in can["others"]:
		_work_box.add_child(BioUi.wrapped("✖ " + str(line), 10, BioUi.MUTED))
