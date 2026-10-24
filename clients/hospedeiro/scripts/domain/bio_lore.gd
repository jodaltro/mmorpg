class_name BioLore
extends RefCounted
## What the Body window (G) tells the player about a class and about each of its abilities: what it is, what it does and how it works,
## in plain words. Pure text; a test holds it to the catalogues (every class and every ability has its entry).

const CLASSES := {
	&"mieloide": {"role": "Linhagem de força", "about": "A raiz dos que enfrentam de perto: células grandes, resistentes, que comem e batem. Daqui saem o Macrófago, o Neutrófilo, o Mastócito e o Eosinófilo.", "play": "Mais membrana e mais ganho de nutrientes. Ainda não tem habilidades de classe: escolha uma forma ao amadurecer."},
	&"linfoide": {"role": "Linhagem de precisão", "about": "A raiz dos que reconhecem e miram: células ágeis, que cospem, marcam e decidem. Daqui saem a Dendrítica, o Linfócito B, os dois T, a Célula NK e o T regulador.", "play": "Toxina mais forte e mais energia. Ainda não tem habilidades de classe: escolha uma forma ao amadurecer."},
	&"macrofago": {"role": "Tanque devorador", "about": "O Devorador. Grande, lento e quase impossível de derrubar: engole o que encontra e se cura com isso, faz cada golpe que recebe custar caro e muda de forma entre lutar e se curar.", "play": "Entre no meio e bata de perto: Engolir cura. Ligue o Contragolpe quando for cercado e alterne a Polarização: M1 para ferir, M2 para aguentar."},
	&"neutrofilo": {"role": "Armadilheiro veloz", "about": "O Armadilheiro. Rápido e frágil, chega primeiro: prepara redes, atravessa os corpos e, no auge, queima a própria membrana para correr o dobro.", "play": "Não fique parado. Prenda com a Rede, atravesse a multidão com a Diapedese e solte tudo seguido no Surto Oxidativo."},
	&"dendritica": {"role": "Cartógrafa", "about": "A Cartógrafa. Lê a sala: varre com um feixe, amadurece para que as próximas habilidades valham mais e abre portas no tecido.", "play": "Aponte à frente com a Varredura, use a Maturação antes das suas melhores habilidades e a Passagem Linfática para escapar ou cruzar a sala."},
	&"linfocito_b": {"role": "Atirador de anticorpos", "about": "O Anticorpomante. Atira de longe, marca com complemento para o terceiro golpe estourar, repete o que acabou de fazer e vira uma fábrica de anticorpos.", "play": "Mantenha distância. Marque com o Complemento e bata três vezes; use a Memória logo depois da sua melhor habilidade e a Fábrica quando tiver espaço para ficar parado."},
	&"t_citotoxico": {"role": "Executor", "about": "O Executor. Corpo a corpo cirúrgico: perfura, salta por cima da multidão, segura um inimigo até o fim e sentencia os quase mortos.", "play": "Fira, espere o inimigo cair e termine. Salte para dentro da luta, segure o mais perigoso com a Sinapse e use a Lise em Massa depois de uma sequência de abates."},
	&"t_auxiliar": {"role": "Maestro de apoio", "about": "O Maestro das Citocinas. Dá uma febre que pula de inimigo em inimigo, chama auxiliares que lutam por ele, ganha uma segunda chance e troca o que sobra pelo que falta.", "play": "Espalhe a Febre onde há grupo, chame os Auxiliares e deixe a Segunda Chance ativa nas lutas arriscadas. A Transfusão acerta a conta entre vida e energia."},
	&"mastocito": {"role": "Bombardeiro", "about": "O Alarmista. Uma bolsa de grânulos prestes a estourar: poucos pontos de vida, muito poder de habilidade. Tudo nele é explosão: minas, bombas coladas, mortes que explodem.", "play": "Ande para semear minas, cole bombas nos grandes e ligue a Cascata antes de matar um grupo. A Anafilaxia é a aposta: quanto mais membrana você gasta, maior o estouro."},
	&"eosinofilo": {"role": "Caça-colossos", "about": "O Caça-Colossos. Resistente e lento, vive de inimigos grandes: corrói pela vida deles, congela monstros em cristal e cresce a cada morte.", "play": "Prenda o maior com a Adesão, congele-o no Cristal e bata para guardar dano. Quando a luta estiver quente, Hipertrofia e Rolagem."},
	&"celula_nk": {"role": "Assassina", "about": "O Assassino Natural. Veloz e frágil, ataca o que não reconhece sem pedir licença: surge atrás da presa, some da vista, volta no tempo.", "play": "Escolha uma presa com Predar e ataque-a: cada golpe devolve recargas. Camuflagem para a emboscada, Âncora para sair do aperto."},
	&"t_regulador": {"role": "Controlador", "about": "O Pacificador. Não bate de frente: arruma a luta. Faz inimigos dormirem, une-os pela dor, lança um isco e puxa a sala para um ponto.", "play": "Junte os inimigos (isco, singularidade), ligue-os com a Sinapse e então bata em um só. Anergia tira o mais perigoso da luta."},
}

