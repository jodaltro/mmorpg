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


func open(file_path: String, who: String) -> void:
	path = file_path
	_file = FileAccess.open(path, FileAccess.WRITE)
	started_ms = Time.get_ticks_msec()
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
	_file.store_line(JSON.stringify(row))
	_file.flush()


## A confirmed action by the player; counts distinct verbs and the first deed.
func verb(action: String, ok: bool) -> void:
	if ok:
		verbs[action] = int(verbs.get(action, 0)) + 1
		if first_deed_ms < 0:
			first_deed_ms = Time.get_ticks_msec() - started_ms
	note("verb", {"action": action, "ok": ok})


func summary() -> Dictionary:
	return {"verbs": verbs.size(), "first_deed_s": snappedf(first_deed_ms / 1000.0, 0.01) if first_deed_ms >= 0 else -1.0,
		"seconds": snappedf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.1)}
