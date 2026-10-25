extends TestCase

func test_inputs_are_finite_bounded_and_only_intentions() -> void:
	var p := BioNetProtocol.input({"seq": 1, "move": [1000,0], "aim": [0,INF], "hp": 9999,
		"actions": ["damage:9999", "lash", "ability:fagocitose", "respawn", "dash"]}, 0)
	assert_eq(p.move, Vector2.RIGHT, "speed is bounded")
	assert_eq(p.aim, Vector2.RIGHT, "nonfinite aim replaced")
	assert_true(not p.has("hp"), "health is never an input")
	assert_eq(p.actions.size(), 3, "bounded action list rejects damage declaration")
	assert_true(BioNetProtocol.input({"seq": 1}, 1).is_empty(), "duplicate sequence rejected")
	assert_true(BioNetProtocol.input({"seq": {}}, 0).is_empty(), "malformed sequence rejected")
	assert_eq(BioNetProtocol.vector(["bad",0]), Vector2.ZERO, "malformed vector rejected")


func test_guest_identity_is_random_and_does_not_require_a_password() -> void:
	var a := BioNakama.guest_identity("user://nonexistent_guest_test.json")
	var b := BioNakama.guest_identity("user://nonexistent_guest_test.json")
	assert_true(str(a.device).length() >= 32, "opaque local guest identity")
	assert_true(a.device != b.device, "separate guests do not collide")

func test_visual_vectors_and_colors_roundtrip_through_json() -> void:
	var visual := {"dir":Vector2(0.5,0.3),"color":Color(0.1,0.2,0.3,0.4),"reach":42}
	var encoded: Variant = JSON.parse_string(JSON.stringify(BioNetProtocol.visual(visual)))
	var restored: Dictionary = BioNetProtocol.visual(encoded, true)
	assert_true((restored.dir as Vector2).is_equal_approx(visual.dir), "procedural directions preserved")
	assert_true((restored.color as Color).is_equal_approx(visual.color), "effect color preserved")
