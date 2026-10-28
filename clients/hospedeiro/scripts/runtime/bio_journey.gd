class_name BioJourney
extends CanvasLayer
## Presentation only: recommendations never grant progress or rewards. The first thing it points at is the crisis the body is living.
var world: BioWorld
var target := Vector2.ZERO
var has_target := false
var destination := ""
var _pinned: Dictionary = {}
var _card: Button
var _modal: BioModal
var _ink: Control
var _age := 0.0
var _local_kills := 0
var _local_food := 0
var _refresh_in := 0.0
var _pointer_until := 0
var route := BioNavigationRoute.new()
var navigation_state := "none"
var goal := Vector2.ZERO
var route_title := ""
var _source := ""
var _pin_revision := 0
var _goal_entity: Node2D
var _passages_signature := ""
var _replan_after := 0.0
var _plan_position := Vector2.ZERO
var _arrival_by_objective := false
var _arrived_until := 0.0

func _ready() -> void:
	layer = 14
	_card = BioUi.button("PRÓXIMO PASSO", "ghost")
	_card.add_theme_font_size_override("font_size", 12)
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.pressed.connect(open)
	add_child(_card)
	_modal = BioModal.new()
	_modal.max_size = Vector2(540, 440)
	add_child(_modal)
	_modal.build("GPS E OBJETIVOS")
	_modal.dismissed.connect(close)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var road_layer := CanvasLayer.new()
	road_layer.layer = 5  # road graphics remain under the HUD, controls and map
	add_child(road_layer)
	road_layer.add_child(_ink)
	_ink.draw.connect(_draw_trail)
	world.atlas.destination_chosen.connect(pin)
	world.virus_destroyed.connect(func() -> void: _local_kills += 1)
	world.nutrient_absorbed.connect(func() -> void: _local_food += 1)

func pin(at: Vector2, title: String) -> void:
	_pinned = {"at": at, "title": title}
	_pin_revision += 1
	_refresh_in = 0
	world.atlas.close()
	_sync_navigation(recommendation())

func clear_destination() -> void:
	_pinned.clear()
	route.clear()
	_source = ""
	navigation_state = "none"
	route_title = ""
	has_target = false
	_goal_entity = null
	_arrival_by_objective = false
	_refresh_in = 0

func navigation_path() -> PackedVector2Array:
	return route.path_from(world.player.global_position) if has_target else PackedVector2Array()

func has_manual_destination() -> bool:
	return not _pinned.is_empty()

func gps_label() -> String:
	if navigation_state == "arrived": return "Chegou · " + route_title
	if navigation_state == "blocked": return "Caminho bloqueado · consulte a membrana no mapa"
	if has_target: return "%s · %d u" % [route_title, ceili(route.remaining / BioArt.UNIT)]
	return ""

