extends TestCase

const SEED := 1337


func test_the_body_grows_the_same_from_the_same_seed() -> void:
	var a := BioAnatomy.build(SEED)
	BioAnatomy._built.clear()
	var b := BioAnatomy.build(SEED)
	for i in (a["regions"] as Array).size():
		assert_eq((a["regions"][i]["outline"] as PackedVector2Array), (b["regions"][i]["outline"] as PackedVector2Array), "region %d is the same" % i)
	assert_true((BioAnatomy.build(SEED + 1)["regions"][2]["outline"] as PackedVector2Array) != (a["regions"][2]["outline"] as PackedVector2Array), "another seed grows another heart")


func test_the_body_is_about_ten_times_the_old_map() -> void:
	var old_area := PI * 14.0 * 14.0 + PI * 18.0 * 18.0 + 2.0 * 2.6 * 8.0  # the marrow, the blood and the sinusoid of before
	var area := BioAnatomy.total_area(SEED)
	assert_true(area > old_area * 8.5 and area < old_area * 14.0, "%.0f square units is %.1fx the old map" % [area, area / old_area])
	var box := BioAnatomy.bounds(SEED)
	assert_true(box.size.x > 200.0, "and it is long: %.0f units from end to end" % box.size.x)


func _link(id: StringName) -> Dictionary:
	for l in BioAnatomy.build(SEED)["links"]:
		if l["id"] == id:
			return l
	return {}


## A point a fraction of the way along a vessel, and the direction it runs there.
func _along(id: StringName, f: float) -> Dictionary:
	var path: PackedVector2Array = _link(id)["path"]
	var i := clampi(int(f * (path.size() - 1)), 0, path.size() - 2)
	return {"p": path[i], "dir": (path[i + 1] - path[i]).normalized()}


func test_the_regions_form_one_connected_body_without_overlaps() -> void:
	var seen: Array[StringName] = BioAnatomy.within(&"medula", 10)
	assert_eq(seen.size(), (BioAnatomy.definition()["regions"] as Array).size(), "every region can be reached from the marrow")
	var regions: Array = BioAnatomy.build(SEED)["regions"]
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			var d := (regions[i]["center"] as Vector2).distance_to(regions[j]["center"])
			assert_true(d > (float(regions[i]["radius"]) + float(regions[j]["radius"])) * 1.1, "%s and %s do not overlap" % [regions[i]["id"], regions[j]["id"]])
	for l in BioAnatomy.build(SEED)["links"]:
		var path: PackedVector2Array = l["path"]
		assert_true(BioAnatomy._inside(BioAnatomy._find(regions, l["from"]), path[0]) and BioAnatomy._inside(BioAnatomy._find(regions, l["to"]), path[path.size() - 1]), "the vessel %s runs from the inside of one chamber to the inside of the other" % l["id"])
		for k in path.size():
			assert_true(BioAnatomy.in_body(SEED, path[k]), "every point of %s is inside the membrane" % l["id"])


func test_the_whole_body_is_one_organic_membrane() -> void:
	var body := BioAnatomy.build(SEED)
	assert_eq((body["loops"] as Array).size(), 1, "one closed wall around everything, not shapes stuck together")
	assert_true((body["loops"][0] as PackedVector2Array).size() > 300, "a long, finely sampled contour")
	for region in body["regions"]:
		var runs := (body["walls"] as Array).filter(func(w: Dictionary) -> bool: return w["region"] == region["id"])
		assert_true(runs.size() >= 1, "%s has a piece of the wall" % region["id"])
	var turns := 0.0  # a vessel winds: it is not a straight pipe
	var path: PackedVector2Array = _link(&"veia_cava")["path"]
	for k in path.size() - 2:
		turns += absf((path[k + 1] - path[k]).angle_to(path[k + 2] - path[k + 1]))
	assert_true(turns > 0.15, "the vessels wind (%.2f rad of turning)" % turns)
	var last := (body["loops"][0] as PackedVector2Array)
	assert_true(last[0].distance_to(last[last.size() - 1]) < 0.001, "the contour closes")


func test_regions_are_found_by_position() -> void:
	for region in BioAnatomy.definition()["regions"]:
		assert_eq(BioAnatomy.region_at(SEED, region["center"]), region["id"], "the centre of %s is in it" % region["id"])
	assert_eq(BioAnatomy.region_at(SEED, _along(&"veia_cava", 0.25)["p"]), &"sangue", "a vessel belongs to the chamber it is closer to (venule side)")
	assert_eq(BioAnatomy.region_at(SEED, _along(&"veia_cava", 0.75)["p"]), &"coracao", "and the heart side")
	assert_true(not BioAnatomy.in_body(SEED, Vector2(0.0, 60.0)), "empty space is not the body")
	assert_true(BioAnatomy.in_body(SEED, _along(&"veia_cava", 0.5)["p"]), "a vessel is")


func test_the_flow_runs_along_the_vessels_and_beats() -> void:
	var peak := 0.25 / BioAnatomy.HEART_HZ  # a beat
	var rest := 0.75 / BioAnatomy.HEART_HZ + 0.1  # between beats
	for id in [&"veia_cava", &"arteria_pulmonar", &"aorta_ascendente"]:
		var at := _along(id, 0.5)
		assert_true(BioAnatomy.flow_at(SEED, at["p"], peak).dot(at["dir"]) > 2.0, "%s carries the blood onwards" % id)
	var mid := _along(&"veia_cava", 0.5)
	assert_true(BioAnatomy.flow_at(SEED, mid["p"], peak).length() > BioAnatomy.flow_at(SEED, mid["p"], rest).length() * 1.3, "stronger on the beat")
	assert_true(BioAnatomy.flow_at(SEED, Vector2(0.0, 0.0), peak).length() < 1.0, "the marrow niche is nearly still")
	assert_near(BioAnatomy.flow_at(SEED, Vector2(0.0, 80.0), peak).length(), 0.0, 0.0001, "and so is outside the body")
	var swirl := BioAnatomy.flow_at(SEED, Vector2(38.0 + 9.0, 0.0), peak)
	assert_true(absf(swirl.y) > 0.5, "the venule swirls")


func test_the_atlas_remembers_what_the_cell_has_seen() -> void:
	var player := Node2D.new()
	tree.root.add_child(player)
	var atlas := BioAtlas.new()
	tree.root.add_child(atlas)
	var path := "user://test_atlas_%d.json" % Time.get_ticks_usec()
	atlas.configure(player, SEED, path)
	assert_eq(atlas.known.size(), 2, "it starts knowing the marrow and the blood")
	assert_true(atlas.discover(&"coracao"), "the heart is new")
	assert_true(not atlas.discover(&"coracao"), "and only once")
	assert_true(not atlas.knows(&"pulmao"), "the lung is still a question mark")
	atlas.toggle()
	assert_true(atlas.is_open(), "M opens it")
	var again := BioAtlas.new()
	tree.root.add_child(again)
	again.configure(player, SEED, path)
	assert_true(again.knows(&"coracao"), "a new session remembers")
	DirAccess.remove_absolute(path)
	atlas.queue_free()
	again.queue_free()
	player.queue_free()
