class_name BioNetActions
extends RefCounted
## Local reservations are provisional. Snapshots acknowledge or reject each token.
var serial := 0
var pending: Dictionary = {}
var shown: Dictionary = {}
var resolved: Dictionary = {}
var result_ack := 0

func reserve(actor: BioActor, id: StringName, now: float, repress := false) -> int:
	if not actor.vitals.is_alive(): return -BioActor.AttackStatus.DEAD
	var status := BioActor.AttackStatus.STARTED if repress else actor.try_begin_attack(id, now)
	if status != BioActor.AttackStatus.STARTED: return -status
	serial += 1
	var definition := actor.attack_def(id)
	pending[serial] = {"id":id, "cost":0.0 if repress else definition.atp_cost, "expires":0.0 if repress else now + definition.cooldown, "frame":-1}
	shown[serial] = true
	while shown.size() > 256: shown.erase(shown.keys()[0])
	return serial

func bind_frame(tokens: Array, frame: int) -> void:
	for token in tokens:
		if pending.has(int(token)): pending[int(token)].frame = frame

func acknowledge(frame: int) -> void:
	for token in pending.keys():
		if int(pending[token].frame) >= 0 and int(pending[token].frame) <= frame: pending.erase(token)

func reserved_atp() -> float:
	var cost := 0.0
	for item in pending.values(): cost += float(item.cost)
	return cost

func apply_cooldowns(actor: BioActor, confirmed: Dictionary, now: float, round_trip: float) -> void:
	actor._ready_at.clear()
	for id in confirmed:
		actor._ready_at[StringName(id)] = now + maxf(0, float(confirmed[id]) - round_trip)
	for item in pending.values():
		actor._ready_at[item.id] = maxf(float(actor._ready_at.get(item.id, 0)), float(item.expires))

func clear() -> void:
	pending.clear()
	shown.clear()
	resolved.clear()
	result_ack = 0

func resolve_results(actor: BioActor, results: Array, now: float, server_time: float, round_trip: float) -> Array[int]:
	var rejected: Array[int] = []
	for result in results:
		var token := int(result.get("token", 0))
		if token <= 0 or resolved.has(token): continue
		resolved[token] = true
		result_ack = maxi(result_ack, token)
		while resolved.size() > 256: resolved.erase(resolved.keys()[0])
		var status := int(result.get("status", 0))
		if status != BioActor.AttackStatus.STARTED:
			rejected.append(token)
			if status == BioActor.AttackStatus.ON_COOLDOWN:
				var id := StringName(str(result.get("attack_id", "")))
				var age := maxf(0, server_time - float(result.get("time", server_time))) + round_trip * 0.5
				actor._ready_at[id] = now + maxf(0, float(result.get("cooldown", 0)) - age)
	return rejected