func recommendation() -> Dictionary:
	if not _pinned.is_empty():
		return {"title": _pinned.title, "detail": "Você chegou ao destino. As setas foram encerradas. Volte ao objetivo atual quando quiser." if navigation_state == "arrived" else "Destino marcado no atlas. Siga a rota azul no cenário, mapa ou minimapa; a marca não movimenta sua célula automaticamente.", "at": _pinned.at}
	var crisis := _crisis()
	if not crisis.is_empty() and BioConflictFocus.demanding(crisis):
		var organ := BioConflictFocus.organ(crisis)
		return {"title": "%s · %s" % [str(crisis.get("title", "")), organ], "detail": BioConflictFocus.suggestion(crisis),
			"at": BioBodyMap.center_px(StringName(str(crisis.get("region", "")))), "crisis": str(crisis.get("id", ""))}
	if not world.engine_offer.is_empty() or not world.engine_lineage_offer.is_empty():
		return {"title": "Escolha sua evolução", "detail": "Você já pode desenvolver sua célula. Abra Corpo para escolher genes ou uma classe. Faça isso em segurança, fora de combate."}
	if world.region == BioBodyMap.MEDULA:
		return {"title": "Saia da Medula → Sangue", "detail": "Seu primeiro destino é o Sangue. Siga a trilha azul pelo canal à direita. Lá, combata vírions e absorva nutrientes para abrir escolhas de evolução. A Medula continua segura para voltar e treinar.", "at": BioBodyMap.center_px(BioBodyMap.SANGUE)}
	var stats: Dictionary = world.sync.link.view.get("self", {}).get("num", {})
	var kills := int(stats.get("abates", _local_kills))
	var food := int(stats.get("nutrientes", _local_food))
	if world.region == BioBodyMap.SANGUE and (kills < 1 or food < 5):
		var next := {"title": "Derrote um vírion no Sangue" if kills < 1 else "Absorva nutrientes · %d/5" % food, "detail": "Primeiro combate: aproxime-se de um invasor marcado e use ataque ou Toxina. NPCs dourados são aliados. Depois, absorva cinco nutrientes passando sobre eles. São sugestões de exploração; as recompensas e missões aparecem em Missões." if kills < 1 else "Passe sobre os nutrientes brilhantes para absorvê-los. Eles alimentam a pressão evolutiva. Ao receber uma escolha, abra Corpo para desenvolver sua célula."}
		var nodes := world.viruses() if kills < 1 else get_tree().get_nodes_in_group("nutrients")
		var closest := INF
		for node in nodes:
			if not node is Node2D or BioBodyMap.region_of(node.global_position) != world.region: continue
			if node is BioCellActor and not node.is_active(): continue
			var distance := world.player.global_position.distance_to(node.global_position)
			if distance < closest:
				closest = distance
				next["at"] = node.global_position
				next["entity"] = node
		return next
	return {"title": "Proteja o corpo e desenvolva sua célula", "detail": "Ataque os invasores e absorva nutrientes passando sobre eles. Isso aumenta sua pressão evolutiva: acompanhe Corpo para escolher genes e classes. Leia os chamados em Missões. As crises do corpo são abertas a todos; você não precisa aceitar uma missão agora."}

## The crisis the player follows (empty when there is none or the living body is off).
func _crisis() -> Dictionary:
	if world.sync == null or world.sync.living_hud == null:
		return {}
	return world.sync.living_hud.focus_conflict()


func _regions_to(at: Vector2) -> Array[StringName]:
	var from := world.region
	var to := BioBodyMap.region_of(at)
	if from == to: return [from]
	var steps := world.exploration.open_route(from, to)
	# Offline has no passage restrictions; still follow the actual vessels.
	if steps.is_empty() and world.exploration.passages.is_empty():
		var parent := {from: &""}
		var queue: Array[StringName] = [from]
		while not queue.is_empty():
			var here: StringName = queue.pop_front()
			for next in BioAnatomy.neighbours(here):
				if not parent.has(next):
					parent[next] = here
					queue.append(next)
		if parent.has(to):
			var cur := to
			while cur != &"":
				steps.push_front(cur)
				cur = parent[cur]
	return steps

func waypoint(at: Vector2) -> Dictionary:
	var preview := BioNavigationRoute.new()
	if not preview.plan(world.seed_value, world.player.global_position, at, _regions_to(at)): return {}
	return {"at": preview.ahead(6 * BioArt.UNIT)}

func _navigation_source(next: Dictionary) -> String:
	if not _pinned.is_empty(): return "pin:%d" % _pin_revision
	if next.has("crisis"): return "crisis:" + str(next["crisis"])
	if not next.has("at"): return ""
	return "intro:blood" if world.region == BioBodyMap.MEDULA else "intro:combat" if str(next.title).begins_with("Derrote") else "intro:food"

