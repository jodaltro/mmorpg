class_name BioGhostForm
extends RefCounted
## The final shape of a class: the SAME membrane, deformed into a single ghostly figure that hints at a person. Nothing is
## added (no arms, no legs): a head bulges up, shoulders widen, a neck and waist pinch, and the lower body drains into a
## wavering hem or a trailing wisp, all as one outline. How much of it shows depends on the ascension (0..1), so a cell
## grows into it gradually, and each class bends the silhouette its own way.
##
## The shape is a sum of bumps on the radius, by angle measured from straight up (clockwise, radians):
## {phi, width, amp}. A positive amp pushes the membrane out there, a negative one pinches it in.


static func bumps(form: StringName) -> Array:
	match form:
		&"macrofago":  # a hulking ghost: a small head sunk between vast shoulders and a broad base
			return [[0.0, 0.38, 0.55], [1.15, 0.5, 0.5], [-1.15, 0.5, 0.5], [2.1, 0.45, 0.3], [-2.1, 0.45, 0.3], [PI, 0.8, 0.2], [0.55, 0.2, -0.2], [-0.55, 0.2, -0.2]]
		&"neutrofilo":  # a lean runner leaning forward, trailing a long wisp
			return [[-0.15, 0.36, 0.65], [0.95, 0.4, 0.14], [-0.95, 0.4, 0.12], [PI, 0.28, 0.95], [0.5, 0.2, -0.18], [-0.5, 0.2, -0.18], [1.6, 0.4, -0.2], [-1.6, 0.4, -0.2]]
		&"dendritica":  # slender, with long sleeves of membrane that hang down and a rippling hem
			return [[0.0, 0.42, 0.5], [0.95, 0.3, 0.12], [-0.95, 0.3, 0.12], [2.45, 0.24, 0.8], [-2.45, 0.24, 0.8], [PI, 0.5, 0.25], [0.5, 0.2, -0.16], [-0.5, 0.2, -0.16], [1.7, 0.3, -0.25], [-1.7, 0.3, -0.25]]
		&"linfocito_b":  # a great head over a narrow body and a bell of robe
			return [[0.0, 0.58, 0.8], [PI, 0.95, 0.55], [0.62, 0.22, -0.3], [-0.62, 0.22, -0.3], [1.5, 0.4, -0.2], [-1.5, 0.4, -0.2]]
		&"t_citotoxico":  # angular: a pointed helm, sharp shoulders and a narrow taper
			return [[0.0, 0.24, 0.85], [1.15, 0.3, 0.42], [-1.15, 0.3, 0.42], [PI, 0.3, 0.5], [0.45, 0.16, -0.22], [-0.45, 0.16, -0.22], [1.75, 0.35, -0.3], [-1.75, 0.35, -0.3]]
		&"t_auxiliar":  # serene: a round head, soft shoulders, flowing robe
			return [[0.0, 0.5, 0.6], [1.0, 0.45, 0.22], [-1.0, 0.45, 0.22], [PI, 0.9, 0.6], [1.85, 0.3, 0.2], [-1.85, 0.3, 0.2], [0.55, 0.2, -0.2], [-0.55, 0.2, -0.2]]
		&"mastocito":  # a round bundle, lumpy with granules, a big head over a puffed body
			return [[0.0, 0.5, 0.55], [1.2, 0.5, 0.35], [-1.2, 0.5, 0.35], [2.3, 0.45, 0.35], [-2.3, 0.45, 0.35], [PI, 0.8, 0.3], [0.65, 0.2, -0.2], [-0.65, 0.2, -0.2]]
		&"eosinofilo":  # a two-lobed head, a deep notch between, a broad chest
			return [[0.4, 0.28, 0.55], [-0.4, 0.28, 0.55], [0.0, 0.14, -0.3], [1.1, 0.4, 0.45], [-1.1, 0.4, 0.45], [PI, 0.7, 0.35], [1.8, 0.3, -0.2], [-1.8, 0.3, -0.2]]
		&"celula_nk":  # a crest over a lean, forward body that trails a thin wisp
			return [[-0.1, 0.2, 0.95], [0.9, 0.3, 0.3], [-0.9, 0.3, 0.2], [PI, 0.22, 0.85], [0.45, 0.18, -0.2], [-0.45, 0.18, -0.2], [1.6, 0.35, -0.28], [-1.6, 0.35, -0.28]]
		&"t_regulador":  # veiled: a wide soft hood and long sleeves hanging down
			return [[0.0, 0.55, 0.55], [0.9, 0.5, 0.28], [-0.9, 0.5, 0.28], [2.6, 0.3, 0.7], [-2.6, 0.3, 0.7], [PI, 1.0, 0.35], [0.5, 0.2, -0.15], [-0.5, 0.2, -0.15]]
	return []


## Radius multiplier of the membrane at world angle `a` (0 = to the right, y down) for this form at ascension `m`.
static func radius_mul(form: StringName, a: float, m: float, t: float = 0.0) -> float:
	if m <= 0.0:
		return 1.0
	var phi := wrapf(a + PI * 0.5, -PI, PI)  # from straight up, clockwise
	var sum := 0.0
	for b in bumps(form):
		var d := angle_difference(float(b[0]), phi) / float(b[1])
		sum += float(b[2]) * exp(-d * d)
	# the lower body drains away: its edge ripples like a hem
	var low := clampf((absf(phi) - 1.9) / 0.9, 0.0, 1.0)
	sum += 0.07 * low * sin(phi * 9.0 + t * 2.6) + 0.03 * low * sin(phi * 5.0 - t * 1.7)
	return maxf(1.0 + sum * m, 0.45)


## How tall the head bulges for this form (the amplitude of the bump straight up).
static func head_height(form: StringName) -> float:
	var h := 0.0
	for b in bumps(form):
		if absf(float(b[0])) < 0.2 and float(b[2]) > 0.0:
			h = maxf(h, float(b[2]))
	return h


## Where the nucleus sits when the body has risen: inside the head bulge.
static func head_center(form: StringName, r: float, m: float) -> Vector2:
	var tilt := -0.15 if form == &"neutrofilo" else 0.0
	return Vector2.from_angle(-PI * 0.5 + tilt) * r * (1.0 + head_height(form) * m) * 0.5 * m


## The largest nucleus radius that still fits inside the head bulge.
static func head_room(form: StringName, r: float, m: float) -> float:
	return r * (0.3 + head_height(form) * 0.62) * minf(m * 1.4, 1.0) + r * 10.0 * (1.0 - minf(m * 1.4, 1.0))


## The lean of the whole figure with its sideways motion (radians), a floaty, ghostly tilt.
static func lean(velocity_x: float, m: float) -> float:
	return clampf(velocity_x / 340.0, -1.0, 1.0) * 0.28 * m
