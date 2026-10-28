class_name BioCallingRules
extends RefCounted
## The callings: the class the crisis where you stand asks of you. The engine decides the offer (what the crisis needs and who already
## covers it); here it is only turned into words and into the form the player's cell takes while the calling is held. Pure.

const ROLES := {
	"combate": {"name": "Combate", "color": Color(1.0, 0.45, 0.45), "does": "enfrenta os invasores"},
	"limpeza": {"name": "Limpeza", "color": Color(1.0, 0.8, 0.4), "does": "recolhe o que sobra e engole o que não devia estar ali"},
	"cura": {"name": "Cura", "color": Color(0.5, 1.0, 0.7), "does": "sustenta quem trabalha e repara o tecido"},
	"controle": {"name": "Controle", "color": Color(0.6, 0.75, 1.0), "does": "acalma a reação e segura a inflamação"},
	"marcacao": {"name": "Marcação", "color": Color(0.85, 0.65, 1.0), "does": "marca os alvos e leva o que descobriu aos outros"},
}
const ABILITIES_PER_FORM := 2


static func role_name(role: String) -> String:
	return str(ROLES.get(role, {}).get("name", role.capitalize()))


static func role_color(role: String) -> Color:
	return ROLES.get(role, {}).get("color", BioUi.ACCENT)


## True when the engine offers the player a choice right now.
static func is_choosing(view: Dictionary) -> bool:
	return str(view.get("current", "")).is_empty() and not (view.get("offer", []) as Array).is_empty()


## The player holds a calling.
static func is_held(view: Dictionary) -> bool:
	return not str(view.get("current", "")).is_empty()


## The lineage whose body the cell wears while the calling is held, or &"" for the base form.
static func form_of(view: Dictionary) -> StringName:
	var form := str(view.get("form", ""))
	return BioLineageCatalog.normalise(form) if not form.is_empty() else &""


## How much the crisis still needs this role, in words.
static func need_text(option: Dictionary) -> String:
	var missing := int(option.get("missing", 0))
	if missing > 0:
		return "Faltam %d" % missing if missing > 1 else "Falta 1"
	return "Coberto"


## The line under the title of an option: what the role does and whether it is the one missing.
static func option_text(option: Dictionary) -> String:
	var role := str(option.get("role", ""))
	var does := str(ROLES.get(role, {}).get("does", ""))
	var lean := "  ·  é o que mais falta" if bool(option.get("gap", false)) else ""
	return "%s\n%s%s" % [str(option.get("desc", "")), does.capitalize() if does != "" else "", lean]


## The abilities the form lends: its first ones, those the player does not know already.
static func lent_abilities(form: StringName, known: Array) -> Array:
	var out: Array = []
	if form == &"":
		return out
	for id in BioAbilityCatalog.ids_of_class(form):
		if out.size() >= ABILITIES_PER_FORM:
			break
		if not known.has(id):
			out.append(id)
	return out
