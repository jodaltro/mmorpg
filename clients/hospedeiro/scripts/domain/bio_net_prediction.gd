class_name BioNetPrediction
extends RefCounted
## Replays only movement not yet acknowledged by the server. Never predicts health, hits or rewards.

var frames: Array[Dictionary] = []

func remember(seq: int, delta: float, intent: Vector2, dash: Vector2 = Vector2.ZERO, distance := 0.0) -> void:
	frames.append({"seq":seq,"dt":clampf(delta,0.0,0.05),"intent":intent.limit_length(1.0),"dash":dash,"distance":distance})
	while frames.size() > 150: frames.pop_front()

func acknowledge(seq: int) -> void:
	frames = frames.filter(func(frame: Dictionary) -> bool: return int(frame.seq)>seq)

func clear() -> void:
	frames.clear()

static func velocity(current: Vector2, intent: Vector2, delta: float, motion: Dictionary) -> Vector2:
	if bool(motion.get("ballistic", false)) and float(motion.get("ballistic_seconds", 1)) > 0:
		motion["ballistic_seconds"] = maxf(0, float(motion.get("ballistic_seconds", 1)) - delta)
		var v: Array = motion.get("velocity", [0,0])
		return Vector2(float(v[0]),float(v[1]))
	if bool(motion.get("stunned", false)):
		return current * maxf(0.0,1.0-float(motion.get("damping",3.5))*2.0*delta)
	return BioMovementModel.step(current,intent,delta,float(motion.get("thrust",42)),float(motion.get("maximum",7)),float(motion.get("damping",3.5)),float(motion.get("speed",1)),float(motion.get("unit",1)))

static func begin_dash(motion: Dictionary, direction: Vector2, distance: float) -> void:
	motion["ballistic"] = true
	motion["ballistic_seconds"] = 0.18
	var v := direction.normalized() * distance * float(motion.get("unit", 48)) / 0.18
	motion["velocity"] = [v.x, v.y]
