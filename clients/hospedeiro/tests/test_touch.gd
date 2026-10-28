extends TestCase
## The controls for a finger: the stick's arithmetic, the button's grip on an input action, the layer that joins them to the game (it
## aims for a thumb that is busy running, hides under windows, and never lets a held button outlive its finger) and the pieces of
## the platform layer that do not need a browser.

var world: BioWorld


func before_each() -> void:
	BioPlatform.forced_touch = 1
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame
	await tree.physics_frame
	world.display.preferences_path = ""


func after_each() -> void:
	BioPlatform.forced_touch = -1
	BioCellBody.background_stride = 1
	Input.action_release(&"bio_lash")
	Input.action_release(&"bio_dash")
	world.queue_free()
	await tree.process_frame


func test_mobile_ping_is_small_visible_and_does_not_capture_taps() -> void:
	world.touch.layout(Vector2(667,375))
	world.touch._update_ping(false)
	assert_eq(world.touch.ping_label.text,"Offline","offline is explicit")
	assert_eq(world.touch.ping_label.mouse_filter,Control.MOUSE_FILTER_IGNORE,"ping never blocks controls")
	assert_true(world.touch.ping_label.position.x+world.touch.ping_label.size.x<=world.touch.menu.position.x,"ping stays beside menu")
	world.touch._update_ping(true)
	assert_true(not world.touch.ping_label.visible,"modal windows hide the combat HUD")


