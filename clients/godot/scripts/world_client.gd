class_name WorldClient
extends Node
## Client for the World Simulation Engine HTTP contract (v1).
## Sends intentions, receives the per-observer view. Holds no game rules.
## Native Godot sends no Origin header, so the loopback guard accepts it.

signal view_changed(view: Dictionary)
signal command_done(label: String, ok: bool, body: Dictionary)
signal world_reset  # the world was started over (by anyone): this character no longer exists

@export var base_url := "http://127.0.0.1:8095"
@export var player_id := "godot-1"
@export var player_name := "Viajante"
@export var poll_seconds := 1.0
var spot_provider := Callable()  # returns the named spot the character stands at now: it travels with each action
var arrival_region := ""  # where the game server lets the newcomer arrive (first join only)
var view_limit := 12  # events asked with each view

var view: Dictionary = {}
var affordances: Array = []  # what the engine says this player could try now
var joined := false
var _counter := 0
var _refreshing := false
var _refresh_again := false
var _timer: Timer
var _sse := HTTPClient.new()
var _sse_state := 0  # 0 off, 1 connecting, 2 requested, 3 streaming
var _sse_retry := 0.0
var last_delta_ms := 0  # when the last push arrived, and how long the view fetch it triggered took (diagnostics)
var last_view_fetch_ms := 0.0
var streaming := false  # true while the push stream is delivering
var _sse_tail := ""


func _ready() -> void:
	set_process(false)
	_timer = Timer.new()
	_timer.wait_time = poll_seconds
	_timer.timeout.connect(refresh)
	add_child(_timer)


func start() -> void:
	await get_tree().create_timer(0.5).timeout  # let the first frames (shader compilation) pass
	for attempt in 5:
		await join()
		if joined:
			break
		await get_tree().create_timer(1.0).timeout
	await refresh()
	_timer.start()
	_sse_state = 0
	set_process(true)


func request(method: int, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, PackedStringArray(["Content-Type: application/json"]), method, payload)
	if err != OK:
		http.queue_free()
		return {"status": 0, "body": {"error": "request_failed"}}
	var r: Array = await http.request_completed
	http.queue_free()
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	if text.is_empty():  # transport failure (r[0] is HTTPRequest.Result), not an engine answer
		push_warning("WorldClient %s %s: no body (result=%d status=%d)" % [method, path, r[0], r[1]])
		return {"status": r[1], "body": {"error": "no_response"}}
	var parsed: Variant = JSON.parse_string(text)
	return {"status": r[1], "body": parsed if parsed is Dictionary else {}}


func _command(origin: String, kind: String, extra: Dictionary = {}) -> Dictionary:
	_counter += 1
	var body := {
		"version": 1,
		"requestId": "gd-%s-%d-%d" % [player_id, Time.get_unix_time_from_system(), _counter],
		"origin": origin,
		"kind": kind,
		"actor": player_id,
	}
	body.merge(extra)
	if kind == "act" and spot_provider.is_valid() and not body.has("spot"):
		var sp: String = spot_provider.call()
		if sp != "":
			body["spot"] = sp  # who is close enough to notice what the character does
	var res := await request(HTTPClient.METHOD_POST, "/v1/commands", body)
	var ok: bool = res.status == 200
	if not ok:
		push_warning("command %s %s -> %d %s" % [kind, extra, res.status, res.body])
	command_done.emit(kind, ok, res.body)
	return res


## Entering the world and changing region are facts the game server confirms.
func join() -> void:
	var extra := {"name": player_name}
	if arrival_region != "":
		extra["region"] = arrival_region
	var res := await _command("adapter", "join", extra)
	joined = res.status == 200 or res.status == 409  # 409: character already exists


func move_region(region: String, spot := "") -> Dictionary:
	if OS.get_cmdline_user_args().has("--ssedebug"):
		print("MOVE sent at ", Time.get_ticks_msec(), " ", region)
	var extra := {"region": region}
	if spot != "":
		extra["spot"] = spot  # where in the region the character stands: it decides who notices what they do
	return await _command("adapter", "move", extra)


