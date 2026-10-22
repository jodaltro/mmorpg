class_name BioAttackDef
extends RefCounted

var id: StringName
var atp_cost: float
var damage: float
var cooldown: float
var range_units: float
var knockback: float
var invulnerable_seconds: float


func _init(p_id: StringName, p_atp_cost: float, p_damage: float, p_cooldown: float, p_range_units: float, p_knockback: float, p_invulnerable_seconds: float) -> void:
	id = p_id
	atp_cost = p_atp_cost
	damage = p_damage
	cooldown = p_cooldown
	range_units = p_range_units
	knockback = p_knockback
	invulnerable_seconds = p_invulnerable_seconds
