extends TestCase
## The bridge to the engine, exercised with views shaped like the engine's (no network).

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _view(extra: Dictionary) -> Dictionary:
	var v := {"tick": 12, "quests": [], "others": [], "signs": [], "beliefs": [], "events": [], "skills": []}
	v.merge(extra, true)
	return v


func _go_to_blood() -> void:
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	for i in 3:
		await tree.process_frame


func test_without_an_engine_the_game_stays_offline() -> void:
	assert_true(not world.sync.link.online, "no engine, no connection")
	assert_true(world.sync.system._status.text.contains("OFFLINE"), "status says offline")
	assert_eq(world.viruses().size(), 6, "combat world still populated")


func test_crossing_the_sinusoid_changes_region() -> void:
	assert_eq(world.region, BioBodyMap.MEDULA, "born in the marrow")
	var seen: Array[StringName] = []
	world.region_changed.connect(func(r: StringName) -> void: seen.append(r))
	await _go_to_blood()
	assert_eq(world.region, BioBodyMap.SANGUE, "now in the blood")
	assert_eq(seen, [BioBodyMap.SANGUE] as Array[StringName], "one region change reported")


func test_viruses_live_in_the_blood() -> void:
	for v in world.viruses():
		assert_eq(BioBodyMap.region_of((v as Node2D).global_position), BioBodyMap.SANGUE, "virion spawned in the blood")


func test_view_shows_the_call_and_the_residents_of_this_region() -> void:
	var neva := {"id": "neva", "kind": "celula", "name": "Neva, neutrofila veterana", "region": "sangue"}
	var offer := {"key": "investigar-inflamacao|p1", "state": "offered", "giver": "neva", "rank": "E", "title": "Calor no capilar", "objective": "Examine o capilar inflamado.", "reward": "Reputacao +1"}
	world.sync.apply_view(_view({"others": [neva], "quests": [offer]}))
	assert_true(world.sync.system.is_offer_visible(), "the call is shown")
	assert_true(world.sync.system.offer_text().contains("Neva"), "the caller is named")
	assert_true(world.sync.system.offer_text().contains("Calor no capilar"), "the quest is named")
	assert_eq(world.sync._residents.size(), 0, "Neva lives in the blood, not shown in the marrow")
	await _go_to_blood()
	world.sync.apply_view(_view({"others": [neva], "quests": [offer]}))
	assert_true(world.sync._residents.has("neva"), "Neva appears once the player is in the blood")
	world.sync.apply_view(_view({"others": [neva]}))
	assert_true(not world.sync.system.is_offer_visible(), "the call goes away when the engine withdraws it")


func test_fever_follows_what_the_player_knows() -> void:
	var fever := {"p": "febre", "s": "sangue", "holds": true, "source": "publication"}
	world.sync.apply_view(_view({"beliefs": [fever]}))
	assert_true(world.fever, "fever on")
	for v in world.viruses():
		assert_near((v as BioCellActor).max_speed_units, BioWorld.VIRUS_SPEED * BioWorld.FEVER_SLOWDOWN, 0.001, "virions slow down")
	fever["holds"] = false
	world.sync.apply_view(_view({"beliefs": [fever]}))
	assert_true(not world.fever, "fever over")


func test_only_new_events_change_the_world() -> void:
	var meal := {"seq": 5, "kind": "refeicao", "public": true, "text": "O Hospedeiro se alimentou."}
	world.sync.apply_view(_view({"events": [meal]}))
	var before := world.nutrient_count()
	assert_true(world.sync.system.feed_text().contains("alimentou"), "history is shown in the feed")
	world.sync.apply_view(_view({"events": [meal]}))
	assert_eq(world.nutrient_count(), before, "the same event is not replayed")
	var second := {"seq": 6, "kind": "refeicao", "public": true, "text": "O Hospedeiro se alimentou de novo."}
	world.sync.apply_view(_view({"events": [meal, second]}))
	assert_eq(world.nutrient_count(), before + 10, "a new meal floods the blood with glucose")


func test_a_discovered_skill_expresses_its_gene() -> void:
	world.sync.apply_view(_view({"skills": [{"id": "cilios-ageis", "name": "Cilios Ageis", "rarity": "incomum"}]}))
	assert_true(world.genome.has_gene(&"cilios_ageis"), "gene expressed")
	assert_near(world.player.combatant.actor.stat(BioGene.SPEED), 1.18, 0.001, "and it reshapes the cell")
