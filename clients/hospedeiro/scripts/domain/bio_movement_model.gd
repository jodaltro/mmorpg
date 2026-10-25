class_name BioMovementModel
extends RefCounted
## The same thrust/drag/cap calculation is used by authority and movement prediction.

static func step(velocity: Vector2, intent: Vector2, delta: float, thrust: float, maximum: float, damping: float, speed: float, unit: float) -> Vector2:
	velocity += intent.limit_length(1.0) * thrust * speed * unit * delta
	velocity -= velocity * minf(1.0, damping * delta)
	var cap := maximum * speed * unit
	if velocity.length() > cap:
		velocity = velocity.move_toward(velocity.normalized() * cap, 60.0 * unit * delta)
	return velocity
