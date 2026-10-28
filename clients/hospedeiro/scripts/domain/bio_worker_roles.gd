class_name BioWorkerRoles
extends RefCounted
## What each cohort of the body does where the player can see it. The engine counts the neutrophils of the lung and says how much work they
## do; here a few of them are drawn doing it: the defenders hunt the invaders of their organ, the cleaners eat what the organ has to be
## cleaned of (toxins, old red cells, urea crystals, bacteria of the flora), the red cells ride the current. Presentation only: nothing here
## changes a number of the body, and a kill by a worker pays the player nothing.

const HUNT := &"hunt"
const EAT := &"eat"
const FLOW := &"flow"
const WANDER := &"wander"

## role of the cohort (the universe's `role`) -> how it works. size is in world units; speed in units per second.
const ROLES := {
	"defesa": {"mode": HUNT, "name": "Neutrófilo", "core": Color(0.88, 0.94, 1.0), "edge": Color(0.5, 0.65, 0.95), "size": 0.5, "speed": 3.4},
	"limpeza": {"mode": HUNT, "name": "Macrófago", "core": Color(1.0, 0.8, 0.42), "edge": Color(0.85, 0.5, 0.2), "size": 0.72, "speed": 2.2},
	"vigilancia": {"mode": HUNT, "name": "Célula NK", "core": Color(1.0, 0.52, 0.42), "edge": Color(0.75, 0.15, 0.2), "size": 0.55, "speed": 3.8},
	"reparo": {"mode": HUNT, "name": "Plaqueta", "core": Color(1.0, 0.78, 0.62), "edge": Color(0.95, 0.55, 0.5), "size": 0.34, "speed": 2.6},
	"amparo": {"mode": HUNT, "name": "Glia", "core": Color(1.0, 0.68, 0.92), "edge": Color(0.7, 0.2, 0.55), "size": 0.58, "speed": 1.8},
	"reciclagem": {"mode": EAT, "group": &"motes", "kind": &"hemacia_velha", "name": "Macrófago do baço", "core": Color(0.88, 0.55, 0.78), "edge": Color(0.55, 0.2, 0.5), "size": 0.68, "speed": 1.9},
	"depuracao": {"mode": EAT, "group": &"toxins", "kind": &"", "name": "Hepatócito", "core": Color(0.95, 0.7, 0.32), "edge": Color(0.6, 0.35, 0.1), "size": 0.72, "speed": 1.5},
	"filtracao": {"mode": EAT, "group": &"motes", "kind": &"cristal_de_ureia", "name": "Célula tubular", "core": Color(0.5, 0.95, 0.9), "edge": Color(0.1, 0.55, 0.6), "size": 0.6, "speed": 1.6},
	"simbiose": {"mode": EAT, "group": &"motes", "kind": &"microbio", "name": "Flora", "core": Color(0.72, 1.0, 0.5), "edge": Color(0.3, 0.7, 0.2), "size": 0.36, "speed": 1.7},
	"transporte": {"mode": FLOW, "name": "Hemácia", "core": Color(1.0, 0.3, 0.3), "edge": Color(0.7, 0.05, 0.12), "size": 0.46, "speed": 1.4},
	"memoria": {"mode": WANDER, "name": "Linfócito", "core": Color(0.58, 0.78, 1.0), "edge": Color(0.2, 0.3, 0.8), "size": 0.46, "speed": 1.1},
	"suporte": {"mode": WANDER, "name": "Célula de suporte", "core": Color(0.78, 0.65, 0.85), "edge": Color(0.45, 0.3, 0.6), "size": 0.42, "speed": 1.0},
}
const FALLBACK := {"mode": WANDER, "name": "Célula", "core": Color(0.6, 1.0, 0.75), "edge": Color(0.2, 0.5, 0.9), "size": 0.45, "speed": 1.0}

## How many of a cohort are drawn: a share of its real headcount, never more than `per_cohort`, and at least one while any is alive.
const SHARE := 0.25


static func spec(role: String) -> Dictionary:
	return ROLES.get(role, FALLBACK)


static func drawn(count: int, per_cohort: int) -> int:
	if count <= 0:
		return 0
	return clampi(ceili(float(count) * SHARE), 1, per_cohort)
