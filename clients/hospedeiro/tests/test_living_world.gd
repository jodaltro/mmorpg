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
	assert_true(hud.card_text().contains("Próximo passo"), "and what to do next")
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


func test_side_quests_leave_the_main_interface_but_stories_stay() -> void:
	var side := {"key": "prova-macrofago|p1", "def": "prova-macrofago", "state": "offered", "title": "Prova do Devorador", "giver": "neva"}
	world.sync.apply_view(_view(10, [], []).merged({"quests": [side]}, true))
	assert_true(not world.sync.system.is_offer_visible(), "an ordinary quest no longer competes for attention")
	var story := {"key": "vigilia|p1", "def": "vigilia", "state": "offered", "title": "Vigília no Sangue", "giver": "neva"}
	world.sync.apply_view(_view(11, [], []).merged({"quests": [story]}, true))
	assert_true(world.sync.system.is_offer_visible(), "the story stays")


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
