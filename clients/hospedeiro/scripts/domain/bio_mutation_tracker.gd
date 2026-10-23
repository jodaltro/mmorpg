class_name BioMutationTracker
extends RefCounted
## Evolutionary pressure: confirmed events (kills, food, evasions) fill a gauge; when it overflows the
## world offers up to three candidate mutations. At most one offer is pending, it can be accepted,
## declined or ignored, and a declined offer is not repeated right away.

const THRESHOLD := 30  # three times the first value: see tools/tune_pacing.py
const KILL_POINTS := 3
const NUTRIENT_POINTS := 1
const EVADE_POINTS := 2
const OFFER_SIZE := 3

var pressure := 0
var offer: Array[StringName] = []
var declined: Array[StringName] = []

var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed


func has_offer() -> bool:
	return not offer.is_empty()


## Returns true when this event created a new offer. Events during a pending offer are not banked.
func add_pressure(points: int, genome: BioGenome) -> bool:
	if has_offer() or points <= 0:
		return false
	pressure += points
	if pressure < THRESHOLD:
		return false
	var candidates := _candidates(genome)
	if candidates.is_empty():
		pressure = THRESHOLD  # nothing left to offer: stay ready instead of overflowing
		return false
	pressure -= THRESHOLD
	for i in mini(OFFER_SIZE, candidates.size()):
		var pick := _rng.randi() % candidates.size()
		offer.append(candidates[pick])
		candidates.remove_at(pick)
	return true


## Accepts offer[index]. Returns the gene id that was reabsorbed to make room (or &"").
func choose(index: int, genome: BioGenome) -> StringName:
	if index < 0 or index >= offer.size():
		return &""
	var replaced := genome.equip(offer[index])
	offer.clear()
	declined.clear()
	return replaced


func decline() -> void:
	declined = offer.duplicate()
	offer.clear()


func _candidates(genome: BioGenome) -> Array:
	var all := BioGeneCatalog.all_ids().filter(func(id: StringName) -> bool:
		var need := BioGeneCatalog.get_gene(id).requires_lineage
		return not genome.has_gene(id) and (need == &"" or need == genome.lineage))
	var fresh := all.filter(func(id: StringName) -> bool: return not declined.has(id))
	# If declining left too few options, allow the declined ones back.
	return fresh if fresh.size() >= OFFER_SIZE or fresh.size() == all.size() else all


func to_dict() -> Dictionary:
	return {
		"pressure": pressure,
		"declined": declined.map(func(id: StringName) -> String: return String(id)),
	}


func load_dict(data: Dictionary) -> void:
	pressure = clampi(int(data.get("pressure", 0)), 0, THRESHOLD)
	declined.clear()
	var known := BioGeneCatalog.all_ids()
	for raw in data.get("declined", []):
		var id := StringName(str(raw))
		if known.has(id) and not declined.has(id):
			declined.append(id)
