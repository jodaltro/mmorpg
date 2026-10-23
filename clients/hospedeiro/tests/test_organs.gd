extends TestCase
## The next organs (E3): the spleen, the intestine and the kidney: where they are, what drifts in them, what lives in them, their verbs
## (a deed reported to the engine) and the entrance and cast of each one's dungeon.

var world: BioWorld

const ORGANS := [BioBodyMap.BACO, BioBodyMap.INTESTINO, BioBodyMap.RIM]
const DUNGEONS := {"centro-germinativo": BioBodyMap.BACO, "criptas-profundas": BioBodyMap.INTESTINO, "nefrons": BioBodyMap.RIM}


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func test_each_organ_is_a_place_of_the_body_with_its_own_wall_and_name() -> void:
	for id in ORGANS:
		assert_eq(BioBodyMap.region_of(BioBodyMap.center_px(id)), id, "%s is where it says" % id)
		assert_true(BioBodyMap.NAMES.has(id), "%s has a name" % id)
		assert_true(BioAnatomy.region_def(id).has("motes"), "%s has something drifting in it" % id)
	var colors := {}
	for id in ORGANS + [BioBodyMap.FIGADO]:
		colors[str(BioAnatomy.region_def(id)["wall"])] = true
	assert_eq(colors.size(), 4, "every organ has its own colour")
	for link in [&"arteria_esplenica", &"arteria_mesenterica", &"arteria_renal"]:
		assert_true(not BioAnatomy.link_point(BioBodyMap.seed_value, link, 0.5).is_empty(), "%s is a vessel of the body" % link)


func test_motes_are_a_verb_of_their_organ() -> void:
	var vitals := world.player.combatant.actor.vitals
	vitals.membrane = vitals.max_membrane * 0.5
	var before := vitals.membrane
	BioMoteRules.apply(&"hemacia_velha", world.player.combatant.actor)
	assert_true(vitals.membrane > before, "recycling a red cell mends the membrane")
	vitals.membrane = vitals.max_membrane
	assert_true(BioMoteRules.apply(&"cristal_de_ureia", world.player.combatant.actor) > 0.0 and vitals.membrane < vitals.max_membrane, "filtering urea costs a little membrane")
	vitals.atp = 0.0
	BioMoteRules.apply(&"microbio", world.player.combatant.actor)
	assert_true(vitals.atp > 0.0, "feeding the microbiota gives energy")


func test_each_organ_drifts_its_own_mote_and_taking_it_is_a_deed() -> void:
	var expected := {BioBodyMap.BACO: [&"hemacia_velha", "reciclar-hemacia"], BioBodyMap.INTESTINO: [&"microbio", "nutrir-microbiota"], BioBodyMap.RIM: [&"cristal_de_ureia", "filtrar-ureia"]}
	var deeds: Array[String] = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	for id in ORGANS:
		world.player.global_position = BioBodyMap.center_px(id)
		for i in 3:
			await tree.process_frame
		world._populate(true)
		var here := world.get_tree().get_nodes_in_group("motes").filter(func(m: Node) -> bool: return BioBodyMap.region_of((m as Node2D).global_position) == id)
		assert_true(here.size() >= 8, "%s is full of motes" % id)
		assert_true(here.all(func(m: Node) -> bool: return (m as BioMote).kind == expected[id][0]), "and only its own kind")
		deeds.clear()
		(here[0] as BioMote)._on_body_entered(world.player)
		assert_eq(deeds, [expected[id][1]] as Array[String], "taking one is the deed %s" % expected[id][1])


func test_kills_and_food_are_the_verbs_of_the_spleen_the_gut_and_the_kidney() -> void:
	var deeds: Array[String] = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	world._on_wild_kill(BioBodyMap.center_px(BioBodyMap.BACO))
	world._on_wild_kill(BioBodyMap.center_px(BioBodyMap.INTESTINO))
	world._on_wild_kill(BioBodyMap.center_px(BioBodyMap.SANGUE))
	assert_eq(deeds, ["capturar-antigeno", "repelir-invasor"] as Array[String], "a kill in the spleen presents an antigen, in the gut repels an invader, elsewhere is only a kill")
	deeds.clear()
	world.region = BioBodyMap.RIM
	world.player.combatant.nutrient_consumed.emit(0)
	assert_eq(deeds, ["equilibrar-sal"] as Array[String], "a nutrient taken in the kidney is salt balanced")


