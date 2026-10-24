class_name BioLore
extends RefCounted
## What the Body window (G) tells the player about a class and about each of its abilities: what it is, what it does and how it works,
## in plain words. Pure text; a test holds it to the catalogues (every class and every ability has its entry).

const CLASSES := {
	&"mieloide": {"role": "Linhagem de força", "about": "A raiz dos que enfrentam de perto: células grandes, resistentes, que comem e batem. Daqui saem o Macrófago, o Neutrófilo, o Mastócito e o Eosinófilo.", "play": "Mais membrana e mais ganho de nutrientes. Ainda não tem habilidades de classe: escolha uma forma ao amadurecer."},
	&"linfoide": {"role": "Linhagem de precisão", "about": "A raiz dos que reconhecem e miram: células ágeis, que cospem, marcam e decidem. Daqui saem a Dendrítica, o Linfócito B, os dois T, a Célula NK e o T regulador.", "play": "Toxina mais forte e mais energia. Ainda não tem habilidades de classe: escolha uma forma ao amadurecer."},
	&"macrofago": {"role": "Tanque devorador", "about": "O Devorador. Grande, lento e quase impossível de derrubar, engole o que encontra e se cura com isso.", "play": "Entre no meio e bata de perto: Engolir cura. Use a Muralha de Carne quando a luta apertar e o Lisossomo para segurar uma área."},
	&"neutrofilo": {"role": "Armadilheiro veloz", "about": "O Armadilheiro. Rápido e frágil, prepara o terreno antes da luta: redes, armadilhas e nuvens.", "play": "Não fique parado. Prenda, retarde e entre com a Explosão Neutrofílica para acabar com o que ficou preso."},
	&"dendritica": {"role": "Cartógrafa de apoio", "about": "A Cartógrafa. Fere pouco, mas faz todo o resto ferir mais: apresenta o inimigo ao corpo e o marca.", "play": "Marque primeiro, deixe os outros baterem. As Esporos recuperam energia e o Mapa Químico marca a sala toda."},
	&"linfocito_b": {"role": "Atirador de anticorpos", "about": "O Anticorpomante. Atira de longe: anticorpos que perseguem, salvas e uma explosão final de plasmócito.", "play": "Mantenha distância. O Anticorpo Y é o seu golpe de todo dia; a Opsonização retarda o que se aproxima."},
	&"t_citotoxico": {"role": "Executor", "about": "O Executor. Corpo a corpo cirúrgico: perfura, avança e termina o que já está ferido.", "play": "Fira, espere o inimigo cair abaixo do limiar e execute. O Sinal de Morte faz tudo valer mais por alguns segundos."},
	&"t_auxiliar": {"role": "Maestro de apoio", "about": "O Maestro das Citocinas. Cura, acelera e chama reforços; a luta é dos outros e ele a rege.", "play": "Fique atrás, cure no momento certo e use o Canto para acelerar o grupo. A Febre Dirigida pune quem se amontoa."},
	&"mastocito": {"role": "Bombardeiro", "about": "O Alarmista. Uma bolsa de grânulos prestes a estourar: poucos pontos de vida, muito poder de habilidade. Tudo nele é explosão: minas, bombas coladas, mortes que explodem.", "play": "Ande para semear minas, cole bombas nos grandes e ligue a Cascata antes de matar um grupo. A Anafilaxia é a aposta: quanto mais membrana você gasta, maior o estouro."},
	&"eosinofilo": {"role": "Caça-colossos", "about": "O Caça-Colossos. Resistente e lento, vive de inimigos grandes: corrói pela vida deles, congela monstros em cristal e cresce a cada morte.", "play": "Prenda o maior com a Adesão, congele-o no Cristal e bata para guardar dano. Quando a luta estiver quente, Hipertrofia e Rolagem."},
	&"celula_nk": {"role": "Assassina", "about": "O Assassino Natural. Veloz e frágil, ataca o que não reconhece sem pedir licença: surge atrás da presa, some da vista, volta no tempo.", "play": "Escolha uma presa com Predar e ataque-a: cada golpe devolve recargas. Camuflagem para a emboscada, Âncora para sair do aperto."},
	&"t_regulador": {"role": "Controlador", "about": "O Pacificador. Não bate de frente: arruma a luta. Faz inimigos dormirem, une-os pela dor, lança um isco e puxa a sala para um ponto.", "play": "Junte os inimigos (isco, singularidade), ligue-os com a Sinapse e então bata em um só. Anergia tira o mais perigoso da luta."},
}

