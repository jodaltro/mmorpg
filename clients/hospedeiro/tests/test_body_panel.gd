extends TestCase
## The windows: what waits for calm, the Body window with its tabs, the comparison of a swap and the saved builds.

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


func _gene(id: String, name: String, rarity: String = "comum") -> Dictionary:
	return {"id": id, "name": name, "rarity": rarity}


## An engine view with three genes expressed, one in the library, a saved build and no rest left.
func _evolution(extra: Dictionary = {}) -> Dictionary:
	var ev := {
		"genes": [_gene("flagelo-calejado", "Flagelo Calejado"), _gene("cilios-ageis", "Cílios Ágeis"), _gene("membrana-espessa", "Membrana Espessa")],
		"library": [_gene("mitocondria-avida", "Mitocôndria Ávida", "rara")],
		"builds": [{"slot": "1", "genes": [_gene("flagelo-calejado", "Flagelo Calejado")]}, {"slot": "2", "genes": []}, {"slot": "3", "genes": []}],
		"offer": [], "pressure": 12, "threshold": 30, "slots": 3, "restLeft": 0}
	ev.merge(extra, true)
	return ev


func _lineage_offer() -> Dictionary:
	return {"current": "", "next": 42, "maturity": 42, "offer": [{"id": "mieloide", "name": "Mieloide", "desc": "x"}, {"id": "linfoide", "name": "Linfoide", "desc": "y"}], "featured": "mieloide"}


func _online() -> void:
	world.sync.link.online = true
	world.sensor.state.reset()


func _fight() -> void:
	world.sensor.state.note_threat(BioClock.now())


# --- the pieces without a screen -------------------------------------------------------------------------------------------------

func test_combat_state_waits_for_calm() -> void:
	var s := BioCombatState.new()
	assert_true(s.is_calm(100.0), "nothing happened: calm")
	s.note_threat(100.0)
	assert_true(s.in_combat(102.0), "two seconds after a threat is still a fight")
	assert_near(s.calm_in(102.0), BioCombatState.CALM_AFTER - 2.0, 0.001, "it says how long is left")
	assert_true(s.is_calm(100.0 + BioCombatState.CALM_AFTER), "calm again after the quiet time")
	s.note_threat(50.0)
	assert_true(s.is_calm(100.0 + BioCombatState.CALM_AFTER), "an old threat does not bring the fight back")


func test_preview_says_what_a_swap_does_to_each_stat() -> void:
	var rows := BioBuildPreview.rows(&"", [&"membrana_espessa"], [&"cilios_ageis"])
	var by_key := {}
	for r in rows:
		by_key[r["key"]] = r
	assert_eq(by_key[BioGene.MAX_MEMBRANE]["better"], -1, "less membrane is worse")
	assert_eq(by_key[BioGene.SPEED]["better"], 1, "more speed is better")
	assert_true(str(by_key[BioGene.MAX_MEMBRANE]["now"]).begins_with("+"), "it reads as a percentage")
	var cooldown := BioBuildPreview.rows(&"", [], [&"nucleo_reativo"])
	var dash := cooldown.filter(func(r: Dictionary) -> bool: return r["key"] == BioGene.DASH_COOLDOWN)
	assert_eq(dash[0]["better"], 1, "a shorter cooldown is better")
	assert_true(BioBuildPreview.lineage_lines(&"macrofago").size() > 0, "a class lists what it does to the body")


func test_builds_keep_their_names_and_the_order_of_the_abilities() -> void:
	var path := "user://test_builds.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var store := BioBuildStore.new(path)
	assert_eq(store.name_of(2), "Build 2", "an unnamed build has a number")
	store.set_name(2, "  Tanque  ")
	store.save_order(2, [&"engolir", &"muralha_de_carne"])
	store.remember_current([&"muralha_de_carne", &"engolir"])
	var again := BioBuildStore.new(path)
	assert_eq(again.name_of(2), "Tanque", "the name is kept, trimmed")
	assert_eq(again.order_of(2), ["engolir", "muralha_de_carne"], "and the order saved with the build")
	assert_eq(again.current_order, ["muralha_de_carne", "engolir"], "and the order in use")
	again.set_name(2, "   ")
	assert_eq(again.name_of(2), "Build 2", "an empty name goes back to the number")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- calls and the tray ------------------------------------------------------------------------------------------------------------