func _touch(control: Control, index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	control._gui_input(e)


func _drag(control: Control, index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	control._gui_input(e)


func test_a_floating_stick_reads_from_where_the_finger_landed() -> void:
	var stick := BioTouchStick.new()
	stick.size = Vector2(300, 300)
	stick.radius = 60.0
	_touch(stick, 0, Vector2(100, 200), true)
	assert_true(stick.is_engaged(), "the finger is on the stick")
	assert_eq(stick.value(), Vector2.ZERO, "landing alone moves nothing")
	_drag(stick, 0, Vector2(160, 200))
	assert_near(stick.value().x, 1.0, 0.001, "a full radius to the right")
	assert_near(stick.value().y, 0.0, 0.001, "and no tilt")
	_drag(stick, 0, Vector2(100, 170))
	assert_near(stick.value().y, -0.5, 0.001, "half a radius up")
	_drag(stick, 0, Vector2(100, 20))
	assert_near(stick.value().length(), 1.0, 0.001, "pulling past the edge still reads one")
	_touch(stick, 0, Vector2(100, 20), false)
	assert_eq(stick.value(), Vector2.ZERO, "letting go stops")
	assert_true(not stick.is_engaged())
	stick.free()


func test_a_stick_ignores_the_dead_zone_and_other_fingers() -> void:
	var stick := BioTouchStick.new()
	stick.size = Vector2(300, 300)
	stick.radius = 60.0
	stick.dead_zone = 0.3
	_touch(stick, 0, Vector2(100, 100), true)
	_drag(stick, 0, Vector2(110, 100))
	assert_eq(stick.value(), Vector2.ZERO, "a tremor is not a direction")
	_drag(stick, 1, Vector2(200, 100))
	assert_eq(stick.value(), Vector2.ZERO, "another finger's drag is not this one's")
	_touch(stick, 1, Vector2(200, 100), false)
	assert_true(stick.is_engaged(), "another finger lifting does not release this one")
	stick.free()


func test_a_fixed_stick_reads_from_its_centre() -> void:
	var stick := BioTouchStick.new()
	stick.floating = false
	stick.size = Vector2(200, 200)
	stick.radius = 50.0
	_touch(stick, 0, Vector2(100, 40), true)  # landing off-centre already points
	assert_true(stick.value().y < -0.9, "landing above the centre points up")
	stick.free()


func test_a_button_holds_its_action_for_as_long_as_the_finger_and_never_less_than_a_frame_or_two() -> void:
	var button := BioTouchButton.round_button(&"bio_dash", "x", Color.WHITE, 30.0)
	tree.root.add_child(button)
	_touch(button, 3, Vector2(30, 30), true)
	assert_true(Input.is_action_pressed(&"bio_dash"), "pressed while the finger is down")
	_touch(button, 3, Vector2(30, 30), false)
	assert_true(Input.is_action_pressed(&"bio_dash"), "a tap shorter than the minimum is stretched, or a poll would miss it")
	await tree.create_timer(0.2).timeout
	assert_true(not Input.is_action_pressed(&"bio_dash"), "and then it lets go")
	button.queue_free()


func test_a_button_taken_off_screen_under_a_finger_lets_go() -> void:
	var button := BioTouchButton.round_button(&"bio_lash", "x", Color.WHITE, 30.0)
	tree.root.add_child(button)
	_touch(button, 0, Vector2(30, 30), true)
	assert_true(Input.is_action_pressed(&"bio_lash"))
	button.visible = false  # a window opened over it: the release will never arrive
	assert_true(not Input.is_action_pressed(&"bio_lash"), "a hidden button must not stay pressed")
	button.queue_free()


func test_a_circle_button_is_hit_a_little_beyond_its_edge_and_not_in_the_corner() -> void:
	var button := BioTouchButton.round_button(&"", "x", Color.WHITE, 30.0)
	assert_true(button._has_point(Vector2(30, 30)), "centre")
	assert_true(button._has_point(Vector2(30, 1)), "near the rim")
	assert_true(not button._has_point(Vector2(2, 2)), "the corner of the square is not the button")
	button.free()


func test_the_world_builds_the_finger_controls_only_on_a_touch_screen() -> void:
	assert_true(world.touch != null, "touch forced on: controls exist")
	assert_true(world.display != null, "and so does the display layer")
	var input: BioPlayerInput
	for child in world.player.get_children():
		if child is BioPlayerInput:
			input = child
	assert_true(input != null and input.touch == world.touch, "the player's input reads from them")
	assert_true(not InputMap.action_get_events(&"bio_lash").any(func(e: InputEvent) -> bool: return e is InputEventMouseButton), "a tap that becomes a click is not an attack")


func test_the_cell_aims_at_the_nearest_enemy_when_no_thumb_aims() -> void:
	var near := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(5.0, 0.0) * BioArt.UNIT, world.player, BioEnemyCatalog.enemy(&"cilindro_hialino"), 1.0, "viruses")
	var far := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(0.0, 9.0) * BioArt.UNIT, world.player, BioEnemyCatalog.enemy(&"cilindro_hialino"), 1.0, "viruses")
	(near as Node).set_process(false)
	(far as Node).set_process(false)
	await tree.physics_frame
	await tree.physics_frame
	world.touch._refresh_aim()
	var aim := world.touch.aim_vector()
	assert_true(aim.x > 0.95, "the closer enemy is to the right: aim %s" % str(aim))
	# a thumb on the attack button takes over
	_touch(world.touch.attack_stick, 0, world.touch.attack_stick.size * 0.5, true)
	_drag(world.touch.attack_stick, 0, world.touch.attack_stick.size * 0.5 + Vector2(0, -40))
	assert_true(world.touch.aim_vector().y < -0.95, "the thumb points up: %s" % str(world.touch.aim_vector()))
	_touch(world.touch.attack_stick, 0, Vector2.ZERO, false)


func test_holding_the_attack_stick_is_holding_the_lash() -> void:
	var stick := world.touch.attack_stick
	_touch(stick, 0, stick.size * 0.5, true)
	assert_true(Input.is_action_pressed(&"bio_lash"), "touching the attack button attacks")
	_touch(stick, 0, stick.size * 0.5, false)
	assert_true(not Input.is_action_pressed(&"bio_lash"), "letting go stops")