const ABILITIES := {
	# Macrófago
	&"engolir": {"what": "Três braços fecham à frente e ferem tudo no cone.", "how": "Cada ponto de dano que acerta cura você em parte. Quanto mais inimigos no cone, mais cura."},
	&"onda_de_pseudopodes": {"what": "Uma onda ao redor do corpo fere e empurra todos.", "how": "Não precisa mirar. Útil para se livrar de quem cercou você."},
	&"lisossomo_acido": {"what": "Uma poça de ácido no chão fere quem está dentro.", "how": "Lance-a à frente (mira no mouse). Dura alguns segundos e fere a cada meio segundo."},
	&"muralha_de_carne": {"what": "A membrana engrossa e você recebe bem menos dano.", "how": "Dura alguns segundos e protege também enquanto você segue batendo."},
	# Neutrófilo
	&"rede_de_dna": {"what": "Uma rede lançada à frente retarda e fere quem fica nela.", "how": "Aponte para onde os inimigos vão passar."},
	&"explosao_neutrofilica": {"what": "Investida que fere tudo o que atravessa.", "how": "Invulnerável durante a investida: serve para entrar e para escapar."},
	&"netose": {"what": "Uma armadilha que explode depois de um instante.", "how": "Fica no chão e detona uma vez, ferindo e empurrando quem estiver ao redor."},
	&"degranulacao": {"what": "Uma nuvem de veneno ao redor do corpo.", "how": "Fica onde foi solta e fere, a cada meio segundo, quem estiver dentro."},
	# Dendrítica
	&"apresentar_antigeno": {"what": "Marca um inimigo: ele sofre mais dano de tudo.", "how": "Escolhe o alvo mais perto da mira. A marca some com o tempo."},
	&"dendritos_em_chicote": {"what": "Um leque de chicotes finos fere à frente.", "how": "Alcance médio, boa para limpar vários pequenos."},
	&"chuva_de_esporos": {"what": "Esporos que devolvem energia e membrana a quem está dentro.", "how": "Fique dentro da área para se recuperar durante a luta."},
	&"mapa_quimico": {"what": "Marca todos os inimigos por perto.", "how": "Sem mira: marca até seis, e todos passam a sofrer mais dano."},
	# Linfócito B
	&"anticorpo_y": {"what": "Um anticorpo que persegue o inimigo.", "how": "Atira na direção do mouse e curva até o alvo mais próximo. Barato e rápido."},
	&"salva_de_anticorpos": {"what": "Cinco anticorpos em leque.", "how": "Perto, todos acertam; de longe, só alguns."},
	&"opsonizacao": {"what": "Cobre um inimigo de anticorpos: ele sofre mais dano e anda mais devagar.", "how": "Escolhe o alvo mais perto da mira."},
	&"explosao_de_plasmocito": {"what": "A célula incha e solta uma parede de anticorpos ao redor.", "how": "Há um instante de carga antes do estouro: use quando eles estiverem em cima de você."},
	# T citotóxico
	&"perforina": {"what": "Uma lança que perfura a linha de inimigos.", "how": "Quem já está com pouca vida leva o dobro: a execução do T."},
	&"golpe_litico": {"what": "Investida pesada que fere tudo no caminho.", "how": "Invulnerável durante a investida."},
	&"apoptose": {"what": "Mata na hora um inimigo que já está ferido.", "how": "Só funciona em quem está abaixo do limiar de vida; sem alvo assim, não gasta nada."},
	&"sinal_de_morte": {"what": "Marca um alvo: ele sofre quase o dobro de dano.", "how": "Combine com a Perforina e a Apoptose."},
	# T auxiliar
	&"citocina_curativa": {"what": "Cura você ao longo de alguns segundos.", "how": "A cura vem aos poucos: use antes de apertar, não no último golpe."},
	&"canto_de_citocinas": {"what": "Você corre mais e recupera energia.", "how": "Dura alguns segundos e acompanha a célula."},
	&"chamado_a_linfa": {"what": "Três sentinelas giram ao seu redor e ferem quem se aproxima.", "how": "Duram alguns segundos. Fique perto dos inimigos."},
	&"febre_dirigida": {"what": "Uma região quente fere e retarda quem entra.", "how": "Lance-a à frente (mira no mouse)."},
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

const KIND_NAMES := {"mines": "minas", "sticky": "bomba colada", "cascade": "reação em cadeia", "overload": "carga com a vida", "tether": "corda", "crystal": "cristal", "grow": "crescimento", "roll": "bola", "blink": "teleporte", "prey": "caça", "cloak": "camuflagem", "recall": "volta no tempo", "sleep": "sono", "link": "elo", "decoy": "isco", "pull": "singularidade"}


static func has_class(id: StringName) -> bool:
	return CLASSES.has(id)


static func class_info(id: StringName) -> Dictionary:
	return CLASSES.get(id, {})


static func has_ability(id: StringName) -> bool:
	return ABILITIES.has(id)


static func ability_info(id: StringName) -> Dictionary:
	return ABILITIES.get(id, {})
