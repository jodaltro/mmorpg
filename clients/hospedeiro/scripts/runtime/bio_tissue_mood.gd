class_name BioTissueMood
extends Node2D
## The organs answer to the crises: inflammation reddens and quickens a region, a wound opens fissures in layers, containment calms it
## to a steady cool light and recovery fades it out gradually. Values come from the engine (phase and severity against its peak);
## nothing here is a fact, and it changes no collider. A spread to another region is drawn only when the engine opened that front.

const TINT := {
	"critical": Color(1.0, 0.2, 0.28), "active": Color(1.0, 0.5, 0.25), "contained": Color(0.4, 0.75, 1.0), "recovering": Color(0.45, 1.0, 0.7),
}
const INTENSITY := {"critical": 0.15, "active": 0.1, "contained": 0.05, "recovering": 0.04}
const FADE_SECONDS := 6.0  # recovery fades slowly: the tissue does not heal in one frame

var prefs: BioVisualPrefs = BioVisualPrefs.new()
var anatomy: BioAnatomyView

var _targets := {}  # region -> {tint, level, ratio, kind}
var _now := {}  # region -> current level (0..1), eased
var _centers := {}
var _radii := {}
var _outlines := {}  # region -> PackedVector2Array in px
var _t := 0.0


func configure(anatomy_view: BioAnatomyView, visual: BioVisualPrefs) -> void:
	anatomy = anatomy_view
	prefs = visual
	z_index = -5
	material = BioArt.additive()
	var body := BioAnatomy.build(BioBodyMap.seed_value)
	for r in body["regions"]:
		var pts := PackedVector2Array()
		for p in (r["outline"] as PackedVector2Array):
			pts.append(p * BioArt.UNIT)
		_outlines[StringName(r["id"])] = pts
		_centers[StringName(r["id"])] = (r["center"] as Vector2) * BioArt.UNIT
		_radii[StringName(r["id"])] = float(r["radius"]) * BioArt.UNIT


## Takes the ordered conflicts of the model. A region shows its worst crisis.
func set_conflicts(items: Array) -> void:
	var next := {}
	for c in items:
		var phase := str(c.get("phase", ""))
		if not TINT.has(phase):
			continue
		var peak := maxf(1.0, float(c.get("peak", 1)))
		var ratio := clampf(float(c.get("severity", 0)) / peak, 0.0, 1.0)
		var level: float = float(INTENSITY[phase]) * (0.4 + 0.6 * ratio)
		_offer(next, StringName(str(c.get("region", ""))), phase, level, ratio, str(c.get("def", "")))
		var fronts: Variant = c.get("frontRegions")
		if fronts is Dictionary:
			for f in fronts:
				_offer(next, StringName(str(fronts[f])), phase, level * 0.55, ratio * 0.6, "")
	_targets = next


func _offer(into: Dictionary, region: StringName, phase: String, level: float, ratio: float, kind: String) -> void:
	if region == &"":
		return
	var old: Dictionary = into.get(region, {})
	if old.is_empty() or level > float(old["level"]):
		into[region] = {"phase": phase, "level": level, "ratio": ratio, "kind": kind if kind != "" else str(old.get("kind", ""))}


func level_of(region: StringName) -> float:
	return float(_now.get(region, 0.0))


func _process(delta: float) -> void:
	_t += delta
	var any := false
	for region in _outlines:
		var want: float = float((_targets.get(region, {}) as Dictionary).get("level", 0.0))
		var cur: float = float(_now.get(region, 0.0))
		var speed := 1.0 / FADE_SECONDS if want < cur else 0.35
		_now[region] = move_toward(cur, want, delta * speed * maxf(0.05, absf(want - cur) + 0.1))
		any = any or float(_now[region]) > 0.003
	visible = any
	if any:
		queue_redraw()


func _draw() -> void:
	if anatomy == null:
		return
	for region in _outlines:
		var level: float = float(_now.get(region, 0.0))
		if level <= 0.003 or not anatomy.live.has(region):
			continue
		var info: Dictionary = _targets.get(region, {"phase": "recovering", "ratio": 0.0, "kind": ""})
		var phase := str(info["phase"])
		var tint: Color = TINT.get(phase, TINT["recovering"])
		var beat := 1.0
		if phase == "active" or phase == "critical":
			var rate := 2.2 + 3.0 * float(info["ratio"])
			beat = 1.0 + 0.35 * sin(_t * rate) * prefs.fx_scale() * (0.0 if prefs.reduce_flash else 1.0)
		var pts: PackedVector2Array = _outlines[region]
		var center: Vector2 = _centers[region]
		for layer in 3:
			var k := 1.0 - layer * 0.22
			var scaled := PackedVector2Array()
			for p in pts:
				scaled.append(center + (p - center) * k)
			draw_colored_polygon(scaled, BioArt.with_alpha(tint, level * beat * (0.4 + 0.15 * layer)))
		_extras(str(info["kind"]), level, float(info["ratio"]), center, float(_radii[region]))