const ABILITIES := {
	# Macrófago
	&"engolir": {"what": "Três braços fecham à frente e ferem tudo no cone.", "how": "Cada ponto de dano que acerta cura você em parte. Quanto mais inimigos no cone, mais cura."},
	&"onda_de_pseudopodes": {"what": "Uma onda ao redor do corpo fere e empurra todos.", "how": "Não precisa mirar. Útil para se livrar de quem cercou você."},
	# Neutrófilo
	&"rede_de_dna": {"what": "Uma rede lançada à frente retarda e fere quem fica nela.", "how": "Aponte para onde os inimigos vão passar."},
	&"explosao_neutrofilica": {"what": "Investida que fere tudo o que atravessa.", "how": "Invulnerável durante a investida: serve para entrar e para escapar."},
	# Dendrítica
	&"dendritos_em_chicote": {"what": "Um leque de chicotes finos fere à frente.", "how": "Alcance médio, boa para limpar vários pequenos."},
	# Linfócito B
	&"anticorpo_y": {"what": "Um anticorpo que persegue o inimigo.", "how": "Atira na direção do mouse e curva até o alvo mais próximo. Barato e rápido."},
	# T citotóxico
	&"perforina": {"what": "Uma lança que perfura a linha de inimigos.", "how": "Quem já está com pouca vida leva o dobro: a execução do T."},
	# T auxiliar
	&"contragolpe": {"what": "A membrana endurece por um instante: quem bate nela paga.", "how": "Durante a postura você recebe só uma parte de cada golpe, quem bateu leva de volta quase o golpe inteiro e fica atordoado por meio segundo, e você se cura com o que aguentou. Use quando for cercado, não antes."},
	&"polarizacao": {"what": "Muda a forma do macrófago.", "how": "Cada vez que aperta, a forma muda: M1 (vermelha) bate mais forte e queima o que fere, mas você recebe mais dano; M2 (verde) bate mais fraco, recebe menos dano e se cura sozinho; a terceira vez volta ao normal. Dura vários segundos."},
	&"diapedese": {"what": "O neutrófilo se afina e atravessa os corpos.", "how": "Por alguns segundos nenhum corpo o bloqueia (só as paredes), você corre mais, recebe metade do dano e fere cada inimigo que atravessa, uma vez. Serve para entrar, sair ou furar uma cerca de inimigos."},
	&"surto_oxidativo": {"what": "Tudo corre o dobro, inclusive as recargas.", "how": "Enquanto dura, as recargas de todas as habilidades andam mais rápido e você corre mais, mas a membrana queima aos poucos (nunca abaixo de um décimo). Chega a hora de soltar tudo em sequência."},
	&"varredura": {"what": "Um feixe que sai da célula e queima o que cruza.", "how": "Segue a mira, mas só vira devagar: aponte à frente do alvo. Fere em pulsos rápidos durante alguns segundos e você anda mais devagar enquanto segura."},
	&"maturacao": {"what": "As próximas habilidades saem reforçadas.", "how": "Dá algumas cargas (os pontos girando ao redor): cada habilidade que você usar gasta uma, não custa energia e bate mais forte por um instante. As cargas somem se o tempo passar. Use antes das suas melhores."},
	&"passagem_linfatica": {"what": "Abre duas portas no tecido.", "how": "Uma porta aparece onde você aponta e a outra sob você: quem entra numa sai na outra. Só você usa. Duram um tempo e uma nova passagem fecha a antiga. Boa para fugir ou cruzar a sala."},
	&"complemento": {"what": "Marca um inimigo: no terceiro golpe, ele estoura.", "how": "Qualquer golpe seu conta (chicote, toxina, habilidade); três círculos acima do inimigo mostram quantos faltam. No último, ele sofre um dano fixo mais uma fração da própria vida (com teto): um colosso perde muito mais."},
	&"memoria_imunologica": {"what": "Repete a última habilidade que você usou.", "how": "Sai de graça, sem recarga, e um pouco mais fraca. Depende do que você fez antes: sem nada para repetir, não gasta nada. Repete até as de alvo, procurando de novo o alvo mais próximo."},
	&"fabrica_de_plasmocito": {"what": "A célula vira uma fábrica parada de anticorpos.", "how": "Por alguns segundos você não se move, recebe menos dano e solta um anticorpo atrás do outro no inimigo mais próximo. Os anticorpos seguem o desenho que o Jev fez para você (trajetória, calibre, impacto)."},
	&"salto_letal": {"what": "Salta por cima de tudo e cai com um golpe.", "how": "Na direção do mouse: no ar nada o bloqueia nem o fere, e ao cair fere e empurra todos ao redor. Não atravessa paredes: para antes delas."},
	&"sinapse_letal": {"what": "Segura um inimigo à frente, apertando mais a cada instante.", "how": "O alvo mais perto da mira é arrastado para a sua frente e fica sem poder agir, enquanto o dano cresce a cada pulso. Se ele estiver quase morto no fim, é terminado. Você anda devagar enquanto segura, e o aperto solta se vocês se afastarem."},
	&"lise_em_massa": {"what": "Fere a sala toda e sentencia os quase mortos.", "how": "Todo inimigo por perto sofre um dano; os que ficarem abaixo de um limiar de vida morrem. O limiar sobe com cada morte sua nos últimos segundos: use depois de uma sequência de abates."},
	&"febre_contagiosa": {"what": "Dá febre a um inimigo, e ela passa para o vizinho.", "how": "O alvo queima por alguns segundos. Pouco depois, passa a febre ao inimigo mais próximo que ainda não a tem, que passa ao seguinte (algumas vezes). Quanto mais juntos, mais longe ela vai."},
	&"chamado_aos_auxiliares": {"what": "Chama duas células auxiliares.", "how": "Elas correm até o inimigo mais próximo e o mordem sem parar por um tempo; sem inimigos, ficam perto de você. Têm pouca vida e somem quando o tempo acaba."},
	&"segunda_chance": {"what": "O próximo golpe mortal não mata.", "how": "Por alguns segundos, o golpe que acabaria com a célula a deixa viva com parte da membrana de volta e uma breve invulnerabilidade. Vale uma vez; o anel dourado ao redor mostra que está ativa. Não protege de queimaduras."},
	&"transfusao": {"what": "Troca o que sobra pelo que falta.", "how": "Se você tem mais membrana do que energia, gasta membrana (nunca abaixo de um quarto) e recebe energia; se tem mais energia, gasta energia e recebe membrana. É instantânea."},
	# Mastócito
	&"granulos_latentes": {"what": "Por alguns segundos, a célula solta um grânulo a cada passo, formando uma trilha de minas.", "how": "Ande para espalhar: parado, não solta nada. Cada mina arma em meio segundo, explode quando um inimigo chega perto e faz as vizinhas explodirem. Há um limite de minas; as mais velhas somem primeiro."},
	&"histamina_instavel": {"what": "Atira um glóbulo que gruda no primeiro inimigo e explode depois de um pavio.", "how": "Atire de novo no mesmo alvo para empilhar: cada glóbulo a mais aumenta a explosão e prolonga o pavio. A explosão fere os vizinhos. Se o alvo morrer antes, ela explode na hora."},
	&"cascata_de_degranulacao": {"what": "Por alguns segundos, tudo o que você mata explode em grânulos.", "how": "Ligue antes de atacar um grupo: a explosão fere os vizinhos e, se matar, eles também explodem, em fila. Só vale para o que você mata, não para o que morre sozinho."},
	&"anafilaxia": {"what": "A célula sangra a própria membrana numa onda que cresce; ao soltar, tudo ao redor é ferido.", "how": "Aperte uma vez e segure a espera: a membrana vai sendo gasta (e você anda mais devagar). Aperte a mesma tecla de novo para soltar. Quanto mais gastou, maior e mais forte. Nunca mata: para sozinha no limite."},
	# Eosinófilo
	&"adesao": {"what": "Prende-se a um inimigo com uma corda de grânulos.", "how": "Enquanto a corda segura, o inimigo é puxado até você e perde, a cada segundo, uma fração da própria vida (com teto): um colosso perde muito mais que um miúdo. A corda se rompe se ele se afastar demais, morrer ou o tempo acabar."},
	&"cristal_de_charcot": {"what": "Prende o inimigo em cristal: ele não anda, não ataca e nada o fere.", "how": "Todo golpe que ele recebe fica guardado. Quando o cristal quebra, o dano guardado (e mais um pouco) explode no inimigo e em todos ao redor. Bata no cristal e posicione-se perto de outros inimigos."},
	&"hipertrofia": {"what": "Por um tempo, a célula cresce a cada morte.", "how": "Começa com um nível; cada morte soma outro (até cinco), e cada nível aumenta o seu dano, o tamanho do corpo e cura um pouco. Ao fim do tempo, volta ao normal."},
	&"rolagem": {"what": "A célula vira uma bola protegida que quica pela sala.", "how": "Voa na direção do mouse e quica nas paredes e nos inimigos, ferindo cada um que bate. Recebe menos dano enquanto rola. Mover o mouse e as teclas a guia um pouco."},
	# Célula NK
	&"passo_sem_identidade": {"what": "Surge atrás do alvo e o golpeia nas costas.", "how": "Escolhe o inimigo mais perto da mira e aparece do outro lado dele, com um instante de invulnerabilidade e dano muito maior. Sem inimigo ao alcance, é só um salto curto na direção do mouse."},
	&"predar": {"what": "Escolhe uma presa: atacá-la devolve recargas e energia.", "how": "Cada golpe seu na presa (qualquer habilidade) reduz o tempo de espera das outras e devolve energia. Matar a presa zera todas as recargas. Você também anda um pouco mais rápido enquanto caça."},
	&"camuflagem_de_mhc": {"what": "A célula some da vista dos inimigos.", "how": "Eles perdem o alvo e voltam a vagar. Você fica translúcida e mais rápida. O primeiro golpe que você der, de qualquer tipo, quebra a camuflagem e é uma emboscada: dano muito maior."},
	&"ancora_de_vigilancia": {"what": "Marca o lugar e a vida de agora; depois volta no tempo.", "how": "Fixa uma âncora (com a sua vida do momento). Após alguns segundos, ou apertando a tecla de novo, a célula é puxada de volta em linha reta, ferindo quem estiver no caminho, e recupera boa parte do que perdeu desde então."},
	# T regulador
	&"anergia": {"what": "Faz um inimigo dormir.", "how": "O alvo mais perto da mira para completamente. Acorda ao primeiro dano, e esse golpe bate mais forte. Inimigos muito grandes (vida alta) dormem bem menos tempo."},
	&"sinapse_imunologica": {"what": "Une até três inimigos pela dor.", "how": "Escolhe o alvo da mira e os mais próximos dele. Todo dano que um sofre, os outros sofrem em parte (sem ecoar de volta). Precisa de pelo menos dois inimigos por perto; se não, não gasta nada."},
	&"autoantigeno": {"what": "Lança um isco de si mesma.", "how": "Os inimigos próximos passam a atacar o isco e largam você, até ele cair (tem vida própria) ou o tempo acabar. Use para reunir os inimigos num ponto ou para respirar."},
	&"singularidade_de_tolerancia": {"what": "Abre um ponto que puxa todos os inimigos para o centro.", "how": "Lance à frente: eles são arrastados (não atravessam paredes) e ficam amontoados. Quando o ponto colapsa, quem estiver no centro leva o golpe. Funciona muito bem com bombas, minas e a Sinapse."},
}

const KIND_NAMES := {"counter": "contragolpe", "stance": "forma", "phase": "atravessa", "frenzy": "surto", "beam": "feixe", "empower": "reforço", "portal": "portal", "complement": "complemento", "replay": "memória", "turret": "fábrica", "leap": "salto", "hold": "aperto", "massacre": "sentença", "contagion": "contágio", "allies": "auxiliares", "lastchance": "segunda chance", "convert": "troca", "mines": "minas", "sticky": "bomba colada", "cascade": "reação em cadeia", "overload": "carga com a vida", "tether": "corda", "crystal": "cristal", "grow": "crescimento", "roll": "bola", "blink": "teleporte", "prey": "caça", "cloak": "camuflagem", "recall": "volta no tempo", "sleep": "sono", "link": "elo", "decoy": "isco", "pull": "singularidade"}


static func has_class(id: StringName) -> bool:
	return CLASSES.has(id)


static func class_info(id: StringName) -> Dictionary:
	return CLASSES.get(id, {})


static func has_ability(id: StringName) -> bool:
	return ABILITIES.has(id)


static func ability_info(id: StringName) -> Dictionary:
	return ABILITIES.get(id, {})
