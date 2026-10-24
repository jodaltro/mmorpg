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
		"membrane": snappedf(p.combatant.actor.vitals.membrane, 0.1),
		"online": link != null and link.online,
		"engineURL": world.engine_url,
		"linkURL": link.base_url if link != null else "missing",
		"http": link.last_http if link != null else {},
		"id": link.player_id if link != null else "",
		"resetAllowed": link.reset_allowed if link != null else true,
		"region": String(world.region),
		"offer": world.sync != null and world.sync.system.has_offer(),
		"offerOpen": world.sync != null and world.sync.system.is_offer_visible(),
		"body": world.body_panel.is_open(),
		"bodyRect": [world.body_panel._window.position.x,world.body_panel._window.position.y,world.body_panel._window.size.x,world.body_panel._window.size.y],
		"debugMenu": world.debug_menu.is_open(),
		"codex": world.codex_panel.is_open() if world.codex_panel.has_method("is_open") else false,
		"touch": BioPlatform.is_touch(),
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
