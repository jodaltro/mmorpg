# Hospedeiro — como jogar (H1)

## Abrir o jogo (PowerShell)

O backend (motor com o universo `hospedeiro`, porta **8096**, Jev ligado) fica rodando à parte. Para jogar, só o cliente:

```powershell
& "D:\tools\godot\bin\Godot_v4.7.2-stable_win64.exe" --path "D:\unity\Mmorpg\clients\hospedeiro"
```

Sem o backend, o jogo abre em **modo offline**: combate, nutrientes e mutações funcionam, sem missões nem história. O canto superior esquerdo mostra `● CONECTADO AO HOSPEDEIRO` ou `○ OFFLINE`.

Subir o backend à mão, se precisar (a chave do Jev fica em `engine\.env`, ignorado pelo Git):

```powershell
cd D:\unity\Mmorpg\engine
go run ./cmd/worldsim serve -universe ../universes/hospedeiro/universe.json -data D:\unity\hospedeiro-data -listen 127.0.0.1:8096 -advisor jev -env-file .env -on-universe-change new-world
```

## Controles

| Ação | Teclado/Mouse | Gamepad |
|---|---|---|
| Mover | WASD / setas | Analógico esquerdo |
| Mirar | Mouse | Analógico direito |
| Chicote de cauda (corpo a corpo, 8 ATP) | J / botão esquerdo | Botão X (oeste) |
| Cuspe de toxina (projétil, 15 ATP) | K / botão direito | Botão B (leste) |
| Impulso de membrana (dash + i-frames, 12 ATP) | Espaço / Shift | Botão A (sul) |
| Aceitar / recusar um chamado | Y / N, ou clique | — |
| Ações do lugar (examinar, contar, farejar, decifrar) | E, depois 1–9 | — |
| Abrir a janela do **Corpo** (forma, genes, habilidades, builds) | G, ou clique no aviso no canto | — |
| Dentro do Corpo: escolher uma oferta / recusar a mutação | 1, 2, 3 / X, ou clique | — |
| Renascer na medula | R | — |
| Habilidades de classe (4 espaços, na ordem em que você as adquire) | Q, F, C, V | — |

## Reiniciar o mundo

O botão **REINICIAR MUNDO** (canto superior esquerdo, só com o mouse) apaga o corpo e a história: aperte uma vez para armar (o texto vira "CONFIRMAR? apaga tudo") e outra vez em até 4 s para confirmar. O motor começa um mundo novo (o antigo fica arquivado no servidor) e você volta como uma esfera, sem genes, classe nem habilidades, na medula.

## Habilidades de classe

Cada classe nasce com **1** habilidade; as outras 3 vêm do que você faz: a prova da classe (missão dada por Neva, Dendra ou Rubra), feitos que combinam com ela e o **despertar** que o Jev decide de tempos em tempos olhando como você joga. Elas ocupam Q, F, C e V; quem tem alvo exigido (marcas, Apoptose) não gasta nada sem alvo. Resumo: Macrófago (engolir cura, onda, ácido, muralha), Neutrófilo (rede, investida, NETose, degranulação), Dendrítica (antígeno, chicote, esporos, mapa), Linfócito B (anticorpo Y teleguiado, salva, opsonização, plasmócito), T citotóxico (perforina, golpe lítico, apoptose, sinal de morte), T auxiliar (citocina curativa, canto, chamado, febre).

## O mundo (H1)

- Duas regiões: a **Medula Óssea** (onde você nasce) e a **Corrente Sanguínea**, ligadas pela sinusoide. No sangue há correnteza.
- **Membrana** é a vida; **ATP** é o recurso. Glicose (âmbar) devolve ATP; lipídio (verde) repara a membrana.
- Vírions espinhosos vivem no sangue: perseguem, brilham em vermelho por 0,65 s antes de avançar e ficam expostos por cerca de 1 s.
- O motor decide missões e história. Células como Osteia (estroma), Neva (neutrófila) e Dendra (dendrítica) só chamam quem já viram agir. Nada é oferecido antes do seu primeiro feito.
- O corpo vive sozinho: surtos virais, febre (vírions lentos), refeições (glicose no sangue), sono (tudo escurece). O Jev escolhe os acontecimentos.
- Conhecimento muda o mundo: destruir um vírion ensina o "rosto" dele. Contar à Dendra arma as defesas do sangue. Conhecer o vírion também permite decifrar o fragmento de código que aparece no nicho (cenário único: só a primeira célula recebe o título).
- **Evoluir é o objetivo de todo jogador.** Cada feito confirmado (vírion destruído, nutriente, esquiva, código decifrado) soma pressão evolutiva e ensina o seu caminho (combate, metabolismo, resistência, exploração, conhecimento). Quando a pressão estoura, o motor oferece 3 mutações; o Jev escolhe para onde o seu corpo pende (marcada com ◆) lendo como você vive. Um aviso discreto aparece no canto; você abre a janela do Corpo (G) quando quiser e escolhe lá (1, 2, 3, ou clique), ou recusa com X. Escolher aprofunda o caminho. Os espaços de genes estão cheios? O gene mais antigo é **silenciado**, não perdido: vai para a biblioteca e pode voltar.

