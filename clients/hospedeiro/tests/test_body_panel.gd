extends TestCase
## The windows: the Body window with its tabs, the comparison of a swap and the saved builds.

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




# --- the pieces without a screen -------------------------------------------------------------------------------------------------


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
	store.save_order(2, [&"engolir", &"polarizacao"])
	store.remember_current([&"polarizacao", &"engolir"])
	var again := BioBuildStore.new(path)
	assert_eq(again.name_of(2), "Tanque", "the name is kept, trimmed")
	assert_eq(again.order_of(2), ["engolir", "polarizacao"], "and the order saved with the build")
	assert_eq(again.current_order, ["polarizacao", "engolir"], "and the order in use")
	again.set_name(2, "   ")
	assert_eq(again.name_of(2), "Build 2", "an empty name goes back to the number")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- calls and the tray ------------------------------------------------------------------------------------------------------------


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


func test_inspection_keeps_the_order_and_explicit_move_swaps_abilities() -> void:
	world.debug_become(&"macrofago")
	var first := world.abilities.slot_id(0)
	var second := world.abilities.slot_id(1)
	world.body_panel.open(BioBodyPanel.ABILITIES)
	world.body_panel.click_ability(0)
	world.body_panel.click_ability(1)
	assert_eq(world.abilities.slot_id(0), first, "inspection never rearranges the bar")
	world.body_panel.click_ability(0)
	world.body_panel._ability_moving = true
	world.body_panel.click_ability(1)
	assert_eq(world.abilities.slot_id(0), second, "the second took the first key")
	assert_eq(world.abilities.slot_id(1), first, "and the first the second key")
	assert_eq(world.build_store.current_order[0], String(second), "the order is remembered")
	world.abilities.arrange([first, second])
	assert_eq(world.abilities.slot_id(0), first, "a saved build puts them back in its order")
	world.body_panel.close()


func test_chips_and_calls_are_always_there_for_the_player_to_open() -> void:
	var tray := world.tray
	tray.set_call("mutation", "mutation", "Mutação disponível", "3 genes para escolher", "G")
	assert_true(tray.chip_text("mutation").contains("3 genes"), "the chip says what is waiting, fight or not")
	tray.clear_call("mutation")
	var offer := {"key": "q|p1", "state": "offered", "giver": "", "rank": "E", "title": "Calor no capilar", "objective": "Examine o capilar.", "reward": "Reputação +1"}
	world.sync.system.show_offer(offer, "Neva")
	assert_true(world.sync.system.is_offer_visible(), "the call card is up as soon as it arrives")
	assert_true(world.sync.system.offer_text().contains("Neva") and world.sync.system.offer_text().contains("Calor no capilar"), "it says who calls and for what")
	world.sync.system.hide_offer()
	assert_true(not world.sync.system.is_offer_visible(), "withdrawn")


func test_choices_are_not_held_back_by_a_fight() -> void:
	_online()
	world.sync.apply_view(_view({"evolution": _evolution({"offer": [_gene("cauda-longa", "Cauda Longa")], "featured": "cauda-longa"})}))
	world.body_panel.open()
	assert_eq(world.body_panel.lock_reason(), "", "nothing in the way, fight or not")
	assert_true(world.body_panel.pick(0), "the choice goes to the engine")
	world.body_panel.close()


func test_abilities_show_one_short_inspector_and_details_are_optional() -> void:
	world.debug_become(&"macrofago")
	world.body_panel.open(BioBodyPanel.ABILITIES)
	assert_eq(world.body_panel.ability_slots.size(), 4)
	assert_true(not world.body_panel.content_text().contains("COMO FUNCIONA"))
	world.body_panel.click_ability(0)
	var text := world.body_panel.content_text()
	assert_true(text.contains("ATP") and not text.contains("COMO FUNCIONA"))
	world.body_panel._ability_details = true
	world.body_panel.refresh()
	assert_true(world.body_panel.content_text().contains("COMO FUNCIONA"))
	world.body_panel.reorder_abilities(0, 3)
	assert_eq(world.body_panel._ability_pick, 3)

func test_build_selection_does_not_equip_or_rename_anything() -> void:
	world.sync.apply_view(_view({"evolution": _evolution()}))
	world.body_panel.open(BioBodyPanel.BUILDS)
	world.body_panel.select_build(2)
	assert_true(world.body_panel.content_text().contains("Preset vazio"))
	assert_eq(world.body_panel.current_genes().size(), 3)
	assert_true(not world.body_panel._rename_build)
	world.body_panel._confirm_save = true
	world.body_panel.select_build(1)
	assert_true(not world.body_panel._confirm_save, "changing preset cancels overwrite confirmation")

