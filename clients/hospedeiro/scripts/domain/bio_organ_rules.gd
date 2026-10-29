class_name BioOrganRules
extends RefCounted
## What the player reads of an organ: its health (the engine's numbers), how to say it, and what the player did there. Every part of the
## body always has work; this only words and colours what the engine reports. Pure.


static func health_color(health: int) -> Color:
	if health < 35:
		return Color(1.0, 0.35, 0.4)
	if health < 60:
		return Color(1.0, 0.65, 0.3)
	if health < 80:
		return Color(0.95, 0.9, 0.4)
	return Color(0.45, 1.0, 0.7)


static func health_word(health: int) -> String:
	if health < 35:
		return "crítica"
	if health < 60:
		return "frágil"
	if health < 80:
		return "regular"
	if health < 95:
		return "boa"
	return "ótima"


## The entry of an organ in the engine's list (empty when it is not there).
static func entry(organs: Array, id: String) -> Dictionary:
	for o in organs:
		if o is Dictionary and str(o.get("id", "")) == id:
			return o
	return {}


## "+4" / "-2" / "0": how much the health moved since the player arrived.
static func delta_text(now: int, then: int) -> String:
	var d := now - then
	return "+%d%%" % d if d > 0 else "%d%%" % d if d < 0 else "estável"


## The role chips: "Cura 1/3" (who is in the organ over what it asks).
static func crew_text(needs: Array) -> String:
	var parts: Array = []
	for n in needs:
		parts.append("%s %d/%d" % [BioCallingRules.role_name(str(n.get("role", ""))), int(n.get("covered", 0)), int(n.get("weight", 0))])
	return "  ·  ".join(parts)


## A name for a deed (an action the game server confirmed), for the player's own log.
static func deed_label(action: String) -> String:
	if action.begins_with("terreno-"):
		var rest := action.trim_prefix("terreno-")
		var verb := rest.split("-")[0]
		var info := BioTerrainRules.info(verb)
		if not info.is_empty():
			return str(info["name"])
	if action.begins_with("entregar-"):
		return "Entrega"
	match action:
		"selar-ferida-pele", "conter-infeccao-pulmonar", "repelir-invasor", "capturar-antigeno", "acalmar-reacao-linfonodo", "amparar-neuronios-cerebro":
			return "Invasor derrotado"
		"nutrir-nicho-medular", "equilibrar-sal":
			return "Nutrientes"
	return action.replace("-", " ").capitalize()


## The lines of the player's own work: the engine's confirmed deeds of this organ, most done first.
static func deed_lines(deeds: Array) -> Array:
	var out: Array = []
	for d in deeds:
		out.append("%s  ×%d" % [str(d.get("title", d.get("action", ""))).trim_prefix("Rotina: "), int(d.get("count", 0))])
	return out


## What the player's calling can do here, and what only other callings can (so the choice of calling means something).
static func can_do(region: String, role: String, has_crisis: bool, crisis_def: String) -> Dictionary:
	var def := crisis_def if has_crisis else "organ-" + region
	var mine: Array = []
	var others: Array = []
	for v in BioTerrainRules.verbs_for(def):
		var line := "%s: %s" % [str(BioTerrainRules.info(v)["name"]), BioTerrainRules.prop_name(def, v)]
		if BioTerrainRules.can(v, role):
			mine.append(line)
		else:
			others.append("%s (%s)" % [line, BioTerrainRules.role_text(v)])
	return {"mine": mine, "others": others}
