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
var _tokens: Array[int] = []
var _frames_to_send: Array[Dictionary] = []
var _sent_frames: Dictionary = {}
var _resend_cursor := 0
var _missing_inputs: Array = []
var actions := BioNetActions.new()
var preview: BioNetPreview
var _dash_for_frame := Vector2.ZERO
var _dash_distance := 0.0
var _visual_offset := Vector2.ZERO
var _tracks: Dictionary = {}
var _remote_time := 0.0
var _server_time := 0.0
var _server_arrival := 0.0
var _has_started := false
var reconnecting := false
var _last_realm := ""
var _repress_until: Dictionary = {}
var _confirmed_atp := 0.0
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
	if not is_ready and not _has_started: return BioActor.AttackStatus.DEAD
	if action == "respawn":
		if is_ready and not _actions.has(action):
			_actions.append(action)
			_tokens.append(0)
		return BioActor.AttackStatus.STARTED
	if _actions.size() >= 4: return BioActor.AttackStatus.ON_COOLDOWN
	var id := BioAttackCatalog.FLAGELLUM_LASH if action == "lash" else BioAttackCatalog.TOXIN_SPIT if action == "spit" else BioAttackCatalog.MEMBRANE_DASH if action == "dash" else StringName(action.trim_prefix("ability:"))
	if action.begins_with("ability:") and not world.abilities.knows(id): return BioAbilityRunner.UNKNOWN
	if bool(_motion.get("stunned", false)): return BioActor.AttackStatus.ON_COOLDOWN
	var now := BioClock.now()
	var repress := float(_repress_until.get(id, 0)) > now
	var token := actions.reserve(world.player.combatant.actor, id, now, repress)
	if token <= 0: return -token
	if repress:
		_repress_until.erase(id)
	elif action.begins_with("ability:"):
		var ability := BioAbilityCatalog.get_ability(id)
		if str(ability.get("kind", "")) in ["overload", "recall"]:
			_repress_until[id] = now + float(ability.get("max_time", ability.get("delay", 0)))
	var controller := world.player.get_node("Controller") as BioCellController
	var aim := controller.aim
	if action == "dash":
		aim = world.player.intent.normalized() if world.player.intent.length_squared() > 0.04 else aim
		_dash_for_frame = aim
		_dash_distance = world.player.combatant.actor.attack_def(id).range_units
		BioNetPrediction.begin_dash(_motion, aim, _dash_distance)
	if preview == null:
		preview = BioNetPreview.new()
		preview.world = world
		world.add_child(preview)
	preview.play(id, aim, token)
	for child in world.player.get_children():
		if child is BioAttackExecutor and not action.begins_with("ability:"):
			child.visual_performed.emit(id, aim)
	if world.evolution_presentation != null: world.evolution_presentation.note_combat()
	if is_ready:
		_actions.append(action)
		_tokens.append(token)
		_send_in = minf(_send_in, 0)  # flush without losing the send clock's accumulated time
	return BioActor.AttackStatus.STARTED


func _process(delta: float) -> void:
	_visual_offset *= exp(-16 * delta)
	if _visual_offset.length_squared() < 0.01: _visual_offset = Vector2.ZERO
	world.camera.network_offset = _visual_offset
	for child in world.player.get_children():
		if child is Node2D and not child is CollisionShape2D: child.position = _visual_offset
	var desired_time := _server_time + (Time.get_ticks_msec()/1000.0 - _server_arrival) - clampf(0.06 + transport.stats.jitter_ms/1000.0 * 1.5, 0.06, 0.16)
	_remote_time = maxf(_remote_time, desired_time)
	for id in _targets:
		if is_instance_valid(_entities.get(id)):
			var n := _entities[id] as Node2D
			if n == world.player: continue
			if _tracks.has(id): n.global_position = (_tracks[id] as BioNetInterpolation).sample(_remote_time)
	if is_ready and Time.get_ticks_msec() - _last_received > 5000:
		_disconnected()
		transport.close()
	_send_in -= delta
	var sends := 0
	while _send_in <= 0.0 and transport.connected and not _frames_to_send.is_empty() and sends < 3:
		sends += 1
		_send_in = maxf(_send_in + 1.0/30.0, -0.1)
		var batch := _frames_to_send.slice(0, 4 if _frames_to_send.size() > 4 else 2)
		_frames_to_send = _frames_to_send.slice(batch.size())
		var latest := int(batch.back().seq)
		for frame in batch: _sent_frames[int(frame.seq)] = frame
		while _sent_frames.size() > 300: _sent_frames.erase(_sent_frames.keys()[0])
		var keys := _sent_frames.keys()
		if not _missing_inputs.is_empty(): keys = _missing_inputs.filter(func(seq: Variant) -> bool: return _sent_frames.has(int(seq)))
		for i in mini(4 - batch.size(), keys.size()):
			_resend_cursor %= keys.size()
			var frame: Dictionary = _sent_frames[int(keys[_resend_cursor])]
			_resend_cursor += 1
			if not batch.any(func(held: Dictionary) -> bool: return int(held.seq) == int(frame.seq)): batch.append(frame)
		batch.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))
		transport.send_data(1, {"seq":latest,"compact":1,"result_ack":actions.result_ack,"frames":batch})


