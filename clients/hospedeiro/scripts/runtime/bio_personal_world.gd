class_name BioPersonalWorld
extends CanvasLayer
## Personal/party lifecycle and a compact entry point on desktop and phones.

var world: BioWorld
var peer: BioPeerTransport
var host: BioPersonalHost
var _clock := 0.0
var _last_view := ""
var _button: Button
var _shield: Control
var _was_modal := false
var _was_guest := false
var _last_role := ""
const PROFILE_FILES := ["hospedeiro_personal_genome.json", "hospedeiro_personal_builds.json", "hospedeiro_personal_atlas.json", "hospedeiro_personal_tutorial.json"]


static func restore_files() -> void:
	var saved: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.HospPersonal.player.files || {})", true)))
	if not saved is Dictionary: return
	for file_name in PROFILE_FILES:
		if saved.get(file_name) is String:
			var file := FileAccess.open("user://" + file_name, FileAccess.WRITE)
			if file != null: file.store_string(saved[file_name])


func _ready() -> void:
	layer = 65
	_button = BioUi.button("Mundo / amigos")
	_button.add_theme_font_size_override("font_size", 12)
	_button.custom_minimum_size = Vector2(110, 36)
	_button.pressed.connect(func() -> void: JavaScriptBridge.eval("window.HospPersonal.partyOpen()", true))
	add_child(_button)
	_shield = Control.new()
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield.hide()
	add_child(_shield)
	var saved: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.HospPersonal.player)", true)))
	if saved is Dictionary and saved.get("position") is Array:
		var pos: Array = saved.position
		if pos.size() == 2 and is_finite(float(pos[0])) and is_finite(float(pos[1])):
			world.player.global_position = Vector2(float(pos[0]), float(pos[1]))
	world.sync.link.view_changed.connect(func(_view: Dictionary) -> void:
		if not saved is Dictionary: return
		var vitals := world.player.combatant.actor.vitals
		vitals.membrane = vitals.max_membrane * clampf(float(saved.get("health", 1.0)), 0, 1)
		vitals.atp = vitals.max_atp * clampf(float(saved.get("energy", 1.0)), 0, 1)
		if not vitals.is_alive(): world._on_player_died(world.player.combatant), CONNECT_ONE_SHOT)
	world.sync.link.view_changed.connect(func(_view: Dictionary) -> void: _send_build())
	world.player.combatant.died.connect(func(victim: BioCombatant) -> void:
		if host != null: host._defeated("host", victim))
	if not str(JavaScriptBridge.eval("window.HospPersonal.incoming", true)).is_empty():
		JavaScriptBridge.eval("window.HospPersonal.partyOpen()", true)


func _process(delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	JavaScriptBridge.eval("window.HospPersonal.canInvite=%s;window.HospPersonal.inCombat=%s" % ["true" if world.player.is_active() and not world.dungeon.active else "false", "true" if world.evolution_presentation.in_combat() else "false"], true)
	_button.position = Vector2(screen.x * 0.5 - 60, 6)
	var modal := bool(JavaScriptBridge.eval("window.HospPersonal.partyModal", true))
	if modal != _was_modal:
		_was_modal = modal
		_shield.visible = modal
		BioUi.set_modal(_shield, modal)
	_button.visible = not BioUi.captures_input()
	var role := str(JavaScriptBridge.eval("window.HospPersonal.peer?.role || ''", true))
	if role != _last_role:
		_last_role = role
		if role.is_empty():
			if _was_guest:
				set_process(false)
				JavaScriptBridge.eval("window.HospPersonal.returnHome()", true)
				return
			if host != null:
				host.queue_free()
				host = null
			if peer != null:
				peer.queue_free()
				peer = null
		else:
			peer = BioPeerTransport.new()
			peer.host = role == "host"
			if role == "host":
				add_child(peer)
				host = BioPersonalHost.new()
				host.arena = world
				host.transport = peer
				add_child(host)
			else:
				_was_guest = true
				(world.sync.link as BioPersonalLink).visiting = true
				world.online_client = BioOnlineClient.new()
				world.online_client.world = world
				world.online_client.personal_peer = peer
				world.add_child(world.online_client)
				peer.packet.connect(_visitor_packet)
	_clock -= delta
	if _clock > 0: return
	_clock = 1.0
	var vitals := world.player.combatant.actor.vitals
	var saved := {"position":BioNetProtocol.xy(world.dungeon._return_to if world.dungeon.active else world.player.global_position),"region":str(world.region),"health":vitals.membrane / maxf(1,vitals.max_membrane),"energy":vitals.atp / maxf(1,vitals.max_atp),"files":{}}
	for file_name in PROFILE_FILES:
		if FileAccess.file_exists("user://" + file_name): saved.files[file_name] = FileAccess.get_file_as_string("user://" + file_name)
	JavaScriptBridge.eval("window.HospPersonal.setPlayer(%s)" % JSON.stringify(saved), true)
	if peer != null and _was_guest:
		_send_build()


func _send_build() -> void:
	if peer == null or not _was_guest: return
	var build := JSON.stringify({"view":BioPartyBuild.clean(world.sync.link.view),"name":world.sync.link.player_name})
	if build != _last_view:
		_last_view = build
		peer.send_data(22, JSON.parse_string(build))


func _visitor_packet(code: int, body: Dictionary) -> void:
	if code == 21:
		var link := world.sync.link as BioPersonalLink
		await link.confirm_host_deed(str(body.get("action", "")), body.get("args", {}))
	elif code == 23:
		if body.has("region"): (world.sync.link as BioPersonalLink).confirm_host_region(str(body.region))
		if body.has("notice"): world.hud.show_pvp_result(int(body.get("result", 0)), str(body.notice))


func _exit_tree() -> void:
	if _shield != null: BioUi.set_modal(_shield, false)
