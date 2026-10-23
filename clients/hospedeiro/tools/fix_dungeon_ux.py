"""Dungeon entry clarity and less glow (one-off edits)."""
from pathlib import Path

repo = Path(__file__).resolve().parents[3]


def sub(path, a, b):
    p = repo / path
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (path, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


rt = "clients/hospedeiro/scripts/runtime/"

# engine: the modifier is decided within one tick, not three, so entering never feels stuck
sub("engine/core/dungeon.go", "Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}\n		w.emit(s, Event{Kind: \"dungeon-preparing\"", "Created: s.Tick, Due: s.Tick + 1, Context: ctx}\n		w.emit(s, Event{Kind: \"dungeon-preparing\"")

# light: a much calmer glow, so shapes read
sub(rt + "bio_world.gd", "	env.glow_intensity = 1.8\n	env.glow_strength = 1.2\n	env.glow_bloom = 0.25\n", "	env.glow_intensity = 0.55\n	env.glow_strength = 0.8\n	env.glow_bloom = 0.03\n")
sub(rt + "bio_world.gd", "	env.glow_hdr_threshold = 0.45\n", "	env.glow_hdr_threshold = 1.0\n")

# gate: a label that says what it is, and what to do
sub(rt + "bio_gate.gd", "	if is_near():\n		draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 56, Color(1, 1, 1, 0.25 + 0.2 * pulse), 2.0, true)\n", """	var font := ThemeDB.fallback_font
	var title := "GRANULOMA"
	var color := Color(0.85, 1.0, 0.6, 0.95) if eligible else Color(0.7, 0.75, 0.8, 0.8)
	draw_string(font, Vector2(-70.0, -r - 30.0), title, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20, color)
	var line := ""
	if is_near():
		draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 56, Color(1, 1, 1, 0.5 + 0.3 * pulse), 2.0, true)
		line = "Aperte E para entrar" if eligible else hint
	elif eligible:
		line = "uma masmorra: chegue perto"
	if line != "":
		draw_string(font, Vector2(-150.0, -r - 8.0), line, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, Color(1, 1, 1, 0.9) if is_near() else color)
""")
# the glow of the gate itself calmer
sub(rt + "bio_gate.gd", "Color(0.55, 0.9, 0.25, 0.18 + 0.12 * pulse))", "Color(0.55, 0.9, 0.25, 0.08 + 0.05 * pulse))")

# HUD: a banner while the run prepares, and an arrow to the gate
sub(rt + "bio_hud.gd", "var _dungeon_label: Label\n", "var _dungeon_label: Label\nvar _guide: Label\n")
sub(rt + "bio_hud.gd", "func set_dungeon_text(text: String) -> void:", """## An arrow at the edge of the screen pointing at something far away (the granuloma), with a short text.
func set_guide(on: bool, direction: Vector2, text: String) -> void:
	_guide.visible = on
	if not on:
		return
	var size := get_viewport().get_visible_rect().size
	var d := direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	var half := size * 0.5 - Vector2(90.0, 70.0)
	var scale := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	_guide.text = text
	_guide.position = size * 0.5 + d * scale - _guide.size * 0.5


func set_dungeon_text(text: String) -> void:""")
sub(rt + "bio_hud.gd", "	_dungeon_label = Label.new()\n", """	_guide = Label.new()
	_guide.visible = false
	_guide.add_theme_font_size_override("font_size", 18)
	_guide.add_theme_color_override("font_color", Color(0.85, 1.0, 0.6, 0.95))
	_guide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_guide.add_theme_constant_override("outline_size", 6)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)
	_dungeon_label = Label.new()
""")

# world: guide arrow while the granuloma is open and far; hide it in the dungeon
sub(rt + "bio_world.gd", "	if not sync.wants_numbers():\n		for i in 3:", """	if gate != null and gate.eligible and not dungeon.active and player.is_active():
		var to := gate.global_position - player.global_position
		var far := to.length() > 9.0 * BioArt.UNIT
		hud.set_guide(far, to, "%s  Granuloma · %d" % ["➤", roundi(to.length() / BioArt.UNIT)])
	else:
		hud.set_guide(false, Vector2.ZERO, "")
	if not sync.wants_numbers():
		for i in 3:""")

# sync: say it once when the granuloma opens, and show a banner while the run prepares
sub(rt + "bio_host_sync.gd", "	_world.gate.eligible = open\n	_world.gate.hint = hint\n", """	if open and not _world.gate.eligible:
		system.push_feed("O Granuloma abriu para você: siga a seta até os anéis na corrente sanguínea e aperte E.")
	_world.gate.eligible = open
	_world.gate.hint = hint
""")
sub(rt + "bio_host_sync.gd", "	if state == \"preparing\" and _dungeon_state != \"preparing\":\n		system.push_feed(\"O granuloma se prepara…\")\n", """	if state == "preparing":
		_world.hud.show_banner("Entrando no granuloma…\\no Jev escolhe o desafio desta vez")
		if _dungeon_state != "preparing":
			system.push_feed("O granuloma se prepara…")
	elif _world.hud.banner_text().begins_with("Entrando no granuloma"):
		_world.hud.show_banner("")
""")
sub(rt + "bio_host_sync.gd", "		var res := await link.act(\"entrar-masmorra\", {\"dungeon\": \"granuloma\"})\n", "		var res := await link.act(\"entrar-masmorra\", {\"dungeon\": \"granuloma\"})\n")
print("ok")