func test_the_play_controls_step_aside_for_a_window_and_come_back() -> void:
	await tree.process_frame
	await tree.process_frame
	assert_true(world.touch.attack_stick.visible and world.touch.move_stick.visible, "in play they are there")
	world.body_panel.open()
	await tree.process_frame
	await tree.process_frame
	assert_true(not world.touch.attack_stick.visible and not world.touch.move_stick.visible and not world.touch.dash.visible, "a window covers the screen: no stick under it")
	assert_true(not world.touch.menu.visible, "navigation does not overlap the window close button")
	assert_true(world.touch.window_buttons[0].emphasis, "and the one that opened it is lit")
	world.body_panel.toggle()
	await tree.process_frame
	await tree.process_frame
	assert_true(world.touch.attack_stick.visible, "closed: back")


func test_a_held_attack_is_released_when_a_window_opens_over_it() -> void:
	var stick := world.touch.attack_stick
	_touch(stick, 0, stick.size * 0.5, true)
	assert_true(Input.is_action_pressed(&"bio_lash"))
	world.body_panel.open()
	await tree.process_frame
	await tree.process_frame
	assert_true(not Input.is_action_pressed(&"bio_lash"), "the cell does not keep attacking behind a window")
	world.body_panel.toggle()


func test_every_control_fits_inside_the_screen_for_each_shape_of_phone_and_tablet() -> void:
	for view in [Vector2(909, 420), Vector2(747, 420), Vector2(1024, 768), Vector2(820, 600), Vector2(960, 420)]:
		world.touch.layout(view)
		var rect := Rect2(Vector2.ZERO, view)
		var controls: Array[Control] = [world.touch.attack_stick, world.touch.toxin, world.touch.dash, world.touch.interact, world.touch.respawn, world.touch.fullscreen]
		for b in world.touch.ability_buttons:
			controls.append(b)
		for b in world.touch.window_buttons:
			controls.append(b)
		for c in controls:
			if c == world.touch.fullscreen and not c.visible:
				continue
			var box := Rect2(c.position, c.size)
			if c == world.touch.attack_stick:
				box = box.grow(-c.size.x * 0.1)
			assert_true(rect.encloses(box), "%s inside a %s screen: %s" % [c.name if c.name != &"" else c.get_class(), str(rect.size), str(box)])


func test_no_two_buttons_on_the_attack_arc_overlap() -> void:
	world.touch.layout(Vector2(909, 420))
	var buttons: Array[BioTouchButton] = [world.touch.toxin, world.touch.dash, world.touch.interact]
	buttons += world.touch.ability_buttons
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a := buttons[i]
			var b := buttons[j]
			var gap := (a.position + a.size * 0.5).distance_to(b.position + b.size * 0.5) - a.radius - b.radius
			assert_true(gap >= 0.0, "buttons %d and %d are %.1f apart" % [i, j, gap])
		var stick := world.touch.attack_stick
		var to_stick := (buttons[i].position + buttons[i].size * 0.5).distance_to(stick.position + stick.size * 0.5) - buttons[i].radius - stick.radius
		assert_true(to_stick >= 0.0, "button %d clears the attack stick by %.1f" % [i, to_stick])


func test_platform_defaults_on_the_native_client() -> void:
	assert_true(not BioPlatform.is_web())
	assert_eq(BioPlatform.engine_url("http://127.0.0.1:8096"), "http://127.0.0.1:8096", "native keeps its own address")
	assert_true(BioPlatform.debug_enabled(), "the developer's client has the test menu")
	assert_true(BioPlatform.fullscreen_available())


func test_a_new_cell_has_no_id_until_the_engine_gives_one() -> void:
	var identity := BioEngineLink.local_identity("user://does_not_exist_%d.json" % Time.get_ticks_usec())
	assert_eq(identity["id"], "", "ids are the engine's to give")
	assert_eq(identity["token"], "")
	assert_true(str(identity["name"]).begins_with("Celula-tronco"))


