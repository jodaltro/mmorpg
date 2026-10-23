class_name BioHumanoid
extends RefCounted
## Full ascension: a cell that has taken all of its class's mutations stands up a little. The body becomes a torso, the
## nucleus becomes the head (so the head has the class's own nucleus shape), and arms, legs or a robe and class gear grow
## from the membrane, drawn in the same glowing ribbons as everything else. It is a hint of a person, not a person.
##
## `k` is how far the cell has risen (0..1). Everything is a pure function of the form and a few phases, so every body
## walks, sways and carries its gear differently.


## Per-class proportions: head (relative to the body radius), shoulder width, arm and leg length, and gear.
static func profile(form: StringName) -> Dictionary:
	var p := {"head": 0.42, "shoulder": 0.85, "arm": 1.05, "leg": 0.95, "skirt": false, "crown": false, "halo": false, "helm": false, "gear": &"none", "torso_w": 0.9, "stoop": 0.0}
	match form:
		&"macrofago":  # a hulking brute: small head, vast shoulders and hands
			p.merge({"head": 0.34, "shoulder": 1.25, "arm": 1.15, "leg": 0.75, "gear": &"fists", "torso_w": 1.1, "stoop": 0.12}, true)
		&"neutrofilo":  # a lean runner
			p.merge({"head": 0.36, "shoulder": 0.62, "arm": 1.0, "leg": 1.35, "gear": &"scarf", "torso_w": 0.7, "stoop": 0.2}, true)
		&"dendritica":  # an elegant figure crowned with dendrites, in a flowing skirt
			p.merge({"head": 0.4, "shoulder": 0.7, "arm": 1.3, "leg": 0.0, "skirt": true, "crown": true, "gear": &"dendrites", "torso_w": 0.75}, true)
		&"linfocito_b":  # a robed mage with a great head and antibody wings
			p.merge({"head": 0.55, "shoulder": 0.75, "arm": 1.0, "leg": 0.0, "skirt": true, "gear": &"wings", "torso_w": 0.8}, true)
		&"t_citotoxico":  # an armoured lancer
			p.merge({"head": 0.38, "shoulder": 0.95, "arm": 1.0, "leg": 1.0, "helm": true, "gear": &"lance", "torso_w": 0.95}, true)
		&"t_auxiliar":  # a haloed healer with floating orbs
			p.merge({"head": 0.42, "shoulder": 0.72, "arm": 1.0, "leg": 0.0, "skirt": true, "halo": true, "gear": &"orbs", "torso_w": 0.78}, true)
	return p


## Where the head sits, relative to the cell's centre, for a body radius `r` (px) and rise `k`.
static func head_center(form: StringName, r: float, k: float) -> Vector2:
	var prof := profile(form)
	return Vector2(0.0, -r * (0.95 + 0.4 * k + float(prof["head"]) * 0.5) * k - r * float(prof["stoop"]) * 0.0)


static func head_radius(form: StringName, r: float, k: float) -> float:
	return r * float(profile(form)["head"]) * 1.25 * k


## A glowing ribbon through `pts`, tapering from width w0 to w1: a soft glow, a body fill and two bright edges.
static func _ribbon(c: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, core: Color, edge: Color, a: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var w := lerpf(w0, w1, i / float(n - 1))
		left.append(pts[i] + d.orthogonal() * w * 0.5)
		right.append(pts[i] - d.orthogonal() * w * 0.5)
	var glow := BioArt.with_alpha(core, 0.1 * a)
	var fill := BioArt.with_alpha(edge.lerp(core, 0.4), 0.3 * a)
	for i in n - 1:
		var gl := PackedVector2Array([pts[i] + (left[i] - pts[i]) * 1.8, pts[i + 1] + (left[i + 1] - pts[i + 1]) * 1.8, pts[i + 1] + (right[i + 1] - pts[i + 1]) * 1.8, pts[i] + (right[i] - pts[i]) * 1.8])
		c.draw_primitive(gl, PackedColorArray([glow, glow, glow, glow]), PackedVector2Array())
		var q := PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]])
		c.draw_primitive(q, PackedColorArray([fill, fill, fill, fill]), PackedVector2Array())
	var line := BioArt.with_alpha(edge.lerp(Color.WHITE, 0.3), 0.85 * a)
	c.draw_polyline(left, line, 2.0, true)
	c.draw_polyline(right, line, 2.0, true)


