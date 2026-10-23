"""E2 part 2, client wiring: the codex panel (B), the advisor's route in the compass, adaptation and the news of the codex.
One-off edits; run from anywhere."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("scripts/runtime/bio_player_input.gd", '	_bind("bio_vitals", [_key(KEY_TAB)])\n', '	_bind("bio_vitals", [_key(KEY_TAB)])\n	_bind("bio_codex", [_key(KEY_B)])\n')
w = "scripts/runtime/bio_world.gd"
sub(w, "var exploration: BioExploration\n", "var exploration: BioExploration\nvar codex_panel: BioCodexPanel\nvar adapted_regions: Array = []\n")
sub(w, "	exploration = BioExploration.new()\n", "	codex_panel = BioCodexPanel.new()\n	codex_panel.name = \"CodexPanel\"\n	add_child(codex_panel)\n	codex_panel.configure()\n	exploration = BioExploration.new()\n")
sub(w, "	if Input.is_action_just_pressed(\"bio_vitals\"):\n		vitals_panel.toggle()\n", "	if Input.is_action_just_pressed(\"bio_vitals\"):\n		vitals_panel.toggle()\n	if Input.is_action_just_pressed(\"bio_codex\"):\n		codex_panel.toggle()\n")
sub(w, "	player.combatant.actor.vitals.regen_scale = body.atp_regen_multiplier()\n", "	_apply_regen()\n")
sub(w, "## Fever (a body state", """## Energy comes back at the pace the body allows (fever, a lung short of air), faster in a place the cell has adapted to.
func _apply_regen() -> void:
	var adapted_here := adapted_regions.has(String(region))
	player.combatant.actor.vitals.regen_scale = body.atp_regen_multiplier() * (1.15 if adapted_here else 1.0)


## The regions the engine says this cell has adapted to by living in them.
func set_adapted(regions: Array) -> void:
	adapted_regions = regions
	_apply_regen()


## Fever (a body state""")
sub(w, "			atlas.set_region(region)\n", "			atlas.set_region(region)\n			_apply_regen()\n")
h = "scripts/runtime/bio_host_sync.gd"
sub(h, "	if view.get(\"explore\") is Dictionary:\n		_world.exploration.apply(view[\"explore\"])\n", "	if view.get(\"explore\") is Dictionary:\n		_world.exploration.apply(view[\"explore\"])\n		_world.set_adapted(view[\"explore\"].get(\"adapted\", []))\n	if view.get(\"codex\") is Array:\n		_world.codex_panel.set_data(view[\"codex\"], _world.adapted_regions)\n")
sub(h, "\"dungeon-left\"]", "\"dungeon-left\", \"codice\", \"adaptou\", \"rota\"]")
sub(h, "			\"nicho\":\n", "			\"codice\":\n				system.push_feed(\"Códice: %s\" % e.get(\"text\", \"\"))\n			\"adaptou\":\n				system.push_feed(str(e.get(\"text\", \"\")))\n			\"nicho\":\n")
x = "scripts/runtime/bio_exploration.gd"
sub(x, "var passages: Array = []\n", "var passages: Array = []\nvar route_id := \"\"  # the niche the advisor pointed this player to\n")
sub(x, "	niches = explore.get(\"niches\", [])\n", "	niches = explore.get(\"niches\", [])\n	route_id = str(explore.get(\"route\", \"\"))\n")
sub(x, "		var cost := float(steps.size())\n", "		var cost := float(steps.size())\n		if str(n.get(\"id\", \"\")) == route_id:\n			cost = -1.0  # the advisor's pick leads\n")
print("ok")
