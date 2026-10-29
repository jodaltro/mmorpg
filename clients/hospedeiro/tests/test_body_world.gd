extends TestCase
## The big body in the running world: the cell can cross it, the walls hold, only the regions around the cell are alive and the
## atlas fills in as it goes.

var world: BioWorld


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _count_in(group: String, region: StringName) -> int:
	var n := 0
	for node in tree.get_nodes_in_group(group):
		if BioBodyMap.region_of((node as Node2D).global_position) == region:
			n += 1
	return n


func test_only_the_regions_around_the_cell_are_alive_and_populated() -> void:
	assert_eq(world.live_regions, [&"medula", &"sangue"] as Array[StringName], "born in the marrow: it and the blood are alive")
	assert_true(_count_in("nutrients", &"medula") >= 20 and _count_in("nutrients", &"sangue") >= 12, "and populated")
	assert_eq(_count_in("nutrients", &"pulmao"), 0, "the lung is asleep and empty")
	assert_true(not world.anatomy.layer(&"pulmao").visible, "and not drawn")
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.CORACAO)
	await tree.create_timer(1.5).timeout
	assert_eq(world.region, BioBodyMap.CORACAO, "now in the heart")
	assert_true(not world.live_regions.has(&"medula"), "the marrow goes to sleep")
	assert_true(_count_in("nutrients", &"medula") == 0, "its nutrients are let go")
	assert_true(not world.live_regions.has(&"pulmao"), "a neighbour far from the cell sleeps too: the heart alone is awake in its middle")
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.CORACAO) + Vector2(0.0, -32.0) * BioArt.UNIT  # towards the lung, in its vessel
	await tree.create_timer(1.2).timeout
	assert_true(world.live_regions.has(&"pulmao"), "near its edge the lung wakes")
	assert_true(_count_in("nutrients", &"pulmao") >= 10, "fills up")
	assert_true(world.anatomy.layer(&"pulmao").visible and not world.anatomy.layer(&"medula").visible, "and the drawing follows")


func test_the_walls_hold_in_the_new_chambers() -> void:
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.CORACAO) + Vector2(0.0, 10.0 * BioArt.UNIT)
	await tree.physics_frame
	world.player.velocity = Vector2.ZERO
	for frame in 240:  # push against the wall of the heart (away from every vessel) for four seconds
		world.player.set_intent(Vector2(-0.6, 0.8))
		await tree.physics_frame
	assert_true(BioAnatomy.in_body(BioBodyMap.seed_value, world.player.global_position / BioArt.UNIT), "the cell is still inside the body")


func test_the_atlas_has_no_fog_and_the_screen_says_where_the_cell_is() -> void:
	assert_true(world.atlas.knows(&"pulmao"), "the lung is on the map before the cell goes there")
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.PULMAO)
	await tree.create_timer(0.4).timeout
	assert_eq(world.region, BioBodyMap.PULMAO, "walking in changes the region")
	assert_eq(world.sync.system._region.text, str(BioBodyMap.NAMES.get(BioBodyMap.PULMAO)), "and the screen says where the cell is")


func test_the_cell_can_cross_from_the_marrow_to_the_aorta_through_the_vessels() -> void:
	var path: Array[Vector2] = BioAnatomy.route(BioBodyMap.seed_value, &"medula", &"aorta")
	var seen: Array[StringName] = []
	var ctrl := world.player.get_node("Controller") as BioCellController
	var step := 0
	var deadline := Time.get_ticks_msec() + 120000
	while step < path.size() and Time.get_ticks_msec() < deadline:
		var to := path[step] * BioArt.UNIT - world.player.global_position
		if to.length() < 2.5 * BioArt.UNIT:
			step += 1
			continue
		ctrl.move(to.normalized())
		await tree.physics_frame
		if seen.is_empty() or seen[seen.size() - 1] != world.region:
			seen.append(world.region)
	ctrl.move(Vector2.ZERO)
	assert_eq(step, path.size(), "every waypoint was reached through the winding vessels (stopped at %d of %d)" % [step, path.size()])
	assert_eq(seen, [&"medula", &"sangue", &"coracao", &"aorta"] as Array[StringName], "the regions crossed, in order")
