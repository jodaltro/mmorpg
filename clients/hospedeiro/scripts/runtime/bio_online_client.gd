class_name BioOnlineClient
extends Node
## Presentation of the shared server world. Replicas never run combat, collection or enemy AI.

var world: BioWorld
var transport: BioNakama
var is_ready := false
var _identity: Dictionary
var _entities: Dictionary = {}
var _targets: Dictionary = {}
var _actions: Array[String] = []
var _seq := 0
var _last_snapshot := -1
var _send_in := 0.0
var _last_received := 0
var _layer: CanvasLayer
var _menu: Control
var _status: Label
var _field: LineEdit
var _button: Button
var _retrying := false
var _snapshot_ready := false
var prediction := BioNetPrediction.new()
var _motion: Dictionary = {}
var _metadata: Dictionary = {}
var authoritative_position := Vector2.ZERO
const IDENTITY_PATH := "user://hospedeiro_guest.json"


static func wanted(engine: String) -> bool:
	if engine.is_empty(): return false
	if BioPlatform.is_web(): return BioPlatform.query_param("multiplayer") != "off"
	return DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--online")


func _ready() -> void:
	_identity = BioNakama.guest_identity(IDENTITY_PATH)
	transport = BioNakama.new()
	transport.coalesce_snapshots = true
	transport.base_url = BioPlatform.query_param("nakama")
	if transport.base_url.is_empty():
		transport.base_url = world.engine_url + "/nakama" if BioPlatform.is_web() else "http://127.0.0.1:7350"
	add_child(transport)
	world.sync.link.nakama = transport
	world.sync.link.identity_path = ""  # Nakama owns identity; don't overwrite the old offline save.
	world.sync.link.view_changed.connect(func(_view: Dictionary) -> void: _unlock())
	transport.packet.connect(_packet)
	transport.disconnected.connect(_disconnected)
	transport.failed.connect(func(message: String) -> void: _status.text = message if _status != null else "")
	var controller := world.player.get_node("Controller") as BioCellController
	controller.network_attack = queue_action
	controller.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.combatant.set_process(false)
	world.debug_menu.process_mode = Node.PROCESS_MODE_DISABLED
	world.design_debug.process_mode = Node.PROCESS_MODE_DISABLED
	world.abilities.network_cast = func(id: StringName) -> int: return queue_action("ability:" + str(id))
	for kit in world.abilities._kits:
		kit.process_mode = Node.PROCESS_MODE_DISABLED
	for group in ["viruses", "nutrients", "motes", "toxins"]:
		for n in get_tree().get_nodes_in_group(group): n.queue_free()
	_join_ui()
	var name := str(_identity.get("name", ""))
	if BioPlatform.is_web():
		var entered: Variant = JavaScriptBridge.eval("window.__hospedeiroGuestName || ''", true)
		if entered != null and not str(entered).strip_edges().is_empty(): name = str(entered)
	if not name.is_empty():
		_field.text = name
		_connect()


func _join_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0.005, 0.015, 0.04, 0.96)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "HOSPEDEIRO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_field = LineEdit.new()
	_field.placeholder_text = "Como sua célula se chama?"
	_field.max_length = 24
	_field.custom_minimum_size.y = 42
	column.add_child(_field)
	_button = Button.new()
	_button.text = "Entrar no corpo"
	_button.custom_minimum_size.y = 42
	_button.pressed.connect(_connect)
	column.add_child(_button)
	_field.text_submitted.connect(func(_text: String) -> void: _connect())
	_status = Label.new()
	_status.text = "Escolha um nome para jogar."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 280
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	BioUi.set_modal(_menu, true)


func _connect() -> void:
	var player_name := _field.text.strip_edges()
	if player_name.length() < 2:
		_status.text = "Use um nome com pelo menos 2 caracteres."
		return
	_button.disabled = true
	_status.text = "Entrando no corpo…"
	_identity["name"] = player_name
	var f := FileAccess.open(IDENTITY_PATH, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(_identity))
	var ok := await transport.open(player_name, str(_identity.device))
	_button.disabled = false
	if not ok:
		_status.text = "O mundo está indisponível. Toque para tentar novamente."