func _sync_navigation(next: Dictionary) -> void:
	var source := _navigation_source(next)
	if not has_manual_destination() and navigation_state in ["navigating", "blocked"] and _objective_completed():
		navigation_state = "arrived"
		_arrival_by_objective = true
		_arrived_until = _age + 2.5
		has_target = false
		return
	if not has_manual_destination() and navigation_state == "arrived" and ((_age < _arrived_until and source != _source) or (_arrival_by_objective and source == _source)):
		return
	# Non-spatial notifications cannot cancel the last real destination.
	if not next.has("at"):
		if source.begins_with("crisis:") and source != _source:
			clear_destination()
			_source = source
		return
	var at: Vector2 = next.at
	if source == _source and is_instance_valid(_goal_entity) and not _goal_entity.is_queued_for_deletion() and (not _goal_entity is BioCellActor or (_goal_entity as BioCellActor).is_active()):
		at = _goal_entity.global_position
	else:
		_goal_entity = next.get("entity") as Node2D
	var changed := source != _source
	var moved := at.distance_to(goal) > 1.5 * BioArt.UNIT
	var passages := JSON.stringify(world.exploration.passages)
	var new_passages := passages != _passages_signature
	var keep_arrival := navigation_state == "arrived" and not changed and not moved
	var off_route := not route.points.is_empty() and route.deviation > 6 * BioArt.UNIT
	if changed or new_passages or ((moved or off_route or (navigation_state == "blocked" and world.player.global_position.distance_to(_plan_position) > 3 * BioArt.UNIT)) and _age >= _replan_after):
		if changed: _arrival_by_objective = false
		goal = at
		_source = source
		route_title = str(_pinned.get("title", next.title))
		_passages_signature = passages
		_plan_position = world.player.global_position
		_replan_after = _age + 0.75
		navigation_state = "navigating" if route.plan(world.seed_value, world.player.global_position, goal, _regions_to(goal)) else "blocked"
		if keep_arrival and navigation_state == "navigating": navigation_state = "arrived"
	_update_position()

func _objective_completed() -> bool:
	var stats: Dictionary = world.sync.link.view.get("self", {}).get("num", {})
	match _source:
		"intro:blood": return world.region == BioBodyMap.SANGUE
		"intro:combat": return int(stats.get("abates", _local_kills)) > 0
		"intro:food": return int(stats.get("nutrientes", _local_food)) >= 5
	if _source.begins_with("crisis:"):  # the crisis stopped asking for attention: contained, recovering or over
		var c := _crisis()
		return c.is_empty() or str(c.get("id", "")) != _source.trim_prefix("crisis:") or not BioConflictFocus.demanding(c)
	return false

func _update_position() -> void:
	if not has_manual_destination() and navigation_state == "navigating" and _objective_completed():
		navigation_state = "arrived"
		_arrival_by_objective = true
		_arrived_until = _age + 2.5
	if not route.points.is_empty():
		route.follow(world.player.global_position)
		if world.player.global_position.distance_to(goal) < 1.5 * BioArt.UNIT and route.remaining < 2 * BioArt.UNIT:
			if navigation_state != "arrived": _arrived_until = _age + 2.5
			navigation_state = "arrived"
		elif navigation_state == "arrived" and not _arrival_by_objective and world.player.global_position.distance_to(goal) > 2.5 * BioArt.UNIT:
			navigation_state = "navigating"
	has_target = navigation_state == "navigating" and not route.points.is_empty()
	if has_target: target = route.projection if route.deviation > 2 * BioArt.UNIT else route.ahead(6 * BioArt.UNIT)

