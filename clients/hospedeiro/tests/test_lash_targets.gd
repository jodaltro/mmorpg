extends TestCase

var world: BioWorld
var limbs: BioLimbs
var controller: BioCellController


func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	world.player.global_position = Vector2.ZERO
	world.player.set_physics_process(false)
	for child in world.player.get_children():
		if child is BioPlayerInput: child.set_process(false)
	world.genome.lineage = &"dendritica"
	world.player.combatant.set_genome(world.genome)
	limbs = world.player.get_node("Limbs") as BioLimbs
	controller = world.player.get_node("Controller") as BioCellController


func after_each() -> void:
	world.queue_free()
	await tree.process_frame


func _enemy(at: Vector2) -> BioCellActor:
	var brain := BioFactory.spawn_virus(world, at*BioArt.UNIT, world.player)
	brain.set_process(false)
	var cell := brain.get_parent() as BioCellActor
	cell.set_physics_process(false)
	cell.combatant.actor.vitals.max_membrane = 1000
	cell.combatant.actor.vitals.membrane = 1000
	return cell


func _whips() -> Array:
	return tree.get_nodes_in_group("limbs").filter(func(n: Node) -> bool: return n.get_parent() == world.player)


func test_three_whips_divide_between_two_valid_targets_and_never_multiply_damage() -> void:
	var a := _enemy(Vector2(1.5,-0.6))
	var b := _enemy(Vector2(1.5,0.6))
	var rear := _enemy(Vector2(-1.5,0))
	await tree.physics_frame
	var a_pos := a.global_position
	var b_pos := b.global_position
	controller.set_aim(Vector2.RIGHT)
	assert_eq(controller.lash(), BioActor.AttackStatus.STARTED)
	var whips := _whips()
	assert_eq(whips.size(), 3)
	assert_true(whips.any(func(w: BioLimb) -> bool: return w.target_point == a_pos))
	assert_true(whips.any(func(w: BioLimb) -> bool: return w.target_point == b_pos))
	for whip in whips:
		assert_true(whip.has_target_point and (whip.target_point == a_pos or whip.target_point == b_pos))
		assert_eq(whip.sweep_time, 0.0, "a targeted tip must not swing away from its enemy")
	assert_near(1000-a.combatant.actor.vitals.membrane, 14, 0.01)
	assert_near(1000-b.combatant.actor.vitals.membrane, 14, 0.01)
	assert_eq(rear.combatant.actor.vitals.membrane, 1000.0)


func test_one_enemy_gets_all_whips_and_empty_aim_stays_forward() -> void:
	var enemy := _enemy(Vector2(1.5,0))
	limbs.lash(Vector2.RIGHT, 1.7)
	for whip in _whips():
		assert_true(whip.has_target_point)
		assert_eq(whip.target_point, enemy.global_position)
		assert_true(whip._current_aim().dot(Vector2.RIGHT) > 0.99)
	assert_true(_whips()[0].root_angle_offset != _whips()[2].root_angle_offset, "converging whips keep distinct roots")
	for whip in _whips(): whip.free()
	limbs.lash(Vector2.UP, 1.7)
	for whip in _whips():
		assert_true(not whip.has_target_point, "manual cone excludes enemies behind the aim")
		assert_eq(whip.aim, Vector2.UP)


func test_auto_lash_prefers_reachable_enemy_and_manual_aim_is_respected() -> void:
	var far := _enemy(Vector2(5,0))
	var close := _enemy(Vector2(0,1.5))
	await tree.physics_frame
	controller.auto_target = far
	controller.auto_aim()
	assert_eq(controller.auto_target, far, "keep a stable ranged target until the melee attack")
	controller.lash()
	assert_eq(controller.auto_target, close, "melee must pick an enemy it can actually reach")
	assert_true(controller.aim.dot(Vector2.DOWN) > 0.99)
	world.player.combatant.actor.reset_cooldowns()
	controller.set_aim(Vector2.UP)
	var health := close.combatant.actor.vitals.membrane
	controller.lash()
	assert_eq(controller.aim, Vector2.UP)
	assert_eq(close.combatant.actor.vitals.membrane, health, "manual aiming is never overridden")


func test_tail_and_extra_whips_share_the_same_valid_target() -> void:
	var target := _enemy(Vector2(1.5,0))
	var tail := world.player.get_node("Flagellum") as BioFlagellum
	tail.set_active(true)
	limbs.lash(Vector2.RIGHT, 1.7, [], tail)
	assert_eq(_whips().size(), 2, "the visible tail is the first of the three whips")
	assert_near(tail._lash_angle, 0, 0.001)
	assert_near(tail._lash_half, 0, 0.001, "the tail converges on the contact instead of sweeping randomly")
	assert_near(tail._lash_length, target.global_position.length(), 0.01)
	for whip in _whips(): assert_eq(whip.target_point, target.global_position)
