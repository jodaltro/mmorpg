class_name BioBodyState
extends RefCounted
## The vital signs of the host as the engine reports them (temperature, pulse, oxygen, glucose, inflammation and three hormones),
## and what they do to a cell living in it. Pure: it only turns numbers into modifiers and short explanations, so the same body
## always weighs the same on every cell and it can be tested without a scene.

const FEVER_FROM := 380  # tenths of a degree
const HYPOXIA_BELOW := 60

var readings: Dictionary = {}  # id -> {label, value, min, max, low, high}
var order: Array[String] = []


## Takes the `vitals` list of an engine view.
func apply(vitals: Array) -> void:
	order.clear()
	for v in vitals:
		var id := str(v.get("id", ""))
		readings[id] = v
		order.append(id)


func value(id: String, fallback: float = 0.0) -> float:
	return float(readings[id].get("value", fallback)) if readings.has(id) else fallback


func has_data() -> bool:
	return not readings.is_empty()


func temperature_c() -> float:
	return value("temperatura", 370.0) / 10.0


func has_fever() -> bool:
	return value("temperatura", 370.0) >= FEVER_FROM


func has_hypoxia() -> bool:
	return value("oxigenio", 100.0) < HYPOXIA_BELOW


## Adrenaline makes every cell quicker (up to +18%); the fever and a heart racing add a little to the hurry.
func speed_multiplier() -> float:
	return 1.0 + 0.18 * clampf(value("adrenalina") / 100.0, 0.0, 1.0)


## Fever tires the cell and a lung short of air starves it of energy.
func atp_regen_multiplier() -> float:
	var m := 1.0
	if has_fever():
		m *= 0.85
	if has_hypoxia():
		m *= 0.6 + 0.4 * clampf((value("oxigenio") - 40.0) / float(HYPOXIA_BELOW - 40), 0.0, 1.0)
	return m


## Insulin makes nutrients worth more (up to +25%).
func nutrient_multiplier() -> float:
	return 1.0 + 0.25 * clampf(value("insulina") / 100.0, 0.0, 1.0)


## Is this vital outside its healthy range.
func is_off(id: String) -> bool:
	if not readings.has(id):
		return false
	var r: Dictionary = readings[id]
	var low := float(r.get("low", 0))
	var high := float(r.get("high", 0))
	if low == 0.0 and high == 0.0:
		return false
	var v := float(r.get("value", 0))
	return v < low or v > high


func display(id: String) -> String:
	if not readings.has(id):
		return ""
	var v := value(id)
	match id:
		"temperatura":
			return "%.1f °C" % (v / 10.0)
		"pulso":
			return "%d bpm" % int(v)
		"oxigenio", "glicose":
			return "%d%%" % int(v)
		_:
			return str(int(v))


## What is going on in the body, in a few words: the chain from cause to effect, for the player to read.
func explain() -> Array[String]:
	var lines: Array[String] = []
	var inflammation := value("inflamacao")
	if has_fever():
		lines.append("FEBRE: o corpo esquenta para conter a infecção. Você gasta mais energia; os vírions ficam lentos.")
	elif inflammation >= 30.0:
		lines.append("INFLAMAÇÃO: há uma infecção; as citocinas sobem no sangue e a febre vem em seguida.")
	if has_hypoxia():
		lines.append("HIPÓXIA: o pulmão inflamado deixa passar pouco ar; a regeneração de ATP cai.")
	if value("adrenalina") >= 30.0:
		lines.append("ADRENALINA: o corpo em alerta; você se move mais depressa e o coração dispara.")
	if value("cortisol") >= 50.0:
		lines.append("CORTISOL alto: o estresse suprime as defesas.")
	if value("insulina") >= 40.0:
		lines.append("INSULINA alta: houve refeição; os nutrientes rendem mais.")
	if lines.is_empty():
		lines.append("O corpo está em equilíbrio.")
	return lines
