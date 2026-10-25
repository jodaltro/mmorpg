class_name BioNetInputBuffer
extends RefCounted
## Input ticks, not client-supplied elapsed time, consume the server's simulation budget.
const STEP := 1.0 / 60.0
var frames: Array[Dictionary] = []
var received := -1
var credit := 0.0
var next_sequence := -1

func push(raw: Variant) -> void:
	if not raw is Array: return
	for value in raw.slice(0, 4):
		if not value is Dictionary: continue
		var frame := BioNetProtocol.input(value, -1)
		if frame.is_empty(): continue
		var seq := int(frame.seq)
		if next_sequence < 0: next_sequence = seq
		if seq < next_sequence: continue
		if frames.any(func(held: Dictionary) -> bool: return int(held.seq) == seq): continue
		received = maxi(received, seq)
		if frames.size() < 150: frames.append(frame)
	frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))

func take(delta: float) -> Array[Dictionary]:
	credit = minf(credit + maxf(0, delta), 5.0)
	var result: Array[Dictionary] = []
	while not frames.is_empty() and credit + 0.000001 >= STEP and result.size() < 3 and int(frames[0].seq) == next_sequence:
		result.append(frames.pop_front())
		next_sequence += 1
		credit -= STEP
	return result

func missing() -> Array[int]:
	var present := {}
	for frame in frames: present[int(frame.seq)] = true
	var result: Array[int] = []
	for seq in range(maxi(0, next_sequence), mini(received + 1, next_sequence + 150)):
		if not present.has(seq): result.append(seq)
		if result.size() >= 32: break
	return result
