extends SceneTree
## The interface as the player sees it (real renderer, a view shaped like the engine's): the HUD with a call waiting in the tray, the call
## card, and every tab of the Body window.
##   godot --path clients/hospedeiro --script res://tests/capture_ui.gd -- <output_dir>

var world: BioWorld
var out_dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _gene(id: String, name: String, rarity: String = "comum") -> Dictionary:
	return {"id": id, "name": name, "rarity": rarity}


func _run() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.8).timeout
	world.debug_become(&"macrofago")
	world.sync.link.online = true
	world.sync.system.set_status(true, 214)
	var quest := {"key": "q|p1", "state": "active", "rank": "D", "title": "Rastro da cripta", "objective": "Encontre o nicho de peroxissomos no fígado."}
	var call := {"key": "c|p1", "state": "offered", "giver": "osteia", "rank": "C", "title": "Guardar a reserva", "objective": "Guarde glicogênio no fígado três vezes.", "reward": "Pressão +6 e um gene"}
	var ev := {
		"genes": [_gene("pseudopodes-gigantes", "Pseudópodes Gigantes", "rara"), _gene("citoplasma-esponjoso", "Citoplasma Esponjoso"), _gene("membrana-espessa", "Membrana Espessa")],
		"library": [_gene("mitocondria-avida", "Mitocôndria Ávida", "incomum"), _gene("cilios-ageis", "Cílios Ágeis")],
		"builds": [{"slot": "1", "genes": [_gene("pseudopodes-gigantes", "Pseudópodes Gigantes"), _gene("mitocondria-avida", "Mitocôndria Ávida")]}, {"slot": "2", "genes": []}, {"slot": "3", "genes": []}],
		"offer": [_gene("fagossomo-profundo", "Fagossomo Profundo", "rara"), _gene("receptor-de-limpeza", "Receptor de Limpeza"), _gene("lisossomos-acidos", "Lisossomos Ácidos")],
		"featured": "fagossomo-profundo", "pressure": 30, "threshold": 30, "slots": 3, "restLeft": 0}
	var view := {"tick": 214, "quests": [quest], "others": [{"id": "osteia", "name": "Osteia, a guardiã", "kind": "celula", "region": "medula"}], "signs": [], "beliefs": [], "events": [], "skills": [], "evolution": ev,
		"lineage": {"current": "macrofago", "next": 120, "maturity": 71, "offer": [], "featured": ""}}
	world.sync.apply_view(view)
	world.sync.system.push_feed("Conectado ao Hospedeiro.")
	world.sync.system.push_feed("Seu corpo expressa um novo gene: Citoplasma Esponjoso")
	world.sensor.state.reset()
	await create_timer(0.8).timeout
	await _shot("ui_1_hud_calm")

	# a call arrives in the middle of a fight: it waits as a chip
	world.sensor.state.note_threat(BioClock.now())
	view["quests"] = [quest, call]
	world.sync.apply_view(view)
	await create_timer(0.7).timeout
	await _shot("ui_2_hud_fight")

	# calm again: the card
	world.sensor.state.reset()
	world.sync.system.set_calm(true)
	view["quests"] = [call]
	world.sync.apply_view(view)
	await create_timer(0.6).timeout
	await _shot("ui_3_call_card")

	view["quests"] = [quest]
	world.sync.apply_view(view)
	world.body_panel.open(BioBodyPanel.GENES)
	world.body_panel._swap_in = "mitocondria-avida"
	world.body_panel._swap_out = "membrana-espessa"
	world.body_panel.refresh()
	await create_timer(0.5).timeout
	await _shot("ui_4_body_genes")

	view["lineage"] = {"current": "", "next": 42, "maturity": 42, "featured": "macrofago", "offer": [
		{"id": "mieloide", "name": "Mieloide", "desc": "Robusto e generalista: ótimo em absorver."},
		{"id": "linfoide", "name": "Linfoide", "desc": "Esguio e preciso: toxina e energia."}]}
	view["evolution"] = _without_offer(ev)
	world.sync.apply_view(view)
	world.body_panel.show_tab(BioBodyPanel.FORM)
	await create_timer(0.5).timeout
	await _shot("ui_5_body_form")

	view["lineage"] = {"current": "macrofago", "next": 120, "maturity": 71, "offer": [], "featured": ""}
	world.sync.apply_view(view)
	world.body_panel.show_tab(BioBodyPanel.ABILITIES)
	await create_timer(0.4).timeout
	await _shot("ui_6_body_abilities")

	world.body_panel.show_tab(BioBodyPanel.BUILDS)
	await create_timer(0.4).timeout
	await _shot("ui_7_body_builds")
	quit()


func _without_offer(ev: Dictionary) -> Dictionary:
	var copy := ev.duplicate(true)
	copy["offer"] = []
	copy["featured"] = ""
	return copy


func _shot(name: String) -> void:
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
