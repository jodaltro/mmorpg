class_name BioNpcMotion
extends RefCounted
## The motor plan of a named cell: what each of its extensions and its whole body should be doing right now, given its task, phase and
## movement. It is the cell's own control (each cell has a personality: tempo and a phase per limb), so every arm moves on its own
## rhythm, the limbs that work lead while the others follow, the body leans into the work and drags behind when it travels. It only
## says where each part should be; the renderer follows with springs, so the result stays fluid even when the plan changes at once.
## Presentation only: it reads the interaction state and never changes a fact.

const GAIT := 5.0  # rad/s of the crawling ripple while moving


## A tempo between 0.8 and 1.25 and a phase, the same for the same cell on every client.
static func personality(seed_value: int) -> Dictionary:
	var u := float(absi(seed_value) % 997) / 997.0
	return {"tempo": 0.8 + 0.45 * u, "phase": u * TAU}


static func _lobe(into: Dictionary, key: String, angle: float, amp: float, width: float, snap: float = 1.0) -> void:
	into[key] = {"a": angle, "amp": amp, "w": width, "k": snap}


## The extensions. ctx: sil, gesture, phase, progress, working, face, aim (angles), speed (0..1), t, tempo, phase_offset, reduce (0..1 motion).
static func limbs(ctx: Dictionary) -> Dictionary:
	var out := {}
	var t: float = ctx["t"] * float(ctx["tempo"])
	var ph: float = ctx["phase_offset"]
	var m: float = ctx["motion"]
	var face: float = ctx["face"]
	var aim: float = ctx["aim"]
	var p: float = ctx["progress"]
	var phase: StringName = ctx["phase"]
	var working: bool = ctx["working"]
	var speed: float = ctx["speed"]
	var act := 1.0 if phase == BioInteractionState.ACT or phase == BioInteractionState.PROGRESS else 0.0
	var ant := 1.0 if phase == BioInteractionState.ANTICIPATE else 0.0
	var sil := str(ctx["sil"])
	# Resting extensions: every one has its own frequency and phase, so no two ever move together.
	match sil:
		"lobed":
			for i in 3:
				_lobe(out, "bump%d" % i, ph + t * 0.35 * m + i * TAU / 3.0, 0.1 + 0.05 * sin(t * (1.1 + 0.3 * i) + i), 0.55)
		"pseudo":
			for i in 4:
				_lobe(out, "foot%d" % i, ph + i * TAU / 4.0 + sin(t * (0.6 + 0.23 * i) + i * 1.9) * 0.35 * m, 0.3 + 0.1 * sin(t * (1.1 + 0.37 * i) + i * 2.3), 0.42, 0.8)
		"branch":
			var reach := 0.6 + (0.35 if working else 0.0)
			for i in 7:
				var sweep := sin(t * (1.0 + 0.19 * i) + i * 1.3) * (0.3 if not working else 0.5) * m
				_lobe(out, "den%d" % i, ph + i * TAU / 7.0 + sweep, reach + 0.12 * sin(t * (1.4 + 0.11 * i) + i), 0.12, 1.2)
		"cluster":
			for i in 3:
				_lobe(out, "clump%d" % i, ph + t * (0.6 + 0.25 * i) * m + i * TAU / 3.0, 0.4 + 0.06 * sin(t * (1.3 + 0.4 * i)), 0.62, 0.9)
		"star":
			for i in 5:
				_lobe(out, "arm%d" % i, ph + i * TAU / 5.0 + sin(t * (0.8 + 0.13 * i) + i) * 0.15 * m, 0.66 + 0.1 * sin(t * (1.2 + 0.2 * i) + i * 1.1), 0.2, 1.0)
		"anchor":
			for i in 3:
				_lobe(out, "root%d" % i, PI * 0.5 + (i - 1) * 0.7 + sin(t * (0.5 + 0.2 * i) + i) * 0.08 * m, 0.72 + 0.06 * sin(t * (0.9 + 0.3 * i)), 0.15, 0.6)
	# Moving: the body leans forward and the limbs behind ripple like a crawl, each a little later than its neighbour.
	if phase == BioInteractionState.APPROACH or phase == BioInteractionState.ANTICIPATE:
		_lobe(out, "lead", face, 0.18 + 0.2 * speed, 0.6, 1.0)
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			_lobe(out, "trail%d" % i, face + PI + side * 0.7, 0.14 + 0.14 * speed + 0.1 * sin(t * GAIT + i * PI) * m, 0.38, 1.3)
	if phase == BioInteractionState.BLOCKED or phase == BioInteractionState.HELP:
		_lobe(out, "push", aim + sin(t * 3.1) * 0.12 * m, 0.4 + 0.22 * sin(t * 5.0) * m, 0.3, 1.3)
	if not working:
		return out
	# Working: the extensions that do the job lead, in their own order and rhythm.
	match str(ctx["gesture"]):
		"carry":
			_lobe(out, "give", aim, 0.35 + 0.55 * act + 0.1 * sin(t * 4.0) * act * m, 0.36, 1.0)
		"patrol":
			_lobe(out, "probe", face + sin(t * 1.6) * 0.9 * m, 0.55 + 0.25 * act, 0.19, 1.4)
			_lobe(out, "probe2", face + PI * 0.5 + sin(t * 1.1 + 2.0) * 0.6 * m, 0.25, 0.22, 1.0)
		"defend":
			for i in 8:
				var wave := 0.5 + 0.5 * sin(t * 6.0 - i * 0.8)  # a ripple of spikes round the outline, not all at once
				_lobe(out, "spike%d" % i, ph + i * TAU / 8.0, 0.12 + (0.2 * ant + (0.3 + 0.35 * wave) * act) * (1.0 - 0.3 * p), 0.1, 1.6)
		"engulf":
			var spread := lerpf(0.95, 0.3, p)
			_lobe(out, "armL", face - spread - 0.1 * sin(t * 3.0) * m, 0.55 + 0.25 * (0.5 + 0.5 * sin(t * 2.4)), 0.3, 1.0)
			_lobe(out, "armR", face + spread + 0.1 * sin(t * 3.0 + 1.5) * m, 0.55 + 0.25 * (0.5 + 0.5 * sin(t * 2.4 + PI)), 0.3, 1.0)  # alternate: one closes while the other opens
		"detox":
			_lobe(out, "mouth", face + PI * 0.5, 0.42 + 0.14 * sin(t * 2.6), 0.38, 1.0)
			_lobe(out, "vent", face - PI * 0.5, 0.22 + 0.08 * sin(t * 2.6 + PI), 0.3, 1.0)
		"signal":
			_lobe(out, "send", aim, 0.45 + 0.2 * (0.5 + 0.5 * sin(t * 3.6)), 0.22, 1.2)
		"seal":
			_lobe(out, "reach", aim + sin(t * 2.2) * 0.1 * m, 0.5 + 0.4 * p, 0.34, 1.0)
		"feed":
			for i in 3:
				var lag := sin(t * 1.8 - i * 1.4)  # the limbs reach in turn
				_lobe(out, "limb%d" % i, ph + 0.5 + i * TAU / 3.0 + 0.05 * lag * m, 0.78 + 0.22 * (0.5 + 0.5 * lag), 0.15, 0.8)
	return out