func test_a_saved_identity_comes_back_with_its_token() -> void:
	var path := "user://identity_test_%d.json" % Time.get_ticks_usec()
	var link := BioEngineLink.new()
	link.configure("http://127.0.0.1:1", {"id": "cel-abc", "name": "N", "token": "tok"}, path)
	link._save_identity()
	var back := BioEngineLink.local_identity(path)
	assert_eq(back["id"], "cel-abc")
	assert_eq(back["token"], "tok")
	link.free()
	DirAccess.remove_absolute(path)


func test_tapping_attack_off_centre_keeps_auto_aim_until_dragged() -> void:
	var stick := world.touch.attack_stick
	_touch(stick, 0, stick.size * 0.5 + Vector2(32, 0), true)
	assert_eq(stick.value(), Vector2.ZERO, "landing near the rim must not override auto aim")
	_drag(stick, 0, stick.size * 0.5 + Vector2(32, -45))
	assert_true(stick.value().y < -0.7, "dragging from the contact aims manually")
	_touch(stick, 0, Vector2.ZERO, false)


func test_menu_hides_combat_and_releases_a_held_attack() -> void:
	_touch(world.touch.attack_stick, 0, world.touch.attack_stick.size * 0.5, true)
	world.touch.menu.tapped.emit()
	await tree.process_frame
	await tree.process_frame
	assert_true(world.touch.menu_open)
	assert_true(world.touch.window_buttons[0].visible)
	assert_true(not world.touch.attack_stick.visible)
	assert_true(not Input.is_action_pressed(&"bio_lash"))
	world.touch.menu.tapped.emit()
	assert_true(not world.touch.window_buttons[0].visible)


func test_auto_aim_keeps_target_when_another_enemy_is_only_slightly_closer() -> void:
	var a := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(5, 0) * BioArt.UNIT, world.player, BioEnemyCatalog.enemy(&"cilindro_hialino"), 1.0, "viruses")
	var b := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(0, 6) * BioArt.UNIT, world.player, BioEnemyCatalog.enemy(&"cilindro_hialino"), 1.0, "viruses")
	a.set_process(false)
	b.set_process(false)
	await tree.physics_frame
	await tree.physics_frame
	world.touch._refresh_aim()
	assert_true(world.touch.aim_vector().x > 0.95)
	(b.get_parent() as BioCellActor).global_position = world.player.global_position + Vector2(0, 4.8) * BioArt.UNIT
	await tree.physics_frame
	world.touch._refresh_aim()
	assert_true(world.touch.aim_vector().x > 0.95, "a tiny distance change must not flicker the aim")
	(b.get_parent() as BioCellActor).global_position = world.player.global_position + Vector2(0, 1) * BioArt.UNIT
	world.touch._refresh_aim()
	assert_eq(world.touch._target, a.get_parent(), "keep the first target even when a different enemy becomes much closer")
	(a.get_parent() as BioCellActor).set_active(false)
	world.touch._refresh_aim()
	assert_eq(world.touch._target, b.get_parent(), "reacquire only after the locked target becomes invalid")
	_touch(world.touch.attack_stick, 0, world.touch.attack_stick.size * 0.5, true)
	_drag(world.touch.attack_stick, 0, world.touch.attack_stick.size * 0.5 + Vector2(-70, 0))
	assert_true(world.touch.aim_vector().x < -0.95, "explicit drag overrides the locked target")
	_touch(world.touch.attack_stick, 0, Vector2.ZERO, false)
	world.touch._refresh_aim()
	assert_true(world.touch.aim_vector().y > 0.95, "releasing manual aim returns to the same valid target")
	(b.get_parent() as BioCellActor).queue_free()
	await tree.process_frame
	world.touch._refresh_aim()
	assert_true(not is_instance_valid(world.touch._target), "destroyed targets are discarded without passing freed objects to typed helpers")


