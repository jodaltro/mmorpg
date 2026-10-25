class_name BioGameServer
extends Node
## Trusted Godot host: the existing combat rules run once for everyone. Nakama routes inputs and private snapshots.

var transport: BioNakama
var arena: BioWorld
var players: Dictionary = {}
var engine_url := "http://127.0.0.1:8096"
var adapter_key := ""
var edge_secret := ""
var _snapshot_in := 0.0
var _upkeep_in := 0.0
var _events: Array = []
var _serial := 0
var _last_reset := -10000
var _report_in := 3.0
var lag_history := BioNetLagHistory.new()


func _ready() -> void:
	adapter_key = OS.get_environment("HOSPEDEIRO_ADAPTER_KEY")
	edge_secret = OS.get_environment("HOSPEDEIRO_EDGE_SECRET")
	if not OS.get_environment("HOSPEDEIRO_ENGINE_URL").is_empty():
		engine_url = OS.get_environment("HOSPEDEIRO_ENGINE_URL")
	arena = BioWorld.new()
	arena.engine_url = ""
	arena.save_path = ""
	arena.identity_path = ""
	add_child(arena)
	arena.ensure_training_target()
	arena.set_process(false)
	arena.player.set_active(false)
	for n in arena.get_children():
		if n is CanvasLayer:
			n.process_mode = Node.PROCESS_MODE_DISABLED
	transport = BioNakama.new()
	transport.base_url = OS.get_environment("HOSPEDEIRO_NAKAMA_URL")
	if transport.base_url.is_empty():
		transport.base_url = "http://127.0.0.1:7350"
	add_child(transport)
	transport.packet.connect(_packet)
	transport.disconnected.connect(_reconnect)
	transport.failed.connect(func(message: String) -> void: print("[nakama] ", message))
	_reconnect()


func _reconnect() -> void:
	while is_inside_tree() and not transport.connected:
		if await transport.open("Hospedeiro servidor", "hosp-host-" + OS.get_environment("HOSPEDEIRO_GAME_KEY").sha256_text(), OS.get_environment("HOSPEDEIRO_GAME_KEY")):
			print("[nakama] game server ready ", transport.match_id)
			return
		await get_tree().create_timer(3.0).timeout


func _packet(code: int, data: Dictionary) -> void:
	var id := str(data.get("id", ""))
	if code == 10:
		if data.get("event") == "join":
			_join(id, str(data.get("name", "Célula")).strip_edges().left(24))
		elif data.get("event") == "leave":
			_leave(id)
	elif code == 1 and players.has(id):
		var p: Dictionary = players[id]
		var raw: Variant = data.get("input", {})
		if not raw is Dictionary: return
		if raw.get("frames") is Array:
			var result_ack: Variant = raw.get("result_ack", 0)
			if (result_ack is int or result_ack is float) and is_finite(float(result_ack)):
				p.results = (p.results as Array).filter(func(result: Dictionary) -> bool: return int(result.token) > int(result_ack))
			p["sequenced"] = true
			p["compact"] = raw.get("compact", 0) == 1
			p.last_input = Time.get_ticks_msec()
			(p.inputs as BioNetInputBuffer).push(raw.frames)
			(p.cell as BioCellActor).set_physics_process(false)
			return
		var input := BioNetProtocol.input(raw, int(p.seq))
		if input.is_empty():
			return
		p.seq = input.seq
		p["compact"] = raw.get("compact", 0) == 1
		p.last_input = Time.get_ticks_msec()
		var cell: BioCellActor = p.cell
		var controller := cell.get_node("Controller") as BioCellController
		controller.move(input.move)
		controller.set_aim(input.aim)
		if not (p.link as BioEngineLink).online and (p.view as Dictionary).is_empty():
			controller.move(Vector2.ZERO)
			return
		_execute_actions(p, input)