## A janela do Corpo (G) e as builds

Uma janela só para tudo o que o corpo virou, com quatro abas:

- **FORMA:** a classe, o que ela faz com o corpo, maturidade e pressão evolutiva. A diferenciação oferecida é escolhida aqui (é permanente).
- **GENES:** os genes expressos, a **biblioteca** dos silenciados, a oferta de mutação pendente e uma **comparação ao vivo** (membrana, velocidade, dano... antes → depois, verde melhora, vermelho piora) do que uma troca faria. Clique num gene da biblioteca e, se os espaços estiverem cheios, no gene expresso que dá o lugar; depois **Trocar**. **Silenciar** libera um espaço.
- **HABILIDADES:** as 4 habilidades de classe e suas teclas; clique em duas para trocá-las de lugar (a ordem fica guardada nesta máquina).
- **BUILDS:** três conjuntos de genes guardados (com a ordem das habilidades e um nome que você escolhe). **Salvar aqui** guarda o que está expresso; **Aplicar** expressa a build de uma vez, e a prévia mostra o efeito antes.

**Quando se pode mexer:** você escolhe quando abrir o Corpo (G); não há trava de combate. Só não vale dentro de uma masmorra, e o corpo precisa **se acomodar** por alguns segundos depois de cada troca (o motor impõe). Chamados de missão aparecem como um cartão pequeno no canto, que você responde quando quiser.

## Arquivos

- `universes/hospedeiro/universe.json`: o mundo no motor.
- `clients/hospedeiro/scripts/domain`: vitais, ator, ataques, genoma (puro).
- `clients/hospedeiro/scripts/runtime`: corpo procedural, combate, mapa do corpo (`bio_body_map.gd`), ligação com o motor (`bio_engine_link.gd`, `bio_host_sync.gd`), janela do Sistema.
- `clients/hospedeiro/tests`: runner headless, testes de regras, mundo e ponte com o motor; `e2e_engine.gd` (ponta a ponta) e `capture.gd` (screenshots).

## O Granuloma (primeira masmorra)

Na corrente sanguínea há um granuloma: anéis de macrófagos em volta de um núcleo necrótico. Chegue perto (a coroa de luz acende) e aperte **E** para entrar; só abre para quem já amadureceu e só com o corpo conectado ao motor. O motor prepara a execução, o Jev escolhe o **modificador** (Em febre, Necrose viva, Guarda redobrada, Ar rarefeito ou Quórum ativo) e a câmara se forma longe do corpo: **cinco salas** (guarda de linfócitos, parede de macrófagos, anel interno, núcleo necrótico e o chefe, O Bacilo). Limpar a sala avança; o chefe faz um golpe em onda com um segundo de aviso (o anel no chão cresce) e solta bacilos. **Backspace** desiste. Morrer encerra a execução, e é preciso esperar um pouco para tentar de novo. Fechar o granuloma reduz a carga de infecção no sangue, dá o Selo do Granuloma e, para a primeira célula do mundo, o título Primeiro Selador.

## Atlas do corpo

**M** abre e fecha o atlas: o corpo é uma única membrana contínua; as regiões que a célula já visitou ficam acesas e nomeadas, as outras aparecem só como contorno apagado com um "?". A descoberta é lembrada entre sessões.

## Sinais vitais

Uma linha no canto superior direito mostra temperatura, pulso e oxigênio (laranja quando fora do normal). **Tab** abre o painel completo: uma barra para cada sinal, com a faixa saudável marcada, e frases que explicam o que está acontecendo e por quê (febre, hipóxia, adrenalina, cortisol, insulina).

## Explorar

Alguns lugares do corpo escondem **nichos**: bolsas com um gene para quem as achar. Uma seta no canto da tela ("rastro químico · distância") aponta para o nicho mais próximo que você já consegue alcançar; o nicho cintila quando você chega perto, e basta tocá-lo. Os nichos únicos dão o gene só ao primeiro a chegar. Algumas passagens têm uma **membrana alaranjada** que só abre para quem tem o gene certo (o pulmão pede o Citoesqueleto Elástico); ela diz o que pede quando você chega perto. Requer o motor conectado.

## Códice

