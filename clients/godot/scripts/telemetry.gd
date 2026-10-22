class_name Telemetry
extends RefCounted
## Local playtest log (JSON lines). Nothing leaves the machine: it answers
## "what did the person do, and when did they get stuck?" for the MVP criteria.

var path := ""
var started_ms := 0
var _file: FileAccess
var _last_ms := 0
var verbs := {}
var first_deed_ms := -1
var last_new_ms := 0  # when the player last did something for the first time
var hints := 0
var io_ms_max := 0.0  # slowest write of a log line (it is flushed every time)
var acks: Array = []  # round trips (ms) from asking the engine to having its answer
var hitches := 0  # frames over 50 ms
var worst_frame_ms := 0.0


func open(file_path: String, who: String) -> void:
	path = file_path
	_file = FileAccess.open(path, FileAccess.WRITE)
	started_ms = Time.get_ticks_msec()
	last_new_ms = started_ms
	_last_ms = started_ms
	note("session", {"player": who})


## Records an event with the seconds since start and since the previous event.
func note(kind: String, data: Dictionary = {}) -> void:
	if _file == null:
		return
	var now := Time.get_ticks_msec()
	var row := {"t": snappedf((now - started_ms) / 1000.0, 0.01), "gap": snappedf((now - _last_ms) / 1000.0, 0.01), "kind": kind}
	row.merge(data)
	_last_ms = now
	var t_io := Time.get_ticks_usec()
	_file.store_line(JSON.stringify(row))
	_file.flush()
	io_ms_max = maxf(io_ms_max, (Time.get_ticks_usec() - t_io) / 1000.0)


## A confirmed action by the player; counts distinct verbs and the first deed.
func verb(action: String, ok: bool) -> void:
	if ok:
		if not verbs.has(action):
			last_new_ms = Time.get_ticks_msec()
		verbs[action] = int(verbs.get(action, 0)) + 1
		if first_deed_ms < 0:
			first_deed_ms = Time.get_ticks_msec() - started_ms
	note("verb", {"action": action, "ok": ok})


## A frame that took too long, with what the client was doing at the time.
func hitch(ms: float, ctx: String) -> void:
	hitches += 1
	worst_frame_ms = maxf(worst_frame_ms, ms)
	note("hitch", {"ms": snappedf(ms, 0.1), "ctx": ctx})


func ack(ms: float, action: String) -> void:
	acks.append(ms)
	note("ack", {"ms": snappedf(ms, 0.1), "action": action})


func percentile(list: Array, q: float) -> float:
	if list.is_empty():
		return 0.0
	var sorted := list.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(q * sorted.size()))])


func summary() -> Dictionary:
	return {"verbs": verbs.size(), "first_deed_s": snappedf(first_deed_ms / 1000.0, 0.01) if first_deed_ms >= 0 else -1.0,
		"seconds": snappedf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.1),
		"ack_p50_ms": snappedf(percentile(acks, 0.5), 0.1), "ack_p95_ms": snappedf(percentile(acks, 0.95), 0.1), "acks": acks.size(),
		"hints": hints, "log_write_max_ms": snappedf(io_ms_max, 0.1), "hitches": hitches, "worst_frame_ms": snappedf(worst_frame_ms, 0.1)}
