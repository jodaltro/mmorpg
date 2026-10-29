extends TestCase

func test_complete_route_follows_all_vessels_and_distance_reaches_zero() -> void:
	for seed_value in [1337, 42, 919]:
		var route := BioNavigationRoute.new()
		var regions: Array[StringName] = [&"medula", &"sangue", &"coracao", &"aorta", &"figado"]
		var goal := BioBodyMap.center_px(&"figado")
		assert_true(route.plan(seed_value, Vector2.ZERO, goal, regions))
		assert_true(route.points.size() > 20, "retain the complete route, not a single region hop")
		var previous := INF
		for point in route.points:
			route.follow(point)
			assert_true(route.remaining <= previous + 0.1)
			previous = route.remaining
		assert_true(route.remaining < 0.1)
		assert_true(route.ahead(300).distance_to(goal) < 0.1)

func test_starting_mid_vessel_does_not_send_player_back_to_region_center() -> void:
	var full := BioAnatomy.route(1337, &"medula", &"sangue")
	var start := full[full.size() / 2] * BioArt.UNIT
	var goal := BioBodyMap.center_px(&"sangue")
	var route := BioNavigationRoute.new()
	assert_true(route.plan(1337, start, goal, [&"medula", &"sangue"] as Array[StringName]))
	assert_true(route.points[1].distance_to(goal) < start.distance_to(goal))
	assert_eq(route.points[0], start)

func test_minimap_clips_segments_crossing_frame_even_when_endpoints_are_outside() -> void:
	var frame := Rect2(7, 7, 78, 78)
	var crossing := BioNavigationRoute.clip_segment(Vector2(-100, 46), Vector2(200, 46), frame)
	assert_eq(crossing, PackedVector2Array([Vector2(7,46), Vector2(85,46)]))
	assert_true(BioNavigationRoute.clip_segment(Vector2(-100,-20), Vector2(200,-20), frame).is_empty())
	assert_eq(BioNavigationRoute.clip_segment(Vector2(30,20), Vector2(30,70), frame), PackedVector2Array([Vector2(30,20),Vector2(30,70)]))

func test_unreachable_and_zero_distance_destinations_have_explicit_results() -> void:
	var route := BioNavigationRoute.new()
	assert_true(not route.plan(1337, Vector2.ZERO, Vector2(999999,0), [] as Array[StringName]))
	assert_true(route.points.is_empty())
	assert_true(route.plan(1337, Vector2.ZERO, Vector2.ZERO, [&"medula"] as Array[StringName]))
	assert_true(route.remaining < 0.1)


func test_a_cell_in_a_fold_of_a_vessel_still_gets_a_route() -> void:
	# 29/10/2026, the long game: in a fold of the venule nothing of the route is in a straight line, and the guide said "blocked".
	var start := Vector2(26.38, 22.93) * BioArt.UNIT
	assert_true(BioAnatomy.in_body(BioBodyMap.seed_value, start / BioArt.UNIT), "the spot is inside the body")
	var route := BioNavigationRoute.new()
	var ok := route.plan(BioBodyMap.seed_value, start, BioBodyMap.center_px(&"linfonodo"), [&"sangue", &"coracao", &"aorta", &"baco", &"linfonodo"] as Array[StringName])
	assert_true(ok, "the route walks out of the fold")
	for i in range(1, route.points.size()):
		assert_true(BioNavigationRoute.inside(BioBodyMap.seed_value, route.points[i - 1], route.points[i]), "and never through a wall (leg %d)" % i)
