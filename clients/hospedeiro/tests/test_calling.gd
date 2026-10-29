extends TestCase
## The callings: the crisis offers a few classes, the player picks one, wears its form while it lasts and gets the base form back.


func _view(current: String, offer: Array, conflict: String = "ferida-1") -> Dictionary:
	return {"conflict": conflict, "current": current, "role": "cura" if current != "" else "", "form": "t-auxiliar" if current != "" else "", "offer": offer}


func _offer() -> Array:
	return [
		{"id": "t-auxiliar", "name": "Sustentador", "desc": "Alimenta quem trabalha.", "role": "cura", "form": "t-auxiliar", "missing": 3, "covered": 0, "gap": true},
		{"id": "neutrofilo", "name": "Armadilheiro", "desc": "Prende invasores.", "role": "combate", "form": "neutrofilo", "missing": 1, "covered": 0, "gap": true},
	]


func test_the_rules_read_the_engine_view() -> void:
	assert_true(BioCallingRules.is_choosing(_view("", _offer())), "an offer and no calling is a choice")
	assert_true(not BioCallingRules.is_choosing(_view("t-auxiliar", _offer())), "holding one is not choosing")
	assert_true(BioCallingRules.is_held(_view("t-auxiliar", [])), "held")
	assert_eq(BioCallingRules.form_of(_view("t-auxiliar", [])), BioLineageCatalog.normalise("t-auxiliar"), "the form is the lineage it names")
	assert_eq(BioCallingRules.form_of(_view("", _offer())), &"", "no calling, no form")
	assert_eq(BioCallingRules.need_text(_offer()[0]), "Faltam 3", "the missing role says how many")
	assert_eq(BioCallingRules.need_text({"missing": 0}), "Coberto", "a covered role says so")
	for role in ["combate", "limpeza", "cura", "controle", "marcacao"]:
		assert_true(BioCallingRules.ROLES.has(role), "%s has words" % role)


func test_a_form_lends_a_few_abilities_the_player_does_not_have() -> void:
	var form := BioLineageCatalog.normalise("neutrofilo")
	var lent := BioCallingRules.lent_abilities(form, [])
	assert_true(lent.size() > 0 and lent.size() <= BioCallingRules.ABILITIES_PER_FORM, "a form lends one or two abilities")
	var again := BioCallingRules.lent_abilities(form, lent)
	assert_true(not again.any(func(id: Variant) -> bool: return lent.has(id)), "never one the player already knows")
	assert_eq(BioCallingRules.lent_abilities(&"", []).size(), 0, "no form, nothing lent")


func test_the_panel_offers_cards_and_a_choice_is_sent() -> void:
	var panel := BioCallingPanel.new()
	tree.root.add_child(panel)
	panel.configure()
	panel.dwell = 0.0
	var picked := []
	panel.chosen.connect(func(id: String) -> void: picked.append(id))
	panel.apply(_view("", _offer()))
	assert_true(panel.is_card_visible(), "the offer shows as cards")
	assert_eq(panel.option_ids(), ["t-auxiliar", "neutrofilo"], "one card per option")
	panel.chosen.emit("neutrofilo")
	assert_eq(picked, ["neutrofilo"], "the choice goes out")
	panel.apply(_view("t-auxiliar", _offer()))
	assert_true(not panel.is_card_visible(), "holding a calling puts the cards away")
	assert_true(panel.chip_text().contains("Sustentador"), "and shows which one: %s" % panel.chip_text())
	panel.apply({"conflict": "", "offer": []})
	assert_eq(panel.chip_text(), "", "away from the crisis there is nothing to show")
	panel.queue_free()


func test_wearing_and_giving_back_the_form_in_the_world() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	var base := world.lineage_id
	var before: Array = world.abilities.known().duplicate()
	world.apply_engine_calling(_view("t-auxiliar", _offer()))
	assert_eq(world.lineage_id, BioLineageCatalog.normalise("t-auxiliar"), "the cell wears the form of the calling")
	assert_true(world.abilities.known().size() > before.size(), "and the form lends abilities")
	world.apply_engine_calling({"conflict": "", "offer": []})
	assert_eq(world.lineage_id, base, "released, the base form is back")
	assert_eq(world.abilities.known(), before, "and so are the abilities")
	world.queue_free()
	await tree.process_frame


func test_passing_through_a_crisis_offers_nothing_until_the_player_stays() -> void:
	var panel := BioCallingPanel.new()
	tree.root.add_child(panel)
	panel.configure()
	panel.dwell = 0.4
	panel.apply(_view("", _offer()))
	assert_true(not panel.is_card_visible(), "just arrived: nothing yet")
	await tree.create_timer(0.7).timeout
	assert_true(panel.is_card_visible(), "after staying a moment the offer comes")
	panel.apply({"conflict": "", "offer": []})
	panel.apply(_view("", _offer(), "other-crisis"))
	assert_true(not panel.is_card_visible(), "another crisis starts the wait again")
	panel.queue_free()


func test_a_long_frame_does_not_throw_the_body_into_a_needle() -> void:
	var body := BioCellBody.new()
	body._stretch = 0.3
	body._stretch_v = 4.0
	body._swell = 1.3
	for i in 30:
		body._step_elastic(0.4)  # a hitch of nearly half a second, again and again
	assert_true(absf(body._stretch) < 0.05, "the stretch settles instead of flipping between its limits (%f)" % body._stretch)
	assert_true(absf(body._swell - 1.0) < 0.05, "and so does the swell (%f)" % body._swell)
	body.free()