**B** abre o códice do corpo: lugares, invasores, o corpo e segredos. O que você ainda não aprendeu aparece como `???`. Também lista as regiões a que você se adaptou por viver nelas (a energia volta mais depressa lá). Há nichos-segredo que só existem em certo estado do corpo, e o rastro químico segue o lugar que o Jev apontou para você, quando há um.

## Debug do design do Jev

**F3** abre o painel de debug: de onde veio o design (motor, debug ou nenhum), cada traço, o estilo dos efeitos, os multiplicadores das partículas e quantos efeitos foram emitidos nesta sessão (e quantos com estilo). **F4** troca o estilo dos efeitos à mão (chama, cristal, névoa, elétrico, orgânico) para ver cada um sem esperar o motor; **F5** sorteia um design completo (núcleo composto, membrana, organelas, brilho, efeitos); **F6** volta ao que o motor decidiu. Cada mudança também escreve `[design] origem=... traços=...` no console. O motor desenha a célula nova depois de uns 6 atos (cerca de 20 s jogando).

**F7** troca o impacto do projétil, **F8** a trajetória e **F9** o calibre (para ver cada projétil do Jev sem esperar o motor).

## Menu de teste (Esc) e painel do Jev (F2)

**Esc** abre o menu de teste (clique com o mouse; o jogo continua rodando por trás): ir direto a cada lugar do corpo, a cada sala do granuloma (ou ao chefe), virar qualquer classe (já com as 4 habilidades dela), criar 5 ou 15 vírions, limpar vírions, vida e ATP cheios, zerar recargas, modo invulnerável, sortear um design completo, voltar ao design do motor, trocar de estilo, trajetória, impacto, calibre ou foco, e abrir os painéis. Ligado ao motor, a classe pode ser desfeita pelo motor; ir a uma região bloqueada pelo motor (o pulmão sem a chave) é aceito só no cliente.

**F2** abre o painel do Jev: o que está à espera de resposta, as últimas decisões com **quem respondeu (Jev ou o padrão do prazo)**, quanto demorou, quanto custou e se diferiu do padrão, e cada traço do design atual com a origem (jev, padrão ou debug). Uma linha fica sempre visível abaixo da região: `JEV: 22 decisões · 22 pelo Jev · 0 pelo padrão · 394 ms · 0 à espera`, ou `JEV: sem motor (offline)` quando nada é decidido por ele.

## Os órgãos além da artéria (E3)

Da artéria saem os caminhos para o **fígado**, o **baço**, o **intestino** e o **rim**. Cada um tem o seu verbo, os seus bichos e a sua masmorra (o jogo avisa quando ela abre e a seta aponta o caminho).

| Órgão | O que flutua | Verbo (o que o motor ouve) | Bichos selvagens | Masmorra |
|---|---|---|---|---|
| Fígado | toxinas | filtrar toxina, guardar glicogênio | plasmódio (se divide), esporo de bile (cospe) | Cordões Hepáticos |
| Baço | hemácias velhas | reciclar hemácia (devolve ferro à medula); capturar antígeno (matar no baço) | meningococos (em trio), bactéria encapsulada | Centro Germinativo |
| Intestino | bactérias boas | nutrir a microbiota; repelir invasor (matar no intestino) | bactéria entérica, verme, esporo de clostrídio (cospe) | Criptas Profundas |
| Rim | cristais de ureia | filtrar ureia; equilibrar o sal (nutriente tomado no rim) | cristais de urato (em trio), cálculo, espícula de oxalato (cospe) | Néfrons |

Os órgãos se falam: o ferro reciclado no baço vira hemácia na medula; o intestino despeja nutrientes **e toxinas** no fígado; a toxina que o fígado não filtra vira ureia no rim; e um rim que não dá conta sobe a pressão da artéria e inflama o corpo.

As masmorras são **procedurais**: cada corrida abre com uma sala fixa, fecha com o chefe e sorteia, da semente, de 3 a 4 salas entre as dos órgãos (emboscada, pilares, ninho, poças, e as de sempre), cada uma com formato, pilares, poças e elenco próprios. Duas corridas não se parecem.

## As habilidades das seis classes antigas

Sete habilidades ficaram como o "cavalo de batalha" de cada família que o Jev desenha para a célula (devorar, onda, zona, investida, cone, projétil, estocada): Engolir, Onda de Pseudópodes, Rede de DNA, Explosão Neutrofílica, Dendritos em Chicote, Anticorpo Y e Perforina. As outras 17 foram refeitas como verbos que o jogo não tinha, e nenhuma repete outra: no total, as 40 habilidades das 10 classes são de 40 tipos diferentes.

