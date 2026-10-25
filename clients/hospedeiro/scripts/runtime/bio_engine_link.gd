class_name BioEngineLink
extends Node
## Link to the World Simulation Engine (HTTP v1). The game here plays the game-server role for its own
## player: it confirms what really happened in combat (adapter) and sends the player's intentions
## (player). It never sends damage or health. With no engine it stays offline and keeps retrying.

signal world_reset_detected
signal status_changed(online: bool)
signal view_changed(view: Dictionary)
signal capabilities_changed(reset_allowed: bool)

const POLL_SECONDS := 1.0
const RETRY_SECONDS := 5.0

var base_url := ""
var player_id := ""
var player_name := "Celula"
var token := ""  # proves this cell is theirs to a public engine; minted by the engine, kept next to the id
var request_headers: Dictionary = {}
var nakama: BioNakama  # online clients send only player intentions through the Nakama gateway
var identity_path := ""
var reset_allowed := true
var region := "medula"  # where the player is now, reported on (re)join
var online := false
var view: Dictionary = {}

var _counter := 0
var last_http := {}
var _web_counter := 0


func configure(url: String, identity: Dictionary, path: String = "") -> void:
	base_url = url
	player_id = str(identity.get("id", ""))
	player_name = str(identity.get("name", "Celula"))
	token = str(identity.get("token", ""))
	identity_path = path


func _ready() -> void:
	if not base_url.is_empty():
		_loop()


func _loop() -> void:
	while is_inside_tree():
		if not online:
			await _connect()
			if not is_inside_tree():
				return
			if not online:
				await get_tree().create_timer(RETRY_SECONDS).timeout
				continue
		await refresh()
		if not is_inside_tree():
			return
		await get_tree().create_timer(POLL_SECONDS).timeout


func _connect() -> void:
	if nakama != null:
		if not nakama.connected:
			return
		player_id = "nk-" + nakama.user_id
		var res := await request(HTTPClient.METHOD_GET, "/v1/views/" + player_id)
		if res.status == 200:
			_set_online(true)
		return
	var health := await request(HTTPClient.METHOD_GET, "/v1/health")
	if health.status != 200:
		return
	if not await _open_session():
		return
	var joined := await _command("adapter", "join", {"name": player_name, "region": region})
	if joined.status != 200 and joined.status != 409:  # 409: this cell already lives in the body
		return
	await _command("adapter", "move", {"region": region})
	_set_online(true)


## Asks the engine who this cell is. A new cell gets its id and token here; one the engine does not recognise (the world was
## replaced, the key changed) is born again rather than stuck.
func _open_session() -> bool:
	for attempt in 2:
		var body := {"version": 1}
		if not player_id.is_empty():
			body["id"] = player_id
			body["token"] = token
		var res := await request(HTTPClient.METHOD_POST, "/v1/session", body)
		if res.status == 200:
			player_id = str(res.body.get("id", player_id))
			token = str(res.body.get("token", ""))
			var allowed: bool = bool(res.body.get("capabilities", {}).get("reset", true))
			if allowed != reset_allowed:
				reset_allowed = allowed
				capabilities_changed.emit(reset_allowed)
			_save_identity()
			return true
		if res.status == 401 and not player_id.is_empty():
			player_id = ""
			token = ""
			continue
		return false
	return false


func _save_identity() -> void:
	if identity_path.is_empty():
		return
	var file := FileAccess.open(identity_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"id": player_id, "name": player_name, "token": token}))


func _set_online(value: bool) -> void:
	if online == value:
		return
	online = value
	status_changed.emit(online)


func refresh() -> void:
	var res := await request(HTTPClient.METHOD_GET, "/v1/views/%s?limit=20" % player_id)
	if res.status == 200:
		view = res.body
		view_changed.emit(view)
		if BioPlatform.is_web() and nakama == null:
			JavaScriptBridge.eval("window.__hospedeiroReady=true", true)
	elif res.status == 0 or (res.status == 404 and res.body.get("error", "") == "unknown_observer"):
		var reset: bool = online and res.status == 404
		_set_online(false)  # engine gone or world reset: rejoin on the next round
		if reset:
			world_reset_detected.emit()


## Asks the engine for a brand new world (the old one stays archived on the server). This cell rejoins by itself.
func reset_world() -> int:
	var res := await request(HTTPClient.METHOD_POST, "/v1/world/reset", {"version": 1, "confirm": "new-world", "player": player_id})
	if res.status == 200:
		view = {}
		_set_online(false)
	return res.status


func fetch_affordances() -> Array:
	if not online:
		return []
	var res := await request(HTTPClient.METHOD_GET, "/v1/affordances/%s" % player_id)
	return res.body.get("affordances", []) if res.status == 200 else []


## The game server confirms something that happened (a virion destroyed, a nutrient absorbed).
func occur(action: String, args: Dictionary = {}) -> Dictionary:
	if nakama != null:
		return {"status": 403, "body": {"error": "server_authority"}}
	var extra := {"action": action}
	if not args.is_empty():
		extra["args"] = args
	return await _command("adapter", "act", extra)


