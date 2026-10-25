class_name BioPersonalLink
extends BioEngineLink
## Same engine contract, executed by a browser worker. Cloud is never on this path.

var _tick_in := 0.8
var _busy := false
var visiting := false


static func wanted() -> bool:
	return BioPlatform.is_web() and bool(JavaScriptBridge.eval("!!window.HospPersonal?.enabled", true))


func _ready() -> void:
	base_url = "local://personal"
	reset_allowed = false
	capabilities_changed.emit(false)
	identity_path = ""
	player_id = str(JavaScriptBridge.eval("window.HospPersonal.identity.id", true))
	player_name = str(JavaScriptBridge.eval("window.__hospedeiroGuestName || 'Célula'", true))
	await _command("adapter", "join", {"name": player_name, "region": region})
	await _command("adapter", "move", {"region": region})
	_set_online(true)
	await refresh()


func _process(delta: float) -> void:
	_tick_in -= delta
	if _tick_in > 0.0 or _busy: return
	_busy = true
	_tick_in = 0.8
	await request(HTTPClient.METHOD_POST, "/tick")
	await refresh()
	_busy = false


func occur(action: String, args: Dictionary = {}) -> Dictionary:
	if visiting:
		return {"status": 403, "body": {"error": "host_confirmation_required"}}
	return await super.occur(action, args)


func confirm_host_deed(action: String, args: Dictionary = {}) -> Dictionary:
	return await super.occur(action, args)


func move_region(new_region: String) -> void:
	if not visiting: await super.move_region(new_region)


func confirm_host_region(new_region: String) -> void:
	await super.move_region(new_region)


func act(action: String, args: Dictionary = {}) -> Dictionary:
	if action in ["entrar-masmorra", "iniciar-masmorra"] and bool(JavaScriptBridge.eval("!!window.HospPersonal.peer", true)):
		return {"status": 409, "body": {"error":"party_open_world", "note":"Masmorras pessoais ficam disponíveis ao jogar sozinho. Feche a visita em Mundo / amigos."}}
	return await super.act(action, args)


func request(_method: int, path: String, body: Variant = null) -> Dictionary:
	var ticket := int(JavaScriptBridge.eval("window.HospPersonal.begin(%s,%s)" % [JSON.stringify(path), JSON.stringify(body)], true))
	while is_inside_tree():
		var raw: Variant = JavaScriptBridge.eval("window.HospPersonal.take(%d)" % ticket, true)
		if raw != null and not str(raw).is_empty():
			var parsed: Variant = JSON.parse_string(str(raw))
			return parsed if parsed is Dictionary else {"status": 0, "body": {}}
		await get_tree().process_frame
	return {"status": 0, "body": {}}
