class_name BioLivingSound
extends Node
## Short original tones for the living body (synthesised, no assets): a soft pair for a delivery, a low pulse for a crisis, a rising
## triad for a resolution, a chirp for a call for help. Quiet by default, optional, and silent on a headless server. Sound is never
## the only carrier of a message: every cue has text and a shape too.

const RATE := 22050
const TONES := {
	&"confirmed": [[660.0, 0.12], [880.0, 0.16]],
	&"start": [[220.0, 0.22], [196.0, 0.26]],
	&"escalate": [[196.0, 0.16], [147.0, 0.16], [196.0, 0.16], [147.0, 0.2]],
	&"contain": [[392.0, 0.14], [330.0, 0.2]],
	&"recover": [[440.0, 0.12], [523.0, 0.16]],
	&"resolve": [[523.0, 0.12], [659.0, 0.12], [784.0, 0.24]],
	&"help": [[740.0, 0.07], [988.0, 0.1]],
}

var enabled := true
var volume_db := -20.0
var _player: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)


func play(kind: StringName, gain_db: float = 0.0) -> void:
	if not enabled or _player == null or not TONES.has(kind):
		return
	if not _cache.has(kind):
		_cache[kind] = _make(TONES[kind])
	_player.stream = _cache[kind]
	_player.volume_db = volume_db + gain_db
	_player.play()


static func _make(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for n in notes:
		var freq: float = n[0]
		var count := int(RATE * float(n[1]))
		for i in count:
			var env := minf(1.0, float(i) / (RATE * 0.01)) * (1.0 - float(i) / count)
			var v := int(sin(TAU * freq * i / RATE) * env * env * 0.5 * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
