"""Family behaviours designed by Jev (BioAbilityMode): the combatant applies them on every ability hit, the runner reshapes the ability,
the zone can wander, the world carries the design and the overlay shows it. One-off edits."""
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
sub(cb, "var focus := {}  # BioAbilityFocus.params: the risk and reward of every non-projectile ability\n",
    "var focus := {}  # BioAbilityFocus.params: the risk and reward of every non-projectile ability\nvar modes := {}  # BioAbilityMode: how each family of abilities behaves {family: mode}\n")
sub(cb, "	var styled := attacker.effect_style", """	var family := BioAbilityMode.family_of(hit_def.id) if not attacker._chaining else ""
	if family != "":
		factor *= BioAbilityMode.direct(family, attacker.modes)
	var styled := attacker.effect_style""")
sub(cb, """	if styled and result.damage_applied > 0.0:
		attacker._apply_style(self, result.damage_applied, hit_def)
""", """	if styled and result.damage_applied > 0.0:
		attacker._apply_style(self, result.damage_applied, hit_def)
	if family != "" and result.outcome != BioActor.HitOutcome.EVADED:
		attacker._apply_mode(self, family, hit_def)
""")
sub(cb, "## The physical consequence of this cell's flavour on a victim it just hurt for `dealt`.", """## What the family's designed mode does to a victim it just hit: reel it in, throw it away, strike it again.
func _apply_mode(victim: BioCombatant, family: String, hit_def: BioAttackDef) -> void:
	var m := BioAbilityMode.mode(family, modes)
	var host := victim.get_parent() as BioCellActor
	var mine := get_parent() as BioCellActor
	if host != null and mine != null:
		var to_me := (mine.global_position - host.global_position).normalized()
		if m.has("pull"):
			host.apply_impulse(to_me * float(m["pull"]))
		if m.has("knock"):
			host.apply_impulse(-to_me * float(m["knock"]))
	if m.has("repeat"):
		var r: Array = m["repeat"]
		for i in int(r[2]):
			get_tree().create_timer(float(r[0]) * (i + 1)).timeout.connect(func() -> void:
				if not is_instance_valid(victim) or not victim.actor.vitals.is_alive() or not is_instance_valid(self):
					return
				_chaining = true  # the second blow does not trigger modes again
				var again := BioAttackDef.new(hit_def.id, 0.0, hit_def.damage * float(r[1]), 0.0, hit_def.range_units, 0.0, 0.0)
				victim.receive_hit(self, again)
				_chaining = false
				BioPfx.burst(BioFx.root, (victim.get_parent() as Node2D).global_position, Color(1.0, 0.85, 0.6), 5, 120.0, 0.25, 8.0))


## The physical consequence of this cell's flavour on a victim it just hurt for `dealt`.""")

ar = "scripts/runtime/bio_ability_runner.gd"
sub(ar, "	a = BioAbilityFocus.apply(a, _host.combatant.focus)", "	a = BioAbilityMode.apply(BioAbilityFocus.apply(a, _host.combatant.focus), BioAbilityMode.family_of(id), _host.combatant.modes)")

z = "scripts/runtime/bio_ability_zone.gd"
sub(z, "var sentinels := 0\n", "var sentinels := 0\nvar drift := 0.0  # units per second towards the nearest enemy (the wandering zone)\n")
sub(z, "	z.sentinels = int(params.get(\"count\", 0)) if z.style == \"sentinels\" else 0\n", "	z.sentinels = int(params.get(\"count\", 0)) if z.style == \"sentinels\" else 0\n	z.drift = float(params.get(\"drift\", 0.0))\n")
sub(z, "func _process(delta: float) -> void:\n	_age += delta\n", """func _process(delta: float) -> void:
	_age += delta
	if drift > 0.0 and is_instance_valid(owner_combatant.get_parent()) and style != "trap":
		var near := BioTargeting.enemies(get_world_2d(), global_position, 7.0 * BioArt.UNIT, owner_combatant.actor.team)
		var best := BioTargeting.best(near, global_position, Vector2.ZERO, 7.0 * BioArt.UNIT)
		if best != null:
			global_position = global_position.move_toward(best.global_position, drift * BioArt.UNIT * delta)
""")

w = "scripts/runtime/bio_world.gd"
sub(w, "	player.combatant.focus = BioAbilityFocus.params(design_traits)\n", "	player.combatant.focus = BioAbilityFocus.params(design_traits)\n	player.combatant.modes = BioAbilityMode.from_traits(design_traits)\n")
sub("scripts/runtime/bio_design_debug.gd", "	lines.append(\"foco das outras habilidades:", "	lines.append(\"comportamento das famílias: %s\" % BioAbilityMode.describe(_world.player.combatant.modes))\n	lines.append(\"foco das outras habilidades:")
print("ok")
