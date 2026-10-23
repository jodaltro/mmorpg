extends TestCase
## The effect styles Jev designs have physical consequences, all held to one yardstick: a style is worth about what the plain
## ability is worth, never much more.

var world: BioWorld
var victims: Array[BioCellActor] = []


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	victims.clear()


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _dummy(at: Vector2) -> BioCellActor:
	BioFactory.spawn_virus(world, world.player.global_position + at, world.player)
	var v := world.viruses().back() as BioCellActor
	for child in v.get_children():
		if child is BioVirusBrain:
			child.queue_free()  # a still dummy: the brain would walk it to the player
	v.velocity = Vector2.ZERO
	v.max_speed_units = 0.0
	v.combatant.actor.vitals.max_membrane = 1000.0
	v.combatant.actor.vitals.membrane = 1000.0
	victims.append(v)
	return v


func _blow(target: BioCellActor, id: StringName = &"onda_de_pseudopodes") -> float:
	var before := target.combatant.actor.vitals.membrane
	world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
	var def := BioAttackDef.new(id, 0.0, 20.0, 0.0, 3.0, 0.0, 0.0)
	target.combatant.receive_hit(world.player.combatant, def)
	return before - target.combatant.actor.vitals.membrane


func _total_over(target: BioCellActor, seconds: float, blows: int) -> float:
	var before := target.combatant.actor.vitals.membrane
	for i in blows:
		_blow(target)
		await tree.create_timer(seconds / blows).timeout
	await tree.create_timer(0.1).timeout
	return before - target.combatant.actor.vitals.membrane


func test_a_style_costs_direct_damage_and_pays_back_in_its_own_way() -> void:
	var plain := _dummy(Vector2(120, 0))
	var base := _blow(plain)
	assert_near(base, 20.0, 0.01, "without a style the blow is what it is")
	for style in BioEffectPhysics.DIRECT:
		world.player.combatant.effect_style = style
		var target := _dummy(Vector2(0, 150))
		var direct := _blow(target)
		assert_near(direct, 20.0 * BioEffectPhysics.direct_mult(style), 0.01, "%s trades some direct damage" % style)
		assert_true(direct < base, "%s hits softer than the plain blow" % style)
		var worth := direct + BioEffectPhysics.extra_worth(style, direct)
		assert_true(worth > base * 0.95 and worth < base * 1.2, "%s is worth %.1f against %.1f: the same yardstick" % [style, worth, base])


func test_flame_keeps_burning_after_the_blow() -> void:
	world.player.combatant.effect_style = &"chama"
	var t := _dummy(Vector2(120, 0))
	var first := _blow(t)
	var after_blow := t.combatant.actor.vitals.membrane
	await tree.create_timer(3.4).timeout
	var burned := after_blow - t.combatant.actor.vitals.membrane
	assert_true(burned > first * 0.3 and burned < first * 0.5, "it burned %.1f more after a blow of %.1f" % [burned, first])
	await tree.create_timer(0.6).timeout
	assert_near(after_blow - burned, t.combatant.actor.vitals.membrane, 0.5, "and then it stops")


func test_crystal_makes_the_target_brittle() -> void:
	world.player.combatant.effect_style = &"cristal"
	var t := _dummy(Vector2(120, 0))
	var first := _blow(t)
	var second := _blow(t)
	assert_near(second, first * BioEffectPhysics.BRITTLE_MULT, 0.05, "the next blow lands %.0f%% harder" % ((BioEffectPhysics.BRITTLE_MULT - 1.0) * 100.0))
	await tree.create_timer(BioEffectPhysics.BRITTLE_SECONDS + 0.2).timeout
	assert_near(_blow(t), first, 0.05, "and it wears off: the next blow is plain again")


func test_mist_slows_the_target_and_its_neighbours() -> void:
	world.player.combatant.effect_style = &"nevoa"
	var hit := _dummy(Vector2(150, 0))
	var near := _dummy(Vector2(190, 0))
	var far := _dummy(Vector2(0, 400))
	_blow(hit)
	assert_true(hit.is_slowed() and near.is_slowed(), "the hit one and the one beside it are slowed")
	assert_true(not far.is_slowed(), "the far one is not")


func test_electricity_arcs_to_those_nearby_once() -> void:
	world.player.combatant.effect_style = &"eletrico"
	var hit := _dummy(Vector2(150, 0))
	var a := _dummy(Vector2(200, 60))
	var b := _dummy(Vector2(200, -60))
	var c := _dummy(Vector2(230, 0))
	var far := _dummy(Vector2(0, 500))
	var direct := _blow(hit)
	var hurt := [a, b, c].filter(func(v: BioCellActor) -> bool: return v.combatant.actor.vitals.membrane < 1000.0)
	assert_eq(hurt.size(), 2, "the arc reaches two enemies, no more")
	assert_near(1000.0 - hurt[0].combatant.actor.vitals.membrane, direct * BioEffectPhysics.CHAIN_SHARE, 0.1, "each for a share of the blow")
	assert_eq(far.combatant.actor.vitals.membrane, 1000.0, "the far one is untouched")


func test_the_organic_style_gives_membrane_back() -> void:
	world.player.combatant.effect_style = &"organico"
	var t := _dummy(Vector2(120, 0))
	world.player.combatant.actor.vitals.membrane = 10.0
	var direct := _blow(t)
	assert_near(world.player.combatant.actor.vitals.membrane, 10.0 + direct * BioEffectPhysics.LEECH_SHARE, 0.05, "part of the damage comes back")


func test_the_basic_attack_is_not_styled_and_the_design_reaches_the_combatant() -> void:
	world.apply_design({"efeito": "chama"}, "debug")
	assert_eq(world.player.combatant.effect_style, &"chama", "the design sets the combatant's style")
	var t := _dummy(Vector2(120, 0))
	var lash := BioAttackDef.new(&"chicote", 0.0, 20.0, 0.0, 3.0, 0.0, 0.0)
	t.combatant.receive_hit(world.player.combatant, lash)
	assert_near(t.combatant.actor.vitals.membrane, 980.0, 0.01, "the basic attack is untouched by the style")
	world.apply_design({}, "motor")
	assert_eq(world.player.combatant.effect_style, &"", "no design, no style")