func _process(delta: float) -> void:
	_age += delta
	var available := world.tutorial != null and ((world.tutorial.completed and not world.tutorial.active) or has_manual_destination()) and world.player.is_active()
	_card.visible = available and not BioUi.captures_input()
	_ink.visible = available and not BioUi.captures_input()
	if not available:
		has_target = false
		_refresh_in = 0
		return
	_ink.queue_redraw()
	_update_position()  # arrival is evaluated every frame, independently of route recalculation
	_refresh_in -= delta
	if delta > 0 and _refresh_in > 0: return
	_refresh_in = 0.2
	var next := recommendation()
	_sync_navigation(next)
	destination = route_title if navigation_state != "none" else str(next.title)
	_card.text = "CHEGOU\n" + route_title if navigation_state == "arrived" else "GPS · caminho bloqueado\nToque para ver os requisitos" if navigation_state == "blocked" else "GPS · %d u\n%s" % [ceili(route.remaining / BioArt.UNIT), route_title] if has_target else "PRÓXIMO PASSO\n" + str(next.title)
	if not BioPlatform.is_touch(): _card.text = _card.text.replace("toque", "clique")
	var view := get_viewport().get_visible_rect().size
	_card.size = Vector2(minf(270, view.x - 32), 48)
	_card.position = Vector2((view.x - _card.size.x) * 0.5, 58 if view.x > view.y else 106)
	if BioPlatform.is_touch():
		_card.size = Vector2(minf(248, maxf(170, view.x - 380)), 52)
		_card.position = Vector2(view.x - _card.size.x - 24, 78) if view.x >= 600 else Vector2((view.x - _card.size.x) * 0.5, 128)
	_ink.queue_redraw()

func open() -> void:
	for child in _modal.content.get_children():
		_modal.content.remove_child(child)
		child.queue_free()
	var next := recommendation()
	if navigation_state != "none":
		_modal.content.add_child(BioUi.wrapped("GPS · " + gps_label(), 14, BioUi.ACCENT))
	_modal.content.add_child(BioUi.wrapped(str(next.title), 16, BioUi.ACCENT))
	_modal.content.add_child(BioUi.wrapped(str(next.detail), 13))
	if next.has("at") and waypoint(next.at).is_empty():
		_modal.content.add_child(BioUi.wrapped("O caminho ainda está bloqueado. Aproxime-se da membrana no vaso para consultar a adaptação necessária.", 12, BioUi.WARN))
	for item in [["Ver as crises do corpo", func() -> void: close(); if world.sync.living_hud != null: world.sync.living_hud.toggle_panel()], ["Ver caminho no mapa", func() -> void: close(); world.atlas.toggle()], ["Genes, classe e habilidades", func() -> void: close(); world.body_panel.toggle()]]:
		var button := BioUi.button(item[0])
		button.pressed.connect(item[1])
		_modal.content.add_child(button)
	if not _pinned.is_empty():
		var cancel := BioUi.button("Voltar ao objetivo atual" if navigation_state == "arrived" else "Cancelar destino marcado")
		cancel.pressed.connect(func() -> void: clear_destination(); close())
		_modal.content.add_child(cancel)
	_modal.present(self)

func close() -> void:
	_modal.hide_modal()
	_pointer_until = Time.get_ticks_msec() + 180

func blocks_pointer() -> bool:
	return Time.get_ticks_msec() < _pointer_until or (_card.visible and _card.get_global_rect().has_point(_card.get_global_mouse_position()))

func _draw_trail() -> void:
	if not has_target: return
	var transform := world.get_global_transform_with_canvas()
	var screen := PackedVector2Array()
	var total := 0.0
	for point in navigation_path():
		var at := transform * point
		if not screen.is_empty(): total += screen[-1].distance_to(at)
		screen.append(at)
		if total > 650: break
	if screen.size() < 2: return
	_ink.draw_polyline(screen, Color(0.01, 0.06, 0.1, 0.8), 7, true)
	_ink.draw_polyline(screen, Color(0.3, 0.95, 1, 0.65), 2, true)
	var along := 0.0
	var next_arrow := 38.0
	for i in range(1, screen.size()):
		var start := screen[i - 1]
		var direction := start.direction_to(screen[i])
		var length := start.distance_to(screen[i])
		while next_arrow <= along + length and next_arrow < 600:
			var at := start + direction * (next_arrow - along)
			_ink.draw_polyline(PackedVector2Array([at - direction * 7 + direction.orthogonal() * 5, at, at - direction * 7 - direction.orthogonal() * 5]), Color(0.55, 1, 1, 0.95), 2.5, true)
			next_arrow += 48
		along += length
