extends TestCase
## P10/P11 rules: the engine's society and conflicts turned into notices, poses and a followed crisis, without duplicates or lies.

func _conflict(id: String, phase: String, revision: int, since: int = 100, severity: int = 50) -> Dictionary:
	return {"id": id, "def": id, "title": id.capitalize(), "phase": phase, "region": "pulmao", "revision": revision, "since": since,
		"severity": severity, "metrics": [{"id": "x", "label": "Carga", "value": 7}]}


func _view(tick: int, active: Array, recent: Array = [], society: Array = []) -> Dictionary:
	var revision := 0
	for c in active:
		revision += int(c["revision"])
	return {"tick": tick, "society": society, "populations": [{"id": "h", "region": "sangue", "count": 30, "max": 60}],
		"conflicts": {"revision": revision, "focus": "a", "active": active, "recent": recent}}


func _npc(phase: String, task: String, done: int, failed: int, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": "rubra", "name": "Rubra", "region": "sangue", "phase": phase, "task": task, "done": done, "failed": failed, "step": 0, "steps": 3, "since": 100}
	e.merge(extra, true)
	return e


func test_the_first_view_is_history_not_news() -> void:
	var m := BioLivingModel.new()
	var n := m.ingest(_view(500, [_conflict("a", "critical", 4, 100)]))
	assert_eq(n.size(), 0, "no banner for what was already going on")
	assert_eq(m.ordered().size(), 1, "but the crisis is known")


func test_transitions_make_one_notice_and_percent_changes_make_none() -> void:
	var m := BioLivingModel.new()
	m.ingest(_view(100, []))
	var n := m.ingest(_view(101, [_conflict("a", "active", 1, 101)]))
	assert_eq(n.size(), 1, "start")
	assert_eq(n[0]["kind"], "start", "kind")
	assert_eq(m.ingest(_view(102, [_conflict("a", "active", 1, 101, 80)])).size(), 0, "severity moving is not news")
	n = m.ingest(_view(110, [_conflict("a", "critical", 2, 110)]))
	assert_eq(n.size(), 1, "escalation")
	assert_eq(n[0]["priority"], 5, "critical outranks everything")
	assert_eq(m.ingest(_view(111, [_conflict("a", "critical", 2, 110)])).size(), 0, "the same view twice repeats nothing")
	n = m.ingest(_view(130, [_conflict("a", "contained", 3, 130)]))
	assert_eq(n[0]["kind"], "contain", "contained")
	n = m.ingest(_view(150, [], [_conflict("a", "resolved", 5, 150)]))
	assert_eq(n[0]["kind"], "resolve", "resolved moves to recent and is announced")
	n = m.ingest(_view(170, [_conflict("a", "active", 6, 170)], []))
	assert_eq(n[0]["kind"], "reopen", "a reopened crisis is told as reopened, not as new")


func test_a_transition_that_happened_while_away_is_not_announced() -> void:
	var m := BioLivingModel.new()
	m.ingest(_view(100, [_conflict("a", "active", 1, 90)]))
	var n := m.ingest(_view(400, [_conflict("a", "critical", 2, 120)]))
	assert_eq(n.size(), 0, "stale: the panel shows it, no banner")
	assert_eq(m.ordered()[0]["phase"], "critical", "state still updated")


func test_reset_makes_the_next_view_history_again() -> void:
	var m := BioLivingModel.new()
	m.ingest(_view(100, [_conflict("a", "active", 1, 100)]))
	m.reset()
	assert_eq(m.ingest(_view(105, [_conflict("a", "critical", 2, 104)])).size(), 0, "reconnection is silent")


func test_three_crises_are_ordered_and_only_two_secondaries_show() -> void:
	var m := BioLivingModel.new()
	m.ingest(_view(100, [_conflict("a", "recovering", 1, 100, 10), _conflict("b", "critical", 1, 100, 90), _conflict("c", "active", 1, 100, 60), _conflict("d", "contained", 1, 100, 20)]))
	var order := m.ordered().map(func(c: Dictionary) -> String: return c["id"])
	assert_eq(order, ["b", "c", "d", "a"], "worst phase first")
	var focus := BioConflictFocus.pick(m.ordered(), "a", "")
	assert_eq(focus, "a", "the engine's suggestion is respected when the player picks nothing")
	assert_eq(BioConflictFocus.pick(m.ordered(), "a", "c"), "c", "the player's choice wins")
	assert_eq(BioConflictFocus.pick(m.ordered(), "zz", "zz"), "b", "an unknown focus falls back to the worst")
	assert_eq(BioConflictFocus.secondaries(m.ordered(), "b", 2).size(), 2, "at most two summaries")
	assert_eq(BioConflictFocus.filtered(m.ordered(), m.recent, "todos").size(), 4, "the panel keeps every crisis")
	assert_eq(BioConflictFocus.filtered(m.ordered(), m.recent, "crítico").size(), 1, "filter by phase")
	assert_eq(BioConflictFocus.next_filter("recuperando"), "todos", "the filter cycles")


func test_the_phase_is_never_only_a_colour() -> void:
	for p in BioConflictFocus.PHASE_NAME:
		assert_true(str(BioConflictFocus.PHASE_GLYPH.get(p, "")) != "", "%s has a glyph" % p)
		assert_true(BioConflictFocus.phase_label({"phase": p}).length() > 3, "%s has text" % p)


func test_alerts_dedupe_by_key_priority_ttl_and_history() -> void:
	var q := BioAlertQueue.new()
	assert_true(q.push({"key": "a:1:start", "priority": 4, "title": "A"}, 0.0), "first push")
	assert_true(not q.push({"key": "a:1:start", "priority": 4, "title": "A"}, 0.5), "same transition twice is one alert")
	q.push({"key": "b:1:escalate", "priority": 5, "title": "B"}, 1.0)
	q.push({"key": "c:1:recover", "priority": 2, "title": "C"}, 1.0)
	assert_eq(q.next(2.0)["title"], "B", "the most severe first")
	assert_eq(q.next(2.0)["title"], "A", "then the older of the rest")
	assert_eq(q.next(BioAlertQueue.TTL + 5.0), {}, "an expired alert is not shown late")
	assert_eq(q.history.size(), 3, "but it stays in the history")
	assert_eq(q.history[0]["title"], "C", "newest first")


func test_a_finish_is_shown_only_after_the_engine_counts_it() -> void:
	var s := BioInteractionState.new("rubra")
	assert_eq(s.apply(_npc("travel", "transportar-oxigenio", 4, 0, {"dest": "pulmao", "arrive": 110}), 102), [] as Array[StringName], "baseline is silent")
	assert_eq(s.phase, BioInteractionState.APPROACH, "heading elsewhere")
	assert_true(s.progress > 0.0 and s.progress < 1.0, "progress comes from ticks")
	s.apply(_npc("travel", "transportar-oxigenio", 4, 0, {"dest": "pulmao", "arrive": 110}), 109)
	assert_eq(s.phase, BioInteractionState.ANTICIPATE, "a short preparation before arriving")
	assert_eq(s.gesture, "carry", "Rubra carries")
	var cues := s.apply(_npc("travel", "transportar-oxigenio", 4, 0, {"region": "pulmao", "dest": "pulmao", "arrive": 114}), 110)
	assert_true(not cues.has(&"confirmed"), "arriving is not delivering")
	assert_true(s.phase == BioInteractionState.ACT or s.phase == BioInteractionState.PROGRESS, "working in place")
	cues = s.apply(_npc("idle", "", 5, 0, {"region": "pulmao"}), 120)
	assert_true(cues.has(&"confirmed"), "the counter grew: delivered")
	assert_eq(s.phase, BioInteractionState.CONFIRMED, "pose of success")
	cues = s.apply(_npc("idle", "", 5, 0, {"region": "pulmao"}), 121)
	assert_eq(cues.size(), 0, "the same counter never confirms twice (late or duplicated view)")
	s.advance(BioInteractionState.CONFIRM_SECONDS + 0.01)
	assert_eq(s.phase, BioInteractionState.RECOVER, "relaxes after the success")
	s.advance(BioInteractionState.RECOVER_SECONDS + 0.01)
	s.apply(_npc("idle", "", 5, 0, {"region": "pulmao"}), 122)
	assert_eq(s.phase, BioInteractionState.IDLE, "and returns to routine")


func test_a_reconnection_does_not_replay_a_finish() -> void:
	var s := BioInteractionState.new("neva")
	var cues := s.apply(_npc("idle", "", 9, 2), 500)
	assert_eq(cues.size(), 0, "history: nine tasks done before we arrived")
	assert_eq(s.phase, BioInteractionState.IDLE, "no pose")


func test_failure_block_and_help_are_shown_as_they_are() -> void:
	var s := BioInteractionState.new("rubra")
	s.apply(_npc("travel", "transportar-oxigenio", 1, 0, {"dest": "sangue", "arrive": 105}), 101)
	var cues := s.apply(_npc("blocked", "transportar-oxigenio", 1, 0), 108)
	assert_true(cues.has(&"blocked"), "the way is shut")
	assert_eq(s.phase, BioInteractionState.BLOCKED, "link broken, looking for another way")
	cues = s.apply(_npc("seek_help", "transportar-oxigenio", 1, 0, {"help": {"need": "capilares-obstruidos", "status": "open"}}), 113)
	assert_true(cues.has(&"asked"), "the request begins")
	assert_eq(s.help_need, "capilares-obstruidos", "with its real cause")
	cues = s.apply(_npc("idle", "", 1, 1), 150)
	assert_true(cues.has(&"failed"), "gave up: the failed counter grew")
	assert_eq(s.phase, BioInteractionState.CANCEL, "failure is readable, not hidden")


func test_roles_have_distinct_silhouettes_and_every_task_a_gesture() -> void:
	var seen := {}
	for id in ["rubra", "neva", "dendra", "macra", "placa", "kupffer", "estroma"]:
		seen[BioNpcRoles.role(id)["silhouette"]] = true
	assert_true(seen.size() >= 6, "six readable silhouettes (%d)" % seen.size())
	for task in ["transportar-oxigenio", "defender-pulmao", "limpar-alveolos", "apresentar-antigenos", "selar-ferida", "limpar-toxinas", "colher-sinais", "patrulhar-sangue"]:
		assert_true(BioNpcRoles.gesture(task) != "idle", "%s has its own gesture" % task)
	assert_eq(BioNpcRoles.gesture("transportar-oxigenio"), "carry", "Rubra")
	assert_eq(BioNpcRoles.gesture("defender-pulmao"), "defend", "Neva")
	assert_eq(BioNpcRoles.gesture("apresentar-antigenos"), "signal", "Dendra")
	assert_eq(BioNpcRoles.gesture("limpar-alveolos"), "engulf", "Macra")
	assert_eq(BioNpcRoles.gesture("selar-ferida"), "seal", "platelets")
	assert_eq(BioNpcRoles.gesture("nutrir-nicho-medular"), "feed", "Osteia feeds the niche")
	assert_eq(BioNpcRoles.verb("feed"), "nutre o nicho", "and says so")
	assert_eq(BioConflictFocus.organ({"def": "medula-esgotada"}), "Medula", "the marrow crisis is named")
	assert_true(BioConflictFocus.suggestion({"def": "medula-esgotada", "phase": "active"}).contains("Osteia"), "and points at her")
	assert_true(not BioOnlineClient.wanted("http://127.0.0.1:8096"), "a PC plays offline unless asked for the online mode")


func test_requests_and_vitality_come_from_the_view() -> void:
	var m := BioLivingModel.new()
	m.ingest(_view(100, [], [], [_npc("seek_help", "transportar-oxigenio", 1, 0, {"help": {"id": "h1", "need": "capilares-obstruidos", "status": "open", "text": "Rubra: ajuda"}}), {"id": "neva", "name": "Neva", "region": "pulmao", "phase": "idle", "done": 0, "failed": 0}]))
	assert_eq(m.open_requests().size(), 1, "only the open request")
	assert_near(m.region_vitality("sangue"), 0.5, 0.001, "headcount over capacity")
	assert_near(m.region_vitality("pele"), 1.0, 0.001, "untracked regions are not shown as sick")


func test_visual_presets_scale_cost_and_accessibility_removes_motion() -> void:
	var p := BioVisualPrefs.new()
	assert_true(BioVisualPrefs.PRESETS["economico"]["npc_cap"] < BioVisualPrefs.PRESETS["alto"]["npc_cap"], "the cheap preset draws fewer cells")
	p.preset = "alto"
	var full := p.fx_scale()
	p.reduced_motion = true
	assert_true(p.fx_scale() < full and not p.shake_allowed(), "reduced motion shrinks effects and forbids shake")
	p.reduced_motion = false
	p.reduce_flash = true
	assert_true(not p.shake_allowed(), "reduced flash also forbids shake")
	var path := "user://test_visual_prefs.cfg"
	p.preset = "economico"
	p.save(path)
	assert_eq(BioVisualPrefs.load_from(path).preset, "economico", "saved per device")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _ctx(sil: String, gesture: String, phase: StringName, t: float, extra: Dictionary = {}) -> Dictionary:
	var c := {"sil": sil, "gesture": gesture, "phase": phase, "progress": 0.5, "working": phase == BioInteractionState.ACT, "face": 0.0, "aim": 1.5, "aim_vec": Vector2.from_angle(1.5),
		"speed": 0.0, "t": t, "tempo": 1.0, "phase_offset": 0.0, "motion": 1.0}
	c.merge(extra, true)
	return c


func test_every_extension_moves_on_its_own_rhythm() -> void:
	var a := BioNpcMotion.limbs(_ctx("branch", "signal", BioInteractionState.ACT, 1.0))
	var b := BioNpcMotion.limbs(_ctx("branch", "signal", BioInteractionState.ACT, 1.7))
	var moved := 0
	var distinct := {}
	for k in a:
		if k.begins_with("den"):
			distinct[snappedf(float(a[k]["a"]) - float(k.trim_prefix("den").to_int()) * TAU / 7.0, 0.01)] = true
			if absf(float(a[k]["a"]) - float(b[k]["a"])) > 0.01:
				moved += 1
	assert_eq(moved, 7, "all seven dendrites move over time")
	assert_true(distinct.size() >= 6, "and not in unison (%d offsets)" % distinct.size())
	var spikes := BioNpcMotion.limbs(_ctx("lobed", "defend", BioInteractionState.ACT, 0.3))
	var amps := {}
	for i in 8:
		amps[snappedf(float(spikes["spike%d" % i]["amp"]), 0.01)] = true
	assert_true(amps.size() >= 4, "the spikes ripple round the outline instead of rising together (%d)" % amps.size())


func test_cells_have_their_own_tempo_and_the_same_on_every_client() -> void:
	var one := BioNpcMotion.personality(hash("rubra"))
	assert_eq(one, BioNpcMotion.personality(hash("rubra")), "stable")
	assert_true(one["tempo"] != BioNpcMotion.personality(hash("neva"))["tempo"], "each cell its own")
	assert_true(one["tempo"] >= 0.8 and one["tempo"] <= 1.25, "within a believable range")


func test_the_body_leans_into_the_work_and_gathers_before_it() -> void:
	var work := BioNpcMotion.body(_ctx("pseudo", "engulf", BioInteractionState.ACT, 1.0))
	assert_true((work["lean"] as Vector2).dot(Vector2.from_angle(1.5)) > 0.1, "towards the target while working")
	var before := BioNpcMotion.body(_ctx("pseudo", "engulf", BioInteractionState.ANTICIPATE, 1.0))
	assert_true((before["lean"] as Vector2).dot(Vector2.from_angle(1.5)) < 0.0, "back, gathering, before it")
	var travelling := BioNpcMotion.body(_ctx("disc", "carry", BioInteractionState.APPROACH, 1.0, {"speed": 1.0}))
	assert_true(float(travelling["stretch"]) > 0.2, "stretched along its heading when it moves fast")
	var calm := BioNpcMotion.body(_ctx("disc", "carry", BioInteractionState.ACT, 1.0, {"motion": 0.35}))
	assert_true(float(calm["stretch"]) <= float(travelling["stretch"]) and (calm["lean"] as Vector2).length() < 0.2, "reduced motion softens it")


func test_springs_follow_smoothly_overshoot_a_little_and_never_blow_up() -> void:
	var x := 0.0
	var v := 0.0
	var peak := 0.0
	for i in 120:
		var s := BioNpcMotion.spring(x, v, 1.0, 1.0 / 60.0)
		x = s.x
		v = s.y
		peak = maxf(peak, x)
	assert_near(x, 1.0, 0.02, "settles on the target")
	assert_true(peak > 1.0 and peak < 1.25, "a gentle overshoot, like soft tissue (%.2f)" % peak)
	var huge := BioNpcMotion.spring(0.0, 0.0, 1.0, 5.0)
	assert_true(is_finite(huge.x) and absf(huge.x) < 3.0, "a long pause does not throw the part away")
	var k := BioNpcMotion.limbs(_ctx("branch", "signal", BioInteractionState.ACT, 1.0))
	assert_true(k.size() >= 7 and k["den0"].has("k"), "each limb carries its own stiffness")
