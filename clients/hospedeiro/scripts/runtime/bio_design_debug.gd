class_name BioDesignDebug
extends CanvasLayer
## Debug overlay for the design Jev made (F3): where the design came from, every trait, the feel of the effects, how many particle
## effects were really emitted with which style, and the last design change. F4 cycles the effect style by hand (so each flavour can
## be seen without waiting for the engine), F5 tries a random full design, F6 returns to what the engine said.

var _label: Label
var _panel: ColorRect
var _world: Node


func configure(world: Node) -> void:
	_world = world
	layer = 20
	_panel = ColorRect.new()
	_panel.color = Color(0.0, 0.01, 0.03, 0.82)
	_panel.position = Vector2(40, 130)
	_panel.size = Vector2(520, 380)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.size = Vector2(492, 360)
	_label.add_theme_font_size_override("font_size", 13)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _process(_delta: float) -> void:
	if _panel.visible:
		refresh()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	refresh()


func text() -> String:
	return _label.text


## Redraws the text from the world's current design.
func refresh() -> void:
	if _world == null or not _panel.visible:
		return
	var traits: Dictionary = _world.design_traits
	var lines: Array[String] = []
	lines.append("DESIGN DO JEV  ·  F3 fecha  ·  F4 estilo  ·  F5 sorteio  ·  F6 motor
F7 impacto  ·  F8 trajetória  ·  F9 calibre do projétil")
	lines.append("origem: %s   ·   motor: %s" % [_world.design_source, "online" if _world.sync != null and _world.sync.link.online else "offline"])
	lines.append("recebido há %s" % ("—" if _world.design_changed_at < 0.0 else "%.0f s" % (Time.get_ticks_msec() * 0.001 - _world.design_changed_at)))
	lines.append("")
	if traits.is_empty():
		lines.append("nenhum traço ainda (a célula é padrão).")
		lines.append("O motor desenha após ~6 atos; o jogo normal já funciona sem isso.")
	else:
		for key in traits:
			lines.append("  %-11s %s" % [key, traits[key]])
	lines.append("")
	lines.append("efeito das habilidades: %s" % (str(_world.abilities.effect_style) if _world.abilities.effect_style != &"" else "(nenhum)"))
	lines.append("efeito físico: %s" % BioEffectPhysics.describe(_world.abilities.effect_style))
	lines.append("projétil: %s" % BioProjectileDesign.describe(_world.design_traits))
	lines.append("comportamento das famílias: %s" % BioAbilityMode.describe(_world.player.combatant.modes))
	lines.append("foco das outras habilidades: %s" % BioAbilityFocus.describe(_world.design_traits))
	_label.text = "\n".join(lines)