## A player intention: the engine validates it against the truth of the world.
func act(action: String, args: Dictionary = {}) -> Dictionary:
	var extra := {"action": action}
	if not args.is_empty():
		extra["args"] = args
	return await _command("player", "act", extra)


## A confirmed outcome from the game server (e.g. a group was defeated).
## The engine validates it against the world and decides what it means.
func occur(action: String, args: Dictionary = {}) -> Dictionary:
	var extra := {"action": action}
	if not args.is_empty():
		extra["args"] = args
	return await _command("adapter", "act", extra)


func accept(quest: String) -> Dictionary:
	return await _command("player", "accept", {"quest": quest})


func decline(quest: String) -> Dictionary:
	return await _command("player", "decline", {"quest": quest})


func refresh_affordances() -> void:
	var res := await request(HTTPClient.METHOD_GET, "/v1/affordances/%s" % player_id)
	if res.status == 200:
		affordances = res.body.get("affordances", [])


## Starts the world over. The engine archives the old log (nothing is deleted) and every character is gone.
func reset_world() -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/world/reset", {"version": 1, "confirm": "new-world"})


func refresh() -> void:
	if not joined:
		return
	if _refreshing:
		_refresh_again = true  # something changed while a fetch was in flight: its answer may predate the change
		return
	_refreshing = true
	var t_fetch := Time.get_ticks_usec()
	var res := await request(HTTPClient.METHOD_GET, "/v1/views/%s?limit=%d" % [player_id, view_limit])
	_refreshing = false
	last_view_fetch_ms = (Time.get_ticks_usec() - t_fetch) / 1000.0
	if res.status == 404 and res.body.get("error", "") == "unknown_observer":  # someone reset the world
		joined = false
		world_reset.emit()
		return
	if res.status == 200:
		view = res.body
		view_changed.emit(view)
	if _refresh_again:
		_refresh_again = false
		refresh()


## Push: the engine's SSE stream says "something changed"; the view is then
## fetched once. The slow timer stays as a fallback while the stream is down.
func _process(delta: float) -> void:
	_sse.poll()
	match _sse_state:
		0:
			_sse_retry -= delta
			if _sse_retry > 0.0 or not joined:
				return
			var url := base_url.trim_prefix("http://")
			var parts := url.split(":")
			var port := int(parts[1]) if parts.size() > 1 else 80
			if _sse.connect_to_host(parts[0], port) == OK:
				_sse_state = 1
			else:
				_sse_retry = 3.0
		1:
			var st := _sse.get_status()
			if st == HTTPClient.STATUS_CONNECTED:
				var err := _sse.request(HTTPClient.METHOD_GET, "/v1/stream/%s" % player_id, PackedStringArray(["Accept: text/event-stream"]))
				_sse_state = 2 if err == OK else 0
				if err != OK:
					_sse_retry = 3.0
			elif st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CANT_RESOLVE or st == HTTPClient.STATUS_CONNECTION_ERROR:
				_sse_drop()
		2:
			var st := _sse.get_status()
			if st == HTTPClient.STATUS_BODY:
				if _sse.get_response_code() == 200:
					_sse_state = 3
					streaming = true
					_timer.wait_time = 5.0
				else:
					_sse_drop()
			elif st == HTTPClient.STATUS_DISCONNECTED or st == HTTPClient.STATUS_CONNECTION_ERROR:
				_sse_drop()
		3:
			if _sse.get_status() != HTTPClient.STATUS_BODY:
				_sse_drop()
				return
			var chunk := _sse.read_response_body_chunk()
			if chunk.size() > 0:
				# Only the signal matters ("something changed"; the view is then fetched), so look for it in
				# the arriving text instead of waiting for message boundaries (a lost boundary used to
				# swallow every later push). The last few characters are kept in case the words are split.
				var text := _sse_tail + chunk.get_string_from_utf8()
				_sse_tail = text.substr(maxi(0, text.length() - 12))
				if text.contains("event: delta"):
					last_delta_ms = Time.get_ticks_msec()
					refresh()


func _sse_drop() -> void:
	_sse.close()
	_sse_state = 0
	_sse_retry = 3.0
	_sse_tail = ""
	streaming = false
	_timer.wait_time = poll_seconds