func queue_action(action: String) -> int:
	if is_ready and not _actions.has(action) and _actions.size() < 4:
		if world.evolution_presentation != null: world.evolution_presentation.note_combat()
		_actions.append(action)
	return BioActor.AttackStatus.STARTED


func _process(delta: float) -> void:
	for id in _targets:
		if is_instance_valid(_entities.get(id)):
			var n := _entities[id] as Node2D
			if n == world.player: continue
			var target: Vector2 = _targets[id]
			n.global_position = n.global_position.lerp(target, 1.0 - exp(-22.0 * delta)) if n.global_position.distance_to(target) < 12.0*BioArt.UNIT else target
	if is_ready and Time.get_ticks_msec() - _last_received > 5000:
		_disconnected()
		transport.close()
	_send_in -= delta
	if _send_in <= 0.0 and transport.connected:
		_send_in = 1.0/30.0
		_seq += 1
		var controller := world.player.get_node("Controller") as BioCellController
		transport.send_data(1, {"seq": _seq, "compact":1, "move": BioNetProtocol.xy(world.player.intent), "aim": BioNetProtocol.xy(controller.aim), "actions": _actions})
		_actions = []


func _physics_process(delta: float) -> void:
	if not is_ready or not world.player.is_active() or not _motion.has("speed"): return
	var cell := world.player
	var dt := minf(delta, 0.05)
	prediction.remember(_seq+1, dt, cell.intent)
	cell.velocity = BioNetPrediction.velocity(cell.velocity, cell.intent, dt, _motion)
	cell.collision_layer = 0
	cell.collision_mask = BioCellActor.LAYER_WALL
	cell.move_and_slide()


func _reconcile(data: Dictionary, ack: int) -> void:
	var cell := world.player
	var pos: Array = data.get("p", [0,0])
	var authoritative := Vector2(float(pos[0]),float(pos[1]))
	authoritative_position = authoritative
	var v: Array = data.get("v", [0,0])
	var velocity := Vector2(float(v[0]),float(v[1]))
	var previous := cell.global_position
	prediction.acknowledge(ack)
	var teleport := ack < 0 or not is_ready or previous.distance_to(authoritative) > 12.0*BioArt.UNIT or float(data.get("hp",0)) <= 0
	if teleport: prediction.clear()
	cell.collision_layer = 0
	cell.collision_mask = BioCellActor.LAYER_WALL
	cell.global_position = authoritative
	for frame in prediction.frames:
		velocity = BioNetPrediction.velocity(velocity,frame.intent,float(frame.dt),_motion)
		cell.move_and_collide(velocity*float(frame.dt))
	var reconciled := cell.global_position
	if not teleport:
		cell.global_position = previous
		cell.move_and_collide((reconciled-previous)*0.35)
	cell.velocity = velocity


func _disconnected() -> void:
	is_ready = false
	_snapshot_ready = false
	prediction.clear()
	_metadata.clear()
	_last_snapshot = -1
	world.player.set_intent(Vector2.ZERO)
	world.sync.link._set_online(false)
	_menu.show()
	BioUi.set_modal(_menu, true)
	_status.text = "Conexão interrompida. Reconectando…"
	if _retrying: return
	_retrying = true
	while is_inside_tree() and not is_ready:
		await get_tree().create_timer(3.0).timeout
		if not transport.connected: await _connect()
	_retrying = false