func test_skill_button_aims_then_casts_only_on_release_and_can_cancel() -> void:
	var b := BioTouchButton.round_button(&"", "", Color.WHITE,27)
	b.cast_on_release = true
	b.cancel_rect = Rect2(Vector2(100,0),Vector2(60,60))
	var casts: Array[Vector2] = []
	b.cast_requested.connect(func(direction: Vector2) -> void: casts.append(direction))
	tree.root.add_child(b)
	_touch(b,0,Vector2(27,27),true)
	assert_eq(casts.size(),0,"holding previews but never casts")
	_drag(b,0,Vector2(27,-20))
	_touch(b,0,Vector2(27,-20),false)
	assert_eq(casts.size(),1)
	assert_true(casts[0].y < -0.95,"release uses the dragged direction")
	_touch(b,0,Vector2(27,27),true)
	_drag(b,0,Vector2(120,20))
	assert_true(b.cancelled)
	_touch(b,0,Vector2(120,20),false)
	assert_eq(casts.size(),1,"release in the cancel area casts nothing")
	_touch(b,0,Vector2(27,27),true)
	b.visible = false
	assert_eq(casts.size(),1,"opening a window while aiming casts nothing")
	b.queue_free()


func test_combat_cluster_leaves_the_centre_free_at_all_mobile_sizes() -> void:
	for view in [Vector2(747,420),Vector2(909,420),Vector2(1024,768)]:
		world.touch.layout(view)
		var middle := Rect2(Vector2(view.x*0.3,view.y*0.3),Vector2(view.x*0.3,view.y*0.6))
		var buttons: Array[Control] = [world.touch.toxin,world.touch.dash,world.touch.interact,world.touch.attack_stick]
		for b in world.touch.ability_buttons:
			buttons.append(b)
		for b in buttons:
			assert_true(not middle.intersects(Rect2(b.position,b.size)),"combat buttons stay outside central visibility")


func test_minimap_tap_opens_the_full_atlas() -> void:
	_touch(world.touch.minimap,0,Vector2(40,40),true)
	assert_true(world.atlas.is_open())
	world.atlas.toggle()


func test_interface_scale_changes_everything_without_changing_world_coverage() -> void:
	var display := world.display
	var coverage := display.logical_size.y/world.camera.zoom.y
	for value in [0.75,1.0,1.25]:
		display.set_interface_scale(value)
		await tree.process_frame
		await tree.process_frame
		assert_near(display.logical_size.y/world.camera.zoom.y,coverage,0.1,"UI scale leaves the world field of view unchanged")
		assert_eq(world.touch.scale_label.text,"Tamanho da interface: %d%%" % roundi(value*100))
		for view in [Vector2(747,420)/value,Vector2(909,420)/value,Vector2(1024,768)/value]:
			world.touch.layout(view)
			var screen := Rect2(Vector2.ZERO,view)
			var controls: Array[Control] = [world.touch.attack_stick,world.touch.toxin,world.touch.dash,world.touch.interact,world.touch.menu]
			for button in world.touch.ability_buttons:
				controls.append(button)
			for control in controls:
				assert_true(screen.encloses(Rect2(control.position,control.size)),"all combat buttons fit at %d%%" % roundi(value*100))
				if control != world.touch.attack_stick:
					assert_true(not world.touch.toxin.cancel_rect.intersects(Rect2(control.position,control.size)),"cancel target remains separate at each scale")
	display.set_interface_scale(1.0)


func test_interface_scale_persists_and_invalid_preferences_are_clamped() -> void:
	var path := "user://display_test_%d.cfg" % Time.get_ticks_usec()
	var display := world.display
	display.preferences_path = path
	display.set_interface_scale(1.25)
	var restored := BioDisplay.new()
	restored.preferences_path = path
	restored._load_scale()
	assert_near(restored.interface_scale,1.25,0.001)
	var config := ConfigFile.new()
	config.set_value("interface","scale",8.0)
	config.save(path)
	restored._load_scale()
	assert_near(restored.interface_scale,1.25,0.001,"saved values outside range are limited")
	display.preferences_path = ""
	display.set_interface_scale(1.0)
	restored.free()
	DirAccess.remove_absolute(path)


