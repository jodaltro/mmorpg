class_name BioWebProbe
extends Node
## For the browser tests only (`?probe=1`): publishes a few facts about the running game on `window.__probe`, and runs the commands a test
## leaves in `window.__cmd`. It never exists in a normal session.

const EVERY := 0.2

var world: BioWorld
var _age := 0.0


static func wanted() -> bool:
	return BioPlatform.is_web() and BioPlatform.query_param("probe") == "1"


func _process(delta: float) -> void:
	_age += delta
	if _age < EVERY or world == null or not is_instance_valid(world.player):
		return
	_age = 0.0
	var cmd: Variant = JavaScriptBridge.eval("(function(){var c=window.__cmd||'';window.__cmd='';return c;})()", true)
	if cmd != null and str(cmd) != "":
		_run(str(cmd))
	var p := world.player
	var link := world.sync.link if world.sync != null else null
	var facts := {
		"x": snappedf(p.global_position.x, 0.1),
		"y": snappedf(p.global_position.y, 0.1),
		"alive": p.is_active(),
		"enemyWear": _wear_facts(),
		"lashTargets": get_tree().get_nodes_in_group("limbs").filter(func(n: Node) -> bool: return n.get_parent() == world.player).map(func(n: BioLimb) -> Dictionary: return {"aimed":n.has_target_point,"target":BioNetProtocol.xy(n.target_point),"extension":n.extension()}),
		"pvpResult": world.hud.pvp_result_text,
		"pvpVisible": world.hud._pvp_result != null and world.hud._pvp_result.modulate.a > 0.5,
		"membrane": snappedf(p.combatant.actor.vitals.membrane, 0.1),
		"online": link != null and link.online,
		"personalProgress": link.view.get("self", {}).get("num", {}) if link is BioPersonalLink else {},
		"network": {
			"ping": world.online_client.transport.stats.current_ms(Time.get_ticks_msec()) if world.online_client != null else -1,
			"socketMs": world.online_client.transport.stats.socket_ms if world.online_client != null else -1,
			"predictionFrames": world.online_client.prediction.frames.size() if world.online_client != null else 0,
			"pingLabel": world.touch.ping_label.text if world.touch != null else "",
			"authorityX": world.online_client.authoritative_position.x if world.online_client != null else 0,
			"authorityY": world.online_client.authoritative_position.y if world.online_client != null else 0,
			"ready": world.online_client != null and world.online_client.is_ready,
			"predictedCasts": world.online_client.preview.visual_count if world.online_client != null and world.online_client.preview != null else 0,
			"pendingCasts": world.online_client.actions.pending.size() if world.online_client != null else 0,
			"correctionPx": world.online_client._visual_offset.length() if world.online_client != null else 0,
			"bufferedInputs": world.online_client._frames_to_send.size() if world.online_client != null else 0,
			"inputSeq": world.online_client._seq if world.online_client != null else 0,
			"inputAck": world.online_client.transport.stats.last_ack if world.online_client != null else 0,
			"missingInputs": world.online_client._missing_inputs if world.online_client != null else [],
			"entities": world.online_client._entities.size() if world.online_client != null else 0,
			"players": world.online_client._entities.values().filter(func(n: Node) -> bool: return n is BioCellActor and not str(n.get_meta("net_uid", "")).is_empty()).size() if world.online_client != null else 0,
		},
		"engineURL": world.engine_url,
		"linkURL": link.base_url if link != null else "missing",
		"http": link.last_http if link != null else {},
		"id": link.player_id if link != null else "",
		"resetAllowed": link.reset_allowed if link != null else true,
		"region": String(world.region),
		"offer": world.sync != null and world.sync.system.has_offer(),
		"offerOpen": world.sync != null and world.sync.system.is_offer_visible(),
		"body": world.body_panel.is_open(),
		"menus": {
			"navigation": world.touch != null and world.touch.menu_open,
			"scaleSlider": _rect(world.touch.scale_slider) if world.touch != null else [],
			"scaleReset": _rect(world.touch.scale_reset) if world.touch != null else [],
			"atlas": world.atlas.is_open(),
			"vitals": world.vitals_panel.is_open(),
			"actions": world.sync.system.menu_open,
			"missions": world.sync.system._missions.visible,
			"resetDialog": world.reset_dialog.modal.visible,
			"missionsButton": _rect(world.touch.missions_button) if world.touch != null else [],
			"restartButton": _rect(world.touch.restart_button) if world.touch != null else [],
			"bodyScroll": world.body_panel._scroll.scroll_vertical,
			"bodyViewport": _rect(world.body_panel._scroll),
			"tabs": world.body_panel._tab_buttons.map(func(b: Button) -> Array: return _rect(b)),
			"codexViewport": _rect(world.codex_panel._modal.scroll),
			"vitalsViewport": _rect(world.vitals_panel._modal.scroll),
			"bodyTab": world.body_panel.tab,
			"abilityPick": world.body_panel._ability_pick,
			"abilitySlots": world.body_panel.ability_slots.map(func(s: BioLoadoutSlot) -> Array: return _rect(s)),
			"draggingSkill": is_instance_valid(BioLoadoutSlot.active),
			"abilityDetails": world.body_panel._ability_details,
			"bodyContent": world.body_panel.content_text() if world.body_panel.is_open() else "",
			"bodyButtons": _body_buttons(),
			"buildPick": world.body_panel._build_pick,
			"codexScroll": world.codex_panel._modal.scroll.scroll_vertical,
			"vitalsScroll": world.vitals_panel._modal.scroll.scroll_vertical,
		},
		"bodyRect": [world.body_panel._window.position.x,world.body_panel._window.position.y,world.body_panel._window.size.x,world.body_panel._window.size.y],
		"debugMenu": world.debug_menu.is_open(),
		"codex": world.codex_panel.is_open() if world.codex_panel.has_method("is_open") else false,
		"touch": BioPlatform.is_touch(),
		"tutorial": {
			"active": world.tutorial.active,
			"step": world.tutorial.step,
			"waiting": world.tutorial._waiting,
			"nextLabel": world.tutorial._next.text,
			"pausedRoute": world.journey.has_manual_destination(),
			"fulfilled": world.tutorial._fulfilled,
			"next": _rect(world.tutorial._next),
			"card": _rect(world.tutorial._card),
			"cardVisible": world.tutorial._card.visible,
			"opacity": world.tutorial._material.get_shader_parameter("opacity"),
			"attack": _rect(world.touch.attack_stick) if world.touch != null else [],
			"toxin": _rect(world.touch.toxin) if world.touch != null else [],
			"dash": _rect(world.touch.dash) if world.touch != null else [],
		},
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"logical": [world.display.logical_size.x, world.display.logical_size.y] if world.display != null else [],
		"fps": Engine.get_frames_per_second(),
		"perf": {
			"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		},
		"abilities": _ability_ids(),
		"lastCast": String(world.abilities.last_cast),
		"moba": _touch_state(),
		"viruses": world.viruses().size(),
		"lash": Input.is_action_pressed("bio_lash"),
		"attackHeld": world.touch != null and world.touch.attack_stick.is_engaged(),
		"moveHeld": world.touch != null and world.touch.move_stick.is_engaged(),
	}
	JavaScriptBridge.eval("window.__probe=%s" % JSON.stringify(facts), true)


func _ability_ids() -> Array:
	var out := []
	for i in BioAbilityRunner.SLOTS:
		out.append(String(world.abilities.slot_id(i)))
	return out


func _run(cmd: String) -> void:
	if not BioPlatform.debug_enabled():
		return
	var parts := cmd.split(":")
	match parts[0]:
		"tutorial":
			if parts.size() > 1 and parts[1] == "pause": world.tutorial.stop()
			elif parts.size() > 1 and str(parts[1]).is_valid_int():
				world.tutorial.start()
				world.tutorial._enter(int(parts[1]))
		"tutorial-outside":
			world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
			world.tutorial.start()
			world.tutorial._enter(1)
		"ui-scale":
			world.display.set_interface_scale(float(parts[1]))
		"become":
			world.debug_become(StringName(parts[1]))
		"god":
			world.debug_god = true
		"off":  # stop what a script class does every frame
			for n in _nodes_of(parts[1]):
				n.set_process(false)
				n.set_physics_process(false)
		"hide":
			for n in _nodes_of(parts[1]):
				if n is CanvasItem:
					(n as CanvasItem).visible = false
		"glow":
			(world.get_node("GlowEnvironment") as WorldEnvironment).environment.glow_enabled = parts[1] == "on"
		"render":
			RenderingServer.render_loop_enabled = parts[1] == "on"
		"census":
			_census()
		"pos":
			world.player.global_position = Vector2(float(parts[1]), float(parts[2])) * BioArt.UNIT
		"party-monster":
			for node in _nodes_of("BioPersonalHost"):
				var host := node as BioPersonalHost
				if not host.players.has("guest"): continue
				var guest := host.players.guest.cell as BioCellActor
				var at := BioBodyMap.center_px(BioBodyMap.SANGUE)
				world._spawn_virus_at(at)
				for enemy in world.viruses():
					if enemy.global_position.distance_to(at) < 1:
						(enemy as BioCellActor).combatant.receive_hit(guest.combatant, BioAttackDef.new(&"probe",0,1000,0,1,0,0))
		"party-pvp":
			for node in _nodes_of("BioPersonalHost"):
				var host := node as BioPersonalHost
				if host.players.has("guest"):
					world.player.combatant.receive_hit((host.players.guest.cell as BioCellActor).combatant, BioAttackDef.new(&"probe",0,1000,0,1,0,0))
		"party-host-win":
			for node in _nodes_of("BioPersonalHost"):
				var host := node as BioPersonalHost
				if host.players.has("guest"):
					(host.players.guest.cell as BioCellActor).combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"probe",0,1000,0,1,0,0))
		"combat-showcase":
			for target in get_tree().get_nodes_in_group("training_targets"): target.queue_free()
			for child in world.player.get_children():
				if child is BioPlayerInput: child.set_process(false)
			world.sync.set_process(false)
			world.sync.link.set_process(false)
			world.player.set_intent(Vector2.ZERO)
			for enemy in world.viruses(): enemy.queue_free()
			for i in 3:
				var at := world.player.global_position + Vector2((i-1)*2.8,-2.2)*BioArt.UNIT
				var brain: Node = BioFactory.spawn_enemy(world, at, world.player, BioEnemyCatalog.enemy(&"macrofago_guarda"), 1.0, "viruses") if parts.size() > 1 and parts[1] == "smooth" else BioFactory.spawn_virus(world, at, world.player)
				brain.set_process(false)
				var enemy := brain.get_parent() as BioCellActor
				enemy.set_physics_process(false)
				enemy.set_meta("wear_probe", i)
				enemy.combatant.actor.vitals.max_membrane = 100
				enemy.combatant.actor.vitals.membrane = 100
		"combat-damage":
			for enemy in world.viruses():
				if not enemy.has_meta("wear_probe"): continue
				var index := int(enemy.get_meta("wear_probe"))
				if index > 0:
					enemy.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"probe",0,45 if index == 1 else 85,0,1,0,0))
		"combat-lash":
			world.genome.lineage = &"dendritica"
			world.player.combatant.set_genome(world.genome)
			for enemy in world.viruses():
				if not enemy.has_meta("wear_probe"): continue
				var index := int(enemy.get_meta("wear_probe"))
				enemy.combatant.reset_vitals()
				enemy.global_position = world.player.global_position + ([Vector2(1.5,-0.6),Vector2(1.5,0.6),Vector2(-1.5,0)][index] as Vector2)*BioArt.UNIT
			await get_tree().physics_frame
			await get_tree().physics_frame # let physics index the fixture's teleported colliders
			var controller := world.player.get_node("Controller") as BioCellController
			controller.set_aim(Vector2.RIGHT)
			controller.lash()


