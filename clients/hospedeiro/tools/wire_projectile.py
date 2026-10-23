"""The projectile designed by Jev: the bolt reads BioProjectileDesign, the combatant can be set alight by it, the runner and the world
carry the traits, the debug overlay shows them, and the universe offers them as design traits. One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


# bolts are added deferred: a fragment is born inside a physics callback
sub("scripts/runtime/bio_ability_bolt.gd", "	parent.add_child(bolt)\n	return bolt\n", "	parent.add_child.call_deferred(bolt)  # a fragment is born inside a physics callback\n	return bolt\n")

# combatant: a burning state that styles and projectiles share
cb = "scripts/runtime/bio_combatant.gd"
sub(cb, """		&"chama":
			victim._burn_dps = maxf(victim._burn_dps, dealt * BioEffectPhysics.BURN_SHARE / BioEffectPhysics.BURN_SECONDS)
			victim._burn_until = now + BioEffectPhysics.BURN_SECONDS
			victim._burn_owner = self
""", """		&"chama":
			victim.ignite(dealt * BioEffectPhysics.BURN_SHARE / BioEffectPhysics.BURN_SECONDS, BioEffectPhysics.BURN_SECONDS, Color(1.0, 0.5, 0.15))
""")
sub(cb, "## A burning cell loses membrane over time; it is credited to whoever set it alight.\n", """## Sets the cell alight (a flame, or a shot that sticks): `dps` membrane per second for `seconds`; a stronger burn replaces a weaker one.
func ignite(dps: float, seconds: float, color: Color = Color(1.0, 0.5, 0.15)) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_until = maxf(_burn_until, BioClock.now() + seconds)
	_burn_color = color


## A burning cell loses membrane over time.
""")
sub(cb, "var _burn_owner: BioCombatant\n", "var _burn_color := Color(1.0, 0.5, 0.15)\n")
sub(cb, "BioPfx.burst(BioFx.root, host.global_position, Color(1.0, 0.5, 0.15), 3, 90.0, 0.4, 8.0, Vector2.UP, 40.0)", "BioPfx.burst(BioFx.root, host.global_position, _burn_color, 3, 90.0, 0.4, 8.0, Vector2.UP, 40.0)")

# runner
ar = "scripts/runtime/bio_ability_runner.gd"
sub(ar, "var effect_style: StringName = &\"\"  # trait \"efeito\" designed by Jev\n", "var effect_style: StringName = &\"\"  # trait \"efeito\" designed by Jev\nvar projectile_traits := {}  # traits \"trajetoria\", \"calibre\", \"impacto\" (and \"ritmo\") designed by Jev: they change the shot itself\n")
sub(ar, "	var homing := bool(a.get(\"homing\", false))\n	for i in count:", "	var homing := bool(a.get(\"homing\", false))\n	var shot := BioProjectileDesign.params(projectile_traits) if BioProjectileDesign.is_designed(projectile_traits) else {}\n	for i in count:")
sub(ar, "		var bolt := BioAbilityBolt.spawn(_host.get_parent(), _host.combatant, def, from, dir, float(a[\"speed\"]), float(a[\"range\"]), color, homing)", "		var bolt := BioAbilityBolt.spawn(_host.get_parent(), _host.combatant, def, from, dir, float(a[\"speed\"]), float(a[\"range\"]), color, homing, shot)")

# world
w = "scripts/runtime/bio_world.gd"
sub(w, "	abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n", "	abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n	abilities.projectile_traits = design_traits.duplicate()\n")

# debug overlay
sub("scripts/runtime/bio_design_debug.gd", "	lines.append(\"partículas:", "	lines.append(\"projétil: %s\" % BioProjectileDesign.describe(_world.design_traits))\n	lines.append(\"partículas:")
print("ok")