static func _chain(from: Vector2, upper: float, lower: float, angle_a: float, angle_b: float) -> PackedVector2Array:
	var elbow := from + Vector2(sin(angle_a), cos(angle_a)) * upper
	var end := elbow + Vector2(sin(angle_b), cos(angle_b)) * lower
	return PackedVector2Array([from, from.lerp(elbow, 0.5), elbow, elbow.lerp(end, 0.5), end])


## Draws the parts behind and around the torso. `walk` is a phase that advances with speed, `face` is -1..1 (which way
## the cell is turned), `sway` an idle sway. The torso is the membrane itself (drawn by the body, stretched taller).
static func draw(c: CanvasItem, form: StringName, k: float, r: float, t: float, walk: float, face: float, speed: float, core: Color, edge: Color) -> void:
	if k <= 0.02:
		return
	var prof := profile(form)
	var a := clampf(k * 1.6, 0.0, 1.0)
	var swing := sin(walk) * clampf(speed * 0.5 + 0.12, 0.12, 1.0)
	var sway := sin(t * 1.3) * 0.06
	var shoulder := float(prof["shoulder"]) * r * float(prof["torso_w"])
	var arm_len := float(prof["arm"]) * r * k
	var width := r * 0.3 * k
	var sy := -r * 0.4 * k  # shoulder height
	# legs, or the hem of a robe
	var hip := r * 0.72 * (1.0 + 0.2 * k)
	if bool(prof["skirt"]):
		_robe(c, r, k, t, walk, core, edge, a)
	else:
		var leg_len := float(prof["leg"]) * r * k
		for side in [-1.0, 1.0]:
			var s := float(side)
			var ang := s * swing * 0.7 + float(prof["stoop"]) * s * 0.0
			var pts := _chain(Vector2(s * r * 0.34, hip), leg_len * 0.55, leg_len * 0.5, ang * 0.8 + s * 0.08, ang * 0.4 - maxf(0.0, -s * swing) * 0.3 + s * 0.05)
			_ribbon(c, pts, width * 1.1, width * 0.7, core, edge, a)
			c.draw_texture_rect(BioArt.glow_texture(), Rect2(pts[4] - Vector2.ONE * 9.0, Vector2.ONE * 18.0), false, BioArt.with_alpha(core, 0.5 * a))
	# arms, with hands that carry the class's gear
	for side in [-1.0, 1.0]:
		var s := float(side)
		var base := Vector2(s * shoulder, sy)
		var ang := -s * swing * 0.6 + sway
		var out := 0.45 + 0.15 * (1.0 if prof["gear"] == &"wings" else 0.0)
		var pts := _chain(base, arm_len * 0.55, arm_len * 0.5, s * out + ang, s * (out * 0.6) + ang * 1.3 - 0.25)
		_ribbon(c, pts, width * 0.95, width * 0.55, core, edge, a)
		_hand(c, StringName(prof["gear"]), pts[4], s, face, t, core, edge, a)
	_gear(c, StringName(prof["gear"]), form, r, k, t, walk, face, core, edge, a, sy)
	if bool(prof["crown"]):
		_crown(c, head_center(form, r, k), head_radius(form, r, k), t, core, a)
	if bool(prof["halo"]):
		var hc := head_center(form, r, k) + Vector2(0.0, -head_radius(form, r, k) * 1.35)
		c.draw_arc(hc, head_radius(form, r, k) * 0.9, 0.0, TAU, 28, BioArt.with_alpha(Color(1.0, 0.92, 0.55), 0.9 * a), 2.6, true)
		c.draw_texture_rect(BioArt.glow_texture(), Rect2(hc - Vector2.ONE * head_radius(form, r, k) * 1.6, Vector2.ONE * head_radius(form, r, k) * 3.2), false, BioArt.with_alpha(Color(1.0, 0.9, 0.5), 0.3 * a))
	if bool(prof["helm"]):
		var hc2 := head_center(form, r, k)
		var hr := head_radius(form, r, k)
		c.draw_primitive(PackedVector2Array([hc2 + Vector2(-hr * 0.5, -hr * 0.8), hc2 + Vector2(hr * 0.5, -hr * 0.8), hc2 + Vector2(0.0, -hr * 2.0)]), PackedColorArray([BioArt.with_alpha(BioArt.CRIMSON, 0.55 * a), BioArt.with_alpha(BioArt.CRIMSON, 0.55 * a), BioArt.with_alpha(Color(1.0, 0.8, 0.8), 0.9 * a)]), PackedVector2Array())
		c.draw_line(hc2 + Vector2(0.0, -hr * 2.0), hc2 + Vector2(0.0, -hr * 2.6), BioArt.with_alpha(Color.WHITE, 0.85 * a), 2.0, true)
	# a thin neck from torso to head
	var neck := PackedVector2Array([Vector2(0.0, sy * 0.9), head_center(form, r, k) + Vector2(0.0, head_radius(form, r, k) * 0.7)])
	_ribbon(c, neck, width * 0.9, width * 0.6, core, edge, a)