func test_navigation_closes_after_selecting_and_windows_are_exclusive() -> void:
	world.touch.menu.tapped.emit()
	assert_true(world.touch.menu_open)
	world.touch.window_buttons[0].tapped.emit()
	assert_true(world.body_panel.is_open())
	assert_true(not world.touch.menu_open)
	world.codex_panel.toggle()
	assert_true(world.codex_panel.is_open())
	assert_true(not world.body_panel.is_open())
	world.atlas.toggle()
	assert_true(world.atlas.is_open())
	assert_true(not world.codex_panel.is_open())
	world.vitals_panel.toggle()
	assert_true(world.vitals_panel.is_open())
	assert_true(not world.atlas.is_open())
	world.vitals_panel.close()
	assert_true(not BioUi.captures_input())

func test_outside_tap_dismisses_but_outside_drag_does_not() -> void:
	world.body_panel.open()
	var modal := world.body_panel._dim
	var event := InputEventScreenTouch.new()
	event.position = Vector2(2, 2)
	event.pressed = true
	modal._outside_input(event)
	assert_true(world.body_panel.is_open(), "wait for release")
	event.pressed = false
	event.position = Vector2(2, 80)
	modal._outside_input(event)
	assert_true(world.body_panel.is_open(), "drag does not dismiss")
	event.position = Vector2(2, 2)
	event.pressed = true
	modal._outside_input(event)
	event.pressed = false
	modal._outside_input(event)
	assert_true(not world.body_panel.is_open())

func test_dragging_a_card_never_selects_it_and_tap_waits_for_release() -> void:
	var card := PanelContainer.new()
	var clicks: Array = []
	BioUi.bind_tap(card, func() -> void: clicks.append(true))
	var press := InputEventScreenTouch.new()
	press.position = Vector2(20, 20)
	press.pressed = true
	card.gui_input.emit(press)
	assert_eq(clicks.size(), 0)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(20, 80)
	card.gui_input.emit(drag)
	press.pressed = false
	press.position = Vector2(20, 20)
	card.gui_input.emit(press)
	assert_eq(clicks.size(), 0, "even dragging back to the origin is not a tap")
	press.pressed = true
	card.gui_input.emit(press)
	press.pressed = false
	card.gui_input.emit(press)
	assert_eq(clicks.size(), 1)
	card.free()

func test_action_menu_selection_closes_and_outside_dismissal_preserves_offer() -> void:
	world.sync.system.open_menu([{"title": "Observar", "action": "inspect"}])
	assert_true(world.sync.system.menu_open)
	world.sync.system._menu_rows.get_child(0).pressed.emit()
	assert_true(not world.sync.system.menu_open, "choosing an action closes its menu")
	world.sync.system.show_offer({"key": "test", "title": "Chamado", "objective": "Observar"}, "Sentinela")
	world.sync.system.open_offer()
	assert_true(world.sync.system.is_offer_visible())
	world.sync.system._offer_modal.dismissed.emit()
	assert_true(not world.sync.system.is_offer_visible())
	assert_true(world.sync.system.has_offer(), "outside means later, not refusing the mission")
	assert_true(not BioUi.captures_input())


