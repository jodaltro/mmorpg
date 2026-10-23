extends TestCase
## The traits Jev designs: every option the engine can offer has a drawing, and a designed cell really looks and fights differently.


func _universe() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://../../universes/hospedeiro/universe.json"))


func test_every_option_the_engine_offers_has_a_drawing() -> void:
	var traits: Array = _universe()["appearance"]["traits"]
	assert_eq(traits.size(), 5, "five designed traits")
	for t in traits:
		for o in t["options"]:
			var id := str(o["id"])
			match str(t["id"]):
				"nucleo":
					assert_true(BioDesign.NUCLEUS.has(id), "nucleus %s has a shape" % id)
				"membrana":
					assert_true(BioDesign.MEMBRANES.has(id), "membrane %s has a texture" % id)
				"organelas":
					assert_true(BioDesign.ORGANELLES.has(id), "organelles %s are drawn" % id)
				"brilho":
					assert_true(BioDesign.GLOW.has(id), "glow %s has a colour" % id)
				"efeito":
					assert_true(BioEffectSignature.STYLES.has(StringName(id)), "effect %s has a flavour" % id)


func test_the_effect_flavour_changes_looks_not_numbers() -> void:
	var base := Color(0.9, 0.2, 0.9)
	for style in BioEffectSignature.STYLES:
		assert_true(BioEffectSignature.tint(base, style) != base, "%s retints the effect" % style)
		assert_true(BioEffectSignature.limb_style(style).has("tip"), "%s reshapes the limbs" % style)
	assert_eq(BioEffectSignature.tint(base, &""), base, "no design leaves the ability as it is")
	var opts := {"tint": base, "style": {"tip": &"cup", "base": 26.0}}
	var signed := BioEffectSignature.sign_options(opts, &"cristal")
	assert_eq(signed["style"]["tip"], &"spear", "the tip follows the signature")
	assert_eq(signed["style"]["base"], 26.0, "the ability's own width stays")
	assert_eq(opts["style"]["tip"], &"cup", "and the original options are not touched")


func test_the_world_applies_the_design_to_body_and_abilities() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.apply_engine_look({"traits": {"nucleo": "estrela", "membrana": "espinhosa", "organelas": "granulos", "brilho": "carmim", "efeito": "chama"}})
	assert_eq(world.abilities.effect_style, &"chama", "abilities burn")
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	assert_eq(str(body.traits.get("nucleo", "")), "estrela", "the body knows its nucleus")
	await tree.create_timer(0.3).timeout
	world.apply_engine_look({"traits": {}})
	assert_eq(world.abilities.effect_style, &"", "no design, no flavour")
	world.queue_free()
	await tree.process_frame
