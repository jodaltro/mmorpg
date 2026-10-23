"""Wires the anatomy (body as data), streaming and the atlas into the world, input and the system panel (one-off edits)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "scripts/runtime"


def sub(name, a, b):
    p = root / name
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (name, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("bio_player_input.gd", '	_bind("bio_leave", [_key(KEY_BACKSPACE)])\n', '	_bind("bio_leave", [_key(KEY_BACKSPACE)])\n	_bind("bio_map", [_key(KEY_M)])\n')

w = "bio_world.gd"
sub(w, "var dungeon: BioDungeon\n", "var dungeon: BioDungeon\nvar anatomy: BioAnatomyView\nvar atlas: BioAtlas\nvar live_regions: Array[StringName] = []\n")
sub(w, "	BioFactory.create_body_boundary(self, BioBodyMap.outline_units())\n	_add_motes(BioBodyMap.MEDULA, [BioArt.AMBER, BioArt.MAGENTA, BioArt.JADE])\n	_add_motes(BioBodyMap.SANGUE, [BioArt.CRIMSON, BioArt.MAGENTA, Color(0.6, 0.05, 0.12)])\n",
    "	BioBodyMap.seed_value = seed_value\n	anatomy = BioAnatomyView.new()\n	anatomy.name = \"Anatomy\"\n	add_child(anatomy)\n	anatomy.build(seed_value)  # the whole body, grown from the seed; only the regions around the cell are alive\n")
sub(w, "	hud.restart_requested.connect(restart_world)\n", "	hud.restart_requested.connect(restart_world)\n	atlas = BioAtlas.new()\n	atlas.name = \"Atlas\"\n	add_child(atlas)\n	atlas.configure(player, seed_value, \"\" if save_path.is_empty() else \"user://hospedeiro_atlas.json\")\n	atlas.discovered.connect(func(id: StringName) -> void:\n		if _built:\n			hud.show_banner(str(BioBodyMap.NAMES.get(id, id)))\n			get_tree().create_timer(2.2).timeout.connect(func() -> void:\n				if is_instance_valid(hud) and hud.banner_text() == str(BioBodyMap.NAMES.get(id, id)):\n					hud.show_banner(\"\"))\n			sync.system.push_feed(\"Nova região no atlas: %s.\" % BioBodyMap.NAMES.get(id, id)))\n")
sub(w, "	for i in nutrient_target:\n		_spawn_nutrient(0.0)\n	for i in virus_count:\n		_spawn_virus(12.0)\n\n	sync = BioHostSync.new()", "	_update_live()\n	_populate(true)\n\n	sync = BioHostSync.new()")
sub(w, "	for i in nutrient_target:\n		_spawn_nutrient(0.0)\n	for i in virus_count:\n		_spawn_virus(12.0)\n	sync.forget()", "	_update_live()\n	_populate(true)\n	atlas.forget_all()\n	sync.forget()")
sub(w, "		var now := BioBodyMap.region_of(player.global_position)\n		if now != region:\n			region = now\n			region_changed.emit(region)\n", "		var now := BioBodyMap.region_of(player.global_position)\n		if now != region:\n			region = now\n			_update_live()\n			atlas.set_region(region)\n			region_changed.emit(region)\n	if Input.is_action_just_pressed(\"bio_map\"):\n		atlas.toggle()\n")
sub(w, "	_upkeep_timer = 1.0\n	if nutrient_count() < nutrient_target:\n		_spawn_nutrient(8.0)\n	if viruses().size() < virus_count:\n		_virus_respawn_timer -= 1.0\n		if _virus_respawn_timer <= 0.0:\n			_spawn_virus(14.0)\n			_virus_respawn_timer = 6.0\n", "	_upkeep_timer = 1.0\n	_populate(false)\n")
sub(w, "## The blood is a river: cells and nutrients there are carried around the chamber.\nfunc _physics_process(delta: float) -> void:\n	for node in get_tree().get_nodes_in_group(\"cells\"):\n		if dungeon != null and dungeon.active:\n			break  # inside the granuloma there is no current\n		var cell := node as BioCellActor\n		if cell != null and cell.is_active():\n			cell.velocity += BioBodyMap.blood_flow_px(cell.global_position, BLOOD_FLOW_UNITS) * delta * 1.5\n	for node in get_tree().get_nodes_in_group(\"nutrients\"):\n		var nutrient := node as Node2D\n		nutrient.global_position += BioBodyMap.blood_flow_px(nutrient.global_position, BLOOD_FLOW_UNITS * 0.6) * delta\n",
    "## The blood is a river that beats with the heart: cells and nutrients are carried by the flow of the body (vessels and chambers).\nfunc _physics_process(delta: float) -> void:\n	var clock := Time.get_ticks_msec() * 0.001\n	if dungeon == null or not dungeon.active:  # inside the granuloma there is no current\n		for node in get_tree().get_nodes_in_group(\"cells\"):\n			var cell := node as BioCellActor\n			if cell != null and cell.is_active():\n				cell.velocity += BioBodyMap.flow_px(cell.global_position, clock) * delta * 1.5\n	for node in get_tree().get_nodes_in_group(\"nutrients\"):\n		var nutrient := node as Node2D\n		nutrient.global_position += BioBodyMap.flow_px(nutrient.global_position, clock) * 0.6 * delta\n")
sub(w, "func _spawn_nutrient(min_distance_units: float) -> void:\n	var kind := BioNutrientRules.Kind.GLUCOSE if _rng.randf() < 0.75 else BioNutrientRules.Kind.LIPID\n	var where := BioBodyMap.MEDULA if _rng.randf() < 0.6 else BioBodyMap.SANGUE\n	BioFactory.spawn_nutrient(self, BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units), kind)\n",
    """## Keeps the regions around the cell alive: the one it is in and the ones a vessel away. The rest of the body sleeps.
