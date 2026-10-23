class_name BioCombatState
extends RefCounted
## Whether the cell is in the middle of a fight. Anything that asks for the player's attention (a call for a quest, a choice of genes)
## waits for calm: no threat, no hit taken and no attack made for CALM_AFTER seconds. Pure: whoever watches the world tells it
## when something threatening happens; it only keeps the time of the last one.

const CALM_AFTER := 4.0

var _last_threat := -1000.0


## Something threatening is happening now (an enemy closing in, a hit taken or given, a dungeon room under way).
func note_threat(now: float) -> void:
	_last_threat = maxf(_last_threat, now)


func in_combat(now: float) -> bool:
	return now - _last_threat < CALM_AFTER


func is_calm(now: float) -> bool:
	return not in_combat(now)


## Seconds left until the fight counts as over (0 when calm).
func calm_in(now: float) -> float:
	return maxf(0.0, CALM_AFTER - (now - _last_threat))


func reset() -> void:
	_last_threat = -1000.0