## What each kind of crisis leaves on the tissue (a fissure, a clot, a haze), in proportion to the engine's severity.
func _extras(kind: String, level: float, ratio: float, center: Vector2, rad: float) -> void:
	var n := clampi(roundi((3.0 + 9.0 * ratio) * prefs.fx_scale()), 0, 14)
	match kind:
		"ferida-na-pele":  # a breach that closes in layers as the wound shrinks
			var at := center + Vector2.from_angle(float(absi("ferida".hash()) % 628) / 100.0) * rad * 0.4
			for i in clampi(ceili(ratio * 6.0), 1, 6):
				var a := (i - 2.5) * 0.45
				var from := at + Vector2.from_angle(a) * rad * 0.04 * i
				draw_line(from, from + Vector2.from_angle(a + 1.2) * rad * (0.12 + 0.05 * i), BioArt.with_alpha(Color(0.6, 0.0, 0.05), 0.65 * level * 3.0), 3.0, true)
		"congestao-esplenica":  # clotted old cells
			for i in n:
				var a := float(i) * 2.4
				draw_circle(center + Vector2.from_angle(a) * rad * (0.25 + 0.4 * fposmod(a, 1.0)), rad * 0.006, Color(0.45, 0.05, 0.2, minf(0.8, level * 4.0)))
		"sobrecarga-hepatica", "disbiose-intestinal":
			var haze := Color(0.65, 1.0, 0.2) if kind == "sobrecarga-hepatica" else Color(0.9, 0.7, 0.3)
			for i in n:
				var a := float(i) * 1.9 + _t * 0.1 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.2 + 0.5 * fposmod(a * 0.37, 1.0)), rad * 0.005, BioArt.with_alpha(haze, minf(0.7, level * 3.5)))
		"tumor-intestinal":  # a mass that takes up the territory of the tissue, in proportion to the engine's severity
			var mass := rad * (0.06 + 0.3 * ratio)
			var at := center + Vector2.from_angle(float(absi("tumor".hash()) % 628) / 100.0) * rad * 0.3
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(at + Vector2.from_angle(a) * mass * (1.0 + 0.18 * sin(a * 5.0 + _t * 0.6 * prefs.motion_scale()) + 0.1 * sin(a * 9.0)))
			draw_colored_polygon(pts, Color(0.75, 0.15, 0.6, minf(0.5, 0.2 + level * 2.0)))
		"sobrecarga-renal":
			for i in n:
				var a := float(i) * 2.2 + _t * 0.1 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.15 + 0.55 * fposmod(a * 0.39, 1.0)), rad * 0.006, BioArt.with_alpha(Color(0.4, 1.0, 0.95), minf(0.7, level * 3.5)))
		"reacao-exagerada":
			for i in n:
				var a := float(i) * 1.7 + _t * 0.2 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.2 + 0.5 * fposmod(a * 0.47, 1.0)), rad * 0.007, BioArt.with_alpha(Color(1.0, 0.55, 0.4), minf(0.7, level * 3.5)))
		"sofrimento-cerebral":
			for i in n:
				var a := float(i) * 2.9 + _t * 0.07 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.15 + 0.55 * fposmod(a * 0.31, 1.0)), rad * 0.006, BioArt.with_alpha(Color(0.8, 0.5, 1.0), minf(0.7, level * 3.5)))
		"medula-esgotada":  # an empty niche: pale dust where new cells should be born
			for i in n:
				var a := float(i) * 2.3 + _t * 0.08 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.15 + 0.5 * fposmod(a * 0.43, 1.0)), rad * 0.006, BioArt.with_alpha(Color(1.0, 0.85, 0.5), minf(0.7, level * 3.5)))
		"infeccao-pulmonar":
			for i in n:
				var a := float(i) * 2.1 + _t * 0.12 * prefs.motion_scale()
				draw_circle(center + Vector2.from_angle(a) * rad * (0.2 + 0.55 * fposmod(a * 0.41, 1.0)), rad * 0.0045, BioArt.with_alpha(Color(0.8, 1.0, 0.3), minf(0.75, level * 3.5)))
