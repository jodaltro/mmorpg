class_name BioConflictFocus
extends RefCounted
## Which crisis the player follows, what to say about it and what is worth doing. Following a crisis changes only the player's
## attention, never the crisis. Texts are presentation: the numbers and the phase come from the engine.

const PHASE_NAME := {"critical": "CRÍTICO", "active": "ATIVO", "contained": "CONTIDO", "recovering": "RECUPERANDO", "resolved": "RESOLVIDO"}
## A glyph per phase, so the phase never depends on colour alone.
const PHASE_GLYPH := {"critical": "▲▲", "active": "▲", "contained": "■", "recovering": "↗", "resolved": "✓"}
const PHASE_COLOR := {"critical": Color(1.0, 0.36, 0.42), "active": Color(1.0, 0.74, 0.32), "contained": Color(0.45, 0.8, 1.0),
	"recovering": Color(0.5, 1.0, 0.75), "resolved": Color(0.62, 0.73, 0.86)}
const FILTERS := ["todos", "ativo", "crítico", "contido", "recuperando"]
const FILTER_PHASE := {"ativo": "active", "crítico": "critical", "contido": "contained", "recuperando": "recovering"}

const ORGAN := {"ferida-na-pele": "Pele", "congestao-esplenica": "Baço", "sobrecarga-hepatica": "Fígado", "disbiose-intestinal": "Intestino",
	"infeccao-pulmonar": "Pulmão", "medula-esgotada": "Medula", "sobrecarga-renal": "Rim", "reacao-exagerada": "Linfonodo", "sofrimento-cerebral": "Cérebro", "tumor-intestinal": "Intestino"}
const EFFECT := {
	"ferida-na-pele": "Sem o tampão, invasores entram no sangue.",
	"congestao-esplenica": "O ferro não volta à medula e o corpo inflama.",
	"sobrecarga-hepatica": "A toxina sobe, os rins acumulam ureia e o corpo inflama.",
	"disbiose-intestinal": "Sem microbiota, o intestino inflama o corpo.",
	"infeccao-pulmonar": "O oxigênio cai, a febre sobe e as citocinas chegam ao sangue.",
	"medula-esgotada": "Sem reserva não nascem hemácias novas: o oxigênio cai e o corpo inflama.",
	"sobrecarga-renal": "A ureia passa do que os néfrons filtram: a pressão na artéria sobe e o corpo inflama.",
	"reacao-exagerada": "A tolerância do linfonodo se esgotou: a defesa ataca demais e a inflamação se alimenta.",
	"sofrimento-cerebral": "Sem energia e com resíduos, os neurônios sofrem; a glia precisa amparar e limpar.",
	"tumor-intestinal": "Células alteradas se multiplicam e ocupam o intestino; a massa cresce com a inflamação.",
}
## What the player does, in one line: where to go and the gesture that counts. The gesture is always the same family: beat the
## invaders of that organ (or touch the glowing things that drift in it). Presentation only; the engine decides what counts.
const NEXT := {
	"ferida-na-pele": "Vá à Pele e derrote os invasores que tentam entrar.",
	"congestao-esplenica": "Vá ao Baço e toque nas hemácias velhas; derrote os invasores de lá.",
	"sobrecarga-hepatica": "Vá ao Fígado e toque nas toxinas para filtrá-las.",
	"disbiose-intestinal": "Vá ao Intestino e toque nas bactérias boas para nutrir a flora.",
	"infeccao-pulmonar": "Vá ao Pulmão e derrote os invasores dos alvéolos.",
	"medula-esgotada": "Fique na Medula e absorva nutrientes para nutrir o nicho.",
	"sobrecarga-renal": "Vá ao Rim e toque nos cristais de ureia para filtrá-los.",
	"reacao-exagerada": "Vá ao Linfonodo e derrote os invasores de lá para acalmar a reação.",
	"sofrimento-cerebral": "Vá ao Cérebro e derrote os invasores para amparar os neurônios.",
	"tumor-intestinal": "Vá ao Intestino e derrote os invasores para ajudar Nika contra o tumor.",
}
const NEXT_BY_PHASE := {"contained": "Mantenha o apoio até o tecido se estabilizar.", "recovering": "Falta pouco: deixe as células terminarem o reparo."}


