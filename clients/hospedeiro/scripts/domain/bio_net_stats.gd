class_name BioNetStats
extends RefCounted
## Monotonic RTT measurements. Gameplay includes relay/tick queues; socket RTT does not.

var socket_ms := -1.0
var game_ms := -1.0
var jitter_ms := 0.0
var last_sample := -1
var last_ack := -1
var _pings: Dictionary = {}
var _inputs: Dictionary = {}

func sent_ping(id: String, now: int) -> void:
	_pings[id] = now
	_prune(_pings, now)

func pong(id: String, now: int) -> void:
	if not _pings.has(id): return
	var sample := float(now - int(_pings[id]))
	_pings.erase(id)
	if sample < 0 or sample > 10000: return
	socket_ms = sample if socket_ms < 0 else lerpf(socket_ms, sample, 0.25)
	last_sample = now

func sent_input(seq: int, now: int) -> void:
	if not _inputs.has(seq): _inputs[seq] = now  # retries must not turn a long RTT into a false short sample
	_prune(_inputs, now)

func acknowledge(seq: int, now: int) -> void:
	if seq <= last_ack: return
	last_ack = seq
	if _inputs.has(seq):
		var sample := float(now - int(_inputs[seq]))
		if sample >= 0 and sample <= 10000:
			jitter_ms = lerpf(jitter_ms, absf(sample-game_ms), 0.15) if game_ms >= 0 else 0.0
			game_ms = sample if game_ms < 0 else lerpf(game_ms, sample, 0.2)
			last_sample = now
	for key in _inputs.keys():
		if int(key) <= seq: _inputs.erase(key)

func current_ms(now: int) -> int:
	if last_sample < 0 or now-last_sample > 5000: return -1
	return roundi(game_ms if game_ms >= 0 else socket_ms)

func clear() -> void:
	socket_ms = -1
	game_ms = -1
	jitter_ms = 0
	last_sample = -1
	last_ack = -1
	_pings.clear()
	_inputs.clear()

func _prune(samples: Dictionary, now: int) -> void:
	for key in samples.keys():
		if now-int(samples[key]) > 10000: samples.erase(key)
