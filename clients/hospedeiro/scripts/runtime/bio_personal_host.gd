class_name BioPersonalHost
extends BioGameServer
## Listen host: the owner's existing world continues running locally. Only the
## visitor's inputs pass through the shared combat adapter.

var _peer_snapshot_in := 0.0
var _result_serial := Time.get_ticks_msec()
var _defeated_lives: Dictionary = {}


func _ready() -> void:
	transport.packet.connect(_packet)
	var cell := arena.player
	var owner_name := str(JavaScriptBridge.eval("window.__hospedeiroGuestName || 'Anfitrião'", true)) if BioPlatform.is_web() else "Anfitrião"
	cell.set_meta("net_id", "host")
	cell.combatant.set_meta("party_player", true)
	cell.combatant.set_meta("party_owner", "host")
	BioPartyHealth.attach(cell, owner_name)
	players["host"] = {"local":true,"cell":cell,"name":owner_name,"view":arena.sync.link.view,"region":str(arena.region),"viewport":null,"dungeon":null,"exploration":arena.exploration,"sequenced":false}
	for child in cell.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(_host_attack)
	arena.abilities.performed.connect(_host_ability)


func _new_player_link() -> BioEngineLink:
	var link := BioGuestLink.new()
	link.peer = transport as BioPeerTransport
	return link


func _host_attack(attack: StringName, aim: Vector2) -> void:
	_events.append({"id":"host","attack":str(attack),"aim":BioNetProtocol.xy(aim)})


func _host_ability(ability: StringName) -> void:
	_events.append({"id":"host","ability":str(ability),"aim":BioNetProtocol.xy((arena.player.get_node("Controller") as BioCellController).aim)})


func _packet(code: int, data: Dictionary) -> void:
	if code == 22:
		if players.has("guest") and data.get("view") is Dictionary:
			_apply_view("guest", BioPartyBuild.clean(data.view))
			players.guest.name = str(data.get("name", "Visitante")).strip_edges().left(24)
			(players.guest.cell.get_node("PartyHealth") as BioPartyHealth).display_name = players.guest.name
		return
	if code == 10:
		if data.get("event") == "join":
			_join("guest", "Visitante")
			var cell: BioCellActor = players.guest.cell
			cell.global_position = arena.player.global_position + Vector2(2,0)*BioArt.UNIT
			cell.combatant._team = BioActor.Team.VISITOR
			cell.combatant.actor.team = BioActor.Team.VISITOR
			BioPartyHealth.attach(cell, "Visitante")
			cell.combatant.set_meta("party_player", true)
			cell.combatant.set_meta("party_owner", "guest")
			cell.combatant.died.connect(func(victim: BioCombatant) -> void: _defeated("guest", victim))
		elif players.has("guest"): _leave("guest")
		return
	super._packet(code, data)


func _defeated(id: String, victim: BioCombatant) -> void:
	if not is_instance_valid(victim._last_attacker) or not victim._last_attacker.has_meta("party_player"): return
	if str(victim._last_attacker.get_meta("party_owner", "")) == id: return
	if _defeated_lives.has(id): return
	_defeated_lives[id] = true
	_result_serial += 1
	var winner := "Visitante" if id == "host" else "Anfitrião"
	var notice := winner + " venceu o confronto · sem recompensas"
	arena.hud.show_pvp_result(_result_serial, notice)
	transport.send_data(23, {"result":_result_serial,"notice":notice})


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for id in players:
		if (players[id].cell as BioCellActor).is_active(): _defeated_lives.erase(id)
	_peer_snapshot_in -= delta
	if _peer_snapshot_in <= 0.0 and transport.connected:
		_peer_snapshot_in = 1.0/30.0
		_snapshot() # after input simulation, never before the next render pass


func _process(delta: float) -> void:
	players.host.region = str(arena.region)
	players.host.view = arena.sync.link.view
	_snapshot_in = 1.0 # personal snapshots have their own physics clock
	super._process(delta)


func _upkeep() -> void:
	super._upkeep()
	if players.has("guest"):
		var cell: BioCellActor = players.guest.cell
		cell.combatant.environment_speed = arena.body.speed_multiplier()
		cell.combatant.actor.vitals.regen_scale = arena.body.atp_regen_multiplier() * (1.15 if players.guest.view.get("explore", {}).get("adapted", []).has(players.guest.region) else 1.0)


func _exit_tree() -> void:
	for id in players.keys():
		if id != "host": _leave(id)
	if is_instance_valid(arena):
		arena.player.remove_meta("net_id")
		arena.player.combatant.remove_meta("party_player")
		arena.player.combatant.remove_meta("party_owner")
		if arena.player.has_node("PartyHealth"): arena.player.get_node("PartyHealth").queue_free()
		for child in arena.player.get_children():
			if child is BioAttackExecutor and (child as BioAttackExecutor).performed.is_connected(_host_attack):
				(child as BioAttackExecutor).performed.disconnect(_host_attack)
		if arena.abilities.performed.is_connected(_host_ability): arena.abilities.performed.disconnect(_host_ability)
