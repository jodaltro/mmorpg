extends SceneTree
## Screenshots of the living body (real renderer): cells at work, a crisis on the tissue, the followed-crisis card, an alert and a call for help.
##   godot --path clients/hospedeiro --script res://tests/capture_living.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _conflict(id: String, title: String, phase: String, region: String, severity: int, revision: int = 3, since: int = 96) -> Dictionary:
	return {"id": id, "def": id, "title": title, "phase": phase, "region": region, "revision": revision, "since": since, "severity": severity, "peak": 80,
		"metrics": [{"id": "x", "label": "Oxigenação do pulmão", "value": 41}], "frontRegions": {"circulacao": "sangue"} if id == "infeccao-pulmonar" else {}}


func _npc(id: String, name_text: String, region: String, phase: String, task: String, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": id, "name": name_text, "region": region, "phase": phase, "task": task, "done": 3, "failed": 0, "step": 1, "steps": 3, "since": 96}
	e.merge(extra, true)
	return e


func _view(tick: int, society: Array, conflicts: Array) -> Dictionary:
	return {"tick": tick, "quests": [], "others": [], "signs": [], "beliefs": [], "events": [], "skills": [], "society": society,
		"populations": [{"id": "hemacias_sangue", "region": "sangue", "count": 40, "max": 80}],
		"conflicts": {"revision": 5, "focus": "infeccao-pulmonar", "active": conflicts, "recent": []}}


func _shoot(path: String) -> void:
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(path)


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.6).timeout
	var sync := world.sync
	var lung := BioBodyMap.center_px(&"pulmao")
	world.player.global_position = lung + Vector2(-6.0, 8.0) * BioArt.UNIT
	await create_timer(0.5).timeout
	var crises := [_conflict("infeccao-pulmonar", "Infecção pulmonar", "active", "pulmao", 55, 2, 90)]
	var society := [
		_npc("neva", "Neva, neutrófila veterana", "pulmao", "travel", "defender-pulmao", {"dest": "pulmao", "arrive": 120, "step": 1}),
		_npc("macra", "Macra", "pulmao", "travel", "limpar-alveolos", {"dest": "pulmao", "arrive": 120, "step": 1}),
		_npc("rubra", "Rubra, hemácia anciã", "pulmao", "travel", "transportar-oxigenio", {"dest": "pulmao", "arrive": 120, "step": 1}),
		_npc("dendra", "Dendra", "pulmao", "travel", "apresentar-antigenos", {"dest": "pulmao", "arrive": 120, "step": 1}),
	]
	sync.apply_view(_view(100, society, crises))
	for i in 30:
		sync.mood._process(0.5)
	for key in sync.presenter._states:
		sync.presenter._states[key].refine(0.55)
	await _shoot(out_dir + "/living_lung_work.png")
	crises[0]["phase"] = "critical"
	crises[0]["severity"] = 78
	crises[0]["revision"] = 3
	crises[0]["since"] = 101
	sync.apply_view(_view(101, society, crises))
	sync.living_hud._process(0.3)
	await _shoot(out_dir + "/living_alert.png")
	society[2] = _npc("rubra", "Rubra, hemácia anciã", "pulmao", "seek_help", "transportar-oxigenio", {"dest": "pulmao", "help": {"id": "h1", "need": "capilares-obstruidos", "text": "Rubra: os capilares do pulmão estão obstruídos pela infecção. Preciso de ajuda para abrir caminho.", "region": "pulmao", "status": "open"}})
	sync.living_hud.set_player_region("pulmao")
	sync.apply_view(_view(130, society, crises))
	sync.living_hud._alert_left = 0.0
	sync.living_hud._alert.visible = false
	sync.living_hud._update_help()
	await _shoot(out_dir + "/living_help.png")
	sync.living_hud.toggle_panel()
	await _shoot(out_dir + "/living_panel.png")
	sync.living_hud.toggle_panel()
	await _roles(world, out_dir)
	quit()


## Every role at work in a row, close to the camera, each in its own gesture.
func _roles(world: BioWorld, out_dir: String) -> void:
	var sync := world.sync
	var order := [["rubra", "transportar-oxigenio"], ["neva", "defender-pulmao"], ["dendra", "apresentar-antigenos"], ["macra", "limpar-alveolos"],
		["placa", "selar-ferida"], ["kupffer", "limpar-toxinas"], ["esplena", "reciclar-no-baco"]]
	var society: Array = []
	for o in order:
		society.append(_npc(o[0], o[0].capitalize(), "pulmao", "travel", o[1], {"dest": "pulmao", "arrive": 140, "step": 1}))
	sync.apply_view(_view(120, society, []))
	await create_timer(0.3).timeout
	sync.presenter.set_process(false)
	var base := world.player.global_position + Vector2(-330.0, -150.0)
	for i in order.size():
		var a := sync.presenter.actor(order[i][0])
		var st := sync.presenter.state_of(order[i][0])
		st.refine(0.5)
		a.position = base + Vector2(i * 110.0, 0.0)
		a.target = a.position
		a.lod = 2
		a.aim(Vector2(0.3, 1.0))
	sync.living_hud.visible = false
	await _shoot(out_dir + "/living_roles.png")
	for i in order.size():
		var st2 := sync.presenter.state_of(order[i][0])
		st2.refine(0.9)
	await _shoot(out_dir + "/living_roles_anticipate.png")
	# Outcomes: blocked, a call for help, a confirmed delivery, a failure.
	var outcome := [
		_npc("rubra", "Rubra", "pulmao", "blocked", "transportar-oxigenio", {"dest": "pulmao"}),
		_npc("neva", "Neva", "pulmao", "idle", "", {"done": 4}),
		_npc("dendra", "Dendra", "pulmao", "seek_help", "apresentar-antigenos", {"dest": "pulmao", "help": {"id": "h9", "need": "x", "text": "x", "region": "pulmao", "status": "open"}}),
		_npc("macra", "Macra", "pulmao", "idle", "", {"failed": 1}),
		_npc("placa", "Placa", "pulmao", "travel", "selar-ferida", {"dest": "pulmao", "arrive": 140, "step": 1}),
		_npc("kupffer", "Kupffer", "pulmao", "travel", "limpar-toxinas", {"dest": "pulmao", "arrive": 140, "step": 1}),
		_npc("esplena", "Esplena", "pulmao", "travel", "reciclar-no-baco", {"dest": "pulmao", "arrive": 140, "step": 1}),
	]
	sync.presenter.apply_view(_view(121, outcome, []))
	for o in order:
		sync.presenter.state_of(o[0]).advance(0.3)
	await _shoot(out_dir + "/living_outcomes.png")
