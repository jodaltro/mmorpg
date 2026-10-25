class_name BioPartyBuild
extends RefCounted
## A visiting character supplies catalogue choices, never damage, HP or inventory.


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value if value is Array else []


static func clean(raw: Dictionary) -> Dictionary:
	var lineage := BioLineageCatalog.normalise(str(_dict(raw.get("lineage")).get("current", "")))
	if BioLineageCatalog.mods_of(lineage).is_empty(): lineage = &""
	var genes: Array = []
	var seen := {}
	for gene in _array(_dict(raw.get("evolution")).get("genes")):
		if not gene is Dictionary: continue
		var id := StringName(str(gene.get("id", "")).replace("-", "_"))
		if BioGeneCatalog.all_ids().has(id) and not seen.has(id) and genes.size() < BioGenome.SLOTS:
			seen[id] = true
			genes.append({"id": str(id)})
	var skills: Array = []
	seen.clear()
	for skill in _array(raw.get("skills")):
		if not skill is Dictionary: continue
		var id := BioAbilityCatalog.normalise(str(skill.get("id", "")))
		if BioAbilityCatalog.has(id) and not seen.has(id):
			seen[id] = true
			skills.append({"id": str(id)})
	var traits := {}
	var look := _dict(raw.get("look"))
	for key in _dict(look.get("traits")):
		var value: Variant = look.traits[key]
		if str(key).length() <= 48 and value is String and value.length() <= 48 and traits.size() < 32:
			traits[str(key)] = value
	var axes := {}
	for key in _dict(look.get("axes")):
		var value: Variant = look.axes[key]
		if str(key).length() <= 48 and (value is float or value is int) and is_finite(float(value)) and axes.size() < 32:
			axes[str(key)] = clampi(int(value), 0, 100)
	return {"lineage": {"current": str(lineage)}, "evolution": {"genes": genes}, "skills": skills, "look":{"traits":traits,"axes":axes}, "explore":_explore(_dict(raw.get("explore")))}


static func _explore(raw: Dictionary) -> Dictionary:
	var out := {"passages":[],"niches":[],"adapted":[],"route":str(raw.get("route", "")).left(64)}
	var regions: Array = BioAnatomy.definition().regions.map(func(r: Dictionary) -> String: return str(r.id))
	for passage in _array(raw.get("passages")).slice(0,64):
		if not passage is Dictionary: continue
		var id := str(passage.get("id", "")).left(64)
		if BioAnatomy.link_point(1337, StringName(id), 0.5).is_empty(): continue
		out.passages.append({"id":id,"from":str(passage.get("from", "")).left(64),"to":str(passage.get("to", "")).left(64),"open":bool(passage.get("open", false)),"hint":str(passage.get("hint", "")).left(200)})
	for niche in _array(raw.get("niches")).slice(0,64):
		if not niche is Dictionary or not regions.has(str(niche.get("region", ""))): continue
		out.niches.append({"id":str(niche.get("id", "")).left(64),"region":str(niche.region),"found":bool(niche.get("found", false)),"hint":str(niche.get("hint", "")).left(200)})
	for region in _array(raw.get("adapted")).slice(0,32):
		if regions.has(str(region)): out.adapted.append(str(region))
	return out