func test_each_dungeon_has_its_door_inside_its_organ() -> void:
	for id in DUNGEONS:
		assert_true(world.gates.has(id), "%s has a door" % id)
		var door: BioGate = world.gates[id]
		assert_eq(BioBodyMap.region_of(door.global_position), DUNGEONS[id], "%s's door is inside the organ" % id)
	var door: BioGate = world.gates["nefrons"]
	world.sync.apply_view({"tick": 1, "dungeon": {"available": [{"id": "nefrons", "eligible": true}]}})
	assert_true(door.eligible and not world.gates["centro-germinativo"].eligible, "the view opens only the kidney's")
	world.sync.apply_view({"tick": 2, "dungeon": {"available": [{"id": "nefrons", "eligible": false}]}})
	assert_true(not door.eligible and not door.hint.is_empty(), "and closing leaves a hint")


func test_every_dungeon_has_its_own_cast_and_every_modifier_its_rule() -> void:
	var seen := {}
	for id in ["granuloma", "cordoes-hepaticos", "centro-germinativo", "criptas-profundas", "nefrons"]:
		var cast := BioDungeonPlan.family(id)
		for role in ["swarm", "ranged", "nest", "emitter", "boss"]:
			assert_true(not BioDungeonPlan.enemy(cast[role]).is_empty(), "%s: %s is defined" % [id, role])
			assert_true(not seen.has(cast[role]), "%s: %s belongs to this dungeon only" % [id, cast[role]])
			seen[cast[role]] = id
		assert_true(float(BioDungeonPlan.enemy(cast["boss"])["hp"]) >= 300.0, "%s has a tough boss" % id)
		for kind in ["guard", "wall", "core", "ambush", "pillars", "nest", "hazard", "boss"]:
			var room := BioDungeonPlan.room(11, 2, kind, "", id)
			assert_true((room["enemies"] as Array).size() > 0, "%s %s has enemies" % [id, kind])
			for e in room["enemies"]:
				assert_true(not BioDungeonPlan.enemy(e["type"]).is_empty(), "%s %s: %s is defined" % [id, kind, e["type"]])
	for modifier in ["hipermutacao", "selecao-rigida", "tolerancia", "baco-congestionado", "polpa-limpa", "disbiose-ativa", "peristaltismo", "microbiota-forte", "refeicao-farta", "jejum",
			"cristalizacao", "pressao-alta", "ureia-alta", "rim-limpo", "diurese"]:
		assert_true(BioDungeonPlan.rules(modifier) != BioDungeonPlan.rules(""), "%s changes the run" % modifier)


func test_a_run_in_each_new_dungeon_builds_its_own_chamber_and_comes_out_in_the_organ() -> void:
	for id in DUNGEONS:
		var cast := BioDungeonPlan.family(id)
		world.sync.apply_view({"tick": 1, "dungeon": {"available": [], "run": {"dungeon": id, "name": id.capitalize(), "state": "active", "seed": 321, "room": 0,
			"rooms": [{"id": "a", "name": "a", "kind": "guard"}, {"id": "b", "name": "b", "kind": "boss"}], "modifier": null}}})
		await tree.physics_frame
		assert_true(world.dungeon.active and world.dungeon.dungeon_id == id, "%s: the run is on" % id)
		var kinds := world.dungeon.enemies().map(func(e: Node) -> StringName: return StringName(str(e.get_meta("kind", ""))))
		assert_true(kinds.size() >= 2 and kinds.all(func(k: StringName) -> bool: return (cast["fodder"] as Array).has(k)), "%s: its own fodder at the door: %s" % [id, kinds])
		world.sync.apply_view({"tick": 2, "dungeon": {"available": [], "run": {"dungeon": id, "name": id.capitalize(), "state": "active", "seed": 321, "room": 1,
			"rooms": [{"id": "a", "name": "a", "kind": "guard"}, {"id": "b", "name": "b", "kind": "boss"}], "modifier": null}}})
		await tree.physics_frame
		assert_true(world.dungeon.enemies().any(func(e: Node) -> bool: return str(e.get_meta("kind", "")) == String(cast["boss"])), "%s: its boss in the last room" % id)
		world.sync.apply_view({"tick": 3, "dungeon": {"available": [], "run": {"dungeon": id, "name": id, "state": "cleared", "seed": 321, "room": 2, "rooms": [], "modifier": null}}})
		await tree.physics_frame
		assert_true(not world.dungeon.active, "%s: cleared" % id)
		assert_eq(BioBodyMap.region_of(world.player.global_position), DUNGEONS[id], "%s: back in the organ" % id)
		world.player.combatant.reset_vitals()