func test_skill_hold_starts_drag_but_swipe_and_hidden_window_cancel_it() -> void:
	world.debug_become(&"macrofago")
	world.body_panel.open(BioBodyPanel.ABILITIES)
	await tree.process_frame
	var slot := world.body_panel.ability_slots[0]
	_touch(slot, 0, Vector2(20, 20), true)
	_drag(slot, 0, Vector2(20, 50))
	slot._down_at = Time.get_ticks_msec() - 400
	slot._process(0)
	assert_true(BioLoadoutSlot.active == null, "swiping leaves the scroll container in control")
	_touch(slot, 0, Vector2(20, 50), false)
	_touch(slot, 0, Vector2(20, 20), true)
	slot._down_at = Time.get_ticks_msec() - 400
	slot._process(0)
	assert_true(BioLoadoutSlot.active == slot, "holding deliberately picks up the skill")
	world.body_panel.refresh()
	assert_true(BioLoadoutSlot.active == slot, "background updates preserve the held skill")
	world.body_panel.close()
	assert_true(BioLoadoutSlot.active == null, "closing the window cancels the drag")

func test_skill_drop_is_scoped_to_its_editor_and_empty_slots_reject_it() -> void:
	var slot := BioLoadoutSlot.new()
	slot.configure(2, &"engolir", 123, false)
	assert_true(slot._get_drag_data(Vector2.ZERO) == null, "emulated mouse never bypasses the touch hold")
	assert_true(slot._can_drop_data(Vector2.ZERO, {"kind": "ability", "scope": 123, "slot": 0}))
	assert_true(not slot._can_drop_data(Vector2.ZERO, {"kind": "ability", "scope": 456, "slot": 0}))
	assert_true(not slot._can_drop_data(Vector2.ZERO, {"kind": "ability", "scope": 123, "slot": 2}))
	slot.free()
	var empty := BioLoadoutSlot.new()
	empty.configure(2, &"", 123, false)
	assert_true(not empty._can_drop_data(Vector2.ZERO, {"kind": "ability", "scope": 123, "slot": 0}))
	empty.free()


func test_missions_open_from_corner_and_navigation_never_blocks_them() -> void:
	world.sync.system.set_active({"title": "Defender a medula", "objective": "Observe o nicho"})
	assert_true(world.tray.has_call("active_quest"))
	var chip: Control = world.tray._chips["active_quest"]["root"]
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(20, 20)
	tap.pressed = true
	chip.gui_input.emit(tap)
	assert_true(not world.sync.system._missions.visible)
	tap.pressed = false
	chip.gui_input.emit(tap)
	assert_true(world.sync.system._missions.visible)
	assert_true(BioUi.captures_input())
	world.sync.system.hide_offer()
	assert_true(BioUi.captures_input(), "an expiring offer cannot release input while the journal remains open")
	world.sync.system.set_active({"title": "Defender a medula", "objective": "Novo objetivo"})
	await tree.process_frame
	await tree.process_frame
	assert_true(world.sync.system._missions.content.get_children().any(func(node: Node) -> bool: return node is Label and node.text.contains("Novo objetivo")), "mission details update while the journal is open")
	world.touch.menu.tapped.emit()
	assert_true(not world.sync.system._missions.visible)
	await tree.process_frame
	assert_true(not world.tray._box.visible, "corner missions do not show through the navigation backdrop")
	assert_true(not world.sync.system._column.visible)
	world.touch.close()
	world.sync.system.open_missions()
	assert_true(world.sync.system._missions.visible)
	world.sync.system.close()
	assert_true(not BioUi.captures_input())

func test_reset_dialog_dismissal_preserves_progress_and_requires_server_permission() -> void:
	world.debug_become(&"macrofago")
	var original: Array = world.abilities.known().duplicate()
	world.reset_dialog.open()
	assert_true(world.reset_dialog.modal.visible)
	world.reset_dialog.close()
	assert_eq(world.abilities.known(), original)
	world.engine_url = "http://127.0.0.1:1"
	world.sync.link.online = false
	world.reset_dialog.open()
	assert_true(world.reset_dialog._confirm.disabled, "an unavailable server cannot silently reset only the local cell")
	world.reset_dialog.close()
	world.engine_url = ""
	world.reset_dialog.open()
	await world.reset_dialog._reset()
	assert_true(world.abilities.known().is_empty())
	assert_true(not world.reset_dialog.modal.visible)
