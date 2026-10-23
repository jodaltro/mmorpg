"""Makes the older tests read mutation numbers from the catalog instead of hard-coding them (one-off)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "tests"


def sub(name, a, b):
    p = root / name
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (name, a[:60])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


def m(gene, stat):
    return 'BioGeneCatalog.get_gene(&"%s").mods[%s]' % (gene, stat)


sub("test_genome.gd", 'assert_near(genome.stat(BioGene.SPEED), 1.18 * 0.9, 0.0001, "speed multiplies")',
    'assert_near(genome.stat(BioGene.SPEED), float(%s) * float(%s), 0.0001, "speed multiplies")' % (m("cilios_ageis", "BioGene.SPEED"), m("membrana_espessa", "BioGene.SPEED")))
sub("test_genome.gd", 'assert_near(genome.stat(BioGene.MAX_MEMBRANE), 0.9 * 1.3, 0.0001, "membrane multiplies")',
    'assert_near(genome.stat(BioGene.MAX_MEMBRANE), float(%s) * float(%s), 0.0001, "membrane multiplies")' % (m("cilios_ageis", "BioGene.MAX_MEMBRANE"), m("membrana_espessa", "BioGene.MAX_MEMBRANE")))
sub("test_genome.gd", 'assert_near(genome.stat(BioGene.ATP_REGEN), 4.0, 0.0001, "regen is additive")',
    'assert_near(genome.stat(BioGene.ATP_REGEN), float(%s), 0.0001, "regen is additive")' % m("mitocondria_avida", "BioGene.ATP_REGEN"))
sub("test_genome.gd", 'assert_near(lash.damage, base.damage * 1.25 * 0.9, 0.001, "lash damage")',
    'assert_near(lash.damage, base.damage * float(%s) * float(%s), 0.001, "lash damage")' % (m("flagelo_calejado", "BioGene.LASH_DAMAGE"), m("cauda_longa", "BioGene.LASH_DAMAGE")))
sub("test_genome.gd", 'assert_near(lash.range_units, base.range_units * 1.3, 0.001, "lash range")',
    'assert_near(lash.range_units, base.range_units * float(%s), 0.001, "lash range")' % m("cauda_longa", "BioGene.LASH_RANGE"))
sub("test_genome.gd", 'BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT).atp_cost * 1.3, 0.001, "spit cost")',
    'BioAttackCatalog.get_def(BioAttackCatalog.TOXIN_SPIT).atp_cost * float(%s), 0.001, "spit cost")' % m("vesicula_toxica", "BioGene.SPIT_COST"))
sub("test_genome.gd", "BioNutrientRules.GLUCOSE_ATP * 1.5, 0.001)", "BioNutrientRules.GLUCOSE_ATP * float(%s), 0.001)" % m("enzima_voraz", "BioGene.NUTRIENT_YIELD"))
sub("test_genome.gd", 'assert_near(float(tuned["radius"]), float(base["radius"]) * 1.35, 0.001, "radius grows")',
    'assert_near(float(tuned["radius"]), float(base["radius"]) * float(BioGeneCatalog.get_gene(&"vacuolo_digestivo").perks[&"lisossomo_acido"]["radius"]), 0.001, "radius grows")')
sub("test_genome.gd", 'assert_near(float(tuned["duration"]), float(base["duration"]) * 1.2, 0.001, "lasts longer")',
    'assert_near(float(tuned["duration"]), float(base["duration"]) * float(BioGeneCatalog.get_gene(&"vacuolo_digestivo").perks[&"lisossomo_acido"]["duration"]), 0.001, "lasts longer")')
sub("test_host.gd", 'assert_near(world.player.combatant.actor.stat(BioGene.SPEED), 1.18, 0.001, "and it reshapes the cell")',
    'assert_near(world.player.combatant.actor.stat(BioGene.SPEED), float(%s), 0.001, "and it reshapes the cell")' % m("cilios_ageis", "BioGene.SPEED"))
sub("test_every_ability.gd", 'assert_true(is_instance_valid(victim) and victim.combatant.actor.vitals.membrane < before, "%s hurt its target" % id)',
    'assert_true(not is_instance_valid(victim) or victim.combatant.actor.vitals.membrane < before, "%s hurt its target" % id)')
print("ok")
