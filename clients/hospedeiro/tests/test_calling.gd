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


func test_a_form_lends_its_whole_class_of_abilities() -> void:
	var form := BioLineageCatalog.normalise("neutrofilo")
	var all := BioAbilityCatalog.ids_of_class(form)
	assert_true(all.size() > 0, "the class has abilities")
	var lent := BioCallingRules.lent_abilities(form, [])
	assert_eq(lent.size(), all.size(), "the player arrives with all of them")
	var again := BioCallingRules.lent_abilities(form, lent)
	assert_eq(again.size(), 0, "never one the player already knows")
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
	panel.choose("neutrofilo")
	panel.choose("neutrofilo")
	assert_eq(picked, ["neutrofilo"], "the choice goes out, once however often it is pressed")
	assert_true(not panel.is_card_visible() and panel.chip_text().begins_with("ASSUMINDO"), "the cards close at once while the engine confirms")
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
	var kit := BioAbilityCatalog.ids_of_class(BioLineageCatalog.normalise("t-auxiliar"))
	assert_eq(world.abilities.known().slice(0, kit.size()), kit, "and its whole kit sits in the first slots, ready to use")
	world.restore_ability_order()
	assert_eq(world.abilities.known().slice(0, kit.size()), kit, "even when the order is restored while it lasts")
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


func test_the_crisis_card_says_what_the_role_does_and_every_place_has_a_short_name() -> void:
	var held := _view("t-auxiliar", [])
	var line := BioCallingRules.card_line(held, "Sustentador")
	assert_true(line.contains("Sustentador") and line.contains("Cura") and line.ends_with("."), "the held calling: its name, its role and what it does (%s)" % line)
	assert_true(BioCallingRules.card_line(_view("", _offer()), "").contains("cartão"), "choosing: it points at the card")
	assert_eq(BioCallingRules.card_line({"conflict": "", "offer": []}, ""), "", "nothing to say away from a crisis")
	assert_eq(BioCallingRules.what_it_does("cura").substr(0, 1), "S", "the sentence starts with a capital, not every word")
	for id in BioBodyMap.NAMES:
		assert_true(BioBodyMap.SHORT.has(id), "%s has a short name for the maps" % id)


func test_the_feed_gives_the_body_s_ambient_news_one_line_at_a_time() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	var sync: BioHostSync = world.sync
	sync._last_ambient = -100.0
	assert_true(sync._worth_the_feed("world-news"), "the first ambient line goes through")
	assert_true(not sync._worth_the_feed("world-news"), "the next ones wait")
	assert_true(sync._worth_the_feed("conflict-escalated"), "a crisis event is never held back")
	assert_true(sync._worth_the_feed("calling-assumed"), "nor the player's own calling")
	world.queue_free()
	await tree.process_frame
