extends TestCase
## E1, the living body: the vital signs the engine reports weigh on the cell, in the panel and in the world.

func _vitals(temperature: int, pulse: int, oxygen: int, adrenaline: int, insulin: int) -> Array:
	return [
		{"id": "temperatura", "label": "Temperatura", "value": temperature, "min": 360, "max": 410, "low": 365, "high": 375},
		{"id": "pulso", "label": "Pulso", "value": pulse, "min": 50, "max": 140, "low": 60, "high": 90},
		{"id": "oxigenio", "label": "Oxigênio", "value": oxygen, "min": 0, "max": 100, "low": 70, "high": 100},
		{"id": "inflamacao", "label": "Inflamação", "value": 0, "min": 0, "max": 100, "low": 0, "high": 30},
		{"id": "adrenalina", "label": "Adrenalina", "value": adrenaline, "min": 0, "max": 100, "low": 0, "high": 50},
		{"id": "insulina", "label": "Insulina", "value": insulin, "min": 0, "max": 100, "low": 10, "high": 70},
	]


func test_a_healthy_body_weighs_nothing() -> void:
	var s := BioBodyState.new()
	s.apply(_vitals(370, 70, 90, 0, 20))
	assert_true(not s.has_fever() and not s.has_hypoxia(), "no fever, no hypoxia")
	assert_near(s.speed_multiplier(), 1.0, 0.0001, "no hurry")
	assert_near(s.atp_regen_multiplier(), 1.0, 0.0001, "energy comes back normally")
	assert_eq(s.explain(), ["O corpo está em equilíbrio."] as Array[String], "and it says so")
	assert_eq(s.display("temperatura"), "37.0 °C", "the temperature reads in degrees")


func test_fever_and_a_lung_short_of_air_tire_the_cell_and_adrenaline_hurries_it() -> void:
	var s := BioBodyState.new()
	s.apply(_vitals(392, 110, 45, 80, 60))
	assert_true(s.has_fever() and s.has_hypoxia(), "fever and hypoxia")
	assert_true(s.atp_regen_multiplier() < 0.6, "energy comes back slowly (%.2f)" % s.atp_regen_multiplier())
	assert_true(s.speed_multiplier() > 1.1, "adrenaline hurries the cell (%.2f)" % s.speed_multiplier())
	assert_true(s.nutrient_multiplier() > 1.1, "insulin makes nutrients worth more")
	assert_true(s.is_off("temperatura") and s.is_off("oxigenio") and s.is_off("pulso"), "the strip flags what is off")
	assert_true(s.explain().size() >= 3, "and the panel explains the chain")


func test_the_world_applies_the_body_to_the_cell() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.apply_body(_vitals(392, 120, 45, 80, 60))
	assert_true(world.player.combatant.environment_speed > 1.1, "the player is quicker with adrenaline")
	assert_true(world.player.combatant.actor.vitals.regen_scale < 0.6, "and regenerates energy slower")
	assert_true(BioNutrientRules.body_multiplier > 1.1, "and nutrients are worth more")
	assert_near(BioAnatomy.heart_hz, 2.0, 0.0001, "the world's pulse follows the heart rate")
	assert_true(world.vitals_panel.strip_text().contains("39.2"), "the strip shows the temperature")
	world.vitals_panel.toggle()
	assert_true(world.vitals_panel.is_open(), "Tab opens the panel")
	world.apply_body(_vitals(370, 70, 90, 0, 20))
	assert_near(world.player.combatant.actor.vitals.regen_scale, 1.0, 0.0001, "when the fever passes, the weight lifts")
	BioAnatomy.heart_hz = BioAnatomy.HEART_HZ
	BioNutrientRules.body_multiplier = 1.0
	world.queue_free()
	await tree.process_frame
