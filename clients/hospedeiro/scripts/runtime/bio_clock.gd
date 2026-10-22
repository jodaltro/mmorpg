class_name BioClock
extends RefCounted


static func now() -> float:
	return Time.get_ticks_msec() * 0.001
