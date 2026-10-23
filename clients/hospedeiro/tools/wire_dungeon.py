"""One-off wiring of the dungeon into the world, HUD, sync and input (kept for the record; not idempotent)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "scripts/runtime"


def sub(name, a, b):
    p = root / name
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (name, a[:60])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


# input: leave the dungeon
sub("bio_player_input.gd", '	_bind("bio_interact", [_key(KEY_E)])\n', '	_bind("bio_interact", [_key(KEY_E)])\n	_bind("bio_leave", [_key(KEY_BACKSPACE)])\n')

# world: dungeon, gate, no blood flow / region changes inside the dungeon
sub("bio_world.gd", "var abilities: BioAbilityRunner\n", "var abilities: BioAbilityRunner\nvar dungeon: BioDungeon\nvar gate: BioGate\n")
sub("bio_world.gd", "	hud.bind_abilities(abilities)\n", "	hud.bind_abilities(abilities)\n	gate = BioGate.new()\n	gate.name = \"GranulomaGate\"\n	gate.position = BioBodyMap.center_px(BioBodyMap.SANGUE) + Vector2(6.0, -9.0) * BioArt.UNIT\n	add_child(gate)\n	gate.configure(player)\n	dungeon = BioDungeon.new()\n	dungeon.name = \"Dungeon\"\n	add_child(dungeon)\n	dungeon.bind(player, gate.global_position + Vector2(0.0, 3.4 * BioArt.UNIT))\n	dungeon.room_started.connect(func(index: int, info: Dictionary) -> void:\n		hud.set_dungeon_text(\"GRANULOMA  ·  sala %d/%d  ·  %s\" % [index + 1, dungeon.rooms.size(), str(info.get(\"name\", \"\"))]))\n	dungeon.finished.connect(func(_cleared: bool) -> void: hud.set_dungeon_text(\"\"))\n")
sub("bio_world.gd", "	if player.is_active():\n		var now := BioBodyMap.region_of(player.global_position)", "	if player.is_active() and not dungeon.active:\n		var now := BioBodyMap.region_of(player.global_position)")
sub("bio_world.gd", "func _physics_process(delta: float) -> void:\n	for node in get_tree().get_nodes_in_group(\"cells\"):", "func _physics_process(delta: float) -> void:\n	for node in get_tree().get_nodes_in_group(\"cells\"):\n		if dungeon != null and dungeon.active:\n			break  # inside the granuloma there is no current")

# HUD: dungeon progress text
sub("bio_hud.gd", "var _banner: Label\n", "var _banner: Label\nvar _dungeon_label: Label\n")
sub("bio_hud.gd", "func show_banner(", "func set_dungeon_text(text: String) -> void:\n	_dungeon_label.text = text\n\n\nfunc show_banner(")
sub("bio_hud.gd", "	var title := Label.new()\n", "	_dungeon_label = Label.new()\n	_dungeon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)\n	_dungeon_label.offset_left = -400\n	_dungeon_label.offset_right = 400\n	_dungeon_label.offset_top = 24\n	_dungeon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n	_dungeon_label.add_theme_font_size_override(\"font_size\", 20)\n	_dungeon_label.add_theme_color_override(\"font_color\", Color(0.8, 1.0, 0.45, 0.9))\n	_dungeon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE\n	add_child(_dungeon_label)\n\n	var title := Label.new()\n")

# sync: events quiet, interaction, view handling
sub("bio_host_sync.gd", '"appearance", "skill-learned"]', '"appearance", "skill-learned", "dungeon-preparing", "dungeon-started", "dungeon-room", "dungeon-cleared", "dungeon-failed", "dungeon-left"]')
sub("bio_host_sync.gd", "var _announce_abilities := false  # the first view is history, not news\n", "var _announce_abilities := false  # the first view is history, not news\nvar _dungeon_state := \"\"  # the run state we last reacted to\nvar _dungeon_seed := 0\n")
sub("bio_host_sync.gd", "	_world.region_changed.connect(_on_region)\n", "	_world.region_changed.connect(_on_region)\n	_world.dungeon.room_cleared.connect(func(_index: int) -> void:\n		if link.online:\n			link.occur(\"sala-limpa\"))\n	_world.dungeon.run_failed.connect(func() -> void:\n		if link.online:\n			link.occur(\"falhar-masmorra\"))\n")
sub("bio_host_sync.gd", "	if Input.is_action_just_pressed(\"bio_interact\"):\n		if system.menu_open:", "	if Input.is_action_just_pressed(\"bio_leave\") and _world.dungeon.active and link.online:\n		link.act(\"abandonar-masmorra\")\n	if Input.is_action_just_pressed(\"bio_interact\"):\n		if _world.gate != null and _world.gate.is_near() and not _world.dungeon.active:\n			enter_dungeon()\n		elif system.menu_open:")
sub("bio_host_sync.gd", "func open_menu() -> void:", """## The player asks to go into the granuloma. The engine decides whether they may and prepares the run.
func enter_dungeon() -> void:
	if not link.online:
		system.push_feed("O granuloma só abre com o corpo conectado ao motor.")
		return
	if not _world.gate.eligible:
		system.push_feed(_world.gate.hint if not _world.gate.hint.is_empty() else "O granuloma ainda não está ao seu alcance.")
		return
	var res := await link.act("entrar-masmorra", {"dungeon": "granuloma"})
	if res.status != 200:
		system.push_feed("O granuloma recusou a entrada agora.")


