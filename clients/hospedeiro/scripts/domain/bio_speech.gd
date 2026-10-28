class_name BioSpeech
extends RefCounted
## What the cells say about their work, in short first-person lines that appear in small balloons above them while they work. Presentation
## only: they are flavour about what the engine already says they are doing, never information the player needs, and they never name a
## number of the body. A cell does not repeat the line it just said.

const TASKS := {
	"selar-ferida": ["Fechando a brecha!", "Plaquetas, juntas!", "Mais fibrina aqui!"],
	"circular-plaquetas": ["Tudo calmo nas paredes.", "De olho na parede."],
	"reciclar-no-baco": ["Hemácia velha, para dentro.", "Reciclando o ferro.", "Esta já deu o que tinha."],
	"rondar-baco": ["Contando hemácias.", "Nada fora do lugar."],
	"limpar-toxinas": ["Toxina capturada!", "O fígado agradece.", "Mais uma fora."],
	"rondar-sinusoides": ["Ronda nos sinusoides.", "Sem intrusos por aqui."],
	"apresentar-antigenos": ["Levo um antígeno ao baço.", "Preciso mostrar isto!"],
	"patrulhar-sangue": ["Rolando atrás de resíduos.", "Sangue limpo por aqui."],
	"transportar-oxigenio": ["Oxigênio a caminho!", "Carga cheia, vou ao coração."],
	"defender-pulmao": ["Invasor à vista!", "Daqui não passa!", "Ataque!"],
	"vigiar-pulmao": ["Alvéolos em ordem.", "De olho nos alvéolos."],
	"colher-sinais": ["Colhendo sinais.", "Quanta citocina..."],
	"limpar-alveolos": ["Engolindo bactérias.", "Limpando os alvéolos."],
	"nutrir-nicho-medular": ["Alimentando as células-tronco.", "Matriz firme, nicho cheio."],
	"rondar-nicho": ["Conferindo a saída.", "Tudo certo no nicho."],
	"filtrar-ureia-renal": ["Filtrando a ureia.", "Glomérulo a todo vapor."],
	"rondar-nefron": ["Conferindo o túbulo."],
	"nutrir-flora": ["Alimentando a flora.", "As bactérias boas agradecem."],
	"absorver-alimento": ["Absorvendo nutrientes.", "Mais glicose para o sangue."],
	"apresentar-no-linfonodo": ["Apresentando o antígeno.", "Linfócitos, atenção!"],
	"rondar-linfonodo": ["Colhendo na polpa."],
	"acalmar-reacao": ["Calma, calma...", "Soltando sinais calmantes."],
	"vigiar-tolerancia": ["Tolerância sob vigia."],
	"limpar-residuos-cerebrais": ["Recolhendo resíduos.", "Neurônios limpos."],
	"amparar-neuronios": ["Passando lactato.", "Energia para os neurônios."],
	"eliminar-tumor": ["Célula alterada!", "Reconheci você.", "Eliminando."],
	"patrulhar-tecidos": ["Inspecionando as células."],
}
const HELP := ["Preciso de ajuda aqui!", "Alguém me dá uma mão?", "Isto é demais para mim!"]
const DONE := ["Pronto!", "Feito.", "Missão cumprida."]
const FALLBACK := ["Trabalhando.", "Seguindo a rotina."]
const CROWD := {
	"defesa": ["Ataque!", "Invasor!", "Cerquem!"], "limpeza": ["Nham!", "Limpando."], "vigilancia": ["Alvo marcado."], "reparo": ["Selando."],
	"amparo": ["Cuidando dos neurônios."], "reciclagem": ["Reciclando."], "depuracao": ["Filtrando."], "filtracao": ["Filtrando."],
	"simbiose": ["Em paz com o corpo."], "transporte": ["Oxigênio!"], "memoria": ["Lembro deste."], "suporte": ["Segurando a parede."],
}


## A line for a cell at work. `salt` varies the choice from one cell and moment to another; `last` is what it said before.
static func line(task: String, phase: String, salt: int, last: String = "") -> String:
	var pool: Array = FALLBACK
	if phase == "help":
		pool = HELP
	elif phase == "confirmed":
		pool = DONE
	elif TASKS.has(task):
		pool = TASKS[task]
	return _pick(pool, salt, last)


static func crowd_line(role: String, salt: int, last: String = "") -> String:
	return _pick(CROWD.get(role, FALLBACK), salt, last)


static func _pick(pool: Array, salt: int, last: String) -> String:
	if pool.size() == 1:
		return str(pool[0])
	var i := absi(salt) % pool.size()
	if str(pool[i]) == last:
		i = (i + 1) % pool.size()
	return str(pool[i])


## Seconds until the next line: a cell that is busy does not chatter.
static func gap(salt: int) -> float:
	return 7.0 + float(absi(salt) % 70) / 10.0
