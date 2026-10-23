"""Makes the granuloma survivable and its death understandable (one-off edits)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def sub(path, a, b):
    p = root / path
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (path, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


rt = "scripts/runtime/"
# enemies hit softer, and the early ones are fewer and slower
plan = "scripts/domain/bio_dungeon_plan.gd"
sub(plan, '"hp": 24.0, "speed": 5.0, "size": 0.42,', '"hp": 18.0, "speed": 3.6, "damage": 0.5, "size": 0.42,')
sub(plan, '"aggro": 12.0, "lunge": 3.2, "telegraph": 0.45, "recover": 0.8}\n		&"macrofago_guarda"', '"aggro": 9.0, "lunge": 3.0, "telegraph": 0.65, "recover": 1.3}\n		&"macrofago_guarda"')
sub(plan, '"hp": 95.0, "speed": 1.9, "size": 0.95,', '"hp": 85.0, "speed": 1.7, "damage": 0.7, "size": 0.95,')
sub(plan, '"hp": 150.0, "speed": 1.5, "size": 1.25,', '"hp": 130.0, "speed": 1.4, "damage": 0.85, "size": 1.25,')
sub(plan, '"hp": 32.0, "speed": 3.4, "size": 0.38,', '"hp": 28.0, "speed": 3.0, "damage": 0.55, "size": 0.38,')
sub(plan, '"hp": 320.0, "speed": 2.3, "size": 1.7,', '"hp": 300.0, "speed": 2.0, "damage": 0.9, "size": 1.7,')
sub(plan, 'r.merge({"speed_mult": 1.3, "drain": 0.9}, true)', 'r.merge({"speed_mult": 1.15, "drain": 0.4}, true)')
sub(plan, "mix = [[&\"linfocito\", 5]]", "mix = [[&\"linfocito\", 3]]")
sub(plan, "mix = [[&\"macrofago_guarda\", 3], [&\"linfocito\", 2]] if index < 2", "mix = [[&\"macrofago_guarda\", 2], [&\"linfocito\", 2]] if index < 2")
sub(plan, "mix = [[&\"bacilo\", 6 + (4 if modifier == \"necrose-viva\" else 0)], [&\"emissor\", 2]]", "mix = [[&\"bacilo\", 5 + (3 if modifier == \"necrose-viva\" else 0)], [&\"emissor\", 2]]")

sub("scripts/runtime/bio_combatant.gd", "var _bonus_atp := 0.0\n", "var _bonus_atp := 0.0\nvar damage_dealt_mult := 1.0  # how hard this one hits (enemies of a dungeon are tuned)\n")
sub("scripts/runtime/bio_combatant.gd", "	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0)\n", "	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0) * attacker.damage_dealt_mult\n")
sub(rt + "bio_factory.gd", "	actor.add_to_group(\"dungeon_enemies\")\n", "	actor.add_to_group(\"dungeon_enemies\")\n	actor.combatant.damage_dealt_mult = float(def.get(\"damage\", 1.0))\n")

# dungeon: a grace period at the start of each room, healing between rooms, a legend of the controls
d = rt + "bio_dungeon.gd"
sub(d, "const CENTER := Vector2(0.0, 5600.0)\n", "const CENTER := Vector2(0.0, 5600.0)\nconst GRACE_SECONDS := 3.5  # enemies hold still while the cell gets its bearings\nconst CLEAR_HEAL := 0.4  # share of the membrane given back when a room is cleared\n")
sub(d, "var _t := 0.0\n", "var _t := 0.0\nvar _grace_until := 0.0\nvar _awake := true\n")
sub(d, "	_clear_sent = false\n	_built_at = BioClock.now()\n	_respawn_in = float(_rule[\"respawn_every\"])\n", "	_clear_sent = false\n	_built_at = BioClock.now()\n	_respawn_in = float(_rule[\"respawn_every\"])\n	_set_awake(false)  # a few seconds before they come\n	_grace_until = BioClock.now() + GRACE_SECONDS\n")
sub(d, "func _body_of(cell: BioCellActor) -> BioCellBody:", """## Lets the enemies of the room move (or holds them still).
func _set_awake(on: bool) -> void:
	_awake = on
	for e in enemies():
		var brain: Variant = e.get_meta("brain", null)
		if brain is Node:
			(brain as Node).set_process(on and float((e as BioCellActor).max_speed_units) > 0.05)


