class_name BioVitals
extends RefCounted

var max_membrane: float
var membrane: float
var max_atp: float
var atp: float
var atp_regen_per_second: float
var regen_scale := 1.0  # the body's state (fever, a lung short of air) scales how fast energy comes back


func _init(p_max_membrane: float, p_max_atp: float, p_atp_regen_per_second: float) -> void:
	assert(p_max_membrane > 0.0)
	max_membrane = p_max_membrane
	membrane = p_max_membrane
	max_atp = maxf(0.0, p_max_atp)
	atp = max_atp
	atp_regen_per_second = maxf(0.0, p_atp_regen_per_second)


## Applies new maxima (e.g. after a mutation) keeping the current fractions of membrane and ATP.
func rescale(p_max_membrane: float, p_max_atp: float, p_atp_regen_per_second: float) -> void:
	var membrane_fraction := membrane / max_membrane
	var atp_fraction := atp / max_atp if max_atp > 0.0 else 1.0
	max_membrane = maxf(1.0, p_max_membrane)
	max_atp = maxf(0.0, p_max_atp)
	atp_regen_per_second = maxf(0.0, p_atp_regen_per_second)
	if membrane > 0.0:
		membrane = maxf(0.01, max_membrane * membrane_fraction)
	atp = max_atp * atp_fraction


func is_alive() -> bool:
	return membrane > 0.0


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0
	var applied := minf(amount, membrane)
	membrane -= applied
	return applied


func repair(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	membrane = minf(max_membrane, membrane + amount)


func try_spend_atp(cost: float) -> bool:
	if cost < 0.0 or atp < cost:
		return false
	atp -= cost
	return true


func add_atp(amount: float) -> void:
	if amount <= 0.0:
		return
	atp = minf(max_atp, atp + amount)


func tick(delta: float) -> void:
	if is_alive() and delta > 0.0:
		add_atp(atp_regen_per_second * regen_scale * delta)