func _packet(code: int, body: Dictionary) -> void:
	if code != 2 or int(body.get("version", 0)) != 1: return
	var seq := int(body.get("seq", -1))
	if seq <= _last_snapshot: return
	_last_snapshot = seq
	_last_received = Time.get_ticks_msec()
	var ack := int(body.get("ack", -1))
	transport.stats.acknowledge(ack, _last_received)
	_motion = body.get("motion", {})
	world.sync.link.reset_allowed = bool(body.get("reset_allowed", false))
	world.hud.set_restart_allowed(world.sync.link.reset_allowed)
	var wanted := {}
	for received in body.get("entities", []):
		var data: Dictionary = received
		var id := str(data.get("id", ""))
		var cached: Dictionary = _metadata.get(id, {})
		cached.merge(data, true)
		_metadata[id] = cached
		data = cached
		wanted[id] = true
		var mine: bool = str(data.get("uid", "")) == transport.user_id
		if not is_instance_valid(_entities.get(id)):
			_entities[id] = world.player if mine else _spawn(data)
		var n := _entities[id] as Node2D
		if n == null: continue
		var pos: Array = data.get("p", [0,0])
		_targets[id] = Vector2(float(pos[0]), float(pos[1]))
		if n is BioCellActor:
			_apply_actor(n as BioCellActor, data)
			if mine: _reconcile(data, ack)
			if mine and not is_ready:
				n.global_position = _targets[id]
				_snapshot_ready = true
				_unlock()
		elif n is BioSignature:
			(n as BioSignature)._age = float(data.get("age", 0))
		elif n is BioAbilityZone:
			(n as BioAbilityZone)._age = float(data.get("age", 0))
			n.queue_redraw()
		elif n is BioMine:
			(n as BioMine)._age = float(data.get("age", 0))
			n.queue_redraw()
	for id in _entities.keys():
		if not wanted.has(id):
			if is_instance_valid(_entities[id]) and _entities[id] != world.player: (_entities[id] as Node).queue_free()
			_entities.erase(id)
			_targets.erase(id)
			_metadata.erase(id)
	var now := BioClock.now()
	for key in body.get("cooldowns", {}):
		world.player.combatant.actor._ready_at[StringName(key)] = now + float(body.cooldowns[key])
	for event in body.get("events", []):
		for id in _entities:
			if not is_instance_valid(_entities[id]): continue
			var n := _entities[id] as BioCellActor
			if n != null and str(n.get_meta("net_uid", "")) == str(event.get("id", "")):
				var aim: Array = event.get("aim", [1,0])
				for child in n.get_children():
					if child is BioAttackExecutor and event.has("attack"):
						(child as BioAttackExecutor).performed.emit(StringName(str(event.get("attack", ""))), Vector2(float(aim[0]), float(aim[1])))
					elif child is BioAbilityRunner and event.has("ability"):
						(child as BioAbilityRunner).last_cast = StringName(str(event.ability))
						(child as BioAbilityRunner).performed.emit(StringName(str(event.ability)))
				BioFx.burst(n.global_position, BioArt.CYAN, 4, 1.4, 0.15, 0.25)


func _unlock() -> void:
	if is_ready or not _snapshot_ready or not world.sync.link.online: return
	is_ready = true
	_menu.hide()
	BioUi.set_modal(_menu, false)
	if BioPlatform.is_web(): JavaScriptBridge.eval("window.__hospedeiroReady=true", true)