## Seconds left of the grace period (0 when the room is live).
func grace_left() -> float:
	return maxf(0.0, _grace_until - BioClock.now()) if active else 0.0


func _body_of(cell: BioCellActor) -> BioCellBody:""")
sub(d, "	cell.set_meta(\"kind\", String(kind))\n", "	cell.set_meta(\"kind\", String(kind))\n	cell.set_meta(\"brain\", brain)\n	if not _awake:\n		brain.set_process(false)\n")
sub(d, "	var alive := enemies()\n	if not _clear_sent", "	if not _awake and BioClock.now() >= _grace_until:\n		_set_awake(true)\n	var alive := enemies()\n	if not _clear_sent")
sub(d, "		_clear_sent = true\n		room_cleared.emit(room_index)\n", "		_clear_sent = true\n		vitals.repair(vitals.max_membrane * CLEAR_HEAL)  # a breath between rooms\n		vitals.add_atp(vitals.max_atp)\n		room_cleared.emit(room_index)\n")

# HUD: the controls legend and the countdown while enemies wait
h = rt + "bio_hud.gd"
sub(h, "func set_dungeon_text(text: String) -> void:\n	_dungeon_label.text = text\n", "func set_dungeon_text(text: String) -> void:\n	_dungeon_text = text\n	_dungeon_label.text = text\n\n\nfunc set_dungeon_extra(extra: String) -> void:\n	_dungeon_label.text = _dungeon_text if extra.is_empty() or _dungeon_text.is_empty() else _dungeon_text + \"\\n\" + extra\n")
sub(h, "var _guide: Label\n", "var _guide: Label\nvar _dungeon_text := \"\"\n")

# world: say what happens, respawn at the portal when the cell fell in the dungeon
w = rt + "bio_world.gd"
sub(w, "var dungeon: BioDungeon\n", "var dungeon: BioDungeon\nvar fell_in_dungeon := false\n")
sub(w, "func _on_player_died(_who: BioCombatant) -> void:\n	player.set_intent(Vector2.ZERO)\n	player.set_active(false)\n	hud.show_banner(\"A célula se dissolveu no fluido\\nPressione R para renascer na medula\")", "func _on_player_died(_who: BioCombatant) -> void:\n	player.set_intent(Vector2.ZERO)\n	player.set_active(false)\n	fell_in_dungeon = dungeon != null and dungeon.active\n	if fell_in_dungeon:\n		hud.show_banner(\"Você caiu no granuloma\\nPressione R para voltar ao portal\")\n	else:\n		hud.show_banner(\"A célula se dissolveu no fluido\\nPressione R para renascer na medula\")")
sub(w, "	player.set_active(true)\n	player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)\n	player.velocity = Vector2.ZERO\n	player.combatant.reset_vitals()\n	hud.show_banner(\"\")", "	player.set_active(true)\n	if fell_in_dungeon:  # back at the portal, not all the way to the marrow\n		player.global_position = gate.global_position + Vector2(0.0, 3.4 * BioArt.UNIT)\n		fell_in_dungeon = false\n	else:\n		player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)\n	player.velocity = Vector2.ZERO\n	player.combatant.reset_vitals()\n	hud.show_banner(\"\")")
sub(w, "	if gate != null and gate.eligible and not dungeon.active and player.is_active():", "	if dungeon.active:\n		var left := dungeon.grace_left()\n		hud.set_dungeon_extra(\"Prepare-se… %d\" % ceili(left) if left > 0.0 else \"WASD move · clique ataca · Q F C V habilidades · Backspace sai\")\n	if gate != null and gate.eligible and not dungeon.active and player.is_active():")
print("ok")