func test_saved_order_can_differ_even_when_genes_match() -> void:
	world.debug_become(&"macrofago")
	var order: Array = world.abilities.known().duplicate()
	world.build_store.save_order(1, order)
	assert_true(not world.body_panel._build_order_differs(1))
	world.body_panel.reorder_abilities(0, 1)
	assert_true(world.body_panel._build_order_differs(1))


class BuildLink extends BioEngineLink:
	var code := 409
	var calls := 0
	func act(_action: String, _args: Dictionary = {}) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return {"status": code, "body": {"events": []}}

func test_failed_build_requests_preserve_the_active_and_saved_order() -> void:
	var fake := BuildLink.new()
	world.add_child(fake)
	fake.online = true
	world.sync.link = fake
	world.sync.apply_view(_view({"evolution": _evolution()}))
	world.debug_become(&"macrofago")
	var order: Array = world.abilities.known().duplicate()
	world.build_store.save_order(1, order)
	world.body_panel.reorder_abilities(0, 1)
	var changed: Array = world.abilities.known().duplicate()
	await world.body_panel.apply_build(1)
	assert_eq(world.abilities.known(), changed, "failed application cannot rearrange abilities")
	await world.body_panel.save_build(1)
	assert_eq(world.build_store.order_of(1), order.map(func(id: Variant) -> String: return str(id)), "failed save keeps the previous preset")
	fake.code = 200
	await world.body_panel.apply_build(1)
	assert_eq(world.abilities.known(), order, "confirmed application restores the saved order")
	assert_true(not world.body_panel._busy)
	assert_true(world.body_panel._operation_note.contains("aplicada"))
	fake.calls = 0
	world.body_panel.save_build(1)
	world.body_panel.save_build(1)
	assert_eq(fake.calls, 1, "two taps while pending send just one request")
	await tree.process_frame
	await tree.process_frame
	assert_true(not world.body_panel._busy)


func test_background_refresh_preserves_a_name_being_edited() -> void:
	world.body_panel.open(BioBodyPanel.BUILDS)
	world.body_panel._rename_build = true
	world.body_panel.refresh()
	await tree.process_frame
	await tree.process_frame
	var edit := tree.root.gui_get_focus_owner() as LineEdit
	assert_true(edit != null)
	if edit != null:
		edit.text = "Guardião"
		world.body_panel.refresh()
		assert_true(tree.root.gui_get_focus_owner() == edit, "polling does not replace the focused name field")
		assert_eq(edit.text, "Guardião")


func test_submitting_a_build_name_commits_and_closes_the_editor() -> void:
	world.body_panel.open(BioBodyPanel.BUILDS)
	world.body_panel._rename_build = true
	world.body_panel.refresh()
	await tree.process_frame
	await tree.process_frame
	var edit := tree.root.gui_get_focus_owner() as LineEdit
	if edit == null:
		assert_true(false, "rename receives keyboard focus")
		return
	edit.text_submitted.emit("Exploração")
	assert_eq(world.build_store.name_of(1), "Exploração")
	assert_true(not world.body_panel._rename_build)
	assert_true(not BioUi.typing())


func test_dragging_a_saved_preset_changes_only_its_saved_order() -> void:
	world.debug_become(&"macrofago")
	var active_order: Array = world.abilities.known().duplicate()
	world.sync.apply_view(_view({"evolution": _evolution()}))
	world.build_store.save_order(1, active_order)
	world.body_panel.open(BioBodyPanel.BUILDS)
	var preview_slots: Array = tree.get_nodes_in_group("loadout_slots").filter(func(node: Node) -> bool: return node.scope == -world.body_panel.get_instance_id())
	assert_eq(preview_slots.size(), 4)
	var target := preview_slots.filter(func(node: Node) -> bool: return node.slot == 3)[0] as BioLoadoutSlot
	target._drop_data(Vector2.ZERO, {"kind": "ability", "scope": -world.body_panel.get_instance_id(), "slot": 0})
	assert_eq(world.abilities.known(), active_order, "editing a preset never equips it")
	assert_eq(world.build_store.order_of(1)[3], String(active_order[0]))
	assert_eq(world.build_store.order_of(1)[0], String(active_order[3]))
	var saved: Array = world.build_store.order_of(1).duplicate()
	world.body_panel.reorder_build_abilities(1, -1, 2)
	assert_eq(world.build_store.order_of(1), saved, "invalid drops cannot change the preset")
