class_name BioEffectPhysics
extends RefCounted
## What the flavour Jev designed for a cell's effects DOES, not only how it looks. Every ability hit of a cell with a style carries one
## physical consequence, paid for by a lower direct blow so the style changes how the cell fights without making it stronger:
##   chama    - the target burns: a damage over time that keeps hurting after the blow
##   cristal  - the target turns brittle: it takes more damage from everything for a few seconds
##   nevoa    - the target and those near it are slowed
##   eletrico - the blow arcs to up to two other enemies close to the target
##   organico - part of the damage comes back to the caster as membrane
## All numbers are here, so the balance test can hold them to one yardstick: over a few seconds a style is worth about what the plain
## ability is worth (a little more when it has time to work, a little less in a single blow).

const DIRECT := {&"chama": 0.78, &"cristal": 0.88, &"nevoa": 0.85, &"eletrico": 0.72, &"organico": 0.88}

const BURN_SHARE := 0.38  # of the damage dealt, again, as burn
const BURN_SECONDS := 3.0
const BRITTLE_MULT := 1.2  # damage taken by a brittle target
const BRITTLE_SECONDS := 4.0
const SLOW_FACTOR := 0.62
const SLOW_SECONDS := 3.0
const SLOW_RADIUS_UNITS := 1.8
const CHAIN_SHARE := 0.4  # of the blow, to each of the nearby enemies
const CHAIN_TARGETS := 2
const CHAIN_RADIUS_UNITS := 3.2
const LEECH_SHARE := 0.32  # of the damage dealt, healed to the caster


static func has_style(style: StringName) -> bool:
	return DIRECT.has(style)


## The multiplier on the direct blow of an ability for this style (1.0 without one).
static func direct_mult(style: StringName) -> float:
	return float(DIRECT.get(style, 1.0))


## Damage dealt over time by the extras of a style for a blow of `dealt` damage, ignoring who stands nearby: the worth of the style
## on a single target over its full duration (used by the balance test).
static func extra_worth(style: StringName, dealt: float) -> float:
	match style:
		&"chama":
			return dealt * BURN_SHARE
		&"cristal":
			return dealt * (BRITTLE_MULT - 1.0) * 1.2  # a follow-up of about the size of the blow lands in the window
		&"nevoa":
			return dealt * 0.25  # time bought by the slow, valued as a fraction of the blow
		&"eletrico":
			return dealt * CHAIN_SHARE * 1.2  # with company around: on average a bit more than one chained target
		&"organico":
			return dealt * LEECH_SHARE * 0.9  # healing is worth a little less than damage
		_:
			return 0.0


## What the style does, in words, for the debug overlay and the player.
static func describe(style: StringName) -> String:
	match style:
		&"chama":
			return "queima: +%d%% do dano em %ds, golpe direto x%.2f" % [roundi(BURN_SHARE * 100.0), roundi(BURN_SECONDS), DIRECT[style]]
		&"cristal":
			return "quebradiço: alvo leva +%d%% por %ds, golpe direto x%.2f" % [roundi((BRITTLE_MULT - 1.0) * 100.0), roundi(BRITTLE_SECONDS), DIRECT[style]]
		&"nevoa":
			return "lentidão: alvo e vizinhos -%d%% por %ds, golpe direto x%.2f" % [roundi((1.0 - SLOW_FACTOR) * 100.0), roundi(SLOW_SECONDS), DIRECT[style]]
		&"eletrico":
			return "cadeia: %d inimigos próximos levam %d%% do golpe, golpe direto x%.2f" % [CHAIN_TARGETS, roundi(CHAIN_SHARE * 100.0), DIRECT[style]]
		&"organico":
			return "sifão: %d%% do dano volta como membrana, golpe direto x%.2f" % [roundi(LEECH_SHARE * 100.0), DIRECT[style]]
		_:
			return "nenhum (habilidades normais)"
