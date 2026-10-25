class_name BioNetLagHistory
extends RefCounted
## Geometry history only. Health, rewards and world state are never rewound.
const MAX_REWIND := 0.5
var tracks: Dictionary = {}

func record(id: int, time: float, point: Vector2) -> void:
	if not tracks.has(id):
		tracks[id] = BioNetInterpolation.new()
		(tracks[id] as BioNetInterpolation).capacity = 40
	(tracks[id] as BioNetInterpolation).push(time, point, Vector2.ZERO)

func point(id: int, requested: float, now: float, current: Vector2) -> Vector2:
	if not tracks.has(id): return current
	return (tracks[id] as BioNetInterpolation).sample(clampf(requested, now - MAX_REWIND, now))

func prune(live: Array[int]) -> void:
	for id in tracks.keys():
		if not live.has(id): tracks.erase(id)
