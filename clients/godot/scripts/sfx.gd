class_name Sfx
extends Node
## Small synthesized sounds, generated at start (no audio files): feedback for steps, blows, menus,
## discoveries, the bell, thunder, rain. They are cues, not music: quiet and short.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var steps_played := 0  # for tests: how many footsteps were triggered
var plays := {}  # cue -> times played (tests)


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


## Plays a named cue; skips quietly if every voice is busy.
func play(cue: String, db := -8.0, pitch := 1.0) -> void:
	if not _streams.has(cue):
		return
	plays[cue] = int(plays.get(cue, 0)) + 1
	for p in _players:
		if not p.playing:
			p.stream = _streams[cue]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


## Starts (or keeps) a looping bed, like rain; stop_loop ends it.
func loops_running() -> int:
	return _loops.size()


func loop(cue: String, db := -22.0) -> void:
	if _loops.has(cue) or not _streams.has(cue):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[cue]
	p.volume_db = db
	add_child(p)
	p.play()
	_loops[cue] = p


func stop_loop(cue: String) -> void:
	if _loops.has(cue):
		_loops[cue].queue_free()
		_loops.erase(cue)


func has_cue(cue: String) -> bool:
	return _streams.has(cue)


func cue_count() -> int:
	return _streams.size()


# --- synthesis ------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


## Noise through a one-pole low-pass (lp 0..1: lower is duller), shaped by an envelope function of t in 0..1.
func _noise(seconds: float, lp: float, env: Callable, seed := 1) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var y := 0.0
	for i in n:
		y += (rng.randf_range(-1.0, 1.0) - y) * lp
		out[i] = y * float(env.call(float(i) / n))
	return out


## A decaying sine (a partial of a bell or chime), added into out starting at `start` seconds.
func _tone(out: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, decay := 4.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		if i0 + i >= out.size():
			return
		var t := float(i) / RATE
		out[i0 + i] += sin(TAU * freq * t) * amp * exp(-decay * t / dur) * minf(1.0, t * 200.0)


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _build() -> void:
	_streams["click"] = _wav(_noise(0.04, 0.5, func(t): return (1.0 - t) * 0.6, 3))
	_streams["step"] = _wav(_noise(0.07, 0.12, func(t): return sin(PI * t) * 0.9, 5))
	_streams["swing"] = _wav(_noise(0.16, 0.35, func(t): return sin(PI * t) * 0.5, 7))
	var hit := _noise(0.14, 0.18, func(t): return exp(-6.0 * t) * 0.9, 9)
	_tone(hit, 0.0, 95.0, 0.14, 0.7, 5.0)
	_streams["hit"] = _wav(hit)
	var chime := _silence(0.9)
	_tone(chime, 0.0, 880.0, 0.7, 0.35, 5.0)
	_tone(chime, 0.12, 1320.0, 0.7, 0.3, 5.0)
	_streams["chime"] = _wav(chime)
	var bell := _silence(1.8)
	for pair in [[220.0, 0.5], [440.0, 0.35], [660.0, 0.2], [990.0, 0.12]]:
		_tone(bell, 0.0, pair[0], 1.8, pair[1], 3.0)
	_streams["bell"] = _wav(bell)
	_streams["thunder"] = _wav(_noise(1.8, 0.05, func(t): return (sin(PI * minf(t * 3.0, 1.0)) * exp(-2.5 * t)) * 1.6, 11))
	_streams["torch"] = _wav(_noise(0.5, 0.3, func(t): return sin(PI * t) * 0.55, 13))
	var mark := _silence(0.25)
	_tone(mark, 0.0, 520.0, 0.12, 0.4, 3.0)
	_tone(mark, 0.08, 700.0, 0.16, 0.4, 3.0)
	_streams["mark"] = _wav(mark)
	var open := _silence(0.2)
	_tone(open, 0.0, 400.0, 0.2, 0.25, 6.0)
	_streams["open"] = _wav(open)
	_streams["rain"] = _wav(_noise(2.0, 0.55, func(t): return 0.45, 17), true)
	var wish := _silence(1.2)
	for i in 5:
		_tone(wish, i * 0.14, 1000.0 + i * 260.0, 0.5, 0.22, 4.0)
	_streams["star"] = _wav(wish)