| Classe | Habilidades novas |
|---|---|
| **Macrófago** | **Contragolpe** (a membrana endurece: quem bate paga o golpe de volta, fica atordoado, e você se cura), **Polarização M1/M2** (muda de forma: M1 bate forte e queima o que fere, M2 bate fraco, aguenta e se cura) |
| **Neutrófilo** | **Diapedese** (atravessa os corpos, mais rápido e com metade do dano, ferindo quem cruza), **Surto Oxidativo** (as recargas correm o dobro, e a membrana queima por isso) |
| **Dendrítica** | **Varredura** (um feixe que segue a mira devagar), **Maturação** (as próximas 3 habilidades saem de graça e mais fortes), **Passagem Linfática** (duas portas no tecido) |
| **Linfócito B** | **Complemento** (marca: no terceiro golpe, de quem for, o inimigo estoura), **Memória Imunológica** (repete de graça a última habilidade), **Fábrica de Plasmócito** (fica parado atirando anticorpos sem parar) |
| **T citotóxico** | **Salto Letal** (salta por cima da multidão e cai com um golpe), **Sinapse Letal** (segura um inimigo à frente, apertando mais, e termina o quase morto), **Lise em Massa** (fere a sala e sentencia os quase mortos; o limiar sobe com as mortes recentes) |
| **T auxiliar** | **Febre Contagiosa** (a febre passa de inimigo em inimigo), **Chamado aos Auxiliares** (duas células que lutam por você), **Segunda Chance** (o próximo golpe mortal não mata), **Transfusão** (troca membrana por energia, ou o contrário) |

O texto de cada uma, e de como funciona, está na janela do Corpo (G), aba Habilidades.

## As quatro classes novas

Da linhagem **mieloide** saem agora também o Mastócito e o Eosinófilo; da **linfoide**, a Célula NK e o Linfócito T regulador. Cada uma tem 4 habilidades (Q, F, C, V), 6 mutações de classe, um corpo próprio e uma prova que dá a segunda habilidade.

| Classe | Papel | Habilidades | O que tem de único |
|---|---|---|---|
| **Mastócito**, o Alarmista | bombardeiro | **Grânulos Latentes** (solta uma mina a cada passo; elas explodem quando um inimigo chega e uma faz a vizinha explodir), **Histamina Instável** (cola uma bomba com pavio no inimigo; cada bomba a mais no mesmo alvo aumenta a explosão), **Cascata de Degranulação** (por 8 s, tudo o que você mata explode, e quem morre da explosão também), **Anafilaxia** (a célula sangra a própria membrana numa onda que cresce; **aperte de novo** para soltar: o dano é feito da vida gasta) | muito poder de habilidade, pouca membrana |
| **Eosinófilo**, o Caça-Colossos | caçador de gigantes | **Adesão** (prende-se com uma corda que puxa o inimigo e corrói uma fração da vida dele por segundo), **Cristal de Charcot-Leyden** (o inimigo fica parado e nada o fere; os golpes ficam **guardados** e saem todos de uma vez quando o cristal quebra, em explosão), **Hipertrofia** (cada morte faz a célula crescer, bater mais forte e se curar), **Rolagem** (vira uma bola protegida que **quica** nas paredes e nos inimigos; o mouse a guia) | o dano escala com o tamanho do inimigo e com o que ele guarda |
| **Célula NK**, o Assassino Natural | assassina | **Passo Sem Identidade** (aparece **atrás** do alvo e o golpeia nas costas), **Predar** (uma presa: cada golpe nela devolve recarga e energia, e matá-la devolve **tudo**), **Camuflagem de MHC** (some da vista dos inimigos; o primeiro golpe de dentro da sombra é uma emboscada), **Âncora de Vigilância** (marca o lugar e a vida; depois **volta no tempo**, em linha reta, ferindo quem estiver no caminho; **aperte de novo** para voltar antes) | rápida, joga com tempo e posição |
| **T regulador**, o Pacificador | controlador | **Anergia** (o inimigo **dorme** até ser ferido; o golpe que o acorda bate mais forte; os grandes dormem mais leve), **Sinapse Imunológica** (une até 3 inimigos: a dor de um é a dor de todos), **Autoantígeno** (lança um **isco** de si: os inimigos vão atrás dele e largam você), **Singularidade de Tolerância** (**puxa** os inimigos para um ponto e, ao colapsar, fere o amontoado) | não bate de frente: arruma a luta para os outros |

A prova de cada uma: Mastócito e T regulador absorvem nutrientes; Eosinófilo chega a 120 invasores destruídos; Célula NK esquiva 10 vezes. (A prova do T citotóxico também subiu para 120: pedia 12, e quando a classe é escolhida a célula já passou disso, então a missão nunca era oferecida.)