func _update_live() -> void:
	live_regions = BioAnatomy.within(region, BioAnatomyView.LIVE_HOPS)
	anatomy.set_live(live_regions)


## The population of the body, streamed: each live region holds the nutrients and virions its biome calls for (scaled by the
## exported targets); what lies in sleeping regions is let go, and spawned again when the cell comes near.
func _populate(fill_all: bool) -> void:
	var nutrient_scale := float(nutrient_target) / 45.0
	var virus_scale := float(virus_count) / 6.0
	var nutrients_in := {}
	var viruses_in := {}
	for node in get_tree().get_nodes_in_group("nutrients"):
		var at := (node as Node2D).global_position
		if not BioAnatomy.in_body(seed_value, at / BioArt.UNIT):
			continue  # not the body's: leave it be (the granuloma's drops)
		var r := BioBodyMap.region_of(at)
		if not live_regions.has(r):
			node.queue_free()
		else:
			nutrients_in[r] = int(nutrients_in.get(r, 0)) + 1
	for node in get_tree().get_nodes_in_group("viruses"):
		var r2 := BioBodyMap.region_of((node as Node2D).global_position)
		if not live_regions.has(r2):
			node.queue_free()
		else:
			viruses_in[r2] = int(viruses_in.get(r2, 0)) + 1
	for id in live_regions:
		var def := BioAnatomy.region_def(id)
		var want_n := roundi(float(def["nutrients"]) * nutrient_scale)
		var want_v := roundi(float(def["viruses"]) * virus_scale)
		var missing_n: int = want_n - int(nutrients_in.get(id, 0))
		var missing_v: int = want_v - int(viruses_in.get(id, 0))
		for i in (missing_n if fill_all else mini(missing_n, 3)):
			_spawn_nutrient_in(id, 0.0 if fill_all else 8.0)
		for i in (missing_v if fill_all else mini(missing_v, 1)):
			if fill_all or _virus_respawn_timer <= 0.0:
				_spawn_virus_in(id, 12.0 if fill_all else 14.0)
				_virus_respawn_timer = 6.0
	_virus_respawn_timer -= 1.0


func _spawn_nutrient_in(where: StringName, min_distance_units: float) -> void:
	var kind := BioNutrientRules.Kind.GLUCOSE if _rng.randf() < 0.75 else BioNutrientRules.Kind.LIPID
	BioFactory.spawn_nutrient(self, BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units), kind)


func _spawn_nutrient(min_distance_units: float) -> void:
	_spawn_nutrient_in(BioBodyMap.MEDULA if _rng.randf() < 0.6 else BioBodyMap.SANGUE, min_distance_units)
""")
sub(w, "func _spawn_virus(min_distance_units: float) -> void:\n	var pos := BioBodyMap.random_point_px(_rng, BioBodyMap.SANGUE, player.global_position, min_distance_units)\n", "func _spawn_virus(min_distance_units: float) -> void:\n	_spawn_virus_in(BioBodyMap.SANGUE, min_distance_units)\n\n\nfunc _spawn_virus_in(where: StringName, min_distance_units: float) -> void:\n	var pos := BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units)\n")
sub(w, "func _add_motes(where: StringName, palette: Array) -> void:\n	var motes := BioAmbientMotes.new()\n	motes.position = BioBodyMap.center_px(where)\n	motes.build(70, 9, BioBodyMap.radius_units(where), seed_value + where.length(), palette)\n	add_child(motes)\n\n\n", "")
print("ok")
