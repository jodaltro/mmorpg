extends TestCase
var world: BioWorld

class DungeonLink extends BioEngineLink:
	var actions: Array[Dictionary] = []
	var status := 200
	func act(action: String, args: Dictionary = {}) -> Dictionary:
		actions.append({"action":action,"args":args.duplicate(true)})
		return {"status":status,"body":{}}

var recording: DungeonLink

func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	await tree.physics_frame
	world.sync.set_process(false)
	recording = DungeonLink.new()
	recording.online = true
	world.sync.add_child(recording)
	world.sync.link = recording

func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func _preview() -> Dictionary:
	return {"token":"test-draft", "choices":[{"kind":"gene","id":"vesicula-toxica","name":"Vesícula Tóxica","rarity":"rara","desc":"efeito"},{"kind":"gene","id":"nucleo-reativo","name":"Núcleo Reativo","desc":"efeito"}], "guaranteed":[{"kind":"number","id":"pressao","amount":12}], "first":[]}

func _run(state: String) -> Dictionary:
	return {"state":state,"dungeon":"granuloma","name":"O Granuloma","seed":818,"room":0,"rooms":[{"id":"guarda","name":"Guarda","kind":"guard"},{"id":"chefe","name":"Chefe","kind":"boss"}],"preview":_preview()}

func _text(node: Node) -> String:
	var text := str((node as Label).text) if node is Label else str((node as Button).text) if node is Button else ""
	for child in node.get_children(): text += "\n" + _text(child)
	return text

func test_entry_explains_actual_prizes_and_keeps_primary_action_outside_scroll() -> void:
	world.gate.eligible = true
	world.gate.expedition = {"preview":_preview()}
	world.dungeon_panel.open_gate(world.gate)
	var text := _text(world.dungeon_panel.modal)
	assert_true(text.contains("ESCOLHA 1 DESTES 2"))
	assert_true(text.contains("mais dois projéteis"))
	assert_true(text.contains("Corpo → Genes"))
	assert_true(text.contains("não entrega o prêmio"))
	assert_true(text.contains("Aproxime-se da entrada"))
	var button := world.dungeon_panel._actions.get_child(0) as Button
	assert_true(button.disabled, "map preview cannot enter a distant portal")
	assert_true(not world.dungeon_panel.modal.scroll.is_ancestor_of(button))
	world.player.position = world.gate.position
	world.dungeon_panel.open_gate(world.gate)
	assert_true(not (world.dungeon_panel._actions.get_child(0) as Button).disabled)

func test_ready_room_has_no_enemies_damage_or_automatic_clear() -> void:
	var run := _run("ready")
	run["modifier"] = {"id":"em-febre"}
	var clears := [0]
	world.dungeon.room_cleared.connect(func(_index: int) -> void: clears[0] += 1)
	world.dungeon.start(run)
	assert_true(world.dungeon.active and world.dungeon.briefing)
	assert_eq(world.dungeon.enemies().size(), 0)
	var hp := world.player.combatant.actor.vitals.membrane
	world.dungeon._process(20)
	assert_eq(world.player.combatant.actor.vitals.membrane, hp)
	assert_eq(clears[0], 0)
	run.state = "active"
	world.dungeon.start(run)
	assert_true(not world.dungeon.briefing)
	assert_eq(world.dungeon.room_index, 0)
	assert_true(not world.dungeon.enemies().is_empty())

func test_ready_starts_once_without_confirmation_and_claim_is_after_victory() -> void:
	var run := _run("ready")
	world.dungeon_panel.apply({"run":run})
	assert_true(not world.dungeon_panel.modal.visible)
	await tree.process_frame
	assert_eq(recording.actions.size(), 1)
	assert_eq(recording.actions[0].action, "iniciar-masmorra")
	assert_eq(recording.actions[0].args.preview, "test-draft")
	world.dungeon_panel.apply({"run":run})
	await tree.process_frame
	assert_eq(recording.actions.size(), 1, "polling never repeats the automatic authorization")
	assert_true(not world.dungeon_panel.modal.visible)
	run.state = "active"
	world.dungeon_panel.apply({"run":run})
	assert_true(not world.dungeon_panel.modal.visible)
	run.state = "cleared"
	world.dungeon_panel.apply({"run":run})
	assert_eq(world.dungeon_panel.mode, "claim")
	assert_true(_text(world.dungeon_panel.modal).contains("Escolher este prêmio"))
	assert_true(world.genome.equipped.is_empty(), "presenting a prize cannot equip it")
	run["rewardClaimed"] = "vesicula-toxica"
	world.dungeon_panel.apply({"run":run})
	assert_true(not world.tray._chips.has("dungeon-reward"))