func _execute_actions(p: Dictionary, input: Dictionary) -> void:
	var cell: BioCellActor = p.cell
	var controller := cell.get_node("Controller") as BioCellController
	for i in input.actions.size():
		p.action_token = int(input.tokens[i])
		cell.set_meta("action_token", p.action_token)
		var action: String = input.actions[i]
		var status := BioActor.AttackStatus.STARTED
		match action:
			"lash":
				var executor: BioAttackExecutor
				for child in cell.get_children():
					if child is BioAttackExecutor: executor = child
				var now := Time.get_ticks_msec()/1000.0
				var requested := float(input.get("view_time", now))
				if requested <= 0: requested = now
				executor.historical_position = func(target: BioCellActor) -> Vector2: return lag_history.point(target.get_instance_id(), requested, now, target.global_position)
				executor.historical_candidates = func(origin: Vector2, radius: float) -> Array:
					var found: Array = []
					for node in get_tree().get_nodes_in_group("cells"):
						if node is BioCellActor and node != cell and node.is_active() and node.get_world_2d() == cell.get_world_2d() and (executor.historical_position.call(node) as Vector2).distance_to(origin) <= radius:
							found.append(node)
					return found
				status = controller.lash()
				executor.historical_candidates = Callable()
				executor.historical_position = Callable()
			"spit": status = controller.spit()
			"dash": status = controller.dash()
			"respawn":
				if not cell.combatant.actor.vitals.is_alive():
					cell.combatant.reset_vitals()
					cell.set_active(true)
					cell.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
			_:
				if action.begins_with("ability:"):
					status = (cell.get_node("Abilities") as BioAbilityRunner).perform_id(StringName(action.trim_prefix("ability:")))
		if int(p.action_token) > 0:
			var attack_id := BioAttackCatalog.FLAGELLUM_LASH if action == "lash" else BioAttackCatalog.TOXIN_SPIT if action == "spit" else BioAttackCatalog.MEMBRANE_DASH if action == "dash" else StringName(action.trim_prefix("ability:"))
			p.results.append({"token":p.action_token,"status":status,"action":action,"attack_id":str(attack_id),"time":Time.get_ticks_msec()/1000.0,"cooldown":cell.combatant.actor.cooldown_remaining(attack_id,BioClock.now())})
			while p.results.size() > 32: p.results.pop_front()
	p.action_token = 0


func _physics_process(delta: float) -> void:
	var live: Array[int] = []
	for node in get_tree().get_nodes_in_group("cells"):
		if node is BioCellActor and node.is_active():
			live.append(node.get_instance_id())
			lag_history.record(node.get_instance_id(), Time.get_ticks_msec()/1000.0, node.global_position)
	lag_history.prune(live)
	for id in players:
		var p: Dictionary = players[id]
		if not bool(p.sequenced): continue
		var cell: BioCellActor = p.cell
		var input_buffer := p.inputs as BioNetInputBuffer
		for frame in input_buffer.take(delta):
			p.seq = int(frame.seq)
			var controller := cell.get_node("Controller") as BioCellController
			controller.move(frame.move)
			controller.set_aim(frame.aim)
			if (p.link as BioEngineLink).online or not (p.view as Dictionary).is_empty():
				_execute_actions(p, frame)
			else: controller.move(Vector2.ZERO)
			if cell.is_active(): cell._physics_process(BioNetInputBuffer.STEP)
		if Time.get_ticks_msec() - int(p.last_input) > 500 and cell.is_active():
			cell.set_intent(Vector2.ZERO)
			cell.velocity = Vector2.ZERO


func _new_player_link() -> BioEngineLink:
	return BioEngineLink.new()


