class_name BioOrganelles
extends RefCounted
## The visible mark of a mutation (BioGene.mark): a few organelle kinds drawn around the body, each with its own
## colour, count and size, so two cells of the same class with different mutations read differently at a glance.
## kinds: orbs (orbiting lights), ring (turning arcs), spikes (spines on the rim), filaments (strands inside),
## crescents (armour plates on the rim), crystals (diamonds), tendrils (short curled threads), pulses (expanding rings),
## vacuoles (bubbles inside).


static func draw(c: CanvasItem, mark: Dictionary, r: float, t: float, edge: Color) -> void:
	var color := Color.html(str(mark.get("color", "#ffffff")))
	var count := int(mark.get("count", 4))
	var seed_shift := float(str(mark.get("color", "")).hash() % 100) * 0.1
	match str(mark.get("kind", "")):
		"orbs":
			var radius := float(mark.get("radius", 0.7))
			for k in count:
				var a := t * (0.5 + 0.08 * (k % 3)) + k * TAU / count + seed_shift
				var p := Vector2.from_angle(a) * r * (radius + 0.08 * sin(t * 2.0 + k))
				c.draw_texture_rect(BioArt.glow_texture(), Rect2(p - Vector2.ONE * 9.0, Vector2.ONE * 18.0), false, BioArt.with_alpha(color, 0.3))
				c.draw_circle(p, 2.6, BioArt.with_alpha(color.lerp(Color.WHITE, 0.2), 0.75))
		"ring":
			for k in count:
				var rr := r * (0.5 + 0.2 * k)
				var a0 := t * (0.8 - 0.25 * k) + k + seed_shift
				c.draw_arc(Vector2.ZERO, rr, a0, a0 + TAU * 0.6, 28, BioArt.with_alpha(color, 0.75), 2.4, true)
				c.draw_arc(Vector2.ZERO, rr, a0 + PI, a0 + PI + TAU * 0.2, 12, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.9), 3.2, true)
		"spikes":
			var length := 13.0 if bool(mark.get("long", false)) else 8.0
			for k in count:
				var a := k * TAU / count + seed_shift
				var base := Vector2.from_angle(a) * r * 0.97
				var tip := base + Vector2.from_angle(a) * (length + 2.5 * sin(t * 3.0 + k))
				c.draw_line(base, tip, BioArt.with_alpha(color, 0.9), 2.4, true)
				c.draw_circle(tip, 1.8, BioArt.with_alpha(Color.WHITE, 0.8))
		"filaments":
			for k in count:
				var a := k * TAU / count + t * 0.12 + seed_shift
				var pts := PackedVector2Array()
				for i in 7:
					var f := i / 6.0
					pts.append(Vector2.from_angle(a + sin(t * 1.5 + f * 4.0 + k) * 0.22) * r * (0.12 + 0.82 * f))
				c.draw_polyline(pts, BioArt.with_alpha(color, 0.6), 1.8, true)
		"crescents":
			for k in count:
				var a := k * TAU / count + t * 0.2 + seed_shift
				c.draw_arc(Vector2.ZERO, r * 1.05, a, a + TAU / count * 0.6, 10, BioArt.with_alpha(color, 0.85), 5.0, true)
		"crystals":
			for k in count:
				var a := -t * 0.3 + k * TAU / count + seed_shift
				var p := Vector2.from_angle(a) * r * 0.62
				var s := 6.0 + 1.5 * sin(t * 2.0 + k)
				var pts := PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s, 0), p + Vector2(0, s * 1.6), p + Vector2(-s, 0)])
				c.draw_primitive(pts, PackedColorArray([BioArt.with_alpha(color, 0.35), BioArt.with_alpha(color, 0.35), BioArt.with_alpha(color, 0.35), BioArt.with_alpha(color, 0.35)]), PackedVector2Array())
				pts.append(pts[0])
				c.draw_polyline(pts, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), 0.95), 1.6, true)
		"tendrils":
			for k in count:
				var a := k * TAU / count + seed_shift + sin(t * 0.8 + k) * 0.2
				var pts := PackedVector2Array()
				for i in 6:
					var f := i / 5.0
					pts.append(Vector2.from_angle(a + sin(t * 3.0 + f * 5.0 + k) * 0.35 * f) * r * (0.95 + 0.55 * f))
				c.draw_polyline(pts, BioArt.with_alpha(color, 0.8), 2.2, true)
				c.draw_circle(pts[5], 2.4, BioArt.with_alpha(Color.WHITE, 0.85))
		"pulses":
			for k in count:
				var phase := fmod(t * 0.45 + k / float(count) + seed_shift, 1.0)
				c.draw_arc(Vector2.ZERO, r * (1.05 + 0.8 * phase), 0.0, TAU, 48, BioArt.with_alpha(color, 0.6 * (1.0 - phase)), 2.4, true)
		"vacuoles":
			for k in count:
				var a := t * 0.18 + k * TAU / count + seed_shift
				var p := Vector2.from_angle(a) * r * 0.5
				var s := 8.0 + 3.0 * sin(t * 0.9 + k)
				c.draw_arc(p, s, 0.0, TAU, 20, BioArt.with_alpha(color, 0.85), 2.2, true)
				c.draw_circle(p, s * 0.5, BioArt.with_alpha(color, 0.3))
