class_name BioAlertQueue
extends RefCounted
## Big alerts without spam: one per conflict transition (never per percentage), highest priority first, old ones expire instead
## of showing up late, and every notice stays in the history for the panel. Time is passed in, so it is testable.

const TTL := 20.0
const HISTORY := 40

var history: Array[Dictionary] = []  # newest first: the notices that were pushed, shown or not
var _pending: Array[Dictionary] = []
var _seen := {}


## False when this transition was already queued (same key).
func push(alert: Dictionary, now: float) -> bool:
	var key := str(alert.get("key", ""))
	if key.is_empty() or _seen.has(key):
		return false
	_seen[key] = true
	var item := alert.duplicate()
	item["born"] = now
	_pending.append(item)
	history.push_front(item)
	if history.size() > HISTORY:
		history.pop_back()
	return true


## The next alert to show, or {} when none is waiting. The most severe first; among equals, the oldest.
func next(now: float) -> Dictionary:
	_pending = _pending.filter(func(a: Dictionary) -> bool: return now - float(a["born"]) <= TTL)
	if _pending.is_empty():
		return {}
	var best := 0
	for i in range(1, _pending.size()):
		if int(_pending[i]["priority"]) > int(_pending[best]["priority"]):
			best = i
	return _pending.pop_at(best)


func waiting() -> int:
	return _pending.size()


func clear() -> void:
	_pending.clear()
	history.clear()
	_seen.clear()
