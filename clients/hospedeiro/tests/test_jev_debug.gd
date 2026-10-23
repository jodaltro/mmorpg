extends TestCase
## The Jev panel and the test menu: what Jev is doing on screen, and buttons that take you straight to what you want to test.

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _advisor() -> Dictionary:
	return {
		"recent": [
			{"tick": 52, "kind": "design", "detail": "nucleo", "choice": "trevo", "default": "rim", "provider": "jev", "model": "typesafe/jev", "latencyMs": 412, "cost": 0.00003},
			{"tick": 52, "kind": "design", "detail": "membrana", "choice": "lisa", "default": "lisa", "provider": "default"},
			{"tick": 40, "kind": "evolution-slot", "detail": "2", "choice": "enzima-voraz", "default": "enzima-voraz", "provider": "jev", "latencyMs": 380, "cost": 0.00003},
		],
		"pending": [{"kind": "design", "detail": "brilho", "options": 6, "default": "ambar", "dueIn": 2}],
	}


func test_the_badge_says_in_a_line_who_is_deciding() -> void:
	assert_true(world.jev_panel.badge_text().contains("sem motor"), "offline it says that Jev decides nothing")
	world.jev_panel.set_online(true)
	world.jev_panel.set_data(_advisor())
	var badge := world.jev_panel.badge_text()
	assert_true(badge.contains("3 decisões") and badge.contains("2 pelo Jev") and badge.contains("1 pelo padrão") and badge.contains("1 à espera"), "the badge counts them: %s" % badge)


func test_the_panel_lists_waiting_and_taken_decisions_with_who_answered() -> void:
	world.jev_panel.set_online(true)
	world.jev_panel.set_data(_advisor())
	world.apply_design({"nucleo": "trevo", "membrana": "lisa"}, "motor")
	world.jev_panel.toggle()
	var text := world.jev_panel.text()
	assert_true(text.contains("design/brilho") and text.contains("em 2 ticks"), "what is waiting")
	assert_true(text.contains("design/nucleo") and text.contains("412 ms") and text.contains("diferente do padrão: rim"), "an answer by Jev, how long it took and that it differed from the default")
	assert_true(text.contains("padrão") and text.contains("evolution-slot/2"), "an answer by the deadline and a mutation slot")
	var totals := world.jev_panel.totals()
	assert_eq(totals["jev"], 2, "two by Jev")
	assert_near(totals["latency_ms"], 396.0, 0.1, "mean latency of Jev")
	assert_eq(world.jev_panel.source_of("nucleo"), "jev", "the nucleus came from Jev")
	assert_eq(world.jev_panel.source_of("membrana"), "padrão", "the membrane from the default")
	assert_eq(world.jev_panel.source_of("foco"), "?", "nothing recorded for the rest")
	world.apply_design({"nucleo": "rim"}, "debug")
	assert_eq(world.jev_panel.source_of("nucleo"), "debug", "a debug preview says so")


func test_the_engine_view_feeds_the_panel() -> void:
	world.sync.apply_view({"tick": 5, "advisor": _advisor()})
	assert_eq(world.jev_panel.rows.size(), 3, "the rows of the view arrive")
	assert_eq(world.jev_panel.pending.size(), 1, "and what is waiting")


func test_escape_opens_the_menu_and_every_button_exists() -> void:
	world.debug_menu.toggle()
	assert_true(world.debug_menu.is_open(), "the menu opens")
	for label in ["Alvéolos", "Granuloma: O bacilo (chefe)", "Macrófago", "5 vírions à frente", "Invulnerável (liga/desliga)", "Sortear um design completo", "Painel do Jev (F2)"]:
		assert_true(world.debug_menu.button_labels().has(label), "a button: %s" % label)
	assert_true(world.debug_menu.press("Fechar menu") and not world.debug_menu.is_open(), "and it closes")


func test_the_place_buttons_take_you_there() -> void:
	for pair in [["Alvéolos", BioBodyMap.PULMAO], ["Artéria", BioBodyMap.AORTA], ["Endocárdio", BioBodyMap.CORACAO]]:
		assert_true(world.debug_menu.press(pair[0]), "press %s" % pair[0])
		await tree.create_timer(0.25).timeout
		assert_eq(world.region, pair[1], "you are in %s" % pair[1])


func test_the_granuloma_buttons_start_the_room_you_choose() -> void:
	world.debug_menu.press("Granuloma: O bacilo (chefe)")
	await tree.create_timer(0.8).timeout
	assert_true(world.dungeon.active, "the run is on")
	assert_true(world.dungeon.enemies().size() > 0, "the boss room has enemies")
	world.debug_menu.press("Sair do granuloma")
	await tree.create_timer(0.3).timeout
	assert_true(not world.dungeon.active, "and you can leave it")


func test_the_class_button_gives_the_class_and_its_abilities() -> void:
	world.debug_menu.press("Linfócito B")
	assert_eq(world.lineage_id, &"linfocito_b", "you are a B cell")
	for id in BioAbilityCatalog.ids_of_class(&"linfocito_b"):
		assert_true(world.abilities.knows(id), "and know %s" % id)


func test_the_test_buttons_spawn_clear_refill_and_protect() -> void:
	world.debug_menu.press("5 vírions à frente")
	await tree.process_frame
	assert_eq(world.viruses().size(), 5, "five virions")
	world.debug_menu.press("Limpar vírions")
	await tree.create_timer(0.1).timeout
	assert_eq(world.viruses().size(), 0, "and none after cleaning: %s" % [world.viruses().map(func(v: Node) -> String: return "%s in %s at %s" % [v.get_path(), str(BioBodyMap.region_of((v.get_parent() as Node2D).global_position)), str(world.region)])])
	world.player.combatant.actor.vitals.membrane = 3.0
	world.debug_menu.press("Vida e ATP cheios")
	assert_eq(world.player.combatant.actor.vitals.membrane, world.player.combatant.actor.vitals.max_membrane, "full membrane")
	world.debug_menu.press("Invulnerável (liga/desliga)")
	world.player.combatant.actor.vitals.membrane = 1.0
	await tree.create_timer(0.2).timeout
	assert_eq(world.player.combatant.actor.vitals.membrane, world.player.combatant.actor.vitals.max_membrane, "god mode keeps the cell whole")
	world.debug_menu.press("Invulnerável (liga/desliga)")


func test_the_design_buttons_change_the_design_at_once() -> void:
	world.debug_menu.press("Sortear um design completo")
	assert_eq(world.design_source, "debug", "a random design is in effect")
	assert_true(world.design_traits.has("modo_cone") and world.design_traits.has("impacto") and world.design_traits.has("efeito"), "with modes, projectile and effects")
	assert_true(world.player.combatant.modes.has("cone"), "the family modes reach the combatant")
	var before := str(world.design_traits["impacto"])
	world.debug_menu.press("Próximo impacto")
	assert_true(str(world.design_traits["impacto"]) != before, "the next impact")
	world.debug_menu.press("Voltar ao design do motor")
	assert_eq(world.design_source, "nenhuma", "back to what the engine said (nothing yet)")
