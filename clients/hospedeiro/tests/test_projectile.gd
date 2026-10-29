extends TestCase
## The projectile designed by Jev changes the shot itself: how it flies, how big it is, what it does on arrival. Each option is held to
## one yardstick (a lower direct blow in exchange for its own reach) and every consequence is checked on real bodies.

var world: BioWorld


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
	world.player.global_position = Vector2.ZERO


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _dummy(at_units: Vector2) -> BioCellActor:
	BioFactory.spawn_virus(world, at_units * BioArt.UNIT, world.player)
	var v := world.viruses().back() as BioCellActor
	for child in v.get_children():
		if child is BioVirusBrain:
			child.queue_free()
	v.velocity = Vector2.ZERO
	v.max_speed_units = 0.0
	v.combatant.actor.vitals.max_membrane = 1000.0
	v.combatant.actor.vitals.membrane = 1000.0
	return v


func _lost(v: BioCellActor) -> float:
	return 1000.0 - v.combatant.actor.vitals.membrane


func _shoot(traits: Dictionary, dir: Vector2 = Vector2.RIGHT, range_units: float = 12.0, homing: bool = false) -> BioAbilityBolt:
	var def := BioAttackDef.new(&"anticorpo_y", 0.0, 20.0, 0.0, range_units, 0.0, 0.0)
	var shot := BioProjectileDesign.params(traits) if BioProjectileDesign.is_designed(traits) else {}
	return BioAbilityBolt.spawn(world, world.player.combatant, def, Vector2(0.8, 0.0) * BioArt.UNIT, dir, 12.0, range_units, Color.WHITE, homing, shot)


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func test_a_plain_cell_shoots_the_plain_bolt() -> void:
	assert_true(not BioProjectileDesign.is_designed({}), "no traits, no design")
	var t := _dummy(Vector2(4, 0))
	_shoot({})
	await _wait(0.7)
	assert_near(_lost(t), 20.0, 0.01, "full damage, one target")


func test_every_impact_is_worth_about_the_plain_shot() -> void:
	for impact in BioProjectileDesign.IMPACTS:
		var p := BioProjectileDesign.params({"impacto": impact})
		var direct: float = 20.0 * float(p["damage"])
		var worth := direct + BioProjectileDesign.extra_worth(impact, direct)
		assert_true(worth > 20.0 * 0.95 and worth < 20.0 * 1.2, "%s is worth %.1f against 20: the same yardstick" % [impact, worth])
	for calibre in BioProjectileDesign.CALIBRE:
		var mult: float = BioProjectileDesign.CALIBRE[calibre]["damage"]
		assert_true(mult > 0.88 and mult < 1.15, "%s pays for its size with %.2f of damage" % [calibre, mult])


func test_a_piercing_shot_goes_through_three_enemies_weaker_each_time() -> void:
	var a := _dummy(Vector2(3, 0))
	var b := _dummy(Vector2(5, 0))
	var c := _dummy(Vector2(7, 0))
	var d := _dummy(Vector2(9, 0))
	_shoot({"impacto": "perfurante"})
	await _wait(1.2)
	var base := 20.0 * float(BioProjectileDesign.params({"impacto": "perfurante"})["damage"])
	assert_near(_lost(a), base, 0.05, "the first takes the full blow")
	assert_near(_lost(b), base * 0.75, 0.05, "the second takes less")
	assert_near(_lost(c), base * 0.75 * 0.75, 0.05, "and the third less still")
	assert_true(_lost(d) <= base * 0.75 * 0.75 * 0.75 + 0.05 and _lost(d) < _lost(c) + 0.01, "after three pierces it stops: the fourth is hit by it only if it is still flying")


func test_an_explosive_shot_hurts_those_near_the_impact() -> void:
	var hit := _dummy(Vector2(5, 0))
	var near := _dummy(Vector2(5, 1.6))
	var far := _dummy(Vector2(5, 5))
	_shoot({"impacto": "explosivo"})
	await _wait(0.9)
	var p := BioProjectileDesign.params({"impacto": "explosivo"})
	assert_near(_lost(hit), 20.0 * float(p["damage"]), 0.05, "the target takes the blow")
	assert_near(_lost(near), 20.0 * float(p["damage"]) * 0.55, 0.05, "the one beside it takes a share")
	assert_near(_lost(far), 0.0, 0.01, "the far one is untouched")


func test_a_fragmenting_shot_breaks_into_pieces_that_find_others() -> void:
	var hit := _dummy(Vector2(4, 0))
	var behind := _dummy(Vector2(6.2, 1.4))
	var aside := _dummy(Vector2(3.3, -1.6))
	var before := world.get_children().filter(func(n: Node) -> bool: return n is BioAbilityBolt).size()
	_shoot({"impacto": "fragmenta"})
	var pieces := 0
	for i in 40:  # watch the frames after the impact: the fragments are short lived
		await tree.physics_frame
		pieces = maxi(pieces, world.get_children().filter(func(n: Node) -> bool: return n is BioAbilityBolt).size())
	assert_true(pieces >= before + 3, "three fragments were born at the impact (%d bolts at most alive)" % pieces)
	await _wait(0.9)
	var p := BioProjectileDesign.params({"impacto": "fragmenta"})
	assert_near(_lost(hit), 20.0 * float(p["damage"]), 0.05, "the target takes the main blow, not its own fragments")
	assert_true(_lost(behind) + _lost(aside) > 0.0, "at least one fragment found someone")