func _join(id: String, player_name: String) -> void:
	if players.has(id):
		return
	var cell := BioFactory.spawn_player(arena, BioBodyMap.center_px(BioBodyMap.MEDULA) + Vector2.from_angle(randf()*TAU)*BioArt.UNIT)
	cell.combatant._id = "nk-" + id
	cell.combatant.actor.id = "nk-" + id
	cell.set_meta("net_id", id)
	for child in cell.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(cell.get_node("Abilities") as BioAbilityRunner).set_process(false)
	(cell.get_node("Abilities") as BioAbilityRunner).performed.connect(func(ability: StringName) -> void:
		_events.append({"id": id, "token":players[id].action_token,"ability": str(ability), "aim": BioNetProtocol.xy((cell.get_node("Controller") as BioCellController).aim)}))
	var link := _new_player_link()
	link.request_headers = {"X-Adapter-Key": adapter_key, "X-Edge-Secret": edge_secret}
	link.configure(engine_url, {"id": "nk-"+id, "name": player_name})
	players[id] = {"cell": cell, "link": link, "name": player_name, "seq": -1, "last_input": 0, "region": "medula", "view": {}, "viewport": null, "dungeon": null, "dungeon_seed": -1, "used": {}, "travel": 0.0, "last_pos": cell.global_position, "compact": false, "metadata": {}}
	players[id].merge({"sequenced":false,"inputs":BioNetInputBuffer.new(),"action_token":0,"results":[]})
	(players[id].inputs as BioNetInputBuffer).next_sequence = 1
	link.view_changed.connect(func(view: Dictionary) -> void: _apply_view(id, view))
	link.world_reset_detected.connect(func() -> void: _reset_cell(id))
	add_child(link)
	cell.combatant.nutrient_consumed.connect(func(_kind: int) -> void:
		link.occur("absorver-nutriente")
		if str(players.get(id, {}).get("region", "")) == "figado": link.occur("guardar-glicogenio")
		elif str(players.get(id, {}).get("region", "")) == "rim": link.occur("equilibrar-sal"))
	cell.combatant.enemy_defeated.connect(func(victim: BioCombatant) -> void:
		link.occur("derrotar-virus")
		var r := BioBodyMap.region_of((victim.get_parent() as Node2D).global_position)
		if r == BioBodyMap.BACO: link.occur("capturar-antigeno")
		elif r == BioBodyMap.INTESTINO: link.occur("repelir-invasor"))
	cell.combatant.hit.connect(func(_who: BioCombatant, result: BioHitResult) -> void:
		if result.outcome == BioActor.HitOutcome.EVADED and not cell.combatant.last_hit_was_pvp: link.occur("esquivar"))
	cell.combatant.died.connect(func(_who: BioCombatant) -> void: cell.set_active(false))
	for child in cell.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(func(attack: StringName, aim: Vector2) -> void:
				_events.append({"id": id, "token":players[id].action_token,"attack": str(attack), "aim": BioNetProtocol.xy(aim)})
				if players.has(id): players[id].used[str(attack)] = true)
	var exploration := BioExploration.new()
	arena.add_child(exploration)
	exploration.configure(cell, arena.seed_value)
	exploration.niche_reached.connect(func(niche: String) -> void: link.occur("achar-nicho", {"niche": niche}))
	players[id]["exploration"] = exploration
	print("[nakama] joined ", player_name)


func _leave(id: String) -> void:
	if not players.has(id): return
	var p: Dictionary = players[id]
	(p.cell as Node).queue_free()
	(p.link as Node).queue_free()
	(p.exploration as Node).queue_free()
	if p.viewport != null: (p.viewport as Node).queue_free()
	players.erase(id)


func _reset_cell(id: String) -> void:
	if not players.has(id): return
	_end_dungeon(id)
	if Time.get_ticks_msec() - _last_reset > 3000:
		_last_reset = Time.get_ticks_msec()
		for group in ["viruses", "nutrients", "motes", "toxins"]:
			for n in get_tree().get_nodes_in_group(group):
				if n is Node2D and (n as Node2D).get_world_2d() == arena.get_world_2d(): n.queue_free()
	var cell: BioCellActor = players[id].cell
	cell.combatant.set_genome(BioGenome.new())
	cell.combatant.reset_vitals()
	cell.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
	cell.velocity = Vector2.ZERO
	cell.set_active(true)
	(cell.get_node("Abilities") as BioAbilityRunner).clear()


