"""Stronger per-style particles, the design debug overlay and one place that applies a design (engine or debug). One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:70])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


def append(rel, text):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    p.write_text(s.rstrip("\r\n") + nl + text.replace("\n", nl), encoding="utf-8", newline="")


# --- a shard texture (a thin diamond) for crystal and electric particles
append("scripts/runtime/bio_art.gd", '''

static var _shard: ImageTexture


## A thin glowing diamond: the particle of crystal and electric effects.
static func shard_texture() -> ImageTexture:
	if _shard == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var dx := absf(x - size * 0.5 + 0.5) / (size * 0.5)
				var dy := absf(y - size * 0.5 + 0.5) / (size * 0.5)
				var d := dx * 1.0 + dy * 3.2  # long on the x axis, thin on y
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * 1.4))
		_shard = ImageTexture.create_from_image(img)
	return _shard
''')

# --- particles: the style gives every effect its own shape, motion and size
pf = "scripts/runtime/bio_pfx.gd"
sub(pf, "	parent.add_child(p)\n	p.global_position = pos\n	return p\n", "	_shape(p, color)\n	parent.add_child(p)\n	p.global_position = pos\n	emitted += 1\n	if style != &\"\":\n		emitted_styled += 1\n	return p\n")
sub(pf, "## The feel Jev designed for this cell's effects: how many particles, how long they linger, how fast they go.\nstatic var density := 1.0\n",
    "## The feel Jev designed for this cell's effects: how many particles, how long they linger, how fast they go, and the style\n## (chama, cristal, nevoa, eletrico, organico) that gives every particle its own shape and motion.\nstatic var style: StringName = &\"\"\nstatic var emitted := 0  # counters for the debug overlay\nstatic var emitted_styled := 0\nstatic var density := 1.0\n")
append(pf, '''

## Each style changes what the particles are, not only their colour: a flame rises and flickers, crystal is angular shards that
## spin, mist is big and soft and slow, electricity is thin quick flashes, the organic is wet blobs that swell and sag.
static func _shape(p: CPUParticles2D, color: Color) -> void:
	match style:
		&"chama":
			p.gravity = Vector2(0.0, -260.0)
			p.scale_amount_min *= 1.3
			p.scale_amount_max *= 1.5
			p.amount = roundi(p.amount * 1.4)
			var flicker := Curve.new()
			flicker.add_point(Vector2(0.0, 0.5))
			flicker.add_point(Vector2(0.15, 1.0))
			flicker.add_point(Vector2(0.4, 0.55))
			flicker.add_point(Vector2(0.6, 0.9))
			flicker.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = flicker
		&"cristal":
			p.texture = BioArt.shard_texture()
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -300.0
			p.angular_velocity_max = 300.0
			p.scale_amount_min *= 1.1
			p.scale_amount_max *= 1.4
			p.amount = roundi(p.amount * 0.8)
		&"nevoa":
			p.scale_amount_min *= 2.4
			p.scale_amount_max *= 3.0
			p.lifetime *= 1.5
			p.amount = maxi(1, roundi(p.amount * 0.6))
			var ramp := Gradient.new()
			ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			ramp.colors = PackedColorArray([Color(color.lerp(Color.WHITE, 0.3), 0.32), Color(color, 0.26), Color(color.darkened(0.2), 0.0)])
			p.color_ramp = ramp
		&"eletrico":
			p.texture = BioArt.shard_texture()
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.scale_amount_min *= 0.7
			p.scale_amount_max *= 1.1
			p.lifetime *= 0.5
			p.amount = roundi(p.amount * 1.8)
		&"organico":
			p.gravity = Vector2(0.0, 140.0)
			p.scale_amount_min *= 1.5
			p.scale_amount_max *= 1.9
			var swell := Curve.new()
			swell.add_point(Vector2(0.0, 0.3))
			swell.add_point(Vector2(0.35, 1.2))
			swell.add_point(Vector2(0.65, 0.8))
			swell.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = swell
''')
sub(pf, "	p.initial_velocity_min = speed * 0.4 * tempo\n	p.initial_velocity_max = speed * tempo\n", "	var pace := tempo * float({&\"nevoa\": 0.55, &\"eletrico\": 1.7, &\"cristal\": 1.2, &\"chama\": 0.9}.get(style, 1.0))\n	p.initial_velocity_min = speed * 0.4 * pace\n	p.initial_velocity_max = speed * pace\n")

# --- one place applies a design
w = "scripts/runtime/bio_world.gd"
sub(w, "func apply_engine_look(look: Dictionary) -> void:\n	var designed: Dictionary = look.get(\"traits\", {})\n	if designed != design_traits:\n		design_traits = designed.duplicate()\n		abilities.effect_style = StringName(str(design_traits.get(\"efeito\", \"\")))\n		var feel := BioDesign.feel(design_traits)\n		BioPfx.density = feel[\"density\"]\n		BioPfx.linger = feel[\"trail\"]\n		BioPfx.tempo = feel[\"tempo\"]\n		for child in player.get_children():\n			if child is BioCellBody:\n				(child as BioCellBody).set_traits(design_traits)\n",
    "func apply_engine_look(look: Dictionary) -> void:\n	var designed: Dictionary = look.get(\"traits\", {})\n	if designed != design_traits and (design_source != \"debug\" or not designed.is_empty()):\n		apply_design(designed, \"motor\")\n")
sub(w, "## The engine's lineage for this player:", """## Applies a design (what Jev decided, or a debug preview) to the body, the abilities and the particles. One place, so what the debug
## overlay shows is what is really in effect.
func apply_design(designed: Dictionary, source: String) -> void:
	design_traits = designed.duplicate()
	design_source = source if not designed.is_empty() else "nenhuma"
	design_changed_at = Time.get_ticks_msec() * 0.001
	abilities.effect_style = StringName(str(design_traits.get("efeito", "")))
	BioPfx.style = abilities.effect_style
	var feel := BioDesign.feel(design_traits)
	BioPfx.density = feel["density"]
	BioPfx.linger = feel["trail"]
	BioPfx.tempo = feel["tempo"]
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).set_traits(design_traits)
	print("[design] origem=%s traços=%s" % [design_source, str(design_traits)])
	if design_debug != null:
		design_debug.refresh()


