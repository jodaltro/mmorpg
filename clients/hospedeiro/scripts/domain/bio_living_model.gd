class_name BioLivingModel
extends RefCounted
## The living body as the engine reports it: named cells at work, persistent conflicts and cohort headcounts. It only mirrors
## the view (the engine decides every fact) and turns two consecutive views into notices. The first view after a (re)connection is
## history, never news, and a transition older than STALE_TICKS is not announced as new.

const STALE_TICKS := 40
const RANK := {"critical": 5, "active": 4, "contained": 3, "recovering": 2, "resolved": 1}

var tick := 0
var npcs := {}  # id -> society entry
var conflicts := {}  # id -> conflict entry (every phase but resolved)
var recent: Array = []  # resolved conflicts, newest first
var engine_focus := ""
var revision := 0
var pops: Array = []
var have_view := false

var _phase := {}  # conflict id -> last phase seen
var _rev := {}  # conflict id -> last revision seen
var _announced := {}  # "id:revision:kind" already turned into a notice


## Forgets everything: the next view is history again (a new world, or a connection that was lost).
func reset() -> void:
	tick = 0
	npcs.clear()
	conflicts.clear()
	recent.clear()
	engine_focus = ""
	revision = 0
	pops = []
	have_view = false
	_phase.clear()
	_rev.clear()
	_announced.clear()


## Applies one view and returns the notices it implies: {key, conflict, kind, priority, title, text, region, revision, phase}.
func ingest(view: Dictionary) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	tick = int(view.get("tick", tick))
	var first := not have_view
	have_view = true
	pops = view.get("populations", []) if view.get("populations") is Array else []
	npcs.clear()
	for n in (view.get("society", []) if view.get("society") is Array else []):
		npcs[str(n.get("id", ""))] = n
	var block: Variant = view.get("conflicts")
	if not (block is Dictionary):
		conflicts.clear()
		recent = []
		return notices
	revision = int(block.get("revision", 0))
	engine_focus = str(block.get("focus", ""))
	conflicts.clear()
	for c in block.get("active", []):
		conflicts[str(c.get("id", ""))] = c
		_note(c, first, notices)
	recent = block.get("recent", []) if block.get("recent") is Array else []
	for c in recent:
		_note(c, first, notices)
	return notices


## The connection was lost: what was known stays (marked stale by the caller), and the next view is history, not news.
func expect_history() -> void:
	have_view = false


func _note(c: Dictionary, first: bool, out: Array[Dictionary]) -> void:
	var id := str(c.get("id", ""))
	var phase := str(c.get("phase", ""))
	var rev := int(c.get("revision", 0))
	var was: String = _phase.get(id, "")
	_phase[id] = phase
	_rev[id] = rev
	if first or was == phase:
		return
	var kind := _kind(was, phase)
	if kind == "":
		return
	var key := "%s:%d:%s" % [id, rev, kind]
	if _announced.has(key):
		return
	_announced[key] = true
	if tick - int(c.get("since", tick)) > STALE_TICKS:
		return  # it happened while we were away: the panel shows it, no banner
	out.append({"key": key, "conflict": id, "kind": kind, "priority": int(RANK.get(phase, 1)), "title": str(c.get("title", id)),
		"region": str(c.get("region", "")), "revision": rev, "phase": phase, "reopened": kind == "reopen"})


static func _kind(was: String, now: String) -> String:
	if was == "resolved" and now != "resolved":
		return "reopen"
	match now:
		"critical":
			return "escalate"
		"contained":
			return "contain"
		"recovering":
			return "recover"
		"resolved":
			return "resolve"
		"active":
			return "start" if was == "" else "relapse"
	return ""


## Everything shown to the player is a conflict that is still alive, worst first.
func ordered() -> Array:
	var out: Array = conflicts.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := int(RANK.get(str(a.get("phase", "")), 0))
		var rb := int(RANK.get(str(b.get("phase", "")), 0))
		if ra != rb:
			return ra > rb
		var sa := int(a.get("severity", 0))
		var sb := int(b.get("severity", 0))
		if sa != sb:
			return sa > sb
		return str(a.get("id", "")) < str(b.get("id", "")))
	return out


## NPCs asking for help right now (open requests only): the engine closes them when the cause is gone.
func open_requests() -> Array:
	var out: Array = []
	for id in npcs:
		var h: Variant = npcs[id].get("help")
		if h is Dictionary and str(h.get("status", "")) == "open":
			out.append({"npc": id, "name": str(npcs[id].get("name", id)), "help": h})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["npc"]) < str(b["npc"]))
	return out


func population(id: String) -> Dictionary:
	for p in pops:
		if str(p.get("id", "")) == id:
			return p
	return {}


## Headcount of a region as a fraction of its capacity, 0..1 (1 when nothing is tracked there).
func region_vitality(region: String) -> float:
	var have := 0.0
	var cap := 0.0
	for p in pops:
		if str(p.get("region", "")) == region:
			have += float(p.get("count", 0))
			cap += float(p.get("max", 0))
	return clampf(have / cap, 0.0, 1.0) if cap > 0.0 else 1.0