func _physics_process(delta: float) -> void:
	if (not is_ready and not _has_started) or not _motion.has("speed"): return
	var cell := world.player
	var dt := BioNetInputBuffer.STEP
	if _dash_for_frame != Vector2.ZERO: BioNetPrediction.begin_dash(_motion, _dash_for_frame, _dash_distance)
	if is_ready:
		_seq += 1
		var controller := cell.get_node("Controller") as BioCellController
		_frames_to_send.append({"seq":_seq,"view_time":_remote_time,"move":BioNetProtocol.xy(cell.intent),"aim":BioNetProtocol.xy(controller.aim),"actions":_actions.duplicate(),"tokens":_tokens.duplicate()})
		actions.bind_frame(_tokens, _seq)
		prediction.remember(_seq, dt, cell.intent, _dash_for_frame, _dash_distance)
		_actions.clear()
		_tokens.clear()
		while _frames_to_send.size() > 90: _frames_to_send.pop_front()
	_dash_for_frame = Vector2.ZERO
	if not cell.is_active(): return
	cell.combatant.actor.vitals.tick(delta)
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
	var realm := str(data.get("realm", ""))
	var teleport := not is_ready or (_last_realm != "" and realm != _last_realm) or previous.distance_to(authoritative) > 12.0*BioArt.UNIT or float(data.get("hp",0)) <= 0
	_last_realm = realm
	if teleport: prediction.clear()
	cell.collision_layer = 0
	cell.collision_mask = BioCellActor.LAYER_WALL
	cell.global_position = authoritative
	for frame in prediction.frames:
		if (frame.dash as Vector2) != Vector2.ZERO: BioNetPrediction.begin_dash(_motion, frame.dash, float(frame.distance))
		velocity = BioNetPrediction.velocity(velocity,frame.intent,float(frame.dt),_motion)
		cell.move_and_collide(velocity*float(frame.dt))
	var reconciled := cell.global_position
	_visual_offset = Vector2.ZERO if teleport else (_visual_offset + previous - reconciled).limit_length(4 * BioArt.UNIT)
	cell.velocity = velocity