func _wear_facts() -> Array:
	var result: Array = []
	for enemy in world.viruses():
		if not enemy.has_meta("wear_probe"): continue
		for child in enemy.get_children():
			if child is BioCellBody:
				result.append({"id":int(enemy.get_meta("wear_probe")),"health":enemy.combatant.actor.vitals.membrane,"integrity":child.integrity,"size":child.wear_size(),"position":BioNetProtocol.xy(enemy.global_position)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return result


## Which scripts the running scene is made of, and which of them think every frame: where a slow device spends its time.
func _census() -> void:
	var counts := {}
	var processing := {}
	var stack: Array[Node] = [world.get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var script: Script = n.get_script()
		var key: StringName = script.get_global_name() if script != null and script.get_global_name() != &"" else n.get_class()
		counts[key] = int(counts.get(key, 0)) + 1
		if n.is_processing() or n.is_physics_processing():
			processing[key] = int(processing.get(key, 0)) + 1
	var rows: Array = []
	for k in counts:
		rows.append([k, counts[k], int(processing.get(k, 0))])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	JavaScriptBridge.eval("window.__census=%s" % JSON.stringify(rows.slice(0, 30)), true)


func _nodes_of(class_name_: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [world.get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var script: Script = n.get_script()
		if (script != null and script.get_global_name() == class_name_) or n.get_class() == class_name_:
			out.append(n)
	return out


func _touch_state() -> Dictionary:
	if world.touch == null:
		return {}
	var buttons := []
	for b in world.touch.ability_buttons:
		var centre := b.position+b.size*0.5
		buttons.append({"x":centre.x,"y":centre.y,"glyph":b.glyph,"held":b.is_down(),"cancelled":b.cancelled})
	return {"buttons":buttons,"scale":world.display.interface_scale,"scaleLabel":world.touch.scale_label.text,"cancel":[world.display.logical_size.x*0.72,70]}


func _rect(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _body_buttons() -> Array:
	var result: Array = []
	var stack: Array[Node] = [world.body_panel._content]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree():
			result.append({"text": node.text, "rect": _rect(node)})
		for child in node.get_children():
			stack.append(child)
	return result
