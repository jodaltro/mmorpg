class_name BioInteractionState
extends RefCounted
## The phases of one cell's work, read from the engine's society entry. The engine owns what happened; this only decides which
## pose to show. A success is shown only after the engine's counter of finished tasks grows (the acknowledgement), a failure only
## when its counter grows; a view that arrives late, twice or after a reconnection never plays a finish again, because the finish
## is keyed by the counters and the first view of a cell is a baseline (history), not an event.

const IDLE := &"idle"
const NOTICE := &"notice"  # the cell is weighing what to do
const APPROACH := &"approach"  # on the way to where the work is
const ANTICIPATE := &"anticipate"  # about to arrive: a short, readable preparation
const ACT := &"act"  # working in place
const PROGRESS := &"progress"  # same as ACT while the tissue is being touched (contact)
const BLOCKED := &"blocked"  # the way is shut: the link breaks, the cell looks for another
const HELP := &"help"  # it asked for help and waits
const CONFIRMED := &"confirmed"  # the engine counted the task as done
const CANCEL := &"cancel"  # the engine counted it as failed
const RECOVER := &"recover"  # relaxing back to routine

const CONFIRM_SECONDS := 0.9
const CANCEL_SECONDS := 1.1
const RECOVER_SECONDS := 0.8
const ANTICIPATE_AT := 0.82

var npc := ""
var task := ""
var gesture := "idle"
var phase: StringName = IDLE
var phase_time := 0.0  # seconds in this phase
var progress := 0.0  # logical progress of the leg (from the engine's ticks)
var dest := ""
var region := ""
var help_need := ""
var interaction_id := ""
var seed_value := 0
var done := -1
var failed := -1
var step := 0  # leg of the route (0-based)
var engine_phase := "idle"
var contact := false  # the tissue is being touched (work in place, past the first third of the leg)

var _after: StringName = IDLE  # what follows CONFIRMED / CANCEL


func _init(npc_id: String = "") -> void:
	npc = npc_id
	seed_value = absi(npc_id.hash()) % 100000


## Applies a society entry. Returns the one-shot cues of this view: "confirmed" and "failed" (each at most once per counter value),
## "blocked" and "asked" when those begin.
func apply(entry: Dictionary, tick: int) -> Array[StringName]:
	var cues: Array[StringName] = []
	engine_phase = str(entry.get("phase", "idle"))
	step = int(entry.get("step", 0))
	var new_task := str(entry.get("task", ""))
	var d := int(entry.get("done", 0))
	var f := int(entry.get("failed", 0))
	region = str(entry.get("region", region))
	dest = str(entry.get("dest", ""))
	var since := int(entry.get("since", tick))
	var arrive := int(entry.get("arrive", 0))
	progress = clampf(float(tick - since) / float(arrive - since), 0.0, 1.0) if engine_phase == "travel" and arrive > since else (1.0 if engine_phase == "travel" else 0.0)
	help_need = str(((entry.get("help") as Dictionary).get("need", "")) if entry.get("help") is Dictionary else "")
	if done >= 0:  # not the baseline
		if d > done:
			cues.append(&"confirmed")
			_enter(CONFIRMED, RECOVER)
		if f > failed:
			cues.append(&"failed")
			_enter(CANCEL, RECOVER)
	done = d
	failed = f
	if new_task != task:
		task = new_task
		gesture = BioNpcRoles.gesture(task) if task != "" else "idle"
	interaction_id = "%s:%s:%d" % [npc, task if task != "" else "-", d + f]
	if phase == CONFIRMED or phase == CANCEL:
		return cues  # the finish is shown to its end before anything else
	var target := _target_phase(engine_phase)
	if target != phase:
		if target == BLOCKED and not cues.has(&"blocked"):
			cues.append(&"blocked")
		if target == HELP and not cues.has(&"asked"):
			cues.append(&"asked")
		_enter(target, IDLE)
	return cues


## A finer progress between two views (the presenter extrapolates the tick), so poses move smoothly instead of in steps.
func refine(p: float) -> void:
	if engine_phase != "travel":
		return
	progress = clampf(p, 0.0, 1.0)
	if phase == APPROACH and progress >= ANTICIPATE_AT:
		_enter(ANTICIPATE, IDLE)
	elif phase == ACT or phase == PROGRESS:
		contact = progress >= 0.34
		phase = PROGRESS if contact else ACT


func _target_phase(engine_phase: String) -> StringName:
	match engine_phase:
		"travel":
			if dest != "" and dest == region:
				contact = progress >= 0.34
				return PROGRESS if contact else ACT
			contact = false
			return ANTICIPATE if progress >= ANTICIPATE_AT else APPROACH
		"blocked":
			return BLOCKED
		"seek_help":
			return HELP
		"deciding":
			return NOTICE
	contact = false
	return IDLE


func _enter(next: StringName, after: StringName) -> void:
	phase = next
	_after = after
	phase_time = 0.0


## Advances local time. A finished CONFIRMED / CANCEL relaxes through RECOVER back to the engine's phase on the next view.
func advance(delta: float) -> void:
	phase_time += delta
	match phase:
		CONFIRMED:
			if phase_time >= CONFIRM_SECONDS:
				_enter(RECOVER, IDLE)
		CANCEL:
			if phase_time >= CANCEL_SECONDS:
				_enter(RECOVER, IDLE)
		RECOVER:
			if phase_time >= RECOVER_SECONDS:
				_enter(_after, IDLE)


## 0..1 blend of the pose of the current phase, easing in so poses never snap.
func blend(duration: float = 0.25) -> float:
	return clampf(phase_time / maxf(duration, 0.001), 0.0, 1.0)


func is_working() -> bool:
	return phase == ACT or phase == PROGRESS or phase == ANTICIPATE
