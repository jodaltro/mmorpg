class_name BioOrganelles
extends RefCounted
## The visible mark of a mutation (BioGene.mark): a small organelle in its own POCKET of the body. Every equipped mutation
## takes one of six fixed places inside the membrane (so they never pile on top of each other), drawn as a little sac
## with a glyph that is the same shape for the same gene every time. Kinds: orbs, ring, spikes, filaments, crescents,
## crystals, tendrils, pulses, vacuoles, capsules.

## Where each slot sits: a 3 x 2 grid in the lower part of the body (the top is left for the nucleus or the head), in
## units of the body radius, so six pockets always fit apart from each other.
const POCKET_GRID := [Vector2(-0.5, 0.4), Vector2(0.0, 0.4), Vector2(0.5, 0.4), Vector2(-0.5, 0.82), Vector2(0.0, 0.82), Vector2(0.5, 0.82)]
const POCKET_SIZE := 0.14  # of the body radius


static func body_radius(rim: PackedVector2Array) -> float:
	if rim.is_empty():
		return 20.0
	var total := 0.0
	for p in rim:
		total += p.length()
	return total / rim.size()


## `away` is a direction the pockets keep clear of (where a tail leaves the body): the whole grid slides the other way.
static func pocket_position(rim: PackedVector2Array, slot: int, away: Vector2 = Vector2.ZERO) -> Vector2:
	var r := body_radius(rim)
	return (POCKET_GRID[slot % POCKET_GRID.size()] as Vector2) * r - away.normalized() * r * 0.32 if away != Vector2.ZERO else (POCKET_GRID[slot % POCKET_GRID.size()] as Vector2) * r


static func draw_pocket(c: CanvasItem, mark: Dictionary, at: Vector2, size: float, t: float, slot: int) -> void:
	var color := Color.html(str(mark.get("color", "#ffffff")))
	var count := clampi(int(mark.get("count", 3)), 1, 9)
	var seed_shift := slot * 1.7
	# the sac: a faint disc and a thin ring, so each mutation reads as its own organelle
	c.draw_circle(at, size, BioArt.with_alpha(color, 0.07))
	c.draw_arc(at, size, 0.0, TAU, 20, BioArt.with_alpha(color, 0.4), 1.4, true)
	match str(mark.get("kind", "")):
		"orbs":
			for k in count:
				var a := t * 0.9 + k * TAU / count + seed_shift
				var p := at + Vector2.from_angle(a) * size * 0.5
				c.draw_circle(p, size * 0.17, BioArt.with_alpha(color.lerp(Color.WHITE, 0.25), 0.85))
		"ring":
			for k in clampi(count, 1, 3):
				var a0 := t * (0.9 - 0.3 * k) + k + seed_shift
				c.draw_arc(at, size * (0.78 - 0.24 * k), a0, a0 + TAU * 0.62, 14, BioArt.with_alpha(color, 0.85), 1.8, true)
			c.draw_circle(at, size * 0.12, BioArt.with_alpha(Color.WHITE, 0.7))
		"spikes":
			for k in count:
				var a := k * TAU / count + seed_shift + sin(t * 1.5 + k) * 0.06
				c.draw_line(at + Vector2.from_angle(a) * size * 0.18, at + Vector2.from_angle(a) * size * 0.84, BioArt.with_alpha(color, 0.85), 1.6, true)
			c.draw_circle(at, size * 0.15, BioArt.with_alpha(color.lerp(Color.WHITE, 0.3), 0.8))
		"filaments":
			for k in count:
				var y := lerpf(-size * 0.6, size * 0.6, (k + 0.5) / count)
				var pts := PackedVector2Array()
				for i in 7:
					var f := i / 6.0
					pts.append(at + Vector2(lerpf(-size * 0.75, size * 0.75, f), y + sin(t * 2.0 + f * 5.0 + k) * size * 0.14))
				c.draw_polyline(pts, BioArt.with_alpha(color, 0.75), 1.5, true)
		"crescents":
			for k in clampi(count, 1, 5):
				var a := k * TAU / clampi(count, 1, 5) + t * 0.3 + seed_shift
				c.draw_arc(at, size * 0.62, a, a + TAU / clampi(count, 1, 5) * 0.55, 8, BioArt.with_alpha(color, 0.9), 2.6, true)
		"crystals":
			for k in clampi(count, 1, 4):
				var a := -t * 0.4 + k * TAU / clampi(count, 1, 4) + seed_shift
				var p := at + Vector2.from_angle(a) * size * (0.0 if count == 1 else 0.42)
				var s := size * (0.34 if count <= 2 else 0.24)
				var pts := PackedVector2Array([p + Vector2(0, -s * 1.5), p + Vector2(s, 0), p + Vector2(0, s * 1.5), p + Vector2(-s, 0), p + Vector2(0, -s * 1.5)])
				c.draw_polyline(pts, BioArt.with_alpha(color.lerp(Color.WHITE, 0.3), 0.9), 1.6, true)
		"tendrils":
			for k in clampi(count, 1, 4):
				var a := k * TAU / clampi(count, 1, 4) + seed_shift
				var pts := PackedVector2Array()
				for i in 8:
					var f := i / 7.0
					pts.append(at + Vector2.from_angle(a + f * 2.2 + sin(t * 2.0 + k) * 0.25) * size * 0.8 * f)
				c.draw_polyline(pts, BioArt.with_alpha(color, 0.85), 1.7, true)
		"pulses":
			for k in clampi(count, 1, 3):
				var phase := fmod(t * 0.6 + k / float(clampi(count, 1, 3)) + seed_shift, 1.0)
				c.draw_arc(at, size * (0.15 + 0.7 * phase), 0.0, TAU, 18, BioArt.with_alpha(color, 0.8 * (1.0 - phase)), 1.6, true)
			c.draw_circle(at, size * 0.13, BioArt.with_alpha(Color.WHITE, 0.7))
		"vacuoles":
			for k in clampi(count, 1, 4):
				var a := t * 0.25 + k * TAU / clampi(count, 1, 4) + seed_shift
				var p := at + Vector2.from_angle(a) * size * (0.0 if count == 1 else 0.38)
				var s := size * (0.5 if count <= 2 else 0.3) * (1.0 + 0.1 * sin(t * 1.5 + k))
				c.draw_arc(p, s, 0.0, TAU, 14, BioArt.with_alpha(color, 0.9), 1.6, true)
				c.draw_circle(p, s * 0.4, BioArt.with_alpha(color, 0.3))
		"capsules":  # mitochondria: ovals with a fold inside
			for k in clampi(count, 1, 4):
				var a := t * 0.2 + k * TAU / clampi(count, 1, 4) + seed_shift
				var p := at + Vector2.from_angle(a) * size * 0.36
				c.draw_set_transform(p, a + PI * 0.5, Vector2(1.7, 1.0))
				c.draw_arc(Vector2.ZERO, size * 0.2, 0.0, TAU, 12, BioArt.with_alpha(color, 0.9), 1.5, true)
				c.draw_line(Vector2(-size * 0.12, 0), Vector2(size * 0.12, 0), BioArt.with_alpha(color, 0.7), 1.2, true)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