## The crisis to show first. The player's choice wins while that crisis lives; otherwise the engine's suggestion; otherwise the worst.
static func pick(ordered: Array, engine_focus: String, chosen: String) -> String:
	for c in ordered:
		if str(c.get("id", "")) == chosen:
			return chosen
	for c in ordered:
		if str(c.get("id", "")) == engine_focus:
			return engine_focus
	return str(ordered[0].get("id", "")) if not ordered.is_empty() else ""


## Up to `count` summaries besides the followed crisis, worst first; the panel still lists all the others.
static func secondaries(ordered: Array, focus: String, count: int = 2) -> Array:
	var out: Array = []
	for c in ordered:
		if str(c.get("id", "")) != focus and out.size() < count:
			out.append(c)
	return out


static func filtered(ordered: Array, recent: Array, filter: String) -> Array:
	var out: Array = []
	if filter == "todos":
		out.append_array(ordered)
		out.append_array(recent)
		return out
	var phase: String = FILTER_PHASE.get(filter, "")
	for c in ordered:
		if str(c.get("phase", "")) == phase:
			out.append(c)
	return out


## The next filter in the cycle (the filter button on a small screen).
static func next_filter(filter: String) -> String:
	var i := FILTERS.find(filter)
	return FILTERS[(i + 1) % FILTERS.size()]


## True when the cell is already where the crisis is.
static func here(c: Dictionary, player_region: String) -> bool:
	return str(c.get("region", "")) == player_region


## Whether this crisis asks for attention now (active or critical). A calm one needs nothing from the player.
static func demanding(c: Dictionary) -> bool:
	var p := str(c.get("phase", ""))
	return p == "active" or p == "critical"


static func organ(c: Dictionary) -> String:
	return str(ORGAN.get(str(c.get("def", "")), str(c.get("region", "")).capitalize()))


static func effect(c: Dictionary) -> String:
	return str(EFFECT.get(str(c.get("def", "")), str(c.get("desc", ""))))


## One suggestion, tied to the phase: never an instruction the engine would refuse.
static func suggestion(c: Dictionary) -> String:
	var phase := str(c.get("phase", ""))
	if NEXT_BY_PHASE.has(phase):
		return str(NEXT_BY_PHASE[phase])
	if phase == "resolved":
		return "Resolvido. Pode voltar se a causa reaparecer."
	return str(NEXT.get(str(c.get("def", "")), "Ajude as células que trabalham aqui."))


## The metric that matters most: the first one the universe lists (its label and value come from the engine).
static func headline(c: Dictionary) -> String:
	var ms: Variant = c.get("metrics")
	if ms is Array and not (ms as Array).is_empty():
		var m: Dictionary = ms[0]
		return "%s: %d" % [str(m.get("label", "")), int(m.get("value", 0))]
	return ""


static func phase_label(c: Dictionary) -> String:
	var p := str(c.get("phase", ""))
	return "%s %s" % [PHASE_GLYPH.get(p, ""), PHASE_NAME.get(p, p)]


static func alert_text(a: Dictionary) -> String:
	var title := str(a.get("title", ""))
	match str(a.get("kind", "")):
		"start":
			return "%s\numa crise começou" % title
		"escalate":
			return "%s\na crise se agravou" % title
		"contain":
			return "%s\ncontida: mantenha o apoio" % title
		"recover":
			return "%s\nrecuperando" % title
		"resolve":
			return "%s\nresolvida" % title
		"reopen":
			return "%s\nvoltou a ficar ativa" % title
		"relapse":
			return "%s\npiorou outra vez" % title
	return title
