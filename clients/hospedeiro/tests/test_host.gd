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
	assert_true(world.sync.system._status.text.contains("offline"), "status says offline")
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


func test_online_the_engine_owns_the_genome_and_the_offer() -> void:
	var ev := {
		"genes": [{"id": "cilios-ageis", "name": "Cílios Ágeis"}],
		"offer": [{"id": "membrana-espessa"}, {"id": "flagelo-calejado"}, {"id": "cauda-longa"}],
		"featured": "membrana-espessa", "pressure": 2, "threshold": 10, "slots": 3}
	world.sync.apply_view(_view({"evolution": ev}))
	assert_true(world.engine_evolution, "engine drives evolution")
	assert_eq(world.genome.equipped, [&"cilios_ageis"] as Array[StringName], "genome from the engine")
	assert_near(world.player.combatant.actor.stat(BioGene.SPEED), float(BioGeneCatalog.get_gene(&"cilios_ageis").mods[BioGene.SPEED]), 0.001, "and it reshapes the cell")
	assert_true(world.panel.is_offer_visible(), "the engine's offer is shown")
	assert_true(world.panel.offer_text(0).contains("pende"), "the featured gene is marked")
	assert_true(not world.panel.offer_text(1).contains("pende"), "only the featured one")
	world.add_pressure(BioMutationTracker.THRESHOLD)
	assert_eq(world.tracker.pressure, 0, "the local tracker stays quiet online")
	world.pick_mutation(1)
	assert_eq(world.genome.equipped, [&"cilios_ageis"] as Array[StringName], "picking asks the engine; the genome changes only when the engine says so")
	world.sync.apply_view(_view({"evolution": {"genes": [{"id": "cilios-ageis"}, {"id": "flagelo-calejado"}], "offer": [], "pressure": 0, "threshold": 10}}))
	assert_true(world.genome.has_gene(&"flagelo_calejado"), "the engine confirmed the choice")
	assert_true(not world.panel.is_offer_visible(), "offer closed")
	world.sync._on_status(false)
	assert_true(not world.engine_evolution, "offline again: the local loop takes over")


func test_the_engine_look_morphs_the_body_gradually_in_the_background() -> void:
	var body: BioCellBody = null
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	var tail := world.player.get_node("Flagellum") as BioFlagellum
	var base_segments := tail.segments
	var look := {"variant": "cacador", "name": "Caçador", "axes": {"ferocidade": 90, "agilidade": 80, "robustez": 10, "metabolismo": 20, "sociabilidade": 20, "misterio": 20}}
	world.sync.apply_view(_view({"look": look}))
	assert_eq(world.look_name, "Caçador", "the advisor's variant is remembered")
	assert_true(body.look_target.get("ferocidade") == 90, "target set")
	assert_true(float(body.look_now["ferocidade"]) < 5.0, "nothing snaps: the body starts neutral")
	assert_true(body.spikes == 0, "no spikes yet")
	body._ease_look(2.0)
	var partial := float(body.look_now["ferocidade"])
	assert_true(partial > 0.0 and partial < 90.0, "a couple of seconds only moves part of the way (%s)" % partial)
	body._ease_look(60.0)
	assert_near(float(body.look_now["ferocidade"]), 90.0, 0.01, "and it arrives in the end")
	assert_true(body.spikes >= 5, "a ferocious body grows spikes")
	assert_true(tail.segments > base_segments, "an agile body grows a longer tail")
	var other := {"variant": "erudito", "name": "Erudito", "axes": {"ferocidade": 5, "agilidade": 10, "robustez": 10, "metabolismo": 10, "sociabilidade": 20, "misterio": 95}}
	world.sync.apply_view(_view({"look": other}))
	body._ease_look(60.0)
	assert_true(body.core.b > body.core.r, "a mysterious body turns violet-blue")


func test_behaviour_is_reported_in_batches_without_blocking() -> void:
	var sync := world.sync
	sync.link.online = true
	sync._used[BioAttackCatalog.FLAGELLUM_LASH] = true
	sync._used[BioAttackCatalog.MEMBRANE_DASH] = true
	sync._report_in = 0.0
	sync._track_behaviour(0.016)  # offline URL: the commands fail quietly, the frame is not held
	assert_true(sync._used.is_empty(), "the interval's usage was handed off")
	assert_near(sync._report_in, BioHostSync.REPORT_SECONDS, 0.001, "and the next report is scheduled")
	sync.link.online = false


