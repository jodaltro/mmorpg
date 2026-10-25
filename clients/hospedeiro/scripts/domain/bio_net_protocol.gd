class_name BioNetProtocol
extends RefCounted
## The online input contract: finite vectors, monotonic sequence and a bounded list of intents.

static func vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not value is Array or value.size() != 2:
		return fallback
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int):
		return fallback
	var v := Vector2(float(value[0]), float(value[1]))
	return v.limit_length(1.0) if v.is_finite() else fallback


static func input(packet: Dictionary, last_sequence: int) -> Dictionary:
	var raw_sequence: Variant = packet.get("seq", -1)
	if not (raw_sequence is int or raw_sequence is float) or not is_finite(float(raw_sequence)) or float(raw_sequence) < 0 or float(raw_sequence) > 2147483647:
		return {}
	var seq := int(raw_sequence)
	if seq <= last_sequence:
		return {}
	var actions: Array[String] = []
	var raw: Variant = packet.get("actions", [])
	if raw is Array:
		for value in raw.slice(0, 4):
			var s := str(value)
			if s in ["lash", "spit", "dash", "respawn"] or (s.begins_with("ability:") and s.length() <= 80):
				actions.append(s)
	var tokens: Array[int] = []
	var raw_tokens: Variant = packet.get("tokens", [])
	for i in actions.size():
		var token: Variant = raw_tokens[i] if raw_tokens is Array and i < raw_tokens.size() else 0
		tokens.append(int(token) if (token is int or token is float) and is_finite(float(token)) and float(token) > 0 and float(token) < 2147483647 else 0)
	var view: Variant = packet.get("view_time", 0)
	return {"seq": seq, "move": vector(packet.get("move")), "aim": vector(packet.get("aim"), Vector2.RIGHT), "actions": actions, "tokens":tokens,"view_time":float(view) if (view is int or view is float) and is_finite(float(view)) else 0.0}


static func xy(value: Vector2) -> Array:
	return [snappedf(value.x, 0.1), snappedf(value.y, 0.1)]


static func coalesce_snapshot(previous: Dictionary, next: Dictionary) -> Dictionary:
	if previous.is_empty(): return next
	if int(next.get("seq",-1)) <= int(previous.get("seq",-1)): return previous
	var older := {}
	for entity in previous.get("entities", []): older[str(entity.id)] = entity
	var entities: Array = []
	for entity in next.get("entities", []):
		var merged: Dictionary = older.get(str(entity.id), {}).duplicate()
		merged.merge(entity, true)
		entities.append(merged)
	var result := next.duplicate()
	result["entities"] = entities
	result["events"] = previous.get("events", []) + next.get("events", [])
	return result


static func visual(value: Variant, decode := false) -> Variant:
	if not decode:
		if value is Vector2: return {"v2": [value.x, value.y]}
		if value is Color: return {"rgba": [value.r,value.g,value.b,value.a]}
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return visual(v, decode))
	if value is Dictionary:
		if decode and value.has("v2"): return Vector2(float(value.v2[0]),float(value.v2[1]))
		if decode and value.has("rgba"): return Color(float(value.rgba[0]),float(value.rgba[1]),float(value.rgba[2]),float(value.rgba[3]))
		var out := {}
		for key in value: out[key] = visual(value[key],decode)
		return out
	return value
