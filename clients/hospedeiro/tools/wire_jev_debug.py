"""The Jev panel (F2 + always-on badge) and the test menu (Esc): world methods behind every button, input, host sync. One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("scripts/runtime/bio_player_input.gd", '	_bind("bio_debug_toggle", [_key(KEY_F3)])\n', '	_bind("bio_debug_toggle", [_key(KEY_F3)])\n	_bind("bio_jev", [_key(KEY_F2)])\n	_bind("bio_menu", [_key(KEY_ESCAPE)])\n')
w = "scripts/runtime/bio_world.gd"
sub(w, "var design_debug: BioDesignDebug\n", """var design_debug: BioDesignDebug
var jev_panel: BioJevPanel
var debug_menu: BioDebugMenu
var debug_god := false

## Rooms and classes the test menu goes straight to.
const DEBUG_ROOMS := [
	{"id": "guarda-de-linfocitos", "name": "A guarda de linfócitos", "kind": "guard"},
	{"id": "parede-de-macrofagos", "name": "A parede de macrófagos", "kind": "wall"},
	{"id": "anel-interno", "name": "O anel interno", "kind": "wall"},
	{"id": "nucleo-necrotico", "name": "O núcleo necrótico", "kind": "core"},
	{"id": "bacilo", "name": "O bacilo (chefe)", "kind": "boss"},
]
const DEBUG_CLASSES := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]
""")
sub(w, "	design_debug = BioDesignDebug.new()\n", """	jev_panel = BioJevPanel.new()
	jev_panel.name = "JevPanel"
	add_child(jev_panel)
	jev_panel.configure(self)
	debug_menu = BioDebugMenu.new()
	debug_menu.name = "DebugMenu"
	add_child(debug_menu)
	debug_menu.configure(self)
	design_debug = BioDesignDebug.new()
""")
sub(w, "	_debug_keys()\n", "	_debug_keys()\n	if debug_god:\n		player.combatant.actor.vitals.membrane = player.combatant.actor.vitals.max_membrane\n		player.combatant.actor.vitals.atp = player.combatant.actor.vitals.max_atp\n")
sub(w, "func _debug_keys() -> void:\n", """func _debug_keys() -> void:
	if Input.is_action_just_pressed("bio_jev"):
		jev_panel.toggle()
	if Input.is_action_just_pressed("bio_menu"):
		debug_menu.toggle()
""")
sub(w, "## Debug keys: F4 cycles", """## The shortcuts behind the test menu (Esc). Each one is a plain method, so it is tested without a screen.
func debug_goto(id: StringName) -> void:
	if dungeon.active:
		dungeon.finish(false)
	player.global_position = BioBodyMap.center_px(id)
	player.velocity = Vector2.ZERO
	player.set_active(true)
	player.combatant.reset_vitals()
	hud.show_banner("")


func debug_dungeon_room(index: int) -> void:
	if dungeon.active:
		dungeon.finish(false)
	player.set_active(true)
	player.combatant.reset_vitals()
	dungeon.start({"state": "active", "seed": 424242, "room": index, "rooms": DEBUG_ROOMS, "modifier": {"id": "necrose-viva", "name": "Necrose viva", "desc": ""}})
	hud.show_banner("")


func debug_leave_dungeon() -> void:
	if dungeon.active:
		dungeon.finish(false)
		respawn_player()


func debug_become(lineage: StringName) -> void:
	lineage_id = lineage
	genome.lineage = lineage
	player.combatant.set_genome(genome)
	abilities.clear()
	for id in BioAbilityCatalog.ids_of_class(lineage):
		abilities.learn(id)
	debug_refill()


func debug_spawn_virions(count: int) -> void:
	for i in count:
		var a := TAU * i / maxf(count, 1) + randf() * 0.4
		_spawn_virus_at(player.global_position + Vector2.from_angle(a) * randf_range(4.0, 8.0) * BioArt.UNIT)


func debug_clear_virions() -> void:
	for v in viruses():
		v.queue_free()


func debug_refill() -> void:
	player.set_active(true)
	player.combatant.actor.vitals.membrane = player.combatant.actor.vitals.max_membrane
	player.combatant.actor.vitals.atp = player.combatant.actor.vitals.max_atp


func debug_reset_cooldowns() -> void:
	player.combatant.actor._ready_at.clear()


func debug_toggle_god() -> void:
	debug_god = not debug_god
	hud.show_banner("INVULNERÁVEL LIGADO" if debug_god else "")


func debug_random_design() -> void:
	_debug_random_design()


func debug_engine_design() -> void:
	apply_design(engine_traits, "motor")


## Moves one trait to its next option (what F4, F7, F8 and F9 do).
func debug_cycle(trait_id: String) -> void:
	var options: Array
	match trait_id:
		"efeito":
			options = BioEffectSignature.STYLES.map(func(s: StringName) -> String: return String(s))
		"trajetoria":
			options = BioProjectileDesign.TRAJECTORIES
		"impacto":
			options = BioProjectileDesign.IMPACTS.keys()
		"calibre":
			options = BioProjectileDesign.CALIBRE.keys()
		"foco":
			options = BioAbilityFocus.FOCUS.keys()
		_:
			return
	var cur := design_traits.duplicate()
	cur[trait_id] = options[(options.find(str(cur.get(trait_id, ""))) + 1) % options.size()]
	apply_design(cur, "debug")


## Debug keys: F4 cycles""")
print("ok")
