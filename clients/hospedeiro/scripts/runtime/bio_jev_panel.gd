class_name BioJevPanel
extends CanvasLayer
## What Jev is doing, on screen: a small badge that is always there (who has decided what so far) and a panel (F2) with the decisions
## waiting for an answer, the last decisions with who answered (Jev or the deadline's default), how long it took and what it cost,
## and every trait of the current design with where it came from. It reads the engine's `advisor` view and the world's design.

var rows: Array = []  # recent decisions, newest first
var pending: Array = []
var online := false

var _world: Node
var _badge: Label
var _panel: ColorRect
var _text: RichTextLabel


func configure(world: Node) -> void:
	_world = world
	layer = 13  # under the Body window
	_badge = Label.new()
	_badge.position = Vector2(28, 104)
	_badge.size = Vector2(620, 18)
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.modulate.a = 0.6
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_panel = ColorRect.new()
	_panel.color = Color(0.0, 0.01, 0.03, 0.97)
	_panel.position = Vector2(40, 152)
	_panel.size = Vector2(780, 700)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.position = Vector2(14, 10)
	_text.size = Vector2(752, 680)
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("bold_font_size", 13)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)
	refresh()


func is_open() -> bool:
	return _panel.visible


## The keys that open the details and the test menu are for the developer.
func _hint() -> String:
	return "  ·  F2 detalhes  ·  Esc menu" if BioPlatform.debug_enabled() and not BioPlatform.is_touch() else ""


func toggle() -> void:
	_panel.visible = not _panel.visible
	refresh()


func text() -> String:
	return _text.get_parsed_text() + "\n" + _badge.text


func badge_text() -> String:
	return _badge.text


func set_online(on: bool) -> void:
	online = on
	refresh()


## Takes the `advisor` of an engine view.
func set_data(advisor: Dictionary) -> void:
	rows = advisor.get("recent", [])
	pending = advisor.get("pending", [])
	refresh()


## How many decisions were taken by each kind of provider, the mean latency of Jev's and the total cost.
func totals() -> Dictionary:
	var out := {"jev": 0, "default": 0, "other": 0, "latency_ms": 0.0, "cost": 0.0}
	var timed := 0
	for r in rows:
		match str(r.get("provider", "")):
			"jev":
				out["jev"] += 1
				if int(r.get("latencyMs", 0)) > 0:
					out["latency_ms"] += float(r["latencyMs"])
					timed += 1
				out["cost"] += float(r.get("cost", 0.0))
			"default":
				out["default"] += 1
			_:
				out["other"] += 1
	out["latency_ms"] = out["latency_ms"] / timed if timed > 0 else 0.0
	return out


## Who decided a trait of the design: "jev", "padrão" (the deadline), "debug" or "?" when nothing was recorded.
func source_of(trait_id: String) -> String:
	if _world != null and _world.design_source == "debug":
		return "debug"
	for r in rows:
		if str(r.get("kind", "")) == "design" and str(r.get("detail", "")) == trait_id:
			return "jev" if str(r.get("provider", "")) == "jev" else "padrão"
	return "?"


func refresh() -> void:
	if _badge == null:
		return
	var t := totals()
	if not online:
		_badge.text = "JEV: sem motor (offline): nada é decidido pelo Jev" + _hint()
		_badge.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4, 0.9))
	else:
		var total: int = int(t["jev"]) + int(t["default"]) + int(t["other"])
		_badge.text = "JEV: %d decisões · %d pelo Jev · %d pelo padrão%s  ·  %d à espera%s" % [total, t["jev"], t["default"], (" · %.0f ms" % t["latency_ms"]) if int(t["jev"]) > 0 else "", pending.size(), _hint()]
		_badge.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75, 0.9) if int(t["jev"]) > 0 else Color(1.0, 0.85, 0.5, 0.9))
	if not _panel.visible:
		return
	var lines: Array[String] = []
	lines.append("[b]JEV · O QUE ESTÁ DECIDINDO[/b]   (F2 fecha)")
	if not online:
		lines.append("[color=#ffb060]Sem motor: nenhuma decisão é pedida ao Jev. O design, as mutações e a classe vêm do padrão local.[/color]")
	else:
		lines.append("decisões registradas: [color=#80ffc0]%d pelo Jev[/color] · [color=#ffb060]%d pelo padrão (prazo)[/color] · latência média do Jev %.0f ms · custo US$ %.5f" % [t["jev"], t["default"], t["latency_ms"], t["cost"]])
	lines.append("")
	lines.append("[b]À ESPERA DE RESPOSTA[/b]  (%d)" % pending.size())
	for p in pending.slice(0, 10):
		lines.append("  %s  ·  %d opções  ·  padrão: %s  ·  em %d ticks" % [_label(p), int(p.get("options", 0)), str(p.get("default", "")), int(p.get("dueIn", 0))])
	if pending.is_empty():
		lines.append("  nada à espera")
	lines.append("")
	lines.append("[b]ÚLTIMAS DECISÕES[/b]")
	for r in rows.slice(0, 15):
		var provider := str(r.get("provider", ""))
		var who := "JEV   " if provider == "jev" else ("padrão" if provider == "default" else provider)
		var color := "#80ffc0" if provider == "jev" else ("#ffb060" if provider == "default" else "#a0b0ff")
		var diff := "" if str(r.get("choice", "")) == str(r.get("default", "")) else "  [color=#ffee80](diferente do padrão: %s)[/color]" % str(r.get("default", ""))
		lines.append("  t%d  [color=%s]%s[/color]  %s → [b]%s[/b]%s%s" % [int(r.get("tick", 0)), color, who, _label(r), str(r.get("choice", "")), ("  %d ms" % int(r["latencyMs"])) if int(r.get("latencyMs", 0)) > 0 else "", diff])
	if rows.is_empty():
		lines.append("  nenhuma ainda")
	lines.append("")
	lines.append("[b]DESIGN ATUAL DA CÉLULA[/b]   (origem: %s)" % (_world.design_source if _world != null else "?"))
	var traits: Dictionary = _world.design_traits if _world != null else {}
	if traits.is_empty():
		lines.append("  sem design ainda (o motor pede após cerca de 6 atos)")
	var cells: Array[String] = []
	for k in traits:
		var src := source_of(str(k))
		var color2 := "#80ffc0" if src == "jev" else ("#ffee80" if src == "debug" else "#ffb060")
		cells.append("%s=[b]%s[/b] [color=%s]%s[/color]" % [str(k), str(traits[k]), color2, src])
	for i in range(0, cells.size(), 3):
		lines.append("  " + "    ".join(cells.slice(i, i + 3)))
	_text.text = "\n".join(lines)


func _label(r: Dictionary) -> String:
	var detail := str(r.get("detail", ""))
	return "%s%s" % [str(r.get("kind", "")), ("/" + detail) if detail != "" else ""]
