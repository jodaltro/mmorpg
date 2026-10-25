extends TestCase

func test_replica_plays_confirmed_hits_once_without_changing_health() -> void:
	var host := BioCellBody.new()
	var replica := BioCellBody.new()
	replica.apply_combat_visual(host.combat_visual_state())
	host.hit_reaction(Vector2.LEFT)
	replica.apply_combat_visual(host.combat_visual_state())
	assert_true(replica._flash > 0.9, "confirmed impact lights the membrane")
	assert_true(replica._impact_left > 0.0, "confirmed impact starts recoil")
	var count := replica._hit_serial
	replica.apply_combat_visual(host.combat_visual_state())
	assert_eq(replica._hit_serial, count, "repeated states never replay damage feedback")
	host.free()
	replica.free()

func test_first_appearance_does_not_replay_old_attacks_or_hits() -> void:
	var body := BioCellBody.new()
	body.apply_combat_visual([7, 9, 0.8, "viral_lunge", 1, 0])
	assert_eq(body._flash, 0.0)
	assert_eq(body._attack_left, 0.0)
	assert_near(body._telegraph_target, 0.8, 0.001, "ongoing windup remains visible")
	body.free()

func test_coalesced_attack_is_directional_and_starts_only_once() -> void:
	var body := BioCellBody.new()
	body.apply_combat_visual([0, 0, 0, "", 1, 0])
	body.apply_combat_visual([0, 3, 0, "enemy_spit", 0, -1])
	assert_eq(body._attack_dir, Vector2.UP)
	assert_true(body._attack_left > 0, "last confirmed attack survives skipped snapshots")
	assert_true(not body._kicks.is_empty(), "smooth recoil and recovery are scheduled")
	body.apply_combat_visual([0, 3, 0, "enemy_spit", 0, -1])
	assert_eq(body._attack_serial, 1, "attack is not retriggered by every snapshot")
	body.free()
