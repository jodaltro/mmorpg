class_name BioNakama
extends Node
## Small JSON transport for Nakama REST + WebSocket (native and web). No game rules here.

signal joined
signal packet(code: int, body: Dictionary)
signal disconnected
signal failed(message: String)

var base_url := "http://127.0.0.1:7350"
var user_id := ""
var match_id := ""
var connected := false
var display_name := ""
var stats := BioNetStats.new()
var coalesce_snapshots := false
var _socket := WebSocketPeer.new()
var _http: BioEngineLink
var _cid := 0
var _opening := false
var _host_key := ""
var _last_packet := 0
var _ping_in := 5.0


func _ready() -> void:
	_http = BioEngineLink.new()
	add_child(_http)


func open(player_name: String, device_id: String, host_key: String = "") -> bool:
	if _opening:
		return false
	_opening = true
	_socket.close()
	connected = false
	stats.clear()
	_host_key = host_key
	display_name = player_name.strip_edges().left(24)
	_http.base_url = base_url
	_http.token = ""
	_http.request_headers = {"Authorization": "Basic " + Marshalls.utf8_to_base64("hospedeiro:")}
	var auth := await _http.request(HTTPClient.METHOD_POST, "/v2/account/authenticate/device?create=true", {"id": device_id})
	_http.request_headers.clear()
	if auth.status != 200:
		_opening = false
		failed.emit("O corpo não respondeu. Tente novamente.")
		return false
	_http.token = str(auth.body.get("token", ""))
	var pieces := _http.token.split(".")
	if pieces.size() != 3:
		_opening = false
		return false
	var claims: Variant = JSON.parse_string(Marshalls.base64_to_utf8(pieces[1].replace("-", "+").replace("_", "/")))
	if not claims is Dictionary:
		_opening = false
		return false
	user_id = str(claims.get("uid", ""))
	var lobby := await call_rpc("hosp_lobby", {"host_key": host_key})
	match_id = str(lobby.get("match_id", ""))
	if match_id.is_empty():
		_opening = false
		failed.emit("O servidor de jogo está iniciando. Tente novamente.")
		return false
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = 1048576
	_socket.outbound_buffer_size = 1048576
	var url := base_url.replace("https://", "wss://").replace("http://", "ws://")
	var err := _socket.connect_to_url(url + "/ws?lang=pt&status=false&format=json&token=" + _http.token.uri_encode())
	if err != OK:
		_opening = false
		return false
	var until := Time.get_ticks_msec() + 15000
	while _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_opening = false
		failed.emit("Não foi possível abrir a conexão com o mundo.")
		return false
	_send({"match_join": {"match_id": match_id, "metadata": {"host_key": host_key, "name": display_name}}})
	while not connected and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	_opening = false
	return connected


func call_rpc(id: String, body: Dictionary) -> Dictionary:
	var result := await _http.request(HTTPClient.METHOD_POST, "/v2/rpc/" + id, JSON.stringify(body))
	if result.status != 200:
		return {}
	var parsed: Variant = JSON.parse_string(str(result.body.get("payload", "{}")))
	return parsed if parsed is Dictionary else {}


func send_data(code: int, body: Dictionary) -> void:
	if connected:
		if code == 1 and body.has("seq"):
			stats.sent_input(int(body.seq), Time.get_ticks_msec())
			for frame in body.get("frames", []): stats.sent_input(int(frame.seq), Time.get_ticks_msec())
		_send({"match_data_send": {"match_id": match_id, "op_code": code, "data": Marshalls.utf8_to_base64(JSON.stringify(body)), "reliable": true}})


func _send(body: Dictionary) -> void:
	_cid += 1
	body["cid"] = str(_cid)
	if body.has("ping"):
		stats.sent_ping(str(_cid), Time.get_ticks_msec())
	_socket.send_text(JSON.stringify(body))


func close() -> void:
	_socket.close()
	connected = false


func _process(delta: float) -> void:
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var newest_snapshot := {}
		_ping_in -= delta
		if _ping_in <= 0:
			_ping_in = 2.0
			_send({"ping": {}})
		while _socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
			if not value is Dictionary:
				continue
			if value.has("pong"):
				stats.pong(str(value.get("cid", "")), Time.get_ticks_msec())
			if value.has("match"):
				connected = true
				_last_packet = Time.get_ticks_msec()
				joined.emit()
			if value.has("error"):
				failed.emit(str(value.error.get("message", "Conexão recusada.")))
			if value.has("match_data"):
				_last_packet = Time.get_ticks_msec()
				var data: Dictionary = value.match_data
				var decoded: Variant = JSON.parse_string(Marshalls.base64_to_utf8(str(data.get("data", ""))))
				if decoded is Dictionary:
					var code := int(data.get("op_code", 0))
					if code == 2 and coalesce_snapshots:
						newest_snapshot = BioNetProtocol.coalesce_snapshot(newest_snapshot, decoded)
					else:
						packet.emit(code, decoded)
		if not newest_snapshot.is_empty(): packet.emit(2, newest_snapshot)
	elif connected:
		connected = false
		disconnected.emit()


static func guest_identity(path: String) -> Dictionary:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	if not saved is Dictionary:
		saved = {}
	if str(saved.get("device", "")).is_empty():
		saved["device"] = "hosp-" + Crypto.new().generate_random_bytes(24).hex_encode()
	return saved
