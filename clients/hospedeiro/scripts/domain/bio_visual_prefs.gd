class_name BioVisualPrefs
extends RefCounted
## How much the living body is drawn. The cost of the visuals is chosen here and never touches the facts: a cell outside the
## camera keeps working in the engine whatever the preset. Saved per device.

const PRESETS := {
	# npc_cap: cells drawn with the full deformable membrane (the costly part); the rest are a light silhouette or a dot.
	"alto": {"fx": 1.0, "npc_cap": 12, "crowd_cap": 36, "crowd_per_cohort": 8, "speech_cap": 4, "lod_near": 1400.0, "lod_far": 3200.0, "particles": 1.0},
	"padrao": {"fx": 0.7, "npc_cap": 8, "crowd_cap": 24, "crowd_per_cohort": 5, "speech_cap": 3, "lod_near": 1000.0, "lod_far": 2400.0, "particles": 0.6},
	"economico": {"fx": 0.35, "npc_cap": 4, "crowd_cap": 10, "crowd_per_cohort": 3, "speech_cap": 1, "lod_near": 650.0, "lod_far": 1600.0, "particles": 0.25},
}
const PATH := "user://hospedeiro_visual.cfg"

var preset := "padrao"
var reduced_motion := false  # slower, smaller, no shake or pulses
var reduce_flash := false  # no sudden brightening; alerts fade in softly
var vibration := false  # optional haptics on touch devices
var sound := true  # short synthesised tones; never the only carrier of a message
var text_scale := 1.0  # 1.0, 1.25 or 1.5 for the living-body panels


static func load_from(path: String = PATH) -> BioVisualPrefs:
	var p := BioVisualPrefs.new()
	if BioPlatform.is_touch():
		p.preset = "economico"
	var cfg := ConfigFile.new()
	if path != "" and cfg.load(path) == OK:
		var saved := str(cfg.get_value("visual", "preset", p.preset))
		p.preset = saved if PRESETS.has(saved) else p.preset
		p.reduced_motion = bool(cfg.get_value("visual", "reduced_motion", false))
		p.reduce_flash = bool(cfg.get_value("visual", "reduce_flash", false))
		p.vibration = bool(cfg.get_value("visual", "vibration", false))
		p.sound = bool(cfg.get_value("visual", "sound", true))
		p.text_scale = clampf(float(cfg.get_value("visual", "text_scale", 1.0)), 1.0, 1.5)
	return p


func save(path: String = PATH) -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("visual", "preset", preset)
	cfg.set_value("visual", "reduced_motion", reduced_motion)
	cfg.set_value("visual", "reduce_flash", reduce_flash)
	cfg.set_value("visual", "vibration", vibration)
	cfg.set_value("visual", "sound", sound)
	cfg.set_value("visual", "text_scale", text_scale)
	cfg.save(path)


## How many cells of the cohorts are drawn at work at most, and how many of one cohort.
func crowd_cap() -> int:
	return int(get_number("crowd_cap"))


func crowd_per_cohort() -> int:
	return int(get_number("crowd_per_cohort"))


func get_number(key: String) -> float:
	return float((PRESETS[preset] as Dictionary).get(key, 1.0))


## Effects scaled by the preset and the accessibility switches (0 turns them off).
func fx_scale() -> float:
	return get_number("fx") * (0.4 if reduced_motion else 1.0)


func motion_scale() -> float:
	return 0.35 if reduced_motion else 1.0


func shake_allowed() -> bool:
	return not reduced_motion and not reduce_flash


func cycle_preset() -> String:
	var keys := PRESETS.keys()
	preset = keys[(keys.find(preset) + 1) % keys.size()]
	return preset


func cycle_text_scale() -> float:
	text_scale = 1.25 if text_scale < 1.1 else (1.5 if text_scale < 1.4 else 1.0)
	return text_scale
