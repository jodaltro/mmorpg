class_name BioRewardUi
extends RefCounted
## Plain language for structured, server-confirmed reward definitions.
const NUMBER_NAMES := {"pressao":"Progresso para a próxima mutação", "maturidade":"Maturidade da célula"}

static func explanation(reward: Dictionary) -> String:
	var id := StringName(str(reward.get("id", "")).replace("-", "_"))
	match str(reward.get("kind", "")):
		"gene":
			if BioGeneCatalog.all_ids().has(id):
				var gene := BioGeneCatalog.get_gene(id)
				if not gene.transformation.is_empty(): return str(gene.transformation.description)
				return gene.summary()
		"skill":
			var key := BioAbilityCatalog.normalise(str(reward.get("id", "")))
			if BioAbilityCatalog.has(key): return str(BioLore.ability_info(key).get("what", reward.get("desc", "")))
		"number":
			var key := str(reward.get("id", ""))
			var hint := str(reward.get("desc", ""))
			return "%s · %+d%s" % [NUMBER_NAMES.get(key, str(reward.get("name", key))), int(reward.get("amount", 0)), "\n" + hint if not hint.is_empty() else ""]
	return str(reward.get("desc", ""))

static func card(reward: Dictionary, choose: Callable = Callable()) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioUi.LINE_STRONG, 9, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var kind := str(reward.get("kind", ""))
	var prefix := "JÁ CONQUISTADO" if reward.get("owned", false) else "GENE PERMANENTE" if kind == "gene" else "NOVA HABILIDADE" if kind == "skill" and BioAbilityCatalog.has(BioAbilityCatalog.normalise(str(reward.get("id", "")))) else "CONQUISTA PERMANENTE"
	var rarity := str(reward.get("rarity", ""))
	box.add_child(BioUi.label(prefix + (" · " + rarity if not rarity.is_empty() else ""), 10, BioUi.ACCENT))
	box.add_child(BioUi.wrapped(str(reward.get("name", "Recompensa")), 14, BioUi.GOOD))
	box.add_child(BioUi.wrapped(explanation(reward), 12, BioUi.TEXT))
	if kind == "gene":
		box.add_child(BioUi.wrapped("Fica na biblioteca. Ative em Corpo → Genes para usar esse efeito." if not reward.get("owned", false) else "Você já possui este gene.", 10, BioUi.MUTED))
		var id := StringName(str(reward.get("id", "")).replace("-", "_"))
		if BioGeneCatalog.all_ids().has(id):
			var details := BioUi.wrapped(BioGeneCatalog.get_gene(id).summary(), 11, BioUi.MUTED)
			details.visible = false
			var inspect := BioUi.button("Ver atributos e custos")
			inspect.pressed.connect(func() -> void:
				details.visible = not details.visible
				inspect.text = "Ocultar detalhes" if details.visible else "Ver atributos e custos")
			box.add_child(inspect)
			box.add_child(details)
	if reward.get("conditional", false): box.add_child(BioUi.wrapped("Depende do requisito da recompensa.", 10, BioUi.WARN))
	if choose.is_valid() and not reward.get("owned", false):
		var button := BioUi.button("Escolher este prêmio", "primary")
		button.pressed.connect(choose)
		box.add_child(button)
	return panel

static func add_rewards(parent: VBoxContainer, rewards: Array, fallback := "") -> void:
	if rewards.is_empty():
		if not fallback.is_empty(): parent.add_child(BioUi.wrapped(fallback, 12, BioUi.MUTED))
		return
	for reward in rewards:
		if str(reward.get("kind", "")) != "number": parent.add_child(card(reward))
	for reward in rewards:
		if str(reward.get("kind", "")) == "number": parent.add_child(BioUi.wrapped(explanation(reward), 11, BioUi.MUTED))

static func summary(rewards: Array, fallback := "") -> String:
	if rewards.is_empty(): return fallback
	var lines: Array[String] = []
	for reward in rewards:
		if str(reward.get("kind", "")) == "number": continue
		lines.append(str(reward.get("name", "")) + ": " + explanation(reward))
		if reward.get("kind", "") == "gene": lines.append("Gene permanente · ative em Corpo → Genes.")
	for reward in rewards:
		if str(reward.get("kind", "")) == "number": lines.append(explanation(reward))
	return "\n".join(lines)
