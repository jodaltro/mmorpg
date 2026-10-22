class_name BioEngineLink
extends Node
## Link to the World Simulation Engine (HTTP v1). The game here plays the game-server role for its own
## player: it confirms what really happened in combat (adapter) and sends the player's intentions
## (player). It never sends damage or health. With no engine it stays offline and keeps retrying.

signal status_changed(online: bool)
signal view_changed(view: Dictionary)

const POLL_SECONDS := 1.0
const RETRY_SECONDS := 5.0

var base_url := ""
var player_id := ""
var player_name := "Celula"
var region := "medula"  # where the player is now, reported on (re)join
var online := false
var view: Dictionary = {}

var _counter := 0


func configure(url: String, id: String, display_name: String) -> void:
	base_url = url
	player_id = id
	player_name = display_name


func _ready() -> void:
	if not base_url.is_empty() and not player_id.is_empty():
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
	var health := await request(HTTPClient.METHOD_GET, "/v1/health")
	if health.status != 200:
		return
	var joined := await _command("adapter", "join", {"name": player_name, "region": region})
	if joined.status != 200 and joined.status != 409:  # 409: this cell already lives in the body
		return
	await _command("adapter", "move", {"region": region})
	_set_online(true)


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
	elif res.status == 0 or (res.status == 404 and res.body.get("error", "") == "unknown_observer"):
		_set_online(false)  # engine gone or world reset: rejoin on the next round


func fetch_affordances() -> Array:
	if not online:
		return []
	var res := await request(HTTPClient.METHOD_GET, "/v1/affordances/%s" % player_id)
	return res.body.get("affordances", []) if res.status == 200 else []


## The game server confirms something that happened (a virion destroyed, a nutrient absorbed).
func occur(action: String, args: Dictionary = {}) -> Dictionary:
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
	if online:
		await _command("adapter", "move", {"region": new_region})


func accept(quest_key: String) -> Dictionary:
	return await _command("player", "accept", {"quest": quest_key})


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
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	if http.request(base_url + path, PackedStringArray(["Content-Type: application/json"]), method, payload) != OK:
		http.queue_free()
		return {"status": 0, "body": {}}
	var r: Array = await http.request_completed
	http.queue_free()
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return {"status": r[1] if r[0] == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed if parsed is Dictionary else {}}


## A stable identity for this machine's cell, so it keeps living in the shared body between sessions.
static func local_identity(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and str(data.get("id", "")).length() > 0:
			return data
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var identity := {"id": "cel-%06x" % (rng.randi() & 0xFFFFFF), "name": "Celula-tronco %03d" % (rng.randi() % 1000)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(identity))
	return identity