func test_a_sticky_shot_keeps_hurting() -> void:
	var t := _dummy(Vector2(4, 0))
	_shoot({"impacto": "grudento"})
	await _wait(0.7)
	var after_blow := t.combatant.actor.vitals.membrane
	await _wait(3.4)
	var burned := after_blow - t.combatant.actor.vitals.membrane
	var direct := 20.0 * float(BioProjectileDesign.params({"impacto": "grudento"})["damage"])
	assert_true(burned > direct * 0.3 and burned < direct * 0.5, "it kept hurting for %.1f after a blow of %.1f" % [burned, direct])


func test_a_big_shot_hits_what_a_thin_one_misses() -> void:
	var off := _dummy(Vector2(5, 0.85))  # a virion is 0.6 units wide: the needle (0.12) passes beside it, the ball (0.45) clips it
	_shoot({"calibre": "fino"})
	await _wait(0.9)
	assert_near(_lost(off), 0.0, 0.01, "the needle passes beside it")
	_shoot({"calibre": "grosso"})
	await _wait(1.2)
	assert_true(_lost(off) > 0.0, "the big ball clips the same one")


func test_trajectories_really_fly_differently() -> void:
	var ends := {}
	for path in ["reta", "ondulada", "espiral", "arco"]:
		var bolt := _shoot({"trajetoria": path}, Vector2.RIGHT, 9.0)
		await tree.physics_frame
		var max_side := 0.0
		for i in 40:
			await tree.physics_frame
			if is_instance_valid(bolt):
				max_side = maxf(max_side, absf(bolt.position.y))
		ends[path] = max_side
		if is_instance_valid(bolt):
			bolt.queue_free()
	assert_true(ends["reta"] < 2.0, "the straight one stays on its line (%.1f)" % ends["reta"])
	assert_true(ends["ondulada"] > 10.0 and ends["espiral"] > 10.0, "the wave and the corkscrew sweep to the sides (%.0f, %.0f)" % [ends["ondulada"], ends["espiral"]])
	assert_true(ends["arco"] > 15.0, "the arc bends away from its line (%.0f)" % ends["arco"])


func test_the_universe_traits_all_have_a_meaning() -> void:
	var universe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../../engine/scenarios/testdata/legacy-dungeons/universe.json"))
	for t in universe["appearance"]["traits"]:
		var id := str(t["id"])
		for o in t["options"]:
			var oid := str(o["id"])
			match id:
				"trajetoria":
					assert_true(BioProjectileDesign.TRAJECTORIES.has(oid), "trajectory %s flies" % oid)
				"calibre":
					assert_true(BioProjectileDesign.CALIBRE.has(oid), "calibre %s has a size" % oid)
				"impacto":
					assert_true(BioProjectileDesign.IMPACTS.has(oid), "impact %s does something" % oid)


func test_the_design_reaches_the_runner_and_the_overlay() -> void:
	world.apply_design({"trajetoria": "espiral", "calibre": "grosso", "impacto": "explosivo"}, "debug")
	assert_eq(str(world.abilities.projectile_traits.get("impacto", "")), "explosivo", "the runner shoots what Jev designed")
	world.design_debug.toggle()
	assert_true(world.design_debug.text().contains("impacto explosivo"), "and the overlay says so")
	world.apply_design({}, "motor")


func test_every_trajectory_pays_for_how_hard_it_is_to_land() -> void:
	var worths := {}
	for path in BioProjectileDesign.PATHS:
		var p := BioProjectileDesign.params({"trajetoria": path})
		var odds: float = BioProjectileDesign.PATHS[path]["odds"]
		worths[path] = float(p["damage"]) * odds
	var lo := 9.0
	var hi := 0.0
	for k in worths:
		lo = minf(lo, worths[k])
		hi = maxf(hi, worths[k])
	assert_true(hi / lo < 1.12, "damage x odds of landing is the same within 12%% for every path: %s" % str(worths))
	var tele := BioProjectileDesign.params({"trajetoria": "teleguiada"})
	var snake := BioProjectileDesign.params({"trajetoria": "ondulada"})
	var straight := BioProjectileDesign.params({"trajetoria": "reta"})
	assert_true(float(snake["damage"]) > float(tele["damage"]) * 1.15, "the snake that is harder to land hits harder than the hunter")
	assert_true(float(straight["damage"]) > float(snake["damage"]) and float(straight["speed"]) > float(tele["speed"]), "and the straight needle is harder still: it hits hardest, fastest and furthest")


## Against an enemy that weaves from side to side, the hunter lands more often than the straight needle: the odds the table rests on.
func test_the_odds_of_landing_follow_the_table() -> void:
	var rates := {}
	for path in ["reta", "teleguiada"]:
		var hits := 0
		for n in 8:
			var target := _dummy(Vector2(8, 0))
			var phase := n * 0.8
			var bolt := _shoot({"trajetoria": path}, Vector2.RIGHT, 14.0, false)
			for i in 70:
				await tree.physics_frame
				if is_instance_valid(target):
					target.global_position.y = sin(Time.get_ticks_msec() * 0.004 + phase) * 2.2 * BioArt.UNIT
			if _lost(target) > 0.0:
				hits += 1
			if is_instance_valid(bolt):
				bolt.queue_free()
			target.queue_free()
		rates[path] = hits / 8.0
	assert_true(rates["teleguiada"] > rates["reta"], "the hunter lands more often than the straight needle: %s" % str(rates))
