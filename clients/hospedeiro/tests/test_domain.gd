extends TestCase

const LASH := BioAttackCatalog.FLAGELLUM_LASH


func _cell(id: String = "c", team: int = BioActor.Team.CELL, atp: float = 100.0) -> BioActor:
	return BioActor.new(id, team, BioVitals.new(100.0, atp, 5.0))


func test_attack_spends_atp_and_starts_cooldown() -> void:
	var cell := _cell()
	var def := BioAttackCatalog.get_def(LASH)
	assert_eq(cell.try_begin_attack(LASH, 0.0), BioActor.AttackStatus.STARTED)
	assert_near(cell.vitals.atp, 100.0 - def.atp_cost)
	assert_eq(cell.try_begin_attack(LASH, 0.1), BioActor.AttackStatus.ON_COOLDOWN)
	assert_eq(cell.try_begin_attack(LASH, def.cooldown + 0.01), BioActor.AttackStatus.STARTED)


func test_attack_refused_without_atp() -> void:
	var cell := _cell("c", BioActor.Team.CELL, 3.0)
	assert_eq(cell.try_begin_attack(LASH, 0.0), BioActor.AttackStatus.NOT_ENOUGH_ATP)
	assert_near(cell.vitals.atp, 3.0)


func test_damage_comes_from_catalog_and_kills() -> void:
	var cell := _cell("c")
	var virus := _cell("v", BioActor.Team.VIRUS)
	var def := BioAttackCatalog.get_def(LASH)
	var first := BioCombatRules.resolve(cell, virus, def, 0.0)
	assert_eq(first.outcome, BioActor.HitOutcome.HIT)
	assert_near(first.damage_applied, def.damage)
	var last := first
	var i := 0
	while i < 10 and virus.vitals.is_alive():
		last = BioCombatRules.resolve(cell, virus, def, float(i))
		i += 1
	assert_eq(last.outcome, BioActor.HitOutcome.KILLED)
	assert_eq(BioCombatRules.resolve(cell, virus, def, 20.0).outcome, BioActor.HitOutcome.IGNORED)


func test_same_team_and_self_cannot_be_hit() -> void:
	var a := _cell("a")
	var b := _cell("b")
	var def := BioAttackCatalog.get_def(LASH)
	assert_eq(BioCombatRules.resolve(a, b, def, 0.0).outcome, BioActor.HitOutcome.IGNORED)
	assert_eq(BioCombatRules.resolve(a, a, def, 0.0).outcome, BioActor.HitOutcome.IGNORED)


func test_dash_grants_invulnerability_window() -> void:
	var cell := _cell()
	var virus := _cell("v", BioActor.Team.VIRUS)
	cell.try_begin_attack(BioAttackCatalog.MEMBRANE_DASH, 1.0)
	var dash := BioAttackCatalog.get_def(BioAttackCatalog.MEMBRANE_DASH)
	var lunge := BioAttackCatalog.get_def(BioAttackCatalog.VIRAL_LUNGE)
	assert_eq(BioCombatRules.resolve(virus, cell, lunge, 1.0 + dash.invulnerable_seconds * 0.5).outcome, BioActor.HitOutcome.EVADED)
	assert_eq(BioCombatRules.resolve(virus, cell, lunge, 1.0 + dash.invulnerable_seconds + 0.01).outcome, BioActor.HitOutcome.HIT)


func test_atp_regenerates_and_caps() -> void:
	var vitals := BioVitals.new(50.0, 50.0, 10.0)
	vitals.try_spend_atp(30.0)
	vitals.tick(1.0)
	assert_near(vitals.atp, 30.0)
	vitals.tick(100.0)
	assert_near(vitals.atp, 50.0)


func test_nutrients_feed_and_repair() -> void:
	var cell := _cell()
	cell.vitals.try_spend_atp(50.0)
	cell.vitals.take_damage(40.0)
	BioNutrientRules.consume(cell, BioNutrientRules.Kind.GLUCOSE)
	BioNutrientRules.consume(cell, BioNutrientRules.Kind.LIPID)
	assert_near(cell.vitals.atp, 50.0 + BioNutrientRules.GLUCOSE_ATP)
	assert_near(cell.vitals.membrane, 60.0 + BioNutrientRules.LIPID_REPAIR)


func test_dead_actor_cannot_attack_or_be_revived_by_nutrients() -> void:
	var cell := _cell()
	cell.vitals.take_damage(1000.0)
	assert_eq(cell.try_begin_attack(BioAttackCatalog.TOXIN_SPIT, 0.0), BioActor.AttackStatus.DEAD)
	BioNutrientRules.consume(cell, BioNutrientRules.Kind.LIPID)
	assert_true(not cell.vitals.is_alive())