## A player intention, validated by the engine against the truth of the world.
func act(action: String, args: Dictionary = {}) -> Dictionary:
	var extra := {"action": action}
	if not args.is_empty():
		extra["args"] = args
	return await _command("player", "act", extra)


func move_region(new_region: String) -> void:
	region = new_region
	if online and nakama == null:
		await _command("adapter", "move", {"region": new_region})


func accept(quest_key: String) -> Dictionary:
	return await _command("player", "accept", {"quest": quest_key})


func acknowledge_quest(quest_key: String) -> Dictionary:
	return await act("acknowledge-quest", {"quest":quest_key})


func decline(quest_key: String) -> Dictionary:
	return await _command("player", "decline", {"quest": quest_key})


func _command(origin: String, kind: String, extra: Dictionary) -> Dictionary:
	if base_url.is_empty():
		return {"status": 0, "body": {}}
	_counter += 1
	var body := {
		"version": 1,
		"requestId": "hosp-%s-%d-%d" % [player_id, Time.get_unix_time_from_system(), _counter],
		"origin": origin,
		"kind": kind,
		"actor": player_id,
	}
	body.merge(extra)
	return await request(HTTPClient.METHOD_POST, "/v1/commands", body)


func request(method: int, path: String, body: Variant = null) -> Dictionary:
	if nakama != null:
		if not nakama.connected:
			return {"status": 0, "body": {}}
		var operation := ""
		if path.begins_with("/v1/views/"):
			operation = "view"
		elif path.begins_with("/v1/affordances/"):
			operation = "affordances"
		elif path == "/v1/commands":
			operation = "command"
		elif path == "/v1/world/reset":
			operation = "reset"
		if operation.is_empty():
			return {"status": 403, "body": {}}
		var response := await nakama.call_rpc("hosp_world", {"op": operation, "body": body, "confirm": "new-world" if operation == "reset" and body != null and body.get("confirm", "") == "new-world" else ""})
		return response if response.has("status") else {"status": 0, "body": {}}
	if BioPlatform.is_web():
		return await _web_request(method, path, body)
	var http := HTTPRequest.new()
	http.timeout = 15.0 if not online else 5.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	for key in request_headers:
		headers.append(str(key) + ": " + str(request_headers[key]))
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var started := http.request(base_url + path, headers, method, payload)
	last_http = {"path": path, "start": started}
	if started != OK:
		http.queue_free()
		return {"status": 0, "body": {}}
	var r: Array = await http.request_completed
	last_http = {"path": path, "result": r[0], "status": r[1]}
	http.queue_free()
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return {"status": r[1] if r[0] == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed if parsed is Dictionary else {}}


## What this machine remembers about its cell, so it keeps living in the shared body between sessions. A cell with no id yet gets
## one from the engine on its first connection.
static func local_identity(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and str(data.get("id", "")).length() > 0:
			return data
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {"id": "", "name": "Celula-tronco %03d" % (rng.randi() % 1000), "token": ""}


## Browser fetch avoids the Web HTTPClient startup stall observed through the HTTPS edge.
## Native builds keep HTTPRequest. Every request has a deadline and its own response slot.
func _web_request(method: int, path: String, body: Variant) -> Dictionary:
	_web_counter += 1
	var key := "%d:%d" % [get_instance_id(), _web_counter]
	var timeout := 15.0 if not online else 5.0
	var headers := {"Content-Type": "application/json"}
	headers.merge(request_headers, true)
	if not token.is_empty():
		headers["Authorization"] = "Bearer " + token
	var options := {"url": base_url + path, "method": "POST" if method == HTTPClient.METHOD_POST else "GET", "headers": headers, "body": JSON.stringify(body) if body != null else null, "timeout": int(timeout * 1000)}
	JavaScriptBridge.eval("""(function(){
        const q=%s, key=%s;
        window.__hostRequests=window.__hostRequests||{};
        const controller=new AbortController();
        const timer=setTimeout(()=>controller.abort(),q.timeout);
        const options={method:q.method,headers:q.headers,signal:controller.signal};
        if(q.body!==null) options.body=q.body;
        fetch(q.url,options).then(async r=>{
            let body={};try{body=await r.json();}catch(e){}
            window.__hostRequests[key]={status:r.status,body:body};
        }).catch(()=>{window.__hostRequests[key]={status:0,body:{}};}).finally(()=>clearTimeout(timer));
    })()""" % [JSON.stringify(options), JSON.stringify(key)], true)
	last_http = {"path": path, "start": OK}
	var started := Time.get_ticks_msec()
	while is_inside_tree():
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify((window.__hostRequests||{})[%s]||null)" % JSON.stringify(key), true)
		var parsed: Variant = JSON.parse_string(str(raw)) if raw != null else null
		if parsed is Dictionary:
			JavaScriptBridge.eval("delete window.__hostRequests[%s]" % JSON.stringify(key), true)
			last_http = {"path": path, "status": parsed.get("status", 0)}
			return parsed
		if Time.get_ticks_msec() - started > int(timeout * 1000) + 1000:
			break
		await get_tree().create_timer(0.05).timeout
	JavaScriptBridge.eval("delete (window.__hostRequests||{})[%s]" % JSON.stringify(key), true)
	last_http = {"path": path, "status": 0}
	return {"status": 0, "body": {}}