func test_gate_automatically_enters_once_and_returning_does_not_reenter() -> void:
	world.gate.eligible = true
	world.gate.expedition = {"preview":_preview()}
	world.player.global_position = world.gate.global_position
	world.sync._auto_enter_gate()
	assert_eq(recording.actions.size(), 1)
	assert_eq(recording.actions[0].action, "entrar-masmorra")
	assert_eq(recording.actions[0].args.briefing, "yes", "keep explicit reward choice after victory")
	assert_true(not world.dungeon_panel.modal.visible)
	world.sync._auto_enter_gate()
	assert_eq(recording.actions.size(), 1)
	world.sync._dungeon_state = "preparing"
	world.player.global_position = Vector2.ZERO
	world.sync._auto_enter_gate()
	world.sync._dungeon_state = "cleared"
	world.player.global_position = world.gate.global_position
	world.sync._auto_enter_gate()
	assert_eq(recording.actions.size(), 1, "return from a run must not automatically enter again")
	world.player.global_position = Vector2.ZERO
	world.sync._auto_enter_gate()
	world.player.global_position = world.gate.global_position
	world.sync._auto_enter_gate()
	assert_eq(recording.actions.size(), 2, "leaving and approaching again allows another run")

func test_locked_gate_or_distant_preview_never_auto_enters() -> void:
	world.gate.expedition = {"preview":_preview()}
	world.player.global_position = world.gate.global_position
	world.sync._auto_enter_gate()
	assert_true(recording.actions.is_empty())
	world.gate.eligible = true
	world.player.global_position = Vector2.ZERO
	world.sync._auto_enter_gate()
	assert_true(recording.actions.is_empty())

func test_failed_automatic_start_shows_retry_instead_of_silently_blocking() -> void:
	recording.status = 0
	world.dungeon_panel.apply({"run":_run("ready")})
	await tree.process_frame
	assert_true(world.dungeon_panel.modal.visible)
	assert_true(_text(world.dungeon_panel.modal).contains("Tentar novamente"))
	world.dungeon_panel.apply({"run":_run("ready")})
	await tree.process_frame
	assert_eq(recording.actions.size(), 1, "a failed automatic request must not flood the engine")
	recording.status = 200
	(world.dungeon_panel._actions.get_child(0) as Button).pressed.emit()
	assert_eq(recording.actions.size(), 2)
	assert_true(not world.dungeon_panel.modal.visible)

func test_reward_copy_explains_the_effect_instead_of_only_naming_the_gene() -> void:
	var reward: Dictionary = _preview().choices[0]
	var text := BioRewardUi.summary([reward,{"kind":"number","id":"maturidade","amount":8}])
	assert_true(text.contains("mais dois projéteis"))
	assert_true(text.contains("Maturidade da célula"))
	assert_true(text.contains("permanente"))
	world.sync.system.set_active({"title":"Missão","rewardDetails":[reward]})
	world.sync.system.open_missions()
	assert_true(_text(world.sync.system._missions).contains("mais dois projéteis"))

func test_owned_prizes_cannot_be_selected_again_and_exhaustion_is_explicit() -> void:
	var run := _run("cleared")
	for reward in run.preview.choices: reward["owned"] = true
	world.dungeon_panel.apply({"run":run})
	var text := _text(world.dungeon_panel.modal)
	assert_true(not text.contains("Escolher este prêmio"))
	assert_true(text.contains("Concluir expedição"))
	world.dungeon_panel.close()
	world.gate.expedition = {"preview":{"choices":[],"guaranteed":[],"token":"empty"}}
	world.dungeon_panel.open_gate(world.gate)
	assert_true(_text(world.dungeon_panel.modal).contains("já conquistou os genes"))
