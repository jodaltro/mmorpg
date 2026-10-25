class_name BioPeerTransport
extends BioNakama
## WebRTC data channels expose the same input/snapshot boundary as the old relay.

var host := false


func _ready() -> void:
	connected = true
	user_id = "host" if host else "guest"


func _process(_delta: float) -> void:
	var raw: Variant = JavaScriptBridge.eval("window.HospPersonal.partyTake()", true)
	var packets: Variant = JSON.parse_string(str(raw))
	if packets is Array:
		for item in packets:
			packet.emit(int(item.code), item.body)
	var ms := float(JavaScriptBridge.eval("window.HospPersonal.partyRTT", true))
	if ms >= 0:
		stats.socket_ms = ms
		stats.last_sample = Time.get_ticks_msec()


func send_data(code: int, body: Dictionary) -> void:
	if code == 1:
		for frame in body.get("frames", []): stats.sent_input(int(frame.seq), Time.get_ticks_msec())
	JavaScriptBridge.eval("window.HospPersonal.partySend(%d,%s)" % [code, JSON.stringify(body)], true)


func close() -> void:
	connected = false
	JavaScriptBridge.eval("window.HospPersonal.partyClose()", true)
