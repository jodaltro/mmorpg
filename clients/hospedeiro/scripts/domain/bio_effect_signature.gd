class_name BioEffectSignature
extends RefCounted
## The flavour Jev designed for every ability of a cell (trait "efeito"): the same ability burns on one cell, crystallises on another,
## crackles or grows on a third. It only changes how effects look and move (tint and the shape of the limbs), never their numbers, so
## balance is untouched. Pure: no nodes.

const STYLES := [&"chama", &"cristal", &"nevoa", &"eletrico", &"organico"]


static func tint(color: Color, style: StringName) -> Color:
	match style:
		&"chama":
			return color.lerp(Color(1.0, 0.45, 0.12), 0.55)
		&"cristal":
			return color.lerp(Color(0.72, 0.95, 1.0), 0.5)
		&"nevoa":
			return color.lerp(Color(0.82, 0.76, 1.0), 0.4)
		&"eletrico":
			return color.lerp(Color(0.55, 0.8, 1.0), 0.5).lightened(0.15)
		&"organico":
			return color.lerp(Color(0.55, 1.0, 0.4), 0.45)
		_:
			return color


## Overrides for the limb style (tip shape, stiffness, waving) of an ability effect; empty keeps the ability's own.
static func limb_style(style: StringName) -> Dictionary:
	match style:
		&"chama":
			return {"tip": &"fork", "wave": 0.65, "stiffness": 0.22}
		&"cristal":
			return {"tip": &"spear", "wave": 0.02, "stiffness": 0.97, "barbs": 3}
		&"nevoa":
			return {"tip": &"blob", "wave": 0.9, "stiffness": 0.08}
		&"eletrico":
			return {"tip": &"fork", "wave": 1.0, "stiffness": 0.12}
		&"organico":
			return {"tip": &"blob", "bumps": 3, "wave": 0.3, "stiffness": 0.3}
		_:
			return {}


## The options of one limb with the signature applied: the tint is shifted and the style keys overridden.
static func sign_options(opts: Dictionary, style: StringName) -> Dictionary:
	if not STYLES.has(style):
		return opts
	var out := opts.duplicate()
	if out.has("tint"):
		out["tint"] = tint(out["tint"], style)
	var s: Dictionary = (out.get("style", {}) as Dictionary).duplicate()
	s.merge(limb_style(style), true)
	out["style"] = s
	return out
