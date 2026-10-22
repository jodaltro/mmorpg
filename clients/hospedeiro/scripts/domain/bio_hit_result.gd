class_name BioHitResult
extends RefCounted

var outcome: int
var damage_applied: float


func _init(p_outcome: int, p_damage_applied: float) -> void:
	outcome = p_outcome
	damage_applied = p_damage_applied