func _apply_view(id: String, view: Dictionary) -> void:
	if not players.has(id): return
	players[id].view = view
	var cell: BioCellActor = players[id].cell
	var genome := BioGenome.new()
	genome.lineage = BioLineageCatalog.normalise(str(view.get("lineage", {}).get("current", "")))
	for gene in view.get("evolution", {}).get("genes", []):
		var key := StringName(str(gene.get("id", "")).replace("-", "_"))
		if BioGeneCatalog.all_ids().has(key): genome.equipped.append(key)
	cell.combatant.set_genome(genome)
	var abilities := cell.get_node("Abilities") as BioAbilityRunner
	abilities.set_known(view.get("skills", []).map(func(s: Dictionary) -> String: return str(s.get("id", ""))))
	var raw_traits: Variant = view.get("look", {}).get("traits", {})
	var traits: Dictionary = raw_traits if raw_traits is Dictionary else {}
	abilities.effect_style = StringName(str(traits.get("efeito", "")))
	abilities.projectile_traits = traits
	cell.combatant.effect_style = abilities.effect_style if BioEffectPhysics.has_style(abilities.effect_style) else &""
	cell.combatant.focus = BioAbilityFocus.params(traits)
	cell.combatant.modes = BioAbilityMode.from_traits(traits)
	var raw_axes: Variant = view.get("look", {}).get("axes", {})
	for child in cell.get_children():
		if child is BioCellBody:
			if (child as BioCellBody).traits != traits: (child as BioCellBody).set_traits(traits)
			if raw_axes is Dictionary and not raw_axes.is_empty(): (child as BioCellBody).set_look(raw_axes)
	(players[id].exploration as BioExploration).apply(view.get("explore", {}))
	_gate_exceptions()
	var body := BioBodyState.new()
	body.apply(view.get("vitals", []))
	cell.combatant.environment_speed = body.speed_multiplier()
	cell.combatant.actor.vitals.regen_scale = body.atp_regen_multiplier() * (1.15 if view.get("explore", {}).get("adapted", []).has(players[id].region) else 1.0)
	var run: Variant = view.get("dungeon", {}).get("run")
	if run is Dictionary and run.get("state", "") in ["ready", "active"]:
		_dungeon(id, run)
	elif players[id].dungeon != null:
		_end_dungeon(id)


func _dungeon(id: String, run: Dictionary) -> void:
	var p: Dictionary = players[id]
	if p.dungeon == null:
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var realm := Node2D.new()
		viewport.add_child(realm)
		var cell: BioCellActor = p.cell
		p["return_to"] = cell.global_position
		cell.reparent(realm)
		var dungeon := BioDungeon.new()
		realm.add_child(dungeon)
		dungeon.bind(cell, p.return_to)
		dungeon.room_cleared.connect(func(_room: int) -> void: (p.link as BioEngineLink).occur("sala-limpa"))
		dungeon.run_failed.connect(func() -> void: (p.link as BioEngineLink).occur("falhar-masmorra"))
		p.viewport = viewport
		p.dungeon = dungeon
		p.dungeon_seed = int(run.get("seed", 0))
		dungeon.start(run)
	else:
		var dungeon := p.dungeon as BioDungeon
		if dungeon.briefing and run.get("state", "") == "active":
			dungeon.start(run)
		elif not dungeon.briefing and dungeon.active and int(run.get("room", 0)) > dungeon.room_index:
			dungeon.advance(int(run.room))


func _end_dungeon(id: String) -> void:
	var p: Dictionary = players[id]
	if p.dungeon == null: return
	var dungeon := p.dungeon as BioDungeon
	dungeon.finish(true)
	var cell: BioCellActor = p.cell
	cell.reparent(arena)
	cell.global_position = p.get("return_to", BioBodyMap.center_px(BioBodyMap.MEDULA))
	(p.viewport as Node).queue_free()
	p.viewport = null
	p.dungeon = null


func _process(delta: float) -> void:
	_snapshot_in -= delta
	_upkeep_in -= delta
	_report_in -= delta
	for id in players:
		var p: Dictionary = players[id]
		var cell: BioCellActor = p.cell
		if bool(p.get("local", false)): continue
		var moved: float = cell.global_position.distance_to(p.last_pos) / BioArt.UNIT
		if moved < 20.0: p.travel += moved
		p.last_pos = cell.global_position
		if Time.get_ticks_msec() - int(p.last_input) > 500 or not transport.connected:
			cell.set_intent(Vector2.ZERO)
		if p.dungeon != null: continue
		var r := String(BioBodyMap.region_of(cell.global_position))
		if r != p.region:
			p.region = r
			(p.link as BioEngineLink).move_region(r)
	if _report_in <= 0.0:
		_report_in = 3.0
		for id in players:
			var p: Dictionary = players[id]
			var styles := {String(BioAttackCatalog.FLAGELLUM_LASH): "estilo-chicote", String(BioAttackCatalog.TOXIN_SPIT): "estilo-toxina", String(BioAttackCatalog.MEMBRANE_DASH): "estilo-impulso"}
			if bool(p.get("local", false)): continue
			for attack in styles:
				if p.used.has(attack): (p.link as BioEngineLink).occur(styles[attack])
			p.used.clear()
			if float(p.travel) >= BioHostSync.EXPLORE_UNITS:
				p.travel = 0.0
				(p.link as BioEngineLink).occur("estilo-explorar")
	if _upkeep_in <= 0.0:
		_upkeep_in = 1.0
		_upkeep()
	if _snapshot_in <= 0.0 and transport.connected:
		_snapshot_in = 1.0 if players.is_empty() else 0.05
		_snapshot()


