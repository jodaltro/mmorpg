extends TestCase
var world: BioWorld

class LocalChoiceLink extends BioEngineLink:
	var calls := 0
	var chosen := {}
	func act(_action: String, args: Dictionary = {}) -> Dictionary:
		calls += 1
		chosen = args.duplicate()
		await get_tree().process_frame
		return {"status":200,"body":{}}

func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	world.set_process(false)
	world.sync.link.online = true
	await tree.physics_frame

func after_each() -> void:
	world.evolution_presentation.close()
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func offer() -> void:
	world.engine_lineage_offer = [{"id":"mieloide","name":"Mieloide","desc":"Resistência e força."},{"id":"linfoide","name":"Linfoide","desc":"Defesa e memória."}]

func test_offer_opens_centrally_only_outside_combat_and_dismisses_once() -> void:
	var ui := world.evolution_presentation
	offer()
	ui.note_combat()
	ui._process(0.1)
	assert_true(not ui.modal.visible, "combat keeps the choice in the Body menu")
	ui._combat_until = 0
	ui._process(0.1)
	assert_true(ui.modal.visible, "safe player sees the class choice in the center")
	ui.note_combat()
	ui._process(0.1)
	assert_true(not ui.modal.visible, "combat resumes controls immediately")
	ui._combat_until = 0
	ui._process(0.1)
	ui.close()
	ui._process(0.1)
	assert_true(not ui.modal.visible, "dismissed offer does not reopen every frame")
	world.body_panel.open(BioBodyPanel.FORM)
	assert_true(world.body_panel.is_open(), "offer remains accessible in the menu")
	world.body_panel.close()

func test_white_body_waits_for_confirmed_complete_design_not_elapsed_time() -> void:
	var ui := world.evolution_presentation
	assert_true(ui.begin({"id":"mieloide","name":"Mieloide"}))
	assert_true(not ui.begin({"id":"linfoide"}), "duplicate requests are blocked")
	ui.request_finished(200, ui._run)
	world.lineage_id = &"mieloide"
	ui.observe({"designRevision":10,"designPending":true})
	ui._process(3.0)
	assert_true(ui.body().evolution_white >= 0.9, "waiting body turns solid white")
	assert_true(not ui._revealing, "time alone cannot finish the evolution")
	ui.observe({"designRevision":10,"designPending":false})
	ui._process(0.1)
	assert_true(ui._revealing, "complete server design starts the reveal")
	assert_true(not ui.body()._evolution_hold)

func test_combat_menu_choice_requests_real_design_once() -> void:
	offer()
	world.panel.show_lineage_offer(world.engine_lineage_offer, "mieloide")
	var link := LocalChoiceLink.new()
	world.sync.add_child(link)
	world.sync.link = link
	link.online = true
	world.evolution_presentation.note_combat()
	world.body_panel.open(BioBodyPanel.FORM)
	assert_true(world.body_panel.pick(0), "combat still allows choosing through the menu")
	world.pick_mutation(1)
	assert_eq(link.calls, 1, "repeated taps cannot submit two class choices")
	assert_eq(link.chosen.get("design"), "refresh", "class choice actually requests the new design")
	assert_eq(link.chosen.get("lineage"), "mieloide")
	await tree.process_frame

func test_new_form_is_held_until_reveal_without_changing_real_genome() -> void:
	var body := world.evolution_presentation.body()
	var old_form := body.form
	body.begin_evolution()
	world.genome.lineage = &"macrofago"
	world.player.combatant.set_genome(world.genome)
	body.set_traits({"nucleo":"trevo"})
	assert_eq(body.form, old_form, "old silhouette stays visible while the design is pending")
	assert_eq(world.player.combatant.genome.lineage, &"macrofago", "actual confirmed class is not delayed")
	body.finish_evolution()
	assert_eq(body.form, &"macrofago")
	assert_eq(body.traits.get("nucleo"), "trevo")

func test_failure_disconnect_and_stale_callback_do_not_leave_a_white_body() -> void:
	var ui := world.evolution_presentation
	ui.begin({"id":"mieloide"})
	var previous_run := ui._run
	ui.request_finished(409, previous_run)
	assert_true(not ui.busy and not ui.body()._evolution_hold, "rejected choice releases presentation")
	ui.begin({"id":"linfoide"})
	ui.request_finished(500, previous_run)
	assert_true(ui.busy, "late callback cannot cancel a newer request")
	world.sync.link.online = false
	ui._process(0.1)
	assert_true(not ui.busy and not ui.body()._evolution_hold)

func test_offer_and_status_fit_small_mobile_viewport() -> void:
	var ui := world.evolution_presentation
	var old_size := tree.root.size
	var old_scale := tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i(360,640)
	tree.root.size = Vector2i(360,640)
	await tree.process_frame
	ui.modal.fit()
	ui._fit_status()
	await tree.process_frame
	ui.modal.fit()
	assert_true(ui.modal.card.size.x <= 360, "mobile card width: %s; heading min: %s; mode: %s; head min: %s; content: %s" % [ui.modal.card.size, ui.modal.heading.get_combined_minimum_size(), ui.modal.heading.autowrap_mode, ui.modal.heading.get_parent().get_combined_minimum_size(),ui.modal.content.get_combined_minimum_size()])
	assert_true(ui._status.offset_right - ui._status.offset_left <= 360, "mobile caption width: %s" % (ui._status.offset_right-ui._status.offset_left))
	assert_true(ui.modal.heading.custom_minimum_size.y >= 22, "offer heading reserves a visible line")
	assert_true(ui._caption.custom_minimum_size.y >= 22, "cinematic caption reserves a visible line")
	tree.root.size = old_size
	tree.root.content_scale_size = old_scale

func test_reset_clears_old_world_revision_and_dismissal() -> void:
	offer()
	var ui := world.evolution_presentation
	ui.close()
	ui._revision = 900
	ui.begin({"id":"mieloide"})
	ui.reset()
	assert_eq(ui._revision, 0, "new world cannot wait for a revision from the previous world")
	assert_eq(ui._dismissed, "", "new world's first offer may open again")
	assert_true(not ui.busy and not ui.body()._evolution_hold)
