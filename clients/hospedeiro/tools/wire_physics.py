"""Gives the effect styles real consequences in combat (BioEffectPhysics) and ties them to the combatant and the design. One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


cb = "scripts/runtime/bio_combatant.gd"
sub(cb, "var damage_dealt_mult := 1.0  # how hard this one hits (enemies of a dungeon are tuned)\n",
    """var damage_dealt_mult := 1.0  # how hard this one hits (enemies of a dungeon are tuned)

## The flavour of this cell's effects (BioEffectPhysics): the ability hits it lands carry a physical consequence.
var effect_style: StringName = &""
var _brittle_until := 0.0
var _burn_until := 0.0
var _burn_dps := 0.0
var _burn_fx := 0.0
var _chaining := false  # a chained blow does not chain again
""")
sub(cb, """	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0) * attacker.damage_dealt_mult
	var def := hit_def""", """	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0) * attacker.damage_dealt_mult
	if now < _brittle_until:
		factor *= BioEffectPhysics.BRITTLE_MULT
	var styled := attacker.effect_style != &"" and not attacker._chaining and BioAbilityCatalog.has(hit_def.id)
	if styled:
		factor *= BioEffectPhysics.direct_mult(attacker.effect_style)
	var def := hit_def""")
sub(cb, """	hit.emit(self, result)
	if result.outcome == BioActor.HitOutcome.KILLED:
		died.emit(self)
	return result
""", """	hit.emit(self, result)
	if styled and result.damage_applied > 0.0:
		attacker._apply_style(self, result.damage_applied, hit_def)
	if result.outcome == BioActor.HitOutcome.KILLED:
		died.emit(self)
	return result


## The physical consequence of this cell's flavour on a victim it just hurt for `dealt`.
func _apply_style(victim: BioCombatant, dealt: float, hit_def: BioAttackDef) -> void:
	var now := BioClock.now()
	var host := victim.get_parent() as BioCellActor
	match effect_style:
		&"chama":
			victim._burn_dps = maxf(victim._burn_dps, dealt * BioEffectPhysics.BURN_SHARE / BioEffectPhysics.BURN_SECONDS)
			victim._burn_until = now + BioEffectPhysics.BURN_SECONDS
			victim._burn_owner = self
		&"cristal":
			victim._brittle_until = now + BioEffectPhysics.BRITTLE_SECONDS
		&"nevoa":
			if host != null:
				host.slow(BioEffectPhysics.SLOW_FACTOR, BioEffectPhysics.SLOW_SECONDS)
				for e in BioTargeting.enemies(host.get_world_2d(), host.global_position, BioEffectPhysics.SLOW_RADIUS_UNITS * BioArt.UNIT, actor.team):
					(e as BioCellActor).slow(BioEffectPhysics.SLOW_FACTOR, BioEffectPhysics.SLOW_SECONDS)
		&"eletrico":
			if host != null:
				var chained := 0
				_chaining = true
				for e in BioTargeting.enemies(host.get_world_2d(), host.global_position, BioEffectPhysics.CHAIN_RADIUS_UNITS * BioArt.UNIT, actor.team):
					if e == host or chained >= BioEffectPhysics.CHAIN_TARGETS:
						continue
					chained += 1
					var arc := BioAttackDef.new(hit_def.id, 0.0, dealt * BioEffectPhysics.CHAIN_SHARE, 0.0, hit_def.range_units, 0.0, 0.0)
					(e as BioCellActor).combatant.receive_hit(self, arc)
					BioPfx.burst(BioFx.root, (e as BioCellActor).global_position, Color(0.6, 0.85, 1.0), 8, 160.0, 0.3, 8.0)
				_chaining = false
		&"organico":
			actor.vitals.repair(dealt * BioEffectPhysics.LEECH_SHARE)
""")
sub(cb, """func _process(delta: float) -> void:
	actor.vitals.tick(delta)
""", """var _burn_owner: BioCombatant


func _process(delta: float) -> void:
	actor.vitals.tick(delta)
	if _burn_dps > 0.0:
		_tick_burn(delta)
""")
sub(cb, "func mark(mult: float, seconds: float) -> void:", """## A burning cell loses membrane over time; it is credited to whoever set it alight.
func _tick_burn(delta: float) -> void:
	if BioClock.now() >= _burn_until or not actor.vitals.is_alive():
		_burn_dps = 0.0
		return
	var before := actor.vitals.is_alive()
	actor.vitals.take_damage(_burn_dps * delta)
	_burn_fx -= delta
	if _burn_fx <= 0.0:
		_burn_fx = 0.35
		var host := get_parent() as Node2D
		if host != null:
			BioPfx.burst(BioFx.root, host.global_position, Color(1.0, 0.5, 0.15), 3, 90.0, 0.4, 8.0, Vector2.UP, 40.0)
	if before and not actor.vitals.is_alive():
		_burn_dps = 0.0
		died.emit(self)


func mark(mult: float, seconds: float) -> void:""")

# the world hands the style to the combatant
sub("scripts/runtime/bio_world.gd", "	BioPfx.style = abilities.effect_style\n", "	BioPfx.style = abilities.effect_style\n	player.combatant.effect_style = abilities.effect_style if BioEffectPhysics.has_style(abilities.effect_style) else &\"\"\n")
print("ok")