func test_tray_chips_wait_while_the_cell_fights() -> void:
	var tray := world.tray
	tray.set_call("mutation", "mutation", "Mutação disponível", "3 genes para escolher", "G")
	assert_true(tray.has_call("mutation"), "the chip is up")
	assert_true(tray.chip_text("mutation").contains("3 genes"), "it says what is waiting")
	tray.set_calm(false)
	assert_true(tray.chip_text("mutation").contains("após o combate"), "in a fight it says to wait")
	tray.set_calm(true)
	assert_true(tray.chip_text("mutation").contains("3 genes"), "calm again: what it is about")
	tray.clear_call("mutation")
	assert_true(not tray.has_call("mutation"), "the chip goes away")


func test_a_call_waits_for_the_end_of_the_fight() -> void:
	var offer := {"key": "q|p1", "state": "offered", "giver": "", "rank": "E", "title": "Calor no capilar", "objective": "Examine o capilar.", "reward": "Reputação +1"}
	var system := world.sync.system
	system.set_calm(false)
	system.show_offer(offer, "Neva")
	assert_true(system.has_offer(), "the call exists")
	assert_true(not system.is_offer_visible(), "but it does not interrupt a fight: Y and N do nothing")
	assert_true(world.tray.has_call("quest"), "it waits as a chip")
	system.set_calm(true)
	assert_true(system.is_offer_visible(), "calm: the card opens")
	assert_true(not world.tray.has_call("quest"), "and the chip goes away")
	assert_true(system.offer_text().contains("Neva") and system.offer_text().contains("Calor no capilar"), "the card says who calls and for what")
	system.hide_offer()
	assert_true(not system.is_offer_visible() and not system.has_offer(), "withdrawn")


func test_the_sensor_sees_an_enemy_that_has_noticed_the_cell() -> void:
	assert_true(not world.sensor._engaged(), "virions that only drift by are not a fight")
	var virus := world.viruses()[0] as BioCellActor
	virus.global_position = world.player.global_position + Vector2(3.0, 0.0) * BioArt.UNIT
	for child in virus.get_children():
		if child is BioVirusBrain:
			child.state = BioVirusBrain.State.CHASE
	assert_true(world.sensor._engaged(), "one that is chasing is")
	for child in virus.get_children():
		if child is BioVirusBrain:
			child.state = BioVirusBrain.State.WANDER
	assert_true(not world.sensor._engaged(), "and when it loses interest the fight ends")


func test_a_pending_offer_puts_a_chip_in_the_tray() -> void:
	world.sync.apply_view(_view({"evolution": _evolution({"offer": [_gene("cauda-longa", "Cauda Longa")], "featured": "cauda-longa"})}))
	assert_true(world.tray.has_call("mutation"), "a mutation to choose")
	world.sync.apply_view(_view({"evolution": _evolution()}))
	assert_true(not world.tray.has_call("mutation"), "chosen: the chip goes")
	world.sync.apply_view(_view({"lineage": _lineage_offer()}))
	assert_true(world.tray.has_call("lineage"), "a body ready to differentiate")


# --- the Body window ---------------------------------------------------------------------------------------------------------------