## The whole body: where it leans (a fraction of its radius, towards the work), how much it stretches along its heading, how fast it
## breathes. The renderer adds the drag behind the cell from its real velocity.
static func body(ctx: Dictionary) -> Dictionary:
	var phase: StringName = ctx["phase"]
	var aim: Vector2 = ctx["aim_vec"]
	var t: float = ctx["t"] * float(ctx["tempo"])
	var m: float = ctx["motion"]
	var lean := Vector2.ZERO
	var stretch: float = 0.3 * float(ctx["speed"])
	if phase == BioInteractionState.ACT or phase == BioInteractionState.PROGRESS:
		var gesture := str(ctx["gesture"])
		var push := 0.25
		match gesture:
			"defend":
				push = 0.18 * (0.5 + 0.5 * sin(t * 6.0))  # a braced pulse
			"engulf":
				push = 0.3
			"patrol":
				push = 0.08
		lean = aim * push
	elif phase == BioInteractionState.ANTICIPATE:
		lean = -aim * 0.14  # gathers back before the work
	elif phase == BioInteractionState.BLOCKED or phase == BioInteractionState.HELP:
		lean = aim * 0.1 * (0.5 + 0.5 * sin(t * 5.0))
	elif phase == BioInteractionState.IDLE or phase == BioInteractionState.RECOVER:
		lean = Vector2(sin(t * 0.43 + float(ctx["phase_offset"])), cos(t * 0.37)) * 0.1  # drifts a little
	return {"lean": lean * m, "stretch": stretch * m, "breath": 1.0 + 0.04 * sin(t * 1.9 + float(ctx["phase_offset"])) * m}


## One spring step (semi-implicit): follows `target` with some overshoot; k scales the stiffness for this part. Stable for any dt.
static func spring(value: float, velocity: float, target: float, delta: float, k: float = 1.0) -> Vector2:
	var stiff := 60.0 * k
	var damp := 8.5 * sqrt(k)
	var left := minf(delta, 0.25)
	var v := velocity
	var x := value
	while left > 0.0:
		var dt := minf(left, 1.0 / 60.0)
		v += (stiff * (target - x) - damp * v) * dt
		x += v * dt
		left -= dt
	return Vector2(x, v)