func _body() -> BioCellBody:
	for child in world.player.get_children():
		if child is BioCellBody:
			return child
	return null


func test_born_as_a_plain_ball_then_the_lineage_reshapes_everything() -> void:
	var body := _body()
	var tail := world.player.get_node("Flagellum") as BioFlagellum
	assert_eq(body.form, &"esfera", "born as a plain ball")
	assert_true(not tail.is_active(), "a ball has no tail")
	var plain_membrane := world.player.combatant.actor.vitals.max_membrane
	world.sync.apply_view(_view({"lineage": {"current": "macrofago", "name": "Macrófago", "tier": 2, "offer": [], "maturity": 40, "next": 0}}))
	assert_eq(world.genome.lineage, &"macrofago", "the engine's lineage reaches the genome")
	assert_eq(body.form, &"macrofago", "and the body")
	assert_true(world.player.combatant.actor.vitals.max_membrane > plain_membrane * 1.4, "a macrophage is far tougher")
	assert_true(world.player.combatant.actor.stat(BioGene.SPEED) < 0.9, "and slower")
	body._size_now = float(body._form["size"])
	assert_true(body._lobes >= 5, "with pseudopods crawling over the body")
	world.sync.apply_view(_view({"lineage": {"current": "neutrofilo", "name": "Neutrófilo", "tier": 2, "offer": [], "maturity": 40, "next": 0}}))
	assert_true(tail.is_active(), "a neutrophil keeps a tail")
	assert_true(world.player.combatant.actor.stat(BioGene.SPEED) > 1.25, "and is fast")


func test_the_lineage_offer_comes_first_and_hands_back_to_the_mutation_offer() -> void:
	var ev := {"genes": [], "offer": [{"id": "cilios-ageis"}, {"id": "membrana-espessa"}, {"id": "cauda-longa"}], "featured": "cilios-ageis", "pressure": 0, "threshold": 10, "slots": 3}
	var lin := {"current": "", "name": "", "tier": 0, "maturity": 14, "next": 14,
		"offer": [{"id": "mieloide", "name": "Mieloide", "desc": "Os devoradores."}, {"id": "linfoide", "name": "Linfoide", "desc": "A memória."}], "featured": "linfoide"}
	world.sync.apply_view(_view({"lineage": lin, "evolution": ev}))
	assert_true(world.panel.is_offer_visible(), "an offer is shown")
	assert_true(world.panel.offer_text(1).contains("pende"), "the advisor's lean is marked on the lineage card")
	assert_true(world.panel.offer_text(0).contains("Mieloide"), "the lineage cards are what is shown first")
	assert_eq(world.engine_lineage_offer.size(), 2, "the pending lineage offer is tracked")
	lin["offer"] = []
	lin["current"] = "mieloide"
	world.sync.apply_view(_view({"lineage": lin, "evolution": ev}))
	assert_true(world.engine_lineage_offer.is_empty(), "differentiated")
	assert_true(world.panel.is_offer_visible() and world.panel.offer_text(0).contains("Cílios"), "then the pending mutation offer appears")


func test_class_mutations_are_only_met_by_their_class() -> void:
	var tracker := BioMutationTracker.new(5)
	var plain := BioGenome.new()
	var macro := BioGenome.new()
	macro.lineage = &"macrofago"
	for round_index in 12:
		var t := BioMutationTracker.new(round_index)
		t.add_pressure(BioMutationTracker.THRESHOLD, plain)
		for id in t.offer:
			assert_eq(BioGeneCatalog.get_gene(id).requires_lineage, &"", "an undifferentiated cell is never offered a class mutation")
	var met := false
	for round_index in 40:
		var t := BioMutationTracker.new(round_index)
		t.add_pressure(BioMutationTracker.THRESHOLD, macro)
		for id in t.offer:
			var need := BioGeneCatalog.get_gene(id).requires_lineage
			assert_true(need == &"" or need == &"macrofago", "a macrophage only meets its own class mutations")
			met = met or need == &"macrofago"
	assert_true(met, "and does meet them")
	assert_eq(tracker.pressure, 0)
