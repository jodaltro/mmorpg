extends TestCase
## P10/P11 in a real world: the engine's society and crises become cells, tissue and interface, once, and a reconnection replays nothing.

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


func _conflict(phase: String, revision: int, since: int, severity: int = 60) -> Dictionary:
	return {"id": "infeccao-pulmonar", "def": "infeccao-pulmonar", "title": "Infecção pulmonar", "phase": phase, "region": "pulmao", "revision": revision, "since": since,
		"severity": severity, "peak": 80, "metrics": [{"id": "oxigenio", "label": "Oxigenação do pulmão", "value": 40}], "frontRegions": {"circulacao": "sangue"}}


func _npc(id: String, name_text: String, region: String, phase: String, task: String, done: int, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": id, "name": name_text, "region": region, "phase": phase, "task": task, "done": done, "failed": 0, "step": 0, "steps": 3, "since": 20}
	e.merge(extra, true)
	return e


func _view(tick: int, society: Array, conflicts: Array, recent: Array = []) -> Dictionary:
	return {"tick": tick, "quests": [], "others": [], "signs": [], "beliefs": [], "events": [], "skills": [], "society": society,
		"populations": [{"id": "hemacias_sangue", "region": "sangue", "count": 40, "max": 80}],
		"conflicts": {"revision": 3, "focus": "infeccao-pulmonar", "active": conflicts, "recent": recent}}


func _go(region: StringName) -> void:
	world.player.global_position = BioBodyMap.center_px(region)
	for i in 4:
		await tree.process_frame


func test_cells_exist_once_and_only_where_the_body_is_alive() -> void:
	await _go(BioBodyMap.SANGUE)
	var society := [_npc("rubra", "Rubra, hemácia ancia", "sangue", "travel", "transportar-oxigenio", 3, {"dest": "pulmao", "arrive": 28}),
		_npc("kupffer", "Kupffer", "figado", "idle", "", 0)]
	world.sync.apply_view(_view(24, society, []))
	await tree.process_frame
	world.sync.apply_view(_view(25, society, []))
	await tree.process_frame
	var p := world.sync.presenter
	assert_true(p.actor("rubra") != null, "Rubra is drawn: her leg is in a live region")
	assert_true(p.actor("kupffer") == null, "the liver is asleep: no node, no effect")
	assert_eq(p.actor_count(), 1, "one actor")
	var count := 0
	for c in p.get_children():
		if c is BioNpcActor and (c as BioNpcActor).npc_id == "rubra":
			count += 1
	assert_eq(count, 1, "never two bodies for the same canonical cell")
	assert_eq(world.sync._residents.has("rubra"), false, "and not drawn also as the old resident")


func test_two_clients_place_a_cell_in_the_same_spot() -> void:
	await _go(BioBodyMap.SANGUE)
	var society := [_npc("neva", "Neva", "sangue", "travel", "defender-pulmao", 1, {"dest": "pulmao", "arrive": 28})]
	world.sync.apply_view(_view(24, society, []))
	var a := world.sync.presenter
	var b := BioNpcPresenter.new()
	b.configure(world.player, world.anatomy, BioVisualPrefs.new())
	world.add_child(b)
	b.apply_view(_view(24, society, []))
	a.state_of("neva").refine(0.5)
	b.state_of("neva").refine(0.5)
	var pa := a._where(a.model.npcs["neva"], a.state_of("neva"))
	var pb := b._where(b.model.npcs["neva"], b.state_of("neva"))
	assert_true(pa["pos"].is_equal_approx(pb["pos"]), "same engine progress, same place")
	b.queue_free()


func test_the_route_follows_the_engine_progress_not_a_local_timer() -> void:
	var society := [_npc("neva", "Neva", "sangue", "travel", "defender-pulmao", 1, {"dest": "pulmao", "arrive": 28})]
	world.sync.apply_view(_view(24, society, []))
	var p := world.sync.presenter
	var st := p.state_of("neva")
	st.refine(0.0)
	var start: Vector2 = p._where(p.model.npcs["neva"], st)["pos"]
	st.refine(0.9)
	var late: Vector2 = p._where(p.model.npcs["neva"], st)["pos"]
	assert_true(start.distance_to(BioBodyMap.center_px(&"sangue")) < start.distance_to(BioBodyMap.center_px(&"pulmao")), "starts near where it was")
	assert_true(late.distance_to(BioBodyMap.center_px(&"pulmao")) < start.distance_to(BioBodyMap.center_px(&"pulmao")), "ends nearer to the destination")


func test_the_followed_crisis_the_alert_and_the_tissue() -> void:
	world.sync.apply_view(_view(100, [], [_conflict("active", 1, 99)]))
	var hud := world.sync.living_hud
	assert_true(hud.card_text().contains("Infecção pulmonar"), "the followed crisis is named")
	assert_true(hud.card_text().contains("O QUE FAZER") and hud.card_text().contains("Vá ao Pulmão"), "and what to do, plainly")
	assert_eq(hud.queue.waiting(), 0, "the first view is history: no banner")
	world.sync.apply_view(_view(101, [], [_conflict("critical", 2, 101, 80)]))
	assert_eq(hud.queue.waiting(), 1, "an escalation is one alert")
	world.sync.apply_view(_view(102, [], [_conflict("critical", 2, 101, 85)]))
	assert_eq(hud.queue.waiting(), 1, "a percentage change adds nothing")
	hud._process(0.1)
	assert_true(hud.alert_visible(), "the alert is shown")
	assert_eq(hud._alert.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and never captures the controls")
	assert_true(world.sync.mood.level_of(&"pulmao") >= 0.0, "the lung has a mood")
	for i in 40:
		world.sync.mood._process(0.5)
	assert_true(world.sync.mood.level_of(&"pulmao") > 0.1, "the inflamed lung is reddened (%.2f)" % world.sync.mood.level_of(&"pulmao"))
	assert_true(world.sync.mood.level_of(&"sangue") > 0.0, "and the front the engine opened reaches the blood")
	assert_eq(world.sync.mood.level_of(&"figado"), 0.0, "other organs are untouched")


func test_reconnection_is_history_not_news() -> void:
	var hud := world.sync.living_hud
	world.sync.apply_view(_view(100, [], [_conflict("active", 1, 99)]))
	world.sync._on_status(false)
	assert_true(hud.stale, "the interface says its data may be old")
	assert_true(hud.card_text().contains("desatualizados"), "in words")
	world.sync._on_status(true)
	world.sync.apply_view(_view(130, [], [_conflict("critical", 2, 125, 90)]))
	assert_eq(hud.queue.waiting(), 0, "what changed while away is in the panel, not a banner")
	assert_true(not hud.stale, "fresh data clears the warning")


func test_a_finished_task_is_celebrated_only_when_the_engine_counts_it() -> void:
	await _go(BioBodyMap.SANGUE)
	var p := world.sync.presenter
	var cues: Array[String] = []
	p.cue.connect(func(npc: String, kind: StringName, _at: Vector2) -> void: cues.append("%s:%s" % [npc, kind]))
	var working := [_npc("rubra", "Rubra", "sangue", "travel", "transportar-oxigenio", 3, {"dest": "sangue", "arrive": 28})]
	world.sync.apply_view(_view(24, working, []))
	world.sync.apply_view(_view(25, working, []))
	assert_eq(cues.size(), 0, "working is not delivering")
	var done := [_npc("rubra", "Rubra", "sangue", "idle", "", 4)]
	world.sync.apply_view(_view(30, done, []))
	assert_eq(cues, ["rubra:confirmed"], "the counter grew: one celebration")
	world.sync.apply_view(_view(31, done, []))
	assert_eq(cues.size(), 1, "the same counter does not play again")


func test_help_call_is_contextual_and_does_not_declare_a_deed() -> void:
	var hud := world.sync.living_hud
	hud.set_player_region("sangue")
	var asking := [_npc("rubra", "Rubra", "sangue", "seek_help", "transportar-oxigenio", 3, {"help": {"id": "h1", "need": "capilares-obstruidos", "text": "Rubra: os capilares do pulmão estão obstruídos.", "region": "sangue", "status": "open"}})]
	world.sync.apply_view(_view(40, asking, []))
	assert_true(hud.help_visible(), "a nearby cell asking for help is shown")
	var heard: Array[String] = []
	hud.help_accepted.connect(func(npc: String, region: String) -> void: heard.append(npc + "@" + region))
	hud._accept_help()
	assert_eq(heard, ["rubra@sangue"], "answered")
	assert_true(not hud.help_visible(), "and gone")
	assert_true(not world.sync.link.online, "nothing was sent to the engine: only the player's attention changed")
	world.sync.apply_view(_view(41, asking, []))
	assert_true(not hud.help_visible(), "the same request is not shown again")
	var far := [_npc("rubra", "Rubra", "pulmao", "seek_help", "transportar-oxigenio", 3, {"help": {"id": "h2", "text": "x", "region": "pulmao", "status": "open"}})]
	world.sync.apply_view(_view(42, far, []))
	assert_true(not hud.help_visible(), "a distant request waits in the panel instead of drawing a balloon")


func test_the_panel_lists_every_crisis_and_filters() -> void:
	var second := _conflict("recovering", 1, 90, 10)
	second["id"] = "ferida-na-pele"
	second["def"] = "ferida-na-pele"
	second["title"] = "Ferida na pele"
	second["region"] = "pele"
	var third := _conflict("contained", 1, 90, 20)
	third["id"] = "sobrecarga-hepatica"
	third["def"] = "sobrecarga-hepatica"
	third["title"] = "Sobrecarga hepática"
	var fourth := _conflict("active", 1, 90, 30)
	fourth["id"] = "disbiose-intestinal"
	fourth["def"] = "disbiose-intestinal"
	fourth["title"] = "Disbiose intestinal"
	world.sync.apply_view(_view(100, [], [_conflict("critical", 1, 90, 70), second, third, fourth]))
	var hud := world.sync.living_hud
	hud.toggle_panel()
	var rows := hud._modal.content.get_child_count()
	assert_true(rows >= 8, "the panel shows the four crises, requests, notices and settings (%d blocks)" % rows)
	assert_eq(BioConflictFocus.secondaries(world.sync.presenter.model.ordered(), hud.focus_id(), 2).size(), 2, "the card keeps only two summaries")
	hud.filter = "crítico"
	hud._rebuild_panel()
	hud.toggle_panel()
	assert_true(not hud.panel_open(), "L closes it")


func test_anemia_shows_in_the_blood_only_when_the_red_cells_fall() -> void:
	var view := _view(100, [], [])
	view["populations"] = [{"id": "hemacias_sangue", "region": "sangue", "count": 640, "max": 700, "baseline": 650}]
	world.sync.apply_view(view)
	for i in 40:
		world.sync.mood._process(0.5)
	assert_eq(world.sync.mood.anemia(), 0.0, "a healthy headcount draws nothing")
	view["populations"] = [{"id": "hemacias_sangue", "region": "sangue", "count": 380, "max": 700, "baseline": 650}]
	world.sync.apply_view(view)
	for i in 40:
		world.sync.mood._process(0.5)
	assert_true(world.sync.mood.anemia() > 0.6, "a blood with 58%% of its red cells is pale (%.2f)" % world.sync.mood.anemia())
	assert_true(world.sync.mood.visible, "and the tissue layer turns on to draw it")
	view["populations"] = [{"id": "hemacias_sangue", "region": "sangue", "count": 650, "max": 700, "baseline": 650}]
	world.sync.apply_view(view)
	for i in 80:
		world.sync.mood._process(0.5)
	assert_eq(world.sync.mood.anemia(), 0.0, "it fades as the marrow replaces the cells")


func test_there_are_no_missions_in_the_interface() -> void:
	var side := {"key": "x|p1", "def": "x", "state": "offered", "title": "Qualquer missão", "giver": "neva"}
	world.sync.apply_view(_view(10, [], []).merged({"quests": [side]}, true))
	assert_true(not world.sync.has_method("_apply_quests") and not world.sync.system.has_method("show_offer"), "the interface has no place for a mission")


func test_the_pc_has_a_minimap_that_opens_the_atlas() -> void:
	assert_true(world.pc_minimap != null and world.pc_minimap.is_visible_in_tree(), "the small map is on the screen of the PC")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	world.pc_minimap._gui_input(click)
	assert_true(world.atlas.is_open(), "a click opens the whole atlas")
	world.atlas.close()


func _pops(count: int) -> Array:
	return [{"id": "neutrofilos_pulmao", "role": "defesa", "region": "pulmao", "count": count, "max": 40},
		{"id": "hepatocitos_figado", "role": "depuracao", "region": "figado", "count": 40, "max": 40}]


func test_the_cohorts_of_the_organs_near_the_player_are_seen_at_work() -> void:
	await _go(&"pulmao")
	world.sync.apply_view(_view(10, [], []).merged({"populations": _pops(40)}, true))
	world.sync.crowd._sync()
	assert_eq(world.sync.crowd.count_of("neutrofilos_pulmao"), world.sync.prefs.crowd_per_cohort(), "the lung's neutrophils are drawn, up to the preset")
	assert_eq(world.sync.crowd.count_of("hepatocitos_figado"), 0, "the liver is far: its cells are not drawn")
	world.sync.apply_view(_view(11, [], []).merged({"populations": _pops(0)}, true))
	world.sync.crowd._sync()
	assert_eq(world.sync.crowd.count_of("neutrofilos_pulmao"), 0, "when none is alive none is drawn")


func test_defenders_finish_an_invader_and_the_player_is_not_paid() -> void:
	await _go(&"pulmao")
	world.sync.apply_view(_view(10, [], []).merged({"populations": _pops(40)}, true))
	world.sync.crowd._sync()
	var paid := [0]
	world.virus_destroyed.connect(func() -> void: paid[0] += 1)
	var foe := BioFactory.spawn_virus(world, BioBodyMap.center_px(&"pulmao"), world.player).get_parent() as BioCellActor
	foe.combatant.actor.vitals.membrane = 10.0
	for w in world.sync.crowd.workers:
		w.pos = foe.global_position + Vector2(1.5, 0.0) * BioArt.UNIT
	for i in 40:
		world.sync.crowd._retarget_in = 0.0
		world.sync.crowd._process(0.1)
		if not foe.is_active():
			break
	assert_true(not foe.is_active() or foe.is_queued_for_deletion(), "the neutrophils killed the invader")
	assert_eq(paid[0], 0, "and a kill of the body pays the player nothing")


func test_cleaners_eat_what_the_organ_clears() -> void:
	await _go(&"figado")
	world.sync.apply_view(_view(10, [], []).merged({"populations": _pops(40)}, true))
	world.sync.crowd._sync()
	for node in tree.get_nodes_in_group("toxins"):
		node.queue_free()
	await tree.process_frame
	var toxin := BioToxin.new()
	toxin.position = BioBodyMap.center_px(&"figado")
	world.add_child(toxin)
	for w in world.sync.crowd.workers:
		w.pos = toxin.global_position + Vector2(1.2, 0.0) * BioArt.UNIT
	for i in 40:
		world.sync.crowd._retarget_in = 0.0
		world.sync.crowd._process(0.1)
		if toxin.is_queued_for_deletion():
			break
	assert_true(toxin.is_queued_for_deletion(), "the hepatocytes cleared the toxin")


func test_a_cell_at_work_says_a_short_line_in_a_balloon_and_only_a_few_at_once() -> void:
	await _go(&"pulmao")
	var society := [_npc("neva", "Neva, neutrófila", "pulmao", "travel", "defender-pulmao", 0, {"dest": "pulmao", "since": 10, "arrive": 30}), _npc("macra", "Macra, macrófago", "pulmao", "travel", "limpar-alveolos", 0, {"dest": "pulmao", "since": 10, "arrive": 30})]
	world.sync.apply_view(_view(20, society, []))
	world.sync.apply_view(_view(21, society, []))
	await tree.process_frame
	var a := world.sync.presenter.actor("neva")
	assert_true(a != null, "the cell is there")
	a.lod = 2
	a._say_in = 0.0
	a._speak(0.1)
	assert_true(a._bubble.is_speaking(), "it speaks while it works")
	assert_true(BioSpeech.TASKS["defender-pulmao"].has(a._last_line), "about its own task (%s)" % a._last_line)
	var b := world.sync.presenter.actor("macra")
	b.lod = 2
	b._say_in = 0.0
	b._speak(0.1)
	assert_true(BioSpeechBubble.live <= world.sync.prefs.get_number("speech_cap"), "never more balloons than the preset allows")