func _upkeep() -> void:
	var live: Array[StringName] = []
	for id in players:
		if players[id].dungeon != null: continue
		for r in BioAnatomy.within(StringName(players[id].region), 1):
			if not live.has(r): live.append(r)
	arena.live_regions = live
	arena._populate(false)
	_gate_exceptions()
	for enemy in arena.viruses():
		var target: BioCellActor = null
		for id in players:
			var cell: BioCellActor = players[id].cell
			if players[id].dungeon == null and cell.is_active() and (target == null or cell.global_position.distance_squared_to(enemy.global_position) < target.global_position.distance_squared_to(enemy.global_position)):
				target = cell
		if target != null: (enemy as BioCellActor).retarget(target)
	for mote in get_tree().get_nodes_in_group("motes"):
		if not mote.has_meta("net_bound"):
			mote.set_meta("net_bound", true)
			(mote as BioMote).collected.connect(func(cell: BioCellActor) -> void:
				var id := str(cell.get_meta("net_id", ""))
				if players.has(id): (players[id].link as BioEngineLink).occur(str(BioMoteRules.kind((mote as BioMote).kind)["action"])))
	for toxin in get_tree().get_nodes_in_group("toxins"):
		(toxin as BioToxin).resistant_check = Callable()
		if not toxin.has_meta("net_bound"):
			toxin.set_meta("net_bound", true)
			(toxin as BioToxin).filtered_by.connect(func(cell: BioCellActor) -> void:
				var id := str(cell.get_meta("net_id", ""))
				if players.has(id): (players[id].link as BioEngineLink).occur("filtrar-toxina"))


func _gate_exceptions() -> void:
	for id in players:
		var exploration := players[id].exploration as BioExploration
		for gate in exploration._gates.values():
			for n in arena.get_children():
				if n is BioCellActor and n != gate.player:
					(gate as BioPassageGate).add_collision_exception_with(n)


