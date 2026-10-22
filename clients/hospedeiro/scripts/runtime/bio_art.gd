class_name BioArt
extends RefCounted
## Procedural art assets: one radial glow texture and one additive material drive the whole bioluminescent look.

const UNIT := 48.0  # pixels per world unit

const CYAN := Color(0.15, 0.9, 1.0)
const DEEP_BLUE := Color(0.2, 0.45, 1.0)
const CRIMSON := Color(1.0, 0.15, 0.3)
const MAGENTA := Color(0.9, 0.2, 0.85)
const AMBER := Color(1.0, 0.75, 0.25)
const JADE := Color(0.35, 1.0, 0.6)
const TOXIN := Color(0.65, 1.0, 0.2)

static var _glow: GradientTexture2D
static var _additive: CanvasItemMaterial


static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Additive glow sprite whose diameter is `diameter_units` world units.
static func make_glow(color: Color, diameter_units: float, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = glow_texture()
	sprite.material = additive()
	sprite.modulate = color
	sprite.scale = Vector2.ONE * (diameter_units * UNIT / 128.0)
	sprite.z_index = z
	return sprite