func _disconnected() -> void:
	is_ready = false
	reconnecting = true
	_snapshot_ready = false
	prediction.clear()
	_metadata.clear()
	_tracks.clear()
	_remote_time = 0
	_frames_to_send.clear()
	_sent_frames.clear()
	_missing_inputs.clear()
	_seq = 0
	_actions.clear()
	_tokens.clear()
	actions.clear()
	_repress_until.clear()
	_last_snapshot = -1
	world.sync.link._set_online(false)
	if not _has_started:
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
	actions.acknowledge(ack)
	var missing: Variant = body.get("missing_inputs", [])
	_missing_inputs = missing.filter(func(value: Variant) -> bool: return (value is int or value is float) and int(value) > ack) if missing is Array else []
	for frame in _sent_frames.keys():
		if int(frame) <= ack: _sent_frames.erase(frame)
	_server_time = float(body.get("time", float(seq) * 0.05))
	_server_arrival = _last_received / 1000.0
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
		if not mine:
			if not _tracks.has(id): _tracks[id] = BioNetInterpolation.new()
			var velocity: Array = data.get("v", [0, 0])
			(_tracks[id] as BioNetInterpolation).push(_server_time, _targets[id], Vector2(float(velocity[0]), float(velocity[1])))
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
			_tracks.erase(id)
	var now := BioClock.now()
	var round_trip := maxf(0, float(transport.stats.current_ms(_last_received))) / 1000.0
	actions.apply_cooldowns(world.player.combatant.actor, body.get("cooldowns", {}), now, round_trip)
	var results: Variant = body.get("results", [])
	for token in actions.resolve_results(world.player.combatant.actor, results if results is Array else [], now, _server_time, round_trip):
		if preview != null: preview.cancel(token)
	for event in body.get("events", []):
		for id in _entities:
			if not is_instance_valid(_entities[id]): continue
			var n := _entities[id] as BioCellActor
			if n != null and str(n.get_meta("net_uid", "")) == str(event.get("id", "")):
				var anticipated := n == world.player and actions.shown.has(int(event.get("token", 0)))
				var aim: Array = event.get("aim", [1,0])
				for child in n.get_children():
					if child is BioAttackExecutor and event.has("attack"):
						if not anticipated: child.visual_performed.emit(StringName(str(event.attack)), Vector2(float(aim[0]),float(aim[1])))
						(child as BioAttackExecutor).performed.emit(StringName(str(event.get("attack", ""))), Vector2(float(aim[0]), float(aim[1])))
					elif child is BioAbilityRunner and event.has("ability"):
						(child as BioAbilityRunner).last_cast = StringName(str(event.ability))
						(child as BioAbilityRunner).performed.emit(StringName(str(event.ability)))
				if not anticipated: BioFx.burst(n.global_position, BioArt.CYAN, 4, 1.4, 0.15, 0.25)


func _unlock() -> void:
	if is_ready or not _snapshot_ready or not world.sync.link.online: return
	if reconnecting:
		actions.clear()  # offline previews were never submitted to this new session
		_repress_until.clear()
		_dash_for_frame = Vector2.ZERO
		world.player.combatant.actor.vitals.atp = _confirmed_atp
		if preview != null: preview.shots.clear()
	is_ready = true
	_has_started = true
	reconnecting = false
	_menu.hide()
	BioUi.set_modal(_menu, false)
	if BioPlatform.is_web(): JavaScriptBridge.eval("window.__hospedeiroReady=true", true)


func _spawn(data: Dictionary) -> Node2D:
	var kind := str(data.get("kind", ""))
	var pos: Array = data.get("p", [0,0])
	var at := Vector2(float(pos[0]), float(pos[1]))
	if kind == "projectile" and str(data.get("action_owner", "")) == transport.user_id and actions.shown.has(int(data.get("action_token", 0))):
		var placeholder := Node2D.new()
		world.add_child(placeholder)
		return placeholder  # the local projectile already draws this same shot
	if kind == "signature":
		var decoded: Variant = BioNetProtocol.visual(data.get("data", {}), true)
		return BioSignature.play(StringName(str(data.get("type", ""))), at, Color(str(data.get("color", "ffffff"))), float(data.get("duration", 1)), decoded if decoded is Dictionary else {})
	if kind == "zone":
		var z := BioAbilityZone.new()
		z.position = at
		z.color = Color(str(data.get("color", "ffffff")))
		z.style = str(data.get("style", ""))
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
	if kind == "player" or kind == "enemy" or kind == "training":
		var cell: BioCellActor
		if kind == "training":
			cell = BioFactory.spawn_training_target(world, at)
		elif kind == "player":
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
	if cell.has_meta("training"):
		(cell.combatant as BioTrainingCombatant).practice = data.get("practice", {})
	var v := cell.combatant.actor.vitals
	v.max_membrane = float(data.get("max_hp", 100))
	v.max_atp = float(data.get("max_atp", 100))
	var next_hp := float(data.get("hp", 0))
	if cell == world.player and next_hp < v.membrane and world.evolution_presentation != null:
		world.evolution_presentation.note_combat()
	v.membrane = next_hp
	v.atp = float(data.get("atp", 0))
	if cell == world.player:
		_confirmed_atp = v.atp
		v.atp = maxf(0, v.atp - actions.reserved_atp())
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