static func _hand(c: CanvasItem, gear: StringName, at: Vector2, side: float, face: float, t: float, core: Color, edge: Color, a: float) -> void:
	var white := BioArt.with_alpha(Color.WHITE, 0.85 * a)
	match gear:
		&"fists":  # heavy glowing fists
			c.draw_texture_rect(BioArt.glow_texture(), Rect2(at - Vector2.ONE * 18.0, Vector2.ONE * 36.0), false, BioArt.with_alpha(core, 0.4 * a))
			c.draw_circle(at, 8.0, BioArt.with_alpha(core.lerp(Color.WHITE, 0.2), 0.75 * a))
			c.draw_arc(at, 9.0, 0.0, TAU, 16, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.4), 0.9 * a), 2.2, true)
		&"dendrites":  # fingers of fine dendrites
			for k in 4:
				var ang := -PI * 0.5 + (k - 1.5) * 0.45 + sin(t * 2.0 + k) * 0.15
				var tip := at + Vector2.from_angle(ang) * 13.0
				c.draw_line(at, tip, BioArt.with_alpha(core.lerp(Color.WHITE, 0.25), 0.85 * a), 1.8, true)
				c.draw_circle(tip, 1.8, white)
		&"orbs":
			var bob := sin(t * 2.5 + side) * 3.0
			c.draw_texture_rect(BioArt.glow_texture(), Rect2(at + Vector2(0, -12.0 + bob) - Vector2.ONE * 14.0, Vector2.ONE * 28.0), false, BioArt.with_alpha(Color(1.0, 0.9, 0.5), 0.6 * a))
			c.draw_circle(at + Vector2(0, -12.0 + bob), 4.5, BioArt.with_alpha(Color(1.0, 0.95, 0.7), 0.9 * a))
		_:
			c.draw_circle(at, 4.0, BioArt.with_alpha(core.lerp(Color.WHITE, 0.3), 0.8 * a))