func _spawn(data: Dictionary) -> Node2D:
	var kind := str(data.get("kind", ""))
	var pos: Array = data.get("p", [0,0])
	var at := Vector2(float(pos[0]), float(pos[1]))
	if kind == "signature":
		var decoded: Variant = BioNetProtocol.visual(data.get("data", {}), true)
		return BioSignature.play(StringName(str(data.get("type", ""))), at, Color(str(data.get("color", "ffffff"))), float(data.get("duration", 1)), decoded if decoded is Dictionary else {})
	if kind == "zone":
		var z := BioAbilityZone.new()
		z.position = at
		z.color = Color(str(data.get("color", "ffffff")))
		z.radius_px = float(data.get("radius", 100))
		z.duration = float(data.get("duration", 4))
		world.add_child(z)
		z.set_process(false)
		return z
	if kind == "mine":
		var m := BioMine.new()
		m.position = at
		m.color = Color(str(data.get("color", "ffffff")))
		m.radius_px = float(data.get("radius", 70))
		world.add_child(m)
		m.set_process(false)
		return m
	if kind == "player" or kind == "enemy":
		var cell: BioCellActor
		if kind == "player":
			cell = BioFactory.spawn_player(world, at)
			var label := Label.new()
			label.text = str(data.get("name", "Célula"))
			label.position = Vector2(-70, -48)
			label.size.x = 140
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 12)
			cell.add_child(label)
		else:
			var enemy_kind := StringName(str(data.get("enemy_kind", "virion")))
			if enemy_kind == &"virion":
				cell = BioFactory.spawn_virus(world, at, world.player).get_parent() as BioCellActor
			else:
				cell = BioFactory.spawn_enemy(world, at, world.player, BioDungeonPlan.enemy(enemy_kind), 1.0, "viruses").get_parent() as BioCellActor
		cell.set_meta("net_uid", str(data.get("uid", "")))
		cell.set_physics_process(false)
		cell.collision_layer = 0
		cell.collision_mask = 0
		cell.combatant.set_process(false)
		for child in cell.get_children():
			if child is BioPlayerInput or child is BioVirusBrain or child is BioRangedBrain or child is BioNestBrain or child is BioCellController or child is BioAttackExecutor or child is BioAbilityRunner:
				child.process_mode = Node.PROCESS_MODE_DISABLED
		return cell
	var n := Node2D.new()
	n.position = at
	var color := Color(str(data.color)) if data.has("color") else BioArt.TOXIN if kind == "projectile" or kind == "toxin" else BioNutrient.color_of(int(data.get("type", 0))) if kind == "nutrient" else BioArt.JADE
	n.add_child(BioArt.make_glow(color, 0.8, 0))
	world.add_child(n)
	return n


func _apply_actor(cell: BioCellActor, data: Dictionary) -> void:
	var v := cell.combatant.actor.vitals
	v.max_membrane = float(data.get("max_hp", 100))
	v.max_atp = float(data.get("max_atp", 100))
	var next_hp := float(data.get("hp", 0))
	if cell == world.player and next_hp < v.membrane and world.evolution_presentation != null:
		world.evolution_presentation.note_combat()
	v.membrane = next_hp
	v.atp = float(data.get("atp", 0))
	if data.get("combat_visual") is Array:
		for child in cell.get_children():
			if child is BioCellBody: (child as BioCellBody).apply_combat_visual(data.combat_visual)
	var alive := v.membrane > 0
	if cell == world.player and cell.is_active() and not alive: world._on_player_died(cell.combatant)
	elif cell.is_active() != alive: cell.set_active(alive)
	cell.set_physics_process(false)
	cell.collision_layer = 0
	cell.collision_mask = BioCellActor.LAYER_WALL if cell == world.player else 0
	var vel: Array = data.get("v", [0,0])
	if cell != world.player: cell.velocity = Vector2(float(vel[0]), float(vel[1]))
	cell.set_meta("net_uid", str(data.get("uid", "")))
	if cell != world.player:
		var lineage := StringName(str(data.get("lineage", "")))
		var genes: Array[StringName] = []
		for g in data.get("genes", []): genes.append(StringName(str(g)))
		if cell.combatant.genome.lineage != lineage or cell.combatant.genome.equipped != genes:
			cell.combatant.genome.lineage = lineage
			cell.combatant.genome.equipped = genes
			cell.combatant.genome_changed.emit(cell.combatant.genome)
		var raw_traits: Variant = data.get("traits", {})
		if raw_traits is Dictionary:
			for child in cell.get_children():
				if child is BioCellBody and (child as BioCellBody).traits != raw_traits:
					(child as BioCellBody).set_traits(raw_traits)
		var axes: Variant = data.get("axes", {})
		if axes is Dictionary and not axes.is_empty():
			for child in cell.get_children():
				if child is BioCellBody: (child as BioCellBody).set_look(axes)
