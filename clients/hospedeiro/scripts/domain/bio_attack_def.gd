class_name BioAttackDef
extends RefCounted

var id: StringName
var atp_cost: float
var damage: float
var cooldown: float
var range_units: float
var knockback: float
var invulnerable_seconds: float
var presentation_token := 0
var presentation_owner := ""

func with_presentation(owner_id: String, token: int) -> BioAttackDef:
	var copy := BioAttackDef.new(id, atp_cost, damage, cooldown, range_units, knockback, invulnerable_seconds)
	copy.presentation_token = token
	copy.presentation_owner = owner_id
	return copy


func _init(p_id: StringName, p_atp_cost: float, p_damage: float, p_cooldown: float, p_range_units: float, p_knockback: float, p_invulnerable_seconds: float) -> void:
	id = p_id
	atp_cost = p_atp_cost
	damage = p_damage
	cooldown = p_cooldown
	range_units = p_range_units
	knockback = p_knockback
	invulnerable_seconds = p_invulnerable_seconds
