class_name BioJourney
extends CanvasLayer
## Presentation only: recommendations never grant quests, progress or rewards.
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
	_modal.build("SEU PRÓXIMO PASSO")
	_modal.dismissed.connect(close)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	_ink.draw.connect(_draw_trail)
	world.atlas.destination_chosen.connect(pin)
	world.virus_destroyed.connect(func() -> void: _local_kills += 1)
	world.nutrient_absorbed.connect(func() -> void: _local_food += 1)

func pin(at: Vector2, title: String) -> void:
	_pinned = {"at": at, "title": title}
	world.atlas.close()

func recommendation() -> Dictionary:
	if not _pinned.is_empty():
		return {"title": _pinned.title, "detail": "Destino marcado no atlas. Siga a trilha azul; a marca não movimenta sua célula automaticamente.", "at": _pinned.at}
	var system := world.sync.system
	if not system._active.is_empty():
		var q := system._active
		var result := {"title": str(q.get("title", "Missão ativa")), "detail": str(q.get("objective", q.get("desc", "")))}
		# Explicit locations for the opening missions; unknown missions retain their real objective.
		match str(q.get("def", "")):
			"primeiro-mergulho":
				result["at"] = BioBodyMap.center_px(BioBodyMap.SANGUE)
				result["detail"] += " Saia pelo canal à direita da Medula: a sinusoide é o vaso que liga o refúgio ao Sangue. Siga a trilha azul."
			"vigilia", "caca-no-capilar":
				result["at"] = BioBodyMap.center_px(BioBodyMap.SANGUE)
				if world.region == BioBodyMap.SANGUE:
					var closest := INF
					for enemy in world.viruses():
						if not enemy.is_active() or BioBodyMap.region_of(enemy.global_position) != world.region: continue
						var distance := world.player.global_position.distance_to(enemy.global_position)
						if distance < closest:
							closest = distance
							result["at"] = enemy.global_position
			"investigar-inflamacao": result["at"] = BioBodyMap.spot_px("capilar")
		return result
	if system.has_offer():
		return {"title": "Responda ao chamado", "detail": "Há uma missão disponível: %s. Abra Missões para ler o objetivo e aceitar o chamado." % str(system._offer.get("title", "Novo chamado"))}
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
		return next
	return {"title": "Proteja o corpo e desenvolva sua célula", "detail": "Ataque os invasores e absorva nutrientes passando sobre eles. Isso aumenta sua pressão evolutiva: acompanhe Corpo para escolher genes e classes. Leia os chamados em Missões. As masmorras são desafios opcionais; você não precisa entrar nelas agora."}

func waypoint(at: Vector2) -> Dictionary:
	var from := world.region
	var to := BioBodyMap.region_of(at)
	if from == to: return {"at": at}
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
	if steps.size() < 2: return {}
	var route := BioAnatomy.route(world.seed_value, steps[0], steps[1])
	var nearest := 0
	for i in route.size():
		if world.player.global_position.distance_to(route[i] * BioArt.UNIT) < world.player.global_position.distance_to(route[nearest] * BioArt.UNIT): nearest = i
	return {"at": route[mini(nearest + 1, route.size() - 1)] * BioArt.UNIT}

func _process(delta: float) -> void:
	_age += delta
	var available := world.tutorial != null and world.tutorial.completed and not world.tutorial.active and world.player.is_active() and not world.dungeon.active
	_card.visible = available and not BioUi.captures_input()
	_ink.visible = _card.visible
	if not available or not _card.visible:
		has_target = false
		_refresh_in = 0
		return
	_ink.queue_redraw()
	_refresh_in -= delta
	if delta > 0 and _refresh_in > 0: return
	_refresh_in = 0.2
	has_target = false
	if not _pinned.is_empty() and world.player.global_position.distance_to(_pinned.at) < 2.5 * BioArt.UNIT:
		_pinned.clear()
	var next := recommendation()
	_card.text = "PRÓXIMO PASSO · toque para ver\n" + str(next.title)
	if not BioPlatform.is_touch(): _card.text = _card.text.replace("toque", "clique")
	var view := get_viewport().get_visible_rect().size
	_card.size = Vector2(minf(270, view.x - 32), 48)
	_card.position = Vector2((view.x - _card.size.x) * 0.5, 58 if view.x > view.y else 106)
	destination = str(next.title)
	if next.has("at"):
		var point := waypoint(next.at)
		if not point.is_empty():
			target = point.at
			has_target = _card.visible
	_ink.queue_redraw()

func open() -> void:
	for child in _modal.content.get_children():
		_modal.content.remove_child(child)
		child.queue_free()
	var next := recommendation()
	_modal.content.add_child(BioUi.wrapped(str(next.title), 16, BioUi.ACCENT))
	_modal.content.add_child(BioUi.wrapped(str(next.detail), 13))
	if next.has("at") and waypoint(next.at).is_empty():
		_modal.content.add_child(BioUi.wrapped("O caminho ainda está bloqueado. Aproxime-se da membrana no vaso para consultar a adaptação necessária.", 12, BioUi.WARN))
	for item in [["Ver missão / chamado", func() -> void: close(); world.sync.system.open_missions()], ["Ver caminho no mapa", func() -> void: close(); world.atlas.toggle()], ["Genes, classe e habilidades", func() -> void: close(); world.body_panel.toggle()]]:
		var button := BioUi.button(item[0])
		button.pressed.connect(item[1])
		_modal.content.add_child(button)
	if not _pinned.is_empty():
		var cancel := BioUi.button("Limpar destino marcado")
		cancel.pressed.connect(func() -> void: _pinned.clear(); close())
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
	var origin := transform * world.player.global_position
	var end := transform * target
	var direction := origin.direction_to(end)
	var length := minf(origin.distance_to(end), 150)
	for i in 5:
		var distance := fmod(_age * 30 + i * 28, 140.0) + 24
		if distance > length: continue
		var at := origin + direction * distance
		_ink.draw_polyline(PackedVector2Array([at - direction * 6 + direction.orthogonal() * 5, at, at - direction * 6 - direction.orthogonal() * 5]), Color(0.35, 0.95, 1, 0.7), 2, true)
