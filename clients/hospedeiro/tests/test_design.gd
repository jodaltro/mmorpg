extends TestCase
## The traits Jev designs: every option the engine can offer has a drawing, and a designed cell really looks and fights differently.


func _universe() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://../../universes/hospedeiro/universe.json"))


func test_every_option_the_engine_offers_has_a_drawing() -> void:
	var traits: Array = _universe()["appearance"]["traits"]
	assert_eq(traits.size(), 19, "nineteen designed traits")
	for t in traits:
		for o in t["options"]:
			var id := str(o["id"])
			match str(t["id"]):
				"nucleo":
					assert_true(BioDesign.NUCLEUS.has(id) or id == "composto", "nucleus %s has a shape" % id)
				"membrana":
					assert_true(BioDesign.MEMBRANES.has(id), "membrane %s has a texture" % id)
				"organelas":
					assert_true(BioDesign.ORGANELLES.has(id), "organelles %s are drawn" % id)
				"brilho":
					assert_true(BioDesign.GLOW.has(id), "glow %s has a colour" % id)
				"efeito":
					assert_true(BioEffectSignature.STYLES.has(StringName(id)), "effect %s has a flavour" % id)
				"lobulacao":
					assert_true(BioDesign.LOBES.has(id), "lobes %s are drawn" % id)
				"recorte":
					assert_true(BioDesign.CUTS.has(id), "cut %s is drawn" % id)
				"nucleolo":
					assert_true(BioDesign.NUCLEOLI.has(id), "nucleolus %s is drawn" % id)
				"ritmo":
					assert_true(BioProjectileDesign.TEMPO.has(id), "rhythm %s has a multiplier" % id)
				"foco":
					assert_true(BioAbilityFocus.FOCUS.has(id), "focus %s has a meaning" % id)


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


func test_a_composed_nucleus_is_unique_to_its_parts() -> void:
	var a := BioNucleusShapes.radius_composite(0.4, 0.0, 5, "liso")
	var b := BioNucleusShapes.radius_composite(0.4, 0.0, 7, "serrilhado")
	assert_true(absf(a - b) > 0.001, "different parts, different outlines")
	var notch := BioNucleusShapes.radius_composite(PI * 0.5, 0.0, 5, "entalhe")
	var plain := BioNucleusShapes.radius_composite(PI * 0.5, 0.0, 5, "liso")
	assert_true(notch < plain * 0.75, "the notch cuts deep on its side")


func test_the_debug_overlay_shows_what_is_really_in_effect() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.design_debug.toggle()
	assert_true(world.design_debug.text().contains("nenhum traço"), "no design yet, and it says so")
	world.apply_design({"efeito": "cristal", "foco": "preciso"}, "debug")
	assert_eq(world.abilities.effect_style, &"cristal", "the abilities take the style")
	var text := world.design_debug.text()
	assert_true(text.contains("origem: debug") and text.contains("cristal"), "the overlay shows the source, the style and the multipliers")
	world.apply_engine_look({"traits": {}})
	assert_eq(world.design_source, "debug", "a debug preview stays when the engine says nothing new")
	world.apply_engine_look({"traits": {"efeito": "chama"}})
	assert_eq(world.design_source, "motor", "but a new engine design takes over")
	assert_eq(world.abilities.effect_style, &"chama", "and the abilities follow it")
	world.apply_design({}, "motor")
	world.queue_free()
	await tree.process_frame


func test_a_look_with_only_traits_and_a_null_axes_does_not_break() -> void:
	var world := BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame
	world.apply_engine_look({"variant": "", "name": "", "axes": null, "traits": {"efeito": "chama"}})  # what the engine sends before the first variant
	assert_eq(world.abilities.effect_style, &"chama", "the traits are applied")
	world.apply_engine_look({"variant": "cacador", "axes": {"ferocidade": 50}, "traits": null})
	world.queue_free()
	await tree.process_frame