## Debug keys: F4 cycles the effect style, F5 tries a random design, F6 goes back to the engine's.
func _debug_keys() -> void:
	if Input.is_action_just_pressed("bio_debug_toggle"):
		design_debug.toggle()
	if Input.is_action_just_pressed("bio_debug_style"):
		var styles: Array = BioEffectSignature.STYLES
		var next: StringName = styles[(styles.find(abilities.effect_style) + 1) % styles.size()]
		var cur := design_traits.duplicate()
		cur["efeito"] = String(next)
		apply_design(cur, "debug")
	if Input.is_action_just_pressed("bio_debug_random"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		apply_design({
			"nucleo": "composto", "lobulacao": BioDesign.LOBES.keys()[rng.randi() % BioDesign.LOBES.size()],
			"recorte": BioDesign.CUTS[rng.randi() % BioDesign.CUTS.size()], "nucleolo": BioDesign.NUCLEOLI[rng.randi() % BioDesign.NUCLEOLI.size()],
			"membrana": BioDesign.MEMBRANES[rng.randi() % BioDesign.MEMBRANES.size()], "organelas": BioDesign.ORGANELLES[rng.randi() % BioDesign.ORGANELLES.size()],
			"brilho": BioDesign.GLOW.keys()[rng.randi() % BioDesign.GLOW.size()], "efeito": String(BioEffectSignature.STYLES[rng.randi() % BioEffectSignature.STYLES.size()]),
			"densidade": BioDesign.DENSITY.keys()[rng.randi() % BioDesign.DENSITY.size()], "rastro": BioDesign.TRAIL.keys()[rng.randi() % BioDesign.TRAIL.size()],
			"ritmo": BioDesign.TEMPO.keys()[rng.randi() % BioDesign.TEMPO.size()]}, "debug")
	if Input.is_action_just_pressed("bio_debug_engine"):
		apply_design(engine_traits, "motor")


## The engine's lineage for this player:""")
sub(w, "var design_traits: Dictionary = {}  # what Jev designed for this cell (engine look traits)\n", "var design_traits: Dictionary = {}  # what Jev designed for this cell (engine look traits)\nvar design_source := \"nenhuma\"  # motor (Jev or default), debug or nenhuma\nvar design_changed_at := -1.0\nvar engine_traits: Dictionary = {}  # the last design the engine sent, kept for F6\nvar design_debug: BioDesignDebug\n")
sub(w, "	var designed: Dictionary = look.get(\"traits\", {})\n	if designed != design_traits", "	var designed: Dictionary = look.get(\"traits\", {})\n	engine_traits = designed.duplicate()\n	if designed != design_traits")
sub(w, "	if Input.is_action_just_pressed(\"bio_codex\"):\n		codex_panel.toggle()\n", "	if Input.is_action_just_pressed(\"bio_codex\"):\n		codex_panel.toggle()\n	_debug_keys()\n")
sub(w, "	exploration = BioExploration.new()\n", "	design_debug = BioDesignDebug.new()\n	design_debug.name = \"DesignDebug\"\n	add_child(design_debug)\n	design_debug.configure(self)\n	exploration = BioExploration.new()\n")
sub("scripts/runtime/bio_player_input.gd", '	_bind("bio_codex", [_key(KEY_B)])\n', '	_bind("bio_codex", [_key(KEY_B)])\n	_bind("bio_debug_toggle", [_key(KEY_F3)])\n	_bind("bio_debug_style", [_key(KEY_F4)])\n	_bind("bio_debug_random", [_key(KEY_F5)])\n	_bind("bio_debug_engine", [_key(KEY_F6)])\n')
print("ok")
