class_name BioNetInterpolation
extends RefCounted
## Remote presentation only: interpolation history, then short bounded extrapolation.
const MAX_EXTRAPOLATION := 0.12
var samples: Array[Dictionary] = []
var capacity := 24

func push(time: float, point: Vector2, velocity: Vector2) -> void:
	if not samples.is_empty() and time <= float(samples.back().time): return
	if not samples.is_empty() and point.distance_to(samples.back().point) > 12.0 * 48:
		samples.clear()
	samples.append({"time":time, "point":point, "velocity":velocity})
	while samples.size() > capacity: samples.pop_front()

func sample(time: float) -> Vector2:
	if samples.is_empty(): return Vector2.ZERO
	if time <= float(samples.front().time): return samples.front().point
	for i in range(1, samples.size()):
		var a := samples[i - 1]
		var b := samples[i]
		if time <= float(b.time):
			return (a.point as Vector2).lerp(b.point, clampf((time - float(a.time)) / (float(b.time) - float(a.time)), 0, 1))
	var last: Dictionary = samples.back()
	return (last.point as Vector2) + (last.velocity as Vector2) * clampf(time - float(last.time), 0, MAX_EXTRAPOLATION)