func open_menu() -> void:""")
sub("bio_host_sync.gd", "	_apply_skills(view.get(\"skills\", []))\n", "	_apply_skills(view.get(\"skills\", []))\n	if view.get(\"dungeon\") is Dictionary:\n		_apply_dungeon(view[\"dungeon\"])\n")
sub("bio_host_sync.gd", "func _apply_quests(quests: Array) -> void:", """## The granuloma: whether the entrance is open to this cell, and the run, step by step. The engine owns the run; this only
## builds what it says (the chamber, the enemies) and confirms what happened in it.
func _apply_dungeon(d: Dictionary) -> void:
	var open := false
	var hint := "Entre no Granuloma na corrente sanguínea quando seu corpo estiver mais maduro."
	for o in d.get("available", []):
		if str(o.get("id", "")) == "granuloma":
			open = bool(o.get("eligible", false))
			if open:
				hint = ""
	_world.gate.eligible = open
	_world.gate.hint = hint
	var run: Variant = d.get("run")
	if not (run is Dictionary):
		return
	var state := str(run.get("state", ""))
	var seed_value := int(run.get("seed", 0))
	var mod: Variant = run.get("modifier")
	if state == "preparing" and _dungeon_state != "preparing":
		system.push_feed("O granuloma se prepara…")
	elif state == "active":
		if not _world.dungeon.active and (_dungeon_state != "active" or seed_value != _dungeon_seed):
			_world.dungeon.start(run)
			if mod is Dictionary:
				system.push_feed("Granuloma, %s: %s" % [mod.get("name", ""), mod.get("desc", "")])
		elif _world.dungeon.active and int(run.get("room", 0)) > _world.dungeon.room_index:
			_world.dungeon.advance(int(run.get("room", 0)))
	elif state == "cleared" and _world.dungeon.active and seed_value == _world.dungeon.seed_value:
		_world.dungeon.finish(true)
		system.push_feed("O granuloma foi selado. A carga de infecção no sangue cai.")
	elif state == "failed" and _world.dungeon.active and seed_value == _world.dungeon.seed_value:
		_world.dungeon.finish(false)
		system.push_feed("Você deixou o granuloma. Ele continua lá.")
	_dungeon_state = state
	_dungeon_seed = seed_value


func _apply_quests(quests: Array) -> void:""")