func test_the_body_window_opens_where_something_waits() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution({"offer": [_gene("cauda-longa", "Cauda Longa"), _gene("enzima-voraz", "Enzima Voraz")], "featured": "cauda-longa"})}))
	world.body_panel.open()
	assert_eq(world.body_panel.tab, BioBodyPanel.GENES, "a mutation to choose: the genes tab")
	assert_true(world.body_panel.content_text().contains("Cauda Longa"), "the offer is on the tab")
	assert_true(world.body_panel.content_text().contains("Flagelo Calejado"), "and the genes expressed")
	assert_true(world.body_panel.content_text().contains("Mitocôndria Ávida"), "and the library")
	world.body_panel.close()
	world.sync.apply_view(_view({"evolution": _evolution(), "lineage": _lineage_offer()}))
	world.body_panel.open()
	assert_eq(world.body_panel.tab, BioBodyPanel.FORM, "a differentiation to choose: the form tab")
	assert_true(world.body_panel.content_text().contains("Mieloide"), "with its options")
	assert_true(BioUi.captures_input(), "an open window takes the mouse")
	world.body_panel.close()
	assert_true(not BioUi.captures_input(), "closed: the cell attacks with the mouse again")


func test_choices_wait_for_calm() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution({"offer": [_gene("cauda-longa", "Cauda Longa")], "featured": "cauda-longa"})}))
	world.body_panel.open()
	_fight()
	assert_true(world.body_panel.lock_reason().contains("combate"), "in a fight the genes are locked")
	assert_true(not world.body_panel.pick(0), "and the offer cannot be chosen")
	world.sensor.state.reset()
	assert_eq(world.body_panel.lock_reason(), "", "calm: nothing in the way")
	assert_true(world.body_panel.pick(0), "the choice goes to the engine")
	world.body_panel.close()


func test_nothing_changes_inside_a_dungeon_or_offline() -> void:
	assert_true(world.body_panel.lock_reason().contains("motor"), "offline the body is not reconfigured")
	_online()
	assert_eq(world.body_panel.lock_reason(), "", "online and calm")
	world.dungeon.active = true
	assert_true(world.body_panel.lock_reason().contains("masmorra"), "not inside a dungeon")
	world.dungeon.active = false


func test_the_body_rests_between_changes() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution({"restLeft": 5})}))
	assert_true(world.body_panel.lock_reason().contains("acomoda"), "the engine says the body is still settling")
	assert_eq(world.body_panel.lock_reason(false), "", "a choice of the offer does not wait for it")


func test_a_swap_is_previewed_before_it_is_made() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution()}))
	world.body_panel.open(BioBodyPanel.GENES)
	world.body_panel._swap_in = "mitocondria-avida"
	world.body_panel._swap_out = "cilios-ageis"
	assert_eq(world.body_panel.previewed_genes(), [&"flagelo_calejado", &"membrana_espessa", &"mitocondria_avida"], "the expressed set after the swap")
	assert_eq(world.body_panel.current_genes(), [&"flagelo_calejado", &"cilios_ageis", &"membrana_espessa"], "while nothing changed yet")
	world.body_panel.refresh()
	assert_true(world.body_panel.content_text().contains("RESULTADO DA TROCA"), "the window shows the comparison")
	world.body_panel.close()


func test_the_builds_tab_shows_the_saved_sets() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution()}))
	world.body_panel.open(BioBodyPanel.BUILDS)
	var text := world.body_panel.content_text()
	assert_true(text.contains("Flagelo Calejado"), "build 1 lists its genes")
	assert_true(text.contains("vazia"), "the others are empty")
	assert_true(text.contains("Salvar aqui") and text.contains("Aplicar"), "with the two gestures")
	world.body_panel.close()


func test_two_clicks_swap_the_keys_of_two_abilities() -> void:
	world.debug_become(&"macrofago")
	var first := world.abilities.slot_id(0)
	var second := world.abilities.slot_id(1)
	world.body_panel.open(BioBodyPanel.ABILITIES)
	world.body_panel.click_ability(0)
	world.body_panel.click_ability(1)
	assert_eq(world.abilities.slot_id(0), second, "the second took the first key")
	assert_eq(world.abilities.slot_id(1), first, "and the first the second key")
	assert_eq(world.build_store.current_order[0], String(second), "the order is remembered")
	world.abilities.arrange([first, second])
	assert_eq(world.abilities.slot_id(0), first, "a saved build puts them back in its order")
	world.body_panel.close()