func _snapshot() -> void:
	if players.is_empty():
		transport.send_data(2, {"target": "", "body": {}})  # keep the host lease alive even in an empty world
	var entities: Array = []
	var nodes: Array[Node] = arena.get_children()
	for id in players:
		if players[id].viewport != null:
			nodes.append_array((players[id].viewport as Node).get_child(0).get_children())
	for n in nodes:
		if not n is Node2D or (n == arena.player and not n.has_meta("net_id")) or n.is_queued_for_deletion(): continue
		var d := {"id": str(n.get_instance_id()), "p": BioNetProtocol.xy((n as Node2D).global_position), "realm": str((n as Node2D).get_world_2d().get_instance_id())}
		if n is BioCellActor:
			var cell := n as BioCellActor
			var actor := cell.combatant.actor
			var uid := str(cell.get_meta("net_id", ""))
			d.merge({"kind": "player" if not uid.is_empty() else "enemy", "uid": uid,
				"team": actor.team, "hp": actor.vitals.membrane, "max_hp": actor.vitals.max_membrane,
				"atp": actor.vitals.atp, "max_atp": actor.vitals.max_atp,
				"v": BioNetProtocol.xy(cell.velocity), "lineage": str(cell.combatant.genome.lineage)})
			if players.has(uid):
				d["name"] = players[uid].name
				d["genes"] = cell.combatant.genome.equipped
				d["traits"] = players[uid].view.get("look", {}).get("traits", {})
				d["axes"] = players[uid].view.get("look", {}).get("axes", {})
			else:
				if cell.has_meta("training"):
					d["kind"] = "training"
					d["practice"] = (cell.combatant as BioTrainingCombatant).practice
				d["enemy_kind"] = str(cell.get_meta("kind", "virion"))
				for child in cell.get_children():
					if child is BioCellBody: d["combat_visual"] = (child as BioCellBody).combat_visual_state()
		elif n is BioNutrient: d.merge({"kind": "nutrient", "type": (n as BioNutrient).kind})
		elif n is BioMote: d.merge({"kind": "mote", "type": str((n as BioMote).kind)})
		elif n is BioToxin: d["kind"] = "toxin"
		elif n is BioProjectile:
			var shot := n as BioProjectile
			d.merge({"kind":"projectile","v":BioNetProtocol.xy(shot._direction * shot.speed_units * BioArt.UNIT),"action_token":int(shot.get_meta("action_token",0)),"action_owner":str(shot.get_meta("action_owner",""))})
		elif n is BioAbilityBolt:
			var bolt := n as BioAbilityBolt
			d.merge({"kind": "projectile", "color": bolt._color.to_html(),"v":BioNetProtocol.xy(bolt._dir * bolt._speed_px)})
		elif n is BioAbilityZone:
			var z := n as BioAbilityZone
			d.merge({"kind":"zone","style":z.style,"color":z.color.to_html(),"radius":z.radius_px,"age":z._age,"duration":z.duration})
		elif n is BioMine:
			var m := n as BioMine
			d.merge({"kind":"mine","color":m.color.to_html(),"radius":m.radius_px,"age":m._age})
		elif n is BioSignature:
			var s := n as BioSignature
			d.merge({"kind":"signature","type":str(s.kind),"color":s.color.to_html(),"age":s._age,"duration":s.dur,"data":BioNetProtocol.visual(s.data)})
			if is_instance_valid(s.follow):
				d["realm"] = str(s.follow.get_world_2d().get_instance_id())
		else: continue
		entities.append(d)
	for id in players:
		var p: Dictionary = players[id]
		var cell: BioCellActor = p.cell
		if bool(p.get("local", false)): continue
		var near: Array = entities.filter(func(e: Dictionary) -> bool:
			var pos := Vector2(float(e.p[0]), float(e.p[1]))
			return e.realm == str(cell.get_world_2d().get_instance_id()) and pos.distance_squared_to(cell.global_position) < pow(100.0 * BioArt.UNIT, 2))
		var cooldowns := {}
		# A practice hit belongs to its player, just like tutorial progress.
		for i in near.size():
			if near[i].get("kind") == "training":
				var specific: Dictionary = near[i].duplicate()
				var key := "nk-" + str(id)
				specific["practice"] = {key: specific.get("practice", {}).get(key, {})}
				near[i] = specific
		for key in cell.combatant.actor._ready_at:
			cooldowns[str(key)] = cell.combatant.actor.cooldown_remaining(key, BioClock.now())
		var speed := cell.combatant.actor.stat(BioGene.SPEED) * cell.combatant.speed_mult()
		if BioClock.now() < cell._slow_until: speed *= cell._slow_factor
		var motion := {"speed":speed,"thrust":cell.thrust_units,"maximum":cell.max_speed_units,"damping":cell.damping,"unit":BioArt.UNIT,
			"stunned":cell.combatant.is_stunned(),"ballistic":cell.is_dashing() or cell.is_rolling(),"ballistic_seconds":maxf(0,maxf(cell._dash_until,cell._roll_until)-BioClock.now()),"velocity":BioNetProtocol.xy(cell.velocity)}
		var outgoing := near
		if bool(p.compact):
			outgoing = compact_entities(near, p.metadata, _serial % 20 == 0)
		transport.send_data(2, {"target": id, "body": {"version": 1, "seq": _serial, "time":Time.get_ticks_msec()/1000.0,"ack":p.seq,"missing_inputs":(p.inputs as BioNetInputBuffer).missing(),"results":p.results,"motion":motion,"entities": outgoing, "events": _events, "cooldowns": cooldowns, "reset_allowed": (p.link as BioEngineLink).reset_allowed}})
	_serial += 1
	_events.clear()


static func compact_entities(entities: Array, cache: Dictionary, full: bool) -> Array:
	var result: Array = []
	var wanted := {}
	const FIELDS := ["name","lineage","genes","traits","axes","enemy_kind","type","style","color","radius","duration","data","max_hp","max_atp"]
	for entity in entities:
		var id := str(entity.id)
		wanted[id] = true
		var meta := {}
		for key in FIELDS:
			if entity.has(key): meta[key] = entity[key]
		var item: Dictionary = entity.duplicate()
		if not full and cache.get(id) == meta:
			for key in FIELDS: item.erase(key)
		else:
			cache[id] = meta.duplicate(true)
		result.append(item)
	for id in cache.keys():
		if not wanted.has(id): cache.erase(id)
	return result