## Gear that is not on a hand: the lance, the antibody wings, the neutrophil's scarf, the dendrites' veil.
static func _gear(c: CanvasItem, gear: StringName, form: StringName, r: float, k: float, t: float, walk: float, face: float, core: Color, edge: Color, a: float, sy: float) -> void:
	match gear:
		&"lance":  # a spear held out on the side the cell faces
			var s := 1.0 if face >= 0.0 else -1.0
			var hand := Vector2(s * r * 1.15 * k, sy + r * 0.55 * k)
			var tip := hand + Vector2(s * 0.2, -1.0).normalized() * r * 2.2 * k
			var back := hand - Vector2(s * 0.2, -1.0).normalized() * r * 0.8 * k
			c.draw_line(back, tip, BioArt.with_alpha(BioArt.CRIMSON, 0.4 * a), 7.0, true)
			c.draw_line(back, tip, BioArt.with_alpha(Color(1.0, 0.85, 0.85), 0.9 * a), 2.4, true)
			c.draw_circle(tip, 3.2, BioArt.with_alpha(Color.WHITE, 0.95 * a))
		&"wings":  # antibodies as wings: two Y-branches on the back
			for side in [-1.0, 1.0]:
				var s := float(side)
				var root := Vector2(s * r * 0.5, sy + r * 0.1)
				var flap := sin(t * 1.6) * 0.1
				for j in 2:
					var ang := -PI * 0.5 + s * (0.6 + j * 0.45 + flap)
					var mid := root + Vector2.from_angle(ang) * r * (1.1 + 0.2 * j) * k
					c.draw_line(root, mid, BioArt.with_alpha(Color(1.0, 0.8, 0.95), 0.6 * a), 2.2, true)
					for sub in [-0.5, 0.5]:
						var tip := mid + Vector2.from_angle(ang + float(sub)) * r * 0.35 * k
						c.draw_line(mid, tip, BioArt.with_alpha(Color(1.0, 0.8, 0.95), 0.85 * a), 2.0, true)
						c.draw_circle(tip, 2.2, BioArt.with_alpha(Color.WHITE, 0.85 * a))
		&"scarf":  # a long streaming tail of membrane from the neck, blown opposite to where it faces
			var s := -1.0 if face >= 0.0 else 1.0
			var pts := PackedVector2Array()
			for i in 8:
				var f := i / 7.0
				pts.append(Vector2(s * r * 0.4 * f * 4.0 * k, sy + sin(t * 4.0 + f * 5.0 + walk) * r * 0.25 * f + f * r * 0.35))
			_ribbon(c, pts, r * 0.22 * k, r * 0.04, core, edge, a)
		&"dendrites":  # a veil of dendrites behind the shoulders
			for j in 7:
				var ang := -PI * 0.5 + (j - 3.0) * 0.38 + sin(t * 0.9 + j) * 0.07
				var root := Vector2((j - 3.0) * r * 0.2, sy)
				var tip := root + Vector2.from_angle(ang) * r * 0.9 * k
				c.draw_line(root, tip, BioArt.with_alpha(core.lerp(Color.WHITE, 0.2), 0.45 * a), 1.6, true)
				c.draw_circle(tip, 1.8, BioArt.with_alpha(Color.WHITE, 0.6 * a))
		&"fists":  # shoulder plates
			for side in [-1.0, 1.0]:
				var s := float(side)
				c.draw_arc(Vector2(s * r * 0.95 * k, sy), r * 0.45 * k, PI * 0.5 + s * 0.2 - 1.3, PI * 0.5 + s * 0.2 + 1.3, 12, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.4), 0.9 * a), 5.0, true)


## A flowing robe in place of legs: a bell of membrane with a wavy hem.
static func _robe(c: CanvasItem, r: float, k: float, t: float, walk: float, core: Color, edge: Color, a: float) -> void:
	var top := r * 0.3
	var bottom := r * (1.25 + 0.55 * k)
	var spread := r * (0.75 + 0.35 * k)
	var n := 14
	var hem := PackedVector2Array()
	for i in n + 1:
		var f := i / float(n)
		var x := lerpf(-spread, spread, f)
		hem.append(Vector2(x, bottom + sin(t * 2.2 + f * 9.0 + walk * 0.5) * r * 0.06))
	var fill := BioArt.with_alpha(core, 0.16 * a)
	var up := BioArt.with_alpha(core, 0.04 * a)
	for i in n:
		var f0 := i / float(n)
		var f1 := (i + 1) / float(n)
		c.draw_primitive(PackedVector2Array([Vector2(lerpf(-r * 0.5, r * 0.5, f0), top), Vector2(lerpf(-r * 0.5, r * 0.5, f1), top), hem[i + 1], hem[i]]), PackedColorArray([up, up, fill, fill]), PackedVector2Array())
	c.draw_polyline(hem, BioArt.with_alpha(edge.lerp(Color.WHITE, 0.4), 0.85 * a), 2.2, true)
	c.draw_line(Vector2(-r * 0.5, top), hem[0], BioArt.with_alpha(edge.lerp(Color.WHITE, 0.3), 0.7 * a), 2.0, true)
	c.draw_line(Vector2(r * 0.5, top), hem[n], BioArt.with_alpha(edge.lerp(Color.WHITE, 0.3), 0.7 * a), 2.0, true)


static func _crown(c: CanvasItem, at: Vector2, hr: float, t: float, core: Color, a: float) -> void:
	for j in 7:
		var ang := -PI * 0.5 + (j - 3.0) * 0.4
		var from := at + Vector2.from_angle(ang) * hr * 0.9
		var mid := at + Vector2.from_angle(ang + sin(t * 1.4 + j) * 0.12) * hr * 1.7
		var tip := mid + Vector2.from_angle(ang + 0.5) * hr * 0.5
		c.draw_polyline(PackedVector2Array([from, mid, tip]), BioArt.with_alpha(core.lerp(Color.WHITE, 0.3), 0.85 * a), 1.8, true)
		c.draw_circle(tip, 2.0, BioArt.with_alpha(Color.WHITE, 0.85 * a))
