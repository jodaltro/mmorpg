# Validação — cliente Godot

Só o que realmente rodou. Máquina: Windows 10 19045, AMD Radeon RX 5700 XT (Vulkan 1.4.315, Forward+), Godot 4.7.2-stable em `D:\tools\godot` (SHA-256 do zip conferido com o digest do release). Assets: pacotes Quaternius CC0 já baixados em `D:\UnrealDownloads\WorldSimDemo`, copiados para `clients/godot/assets` (fora do git).

## 21/10/2026

### Rig e animações

Inspeção em Godot headless: o personagem (`Superhero_Male_FullBody`), os outfits e a UAL têm o mesmo esqueleto (65 ossos, caminho `Armature/Skeleton3D`). As 43 animações da UAL1 e as 43 da UAL2 tocam no personagem sem retargeting; os meshes dos outfits (Peasant, Ranger) se movem para o esqueleto do personagem e acompanham as animações.

### Teste automático contra o motor

Motor: `worldsim serve` (Valdoria, `-advisor deterministic`) em `127.0.0.1:8096`, com dados descartáveis. Cliente: `Godot --path clients/godot --resolution 1280x720 -- --autotest --player=gd-<timestamp> --name=Teste --server=http://127.0.0.1:8096`.

| Passo | Resultado |
|---|---|
| join + `view` | `view: true`, NPCs da região criados a partir de `others` (`npcs: 5` na vila) |
| `act examinar-poco` (Orin) | aceito; evento "Teste examina a agua do Poco Antigo." voltou na `view` |
| `act forjar` (Brom) | **recusado pelo motor** (`rejected: requirements`), mostrado no HUD |
| missão oferecida → `accept` | `quest_offered: true`, `quest_active: true` |
| entrada na floresta (volume de região) | `move` aceito; `region_local` e `region_server` = `floresta` |
| golpe | animação `Sword_Regular_A`, faíscas e tremor de câmera (capturas conferidas) |

Resumo impresso: `AUTOTEST {"npcs":5,"quest_active":true,"quest_offered":true,"region_local":"floresta","region_server":"floresta","skills":0,"view":true}`.

### Defeitos encontrados e corrigidos na validação

- `HTTPRequest` com timeout de 5 s expirava na primeira requisição, presa pela compilação de shaders do primeiro frame (`result=13`). Passou a 15 s, com início da rede adiado e `join` repetido até 5 vezes.
- `walk_to` era ignorado durante um clipe pontual, e o teste travava esperando `arrived`. Andar agora cancela o clipe.
- Em mundo persistido o jogador começava na vila com o servidor dizendo "floresta". O cliente passou a se posicionar pela região da primeira `view`.

### Não validado

Export web, stream SSE, pathfinding, estilização, mais de um cliente simultâneo, desempenho com muitos NPCs.

## 22/10/2026 — estilização e inimigos, com o Jev ligado

Daqui em diante os testes rodam com o Jev: `worldsim serve ... -advisor jev -env-file .env` (log do servidor: `advisor=jev`), mundo novo em `data/mundo-novo`, porta 8095. Latência, custo e taxa de resolução do Jev **não foram medidos** nesta rodada; só se confirmou que o servidor subiu e respondeu com o Jev ligado.

### Estilização

- Primeira versão do pós-processamento (contorno por profundidade **e** normal): exagerada. As normal maps davam contorno a cada pedra do calçamento, e a posterização escurecia demais a noite. Corrigido: contorno só por profundidade (limiar de 0,45 m, intensidade 0,7, graduado), faixas de luz suaves, noite mais clara. Conferido em capturas (`--out`); o ajuste é de gosto e segue aberto a revisão.
- Árvores de 7 m escondiam a luta; abertos corredores sem árvores na estrada e no acampamento.

### Combate contra o motor (Jev ligado)

Comando: `Godot --path clients/godot --resolution 1280x720 -- --autotest --threat=estrada --player=gd-<timestamp> --name=Teste --out=...`.

| Passo | Resultado |
|---|---|
| ameaça da vila | o mundo emitiu `wolves` por conta própria; 3 corrompidos apareceram na vila (log do cliente) |
| `act examinar-poco` e `accept` | aceitos; missão `active` |
| acampamento na estrada | 3 bandidos criados (`--threat` força o acampamento) |
| luta | 3 abates, 0 quedas, vida final do jogador 64 de 100 |
| `occur enfrentar-bandidos` (adapter) | **aceito** pelo motor: evento público "Teste derrota um grupo de bandidos na estrada." |

Resumo: `AUTOTEST {"deaths":0,"enemies_spawned":3,"kills":3,"quest_active":true,"quest_offered":true,"region_local":"estrada","region_server":"estrada","report":"enfrentar-bandidos:ok","view":true}`.

Observação: em uma rodada em que o evento `bandits-left` já tinha chegado, o acampamento não surgiu (comportamento correto: o mundo mandou os bandidos embora). A flag `--threat` passou a prevalecer sobre esse evento só para teste.

### Defeitos corrigidos

- `await player.arrived` nunca resolvia se o jogador caía no caminho; o teste agora espera com tempo limite.
- Acesso a inimigo já liberado em `_sync_enemies` (corrigido filtrando instâncias válidas).
- Aviso "owner inconsistent" ao vestir outfits (corrigido zerando o `owner` antes do `reparent`).

### Não validado

Queda e renascimento do jogador (`_player_fell`) no cliente completo (ocorreu uma vez numa rodada, sem registro de conferência), esquiva, combo de 3 golpes em jogo manual, corrompidos da vila em combate, export web, SSE, pathfinding.

## 22/10/2026 — oclusão, pathfinding, interface e missões (Jev ligado)

Servidor: `worldsim serve ... -advisor jev -env-file .env` em `127.0.0.1:8095`, mundo novo. Teste: `Godot --path clients/godot --resolution 1280x720 -- --autotest --threat=estrada --player=gd-<timestamp> --name=Teste --out=...`, repetido várias vezes durante o desenvolvimento.

| Item | Resultado |
|---|---|
| NavMesh em tempo de execução | `NAV baked: polygons=1052`; `nav: true` |
| Pathfinding | de (-8,-12) até (-24,-12), com uma casa no meio: `path_reached: true`, 4,2 s para 17,3 m em linha reta (houve desvio); captura mostra o personagem contornando |
| Oclusão | `occluders_faded: 1` na floresta; na captura da casa o telhado fica transparente com o jogador atrás |
| Oferta de missão | cartão com rank, quem deu, descrição, objetivo, local e recompensa; `accept` por tecla → `quest_active: true`; aviso "Missao aceita" |
| Rastreador, diário (`J`), minimapa, log, dica `[E] Falar com Orin`, barra de vida | conferidos em capturas (`02_offer`, `03_tracker`, `08_journal`) |
| Marcador "!" no NPC que oferece missão | `markers: 1` |
| Combate + motor (Jev ligado) | 3 abates; `enfrentar-bandidos` aceito em algumas rodadas e recusado (`rejected: requirements`) em outra em que os bandidos já tinham partido do mundo: o motor decide |

### Defeitos corrigidos na validação

- Painéis ancorados com `set_anchors_preset` ficaram com tamanho e posição errados (o log cobriu a tela). Trocado por contêineres de margem.
- Tween do log capturava linhas já liberadas (`Lambda capture ... was freed`): o tween passou a pertencer à própria linha.
- O pop-up central de oferta atrapalhava o jogo quando o mundo oferecia missões em sequência: virou um cartão compacto na coluna direita.

### Não validado

Clique nos botões Aceitar/Recusar/Abandonar (só se exercitou a tecla `Y` e a geração dos botões), avisos de missão falha/expirada, desempenho do bake em mundos maiores, oclusão nas árvores em jogo manual (só uma árvore transparente foi medida), mais de um jogador.

## 22/10/2026 — lobos e javalis (Jev ligado)

Modelos: `wolf_a.glb` (Quaternius, animado) e `boar_polygoogle.glb` (Poly by Google, CC-BY, estático), baixados do poly.pizza porque a pasta do pacote oficial no Google Drive respondeu "Quota exceeded". Servidor: `-advisor jev`, `127.0.0.1:8095`.

| Item | Resultado |
|---|---|
| Escala e orientação | conferidas num cenário de teste (`--autotest=zoo`): lobo escala 0,32, javali 0,0085, ambos olham para +Z (de frente para a câmera quando virados para ela) |
| Floresta, javalis | `boars_spawned: 3`, `boar_kills: 3`; cada abate reportado como `cacar-javali` e **aceito** pelo motor ("Teste abate um javali na floresta.") |
| Efeito emergente | um dos abates ao amanhecer gerou "Ao amanhecer, Teste ve orelhas compridas sumindo atras de uma raiz enorme. Uma toca!" |
| Vila, lobos (`--autotest=wolves --threat=vila`) | `wolves_spawned: 3`, `kills: 3`, `cacar-lobos` **aceito** ("Teste afugenta lobos corrompidos da vila."), vida final 76 |
| Bandidos na rodada completa | `enfrentar-bandidos` recusado (`rejected: requirements`): os bandidos já tinham partido do mundo |
| Capturas | lobo golpeado ao lado de NPC na vila; javali com faíscas de golpe e outro caído (queda procedural) |

Resumo da rodada completa: `AUTOTEST {"boar_kills":3,"boar_report":"cacar-javali:ok","boars_spawned":3,"deaths":0,"kills":6,"nav":true,"path_reached":true,"player_hp":17,...}`.

### Defeitos corrigidos

- A fileira de teste ficou fora de quadro por causa da câmera girada 45°; passou a usar os eixos da câmera.
- Lobo pequeno e escuro demais: escala 0,25 → 0,32 e tinta mais clara.

### Não validado

Respawn do javali 25 s depois do abate (o código existe; o teste não esperou esse tempo), animação `Idle_HitReact_Right` (só se usa a esquerda), lobos em perseguição entre regiões, javalis em mais de uma região, desempenho com muitas criaturas.

## 22/10/2026 — pendências: javali animado, respawn, botões, avisos, cercas, oclusão, desempenho, vários jogadores, Jev

Servidor com `-advisor jev`, `127.0.0.1:8095`. Teste principal: `--autotest --threat=estrada --respawn=4`.

| Pendência | O que mudou | Resultado |
|---|---|---|
| Javali sem animação | trocado pelo porco animado do Quaternius (CC0) escurecido, escala 0,55, presas no osso `Head_end`; o código procedural e o modelo CC-BY saíram | close-up confere tamanho, presas e tom; corre, dá cabeçada e morre com animação |
| Respawn não testado | `--respawn=S` encurta o tempo para teste | `boar_respawned: 3` (os 3 voltaram 4 s depois); `boar_kills: 3`, cada `cacar-javali` aceito |
| Cliques nos botões | clique real pelo pipeline de entrada (`Input.parse_input_event`) | Aceitar no cartão: `click_accept: true`. Abandonar no diário: o clique chega, e o motor **recusa por regra do universo** ("this world requires finishing the accepted quest"). Aceitar/Recusar do diário: não havia oferta pendente nessa rodada, **não exercitados** |
| Avisos de falha/expiração | `--autotest=hud` com estados **sintéticos** (sem o motor) | avisos de nova, aceita, encerrada (expirou), falhou e habilidade aprendida aparecem; diário agrupa "expirou"/"falhou". Limitado a 4 avisos visíveis |
| Cercas | colisores ao longo das duas cercas da estrada | pathfinding segue `path_reached: true`; bandidos atrás da cerca chegam pela ponta |
| Oclusão das árvores | teste determinístico: jogador posto atrás de uma árvore, vista da câmera | `tree_fade: 0.82` |
| Desempenho | amostra de 3 s com vsync desligado (RX 5700 XT, 1280×720) | praça: 327 fps, pior quadro 7,6 ms, 305 draw calls; floresta: 338 fps, 6,6 ms, 269 draw calls |
| Vários jogadores | `others` já trazia jogadores; o cliente passou a mostrá-los | com 2 jogadores via contrato (`mp-ana` na vila, `mp-bruno` na floresta), cada um vê o outro com a região certa; o cliente de `mp-ana` mostrou 5 jogadores da vila e não o da floresta (`other_players: 5`). Posições são fixas por id (o motor não tem coordenadas) |

### Jev (medido)

`worldsim simulate -universe ../universes/valdoria/universe.json -advisor jev -env-file .env -pace 800ms -ticks 150 -players 3`:

| Tipo | Decisões | Latência média | Confiança média | Custo |
|---|---|---|---|---|
| offer/jev | 19 | 551 ms | 0,51 | US$ 0,001009 |
| story/jev | 2 | 529 ms | 0,54 | US$ 0,000080 |
| world/jev | 16 | 512 ms | 0,47 | US$ 0,000698 |
| world/default (prazo vencido) | 1 | — | — | — |

Taxa de resolução pelo Jev no prazo: 37 de 38 (97%). Custo total: US$ 0,0018 em 150 ticks. A história avançou (10 missões concluídas, cenários únicos disputados, digest `81d173de…`).

### Não validado

Aceitar/Recusar pelo diário (sem oferta pendente na rodada), avisos de falha/expiração vindos do motor real (só com dados sintéticos), posição real entre jogadores.

## 22/10/2026 — todas as regiões e todas as interações do motor

Pedido do usuário: "não achei a mina" e "implementar a possibilidade para todas as missões e interações que tem no motor". Antes, o cliente só tinha vila, estrada e floresta, e só conseguia caçar e lutar; ações como minerar, explorar ruínas, colher ervas, forjar com Brom, entregar ervas etc. não tinham como acontecer.

- Motor: `GET /v1/affordances/{id}` (aditivo, v1) e `title` opcional nas ações; testes `TestAffordancesFollowThePlayer`, `TestAffordancesDoNotRevealHiddenFacts` (procurar Nino aparece na floresta mesmo sem Nino perdido, e o motor recusa) e `TestAffordancesEndpoint`. `gofmt`, `go vet`, `go test ./...` ok; `worldsim validate` ok.
- Cliente: mina (encosta ao norte da estrada, entrada, veios, escombros), ruínas (muros caídos, salão, escada), toca (raiz gigante, cogumelos), poço e selo; menus de NPC, de ponto de interação (`E`) e da região (`F`) montados a partir das affordances; Javali Branco (noturno, para quem achou o rastro, `cacar-javali-branco`) e onda de corrompidos quando o jogador sabe que o selo se despedaçou (`defender-vila`). Assim, as 38 ações de jogador e de servidor de jogo do Valdoria ficam ao alcance (as de combate são reportadas pelas lutas).
- `--autotest=places` contra `serve -advisor jev` (15 s por tick): conversar com Orin → ir à mina, abrir o menu do veio e **clicar** em "Minerar um veio" → aceito ("Teste extrai minerio da Mina de Kharum."); ruínas → "Explorar o salao das ruinas" aceito ("Teste encontra uma bigorna antiga coberta de runas..."); toca → Pipo e Sora presentes, conversar com Pipo aceito; vila → o menu de Brom passou a ter "Forjar com Brom" (havia minério) e a forja foi aceita.
- Regressão (`--autotest --threat=estrada --respawn=4`): bandidos, javalis (3 abates, respawn 3), caminho, oclusão (0,82), cliques em Aceitar/Abandonar; 0 quedas; 285–370 fps.

### Defeitos encontrados e corrigidos

- A encosta da mina foi posta atravessando a estrada e bloqueava as ruínas: mina movida para o norte da estrada.
- `play_once` esperava `animation_finished`, que nunca chega em clipes que vêm em loop no arquivo (`TreeChopping`): o personagem ficava "ocupado" para sempre após minerar. Agora espera a duração do clipe.
- Javalis colados à estrada atacavam todo viajante (chegou a 25/100 de vida no caminho): bando movido para dentro da mata.
- O teste desistia de andar quando um golpe interrompia a caminhada; agora retoma, como um jogador clicaria de novo.

### Não validado

Javali Branco e onda de corrompidos em jogo (dependem de rastro à noite e do selo despedaçado; não ocorreram nas rodadas), ações de habilidade (diagnosticar, Florescer, chá...) que só aparecem com a habilidade, resgate de mineiro (precisa do desabamento), escolta e recuperação de mercadorias pelos menus.

## 22/10/2026 — WASD, ataque com o mouse, barra e efeitos de habilidade

- Controles: WASD relativo à câmera; botão esquerdo golpeia na direção do cursor (segurar mantém o combo); botão direito anda/usa; 1–4 e R na barra; K abre o painel de habilidades (combate + aprendidas no mundo).
- Habilidades de combate (regra do servidor de jogo, fora do motor): Golpe Giratório (anel dourado, 30 a quem estiver perto), Investida (rastro azul, 25 a quem estiver no caminho), Lâmina de Energia (projétil lilás com luz e rastro, 35), Fôlego (anel e partículas verdes, +30), Esquiva (na direção do movimento). Recarga desenhada no ícone.
- `--autotest=skills` (contra `serve -advisor jev`), duas rodadas iguais: `giro_damage: 60` (dois alvos), `investida_damage: 45`, `lamina_damage: 35`, `hp_after_heal: 80` (de 50), recarga bloqueia o reuso, painel K abre; W enviado pela fila de entrada move na direção "para cima da tela" (`w_goes_up_screen: true`); clique esquerdo pela fila de entrada golpeia e vira para a mira (`lmb_attacked`, `lmb_faces_aim`). Regressão `--autotest`: 0 quedas, caminho chegou, javalis e bandidos, 300–410 fps.

### Defeitos encontrados e corrigidos

- **O pós-processamento cobria tudo o que é transparente** desde que entrou: nomes sobre os personagens, barras de vida, números de dano, marcadores "!", anéis de efeito. Ele era desenhado por último; passou a ser o primeiro entre os transparentes (`render_priority = -128`), e o resto é desenhado por cima. Conferido com e sem `--nopost`.
- A recarga vazava como um círculo escuro fora do ícone (`clip_contents`).
- A cura era bloqueada durante outra animação; agora ela e a esquiva interrompem o golpe.
- `_on_enemy_died` quebrava com inimigo fora de acampamento conhecido.

### Não validado

Sensação das habilidades em jogo manual (força, tempo de recarga, alcance), Investida contra paredes, clique direito em NPC distante, uso com teclado ABNT diferente de QWERTY para WASD (usa a tecla física).

## 22/10/2026 — F0 do plano MVP (base: push, mapa em branco, telemetria)

Motor: `worldsim serve ... -advisor jev` em `127.0.0.1:8095`, mundo novo (`data/f0`). Cliente: `Godot --path clients/godot -- --autotest=f0`.

- **Motor:** `discovered` (predicado privado por jogador, afirmado ao entrar e a cada `move`) e `onJoin` (efeitos na criação do personagem). Testes novos em `engine/scenarios/discovery_test.go`: `TestPlacesAreDiscoveredByGoingThere`, `TestOnJoinEffectsRunForTheNewcomer`. `gofmt`, `go vet`, `go test ./...` passaram; `worldsim validate` ok; `simulate` de 200 ticks e 3 jogadores sem travar.
- **Push (SSE):** o cliente abre `/v1/stream/{id}` e busca a visão quando chega um `delta`; o polling cai para 5 s enquanto o stream está no ar. Três rodadas do `--autotest=f0`: acontecimento visível em 227, 236 e 245 ms (sem refresh manual). Uma rodada anterior, logo após reimportar o projeto, falhou (o `move` não chegou a ser confirmado em 4 s); não repetiu em quatro tentativas seguintes, causa não investigada.
- **Mapa em branco:** ao entrar, só a vila está descoberta; a estrada passou a constar depois do `move`; a Toca continua oculta. Rótulos de pontos de interesse só aparecem a menos de 7 m e em regiões descobertas (0 rótulos distantes visíveis).
- **Telemetria:** `user://telemetry-<jogador>.jsonl` (ou `--telemetry=`) com sessão, lugares descobertos, regiões, verbos e lacunas. Resumo no teste: verbos distintos, tempo até o primeiro feito, duração.
- **Regressão:** `--autotest` (javalis, bandidos, caminho, missão aceita pelo clique; 300–410 fps) e `--autotest=places` passaram. O principal registrou 1 queda do jogador na luta.
- **Não feito da F0:** POIs lidos do universo (ainda em `places.gd`), tabela de apresentação (`presentation.json`) e lugares/`spot` no universo. Ficam para a F1, onde a nova planta da vila os exige.

## 22/10/2026 — F1: vila viva e mapa em centro e raios

Motor: `worldsim serve ... -advisor jev` (porta 8095, tick de 15 s) e uma segunda instância com Jev em 8097, tick de 500 ms, para ver um dia inteiro em ~25 s.
- **Mapa:** o corredor virou um centro com raios (`clients/godot/scripts/layout.gd`, única fonte de coordenadas). Vila murada com portão leste, portão norte e uma brecha oeste escondida atrás de um arbusto; estrada leste até o cruzamento; do cruzamento, a mina (nordeste) e as ruínas (leste); a floresta ao norte da vila (trilha até o selo); a toca a oeste. Sete construções (casa de Mira, taverna, forja, capela, celeiro, casa de Nino, guarita), um mirante, horta, lanternas que acendem à noite.
- **Rotinas e conversas no cliente:** NPCs andam até o spot do momento, dormem sem aparecer, mostram "(fazendo tal coisa)" de perto; as falas ouvidas viram balões acima de quem fala quando se está a menos de 15 m. Rótulos do minimapa e do mundo continuam só para o descoberto.
- **`--autotest=f1`** (servidor rápido, 75 s): 24 horas do dia vistas; 5 dos 6 NPCs trocaram de lugar (Brom forja→taverna, Elena capela→praça→poço, Mira casa→horta→poço, Nino casa→mirante→celeiro→praça, Orin guarita→portão→praça); 47 falas ouvidas; capturas conferidas.
- **`--autotest=tour`** (Jev, tick de 15 s): do centro ao cruzamento (17 s), floresta (21 s), selo (24 s), mina (19 s), ruínas (17 s), toca (40 s, pela brecha) e de volta à vila (15 s); o motor concordou com a região em todas as paradas e as seis regiões ficaram descobertas.
- **`--autotest=places`** passou inteiro no novo mapa (forja, mina, ruínas, toca, Pipo). **`--autotest`** terminou sem erro de script, mas dependeu do estado do mundo naquela execução (lobos na vila no lugar de bandidos na estrada; 1 queda do jogador) e a medição do pico de quadro na floresta foi ruim (fps 128, pior quadro 1,5 s, primeira carga); a regressão de combate no mapa novo não ficou confirmada.
- **Não feito da F1:** cômodos-caixa (as casas ainda não têm interior; quem dorme some), quadro de avisos e sino, 30–40 falas (são 9), tabela de apresentação e POIs lidos do universo.

### 22/10/2026 — fecho das pendências da F1

- **Interiores:** as casas agora têm paredes com vão de porta (dá para entrar), móveis por tipo (casa, taverna, forja, capela, celeiro, guarita) e o teto some pela oclusão existente quando a câmera olha por cima. Quem dorme (Mira, Brom e Nino) vai para dentro da própria casa e fica sentado, no lugar de sumir.
- **Quadro de avisos e sino:** ações novas no universo, `ler-quadro` (privada a quem lê, mostra o que está afixado) e `tocar-sino` (evento público; o motor recusa um segundo toque até a vila se acalmar, 8 ticks). No cliente são pontos de interesse com adereços. `--autotest=board` (Jev ligado): ambos oferecidos pelo menu e aceitos pelo motor (`ler-quadro:ok`, `tocar-sino:ok`). A leitura do quadro foi seguida da oferta "Minério para a forja" (já era comportamento do motor: ato testemunhado).
- **Conversas:** de 9 para 34 (um quarto delas ligado a crenças dos falantes). Num dia inteiro do `--autotest=f1`: 81 falas ouvidas, 24 horas vistas, 5 dos 6 NPCs trocando de lugar.
- **Testes do motor:** `go test -count=1 ./...` passa, com `TestBoardAndBell` novo. O teste do chá (`TestUselessSpellsFuseAndBecomeFamous`) dependia de o Velho Tomas estar na estrada; passou a seguir a rotina dele.
- **Regressão de combate no mapa novo** (`--autotest --threat=estrada`, Jev ligado): bandidos e javalis apareceram e foram enfrentados (6 abates, 3 javalis); a confirmação de bandidos foi recusada pelo motor por requisitos (esperado: o acontecimento "bandidos" não existia no mundo, o teste forçou o grupo), 261 fps na floresta, pior quadro 6,6 ms.
- **Continua fora:** POIs lidos do universo e tabela de apresentação (a ligação ação→lugar é apresentação do cliente, não regra; fica em `places.gd`).

## 22/10/2026 — F2: chegada

Motor com o Jev (porta 8095, tick de 15 s), mundo novo. `--autotest=arrival` com personagem novo:
- Chega em `estrada` (carroça de Lia ao lado), mapa só com a Estrada do Leste, **0 ofertas em 20 s parado**. Cartão de abertura ("Valdoria / Ninguém sabe o seu nome") conferido em captura.
- Fala de Lia ao conversar (balão e registro): "Chegamos! A vila fica logo depois do portão…"; fala de Orin a um estranho: "Nome? De onde vem?…". Com o personagem na vila, ler o quadro (um feito) trouxe a primeira oferta; a cerimônia "O Sistema percebeu você." apareceu antes do cartão da missão (captura conferida).
- **Voltando:** repetir com o mesmo personagem mostrou "Enquanto você esteve fora" com os acontecimentos desde a última visita (uivos de lobos, luzes no selo), centralizado; os lugares já conhecidos não são mais anunciados ao carregar.
- Regressão: `--autotest=board` e `--autotest=places` passaram, mas no `places` o `forjar` foi recusado por requisitos: naquele mundo o minério estava amaldiçoado (acontecimento do diretor), regra correta do motor e não defeito do mapa.
- **Não feito da F2:** mostrar ao jogador "quem me conhece" (fica para o Caderno, F3); o resumo pega só eventos públicos ou privados do próprio jogador que o motor ainda guarda (até `maxEvents`).

### 22/10/2026 — pendência final da F1: apresentação em dados

Os pontos de interesse (id, região, deslocamento a partir da origem da região, rótulo, entidade que representam, ações que ancoram) e as animações por ação saíram do código para `clients/godot/data/presentation.json`; `places.gd` só os lê. Teste do motor novo, `TestClientPresentationMatchesTheUniverse` (`engine/scenarios/presentation_test.go`): o arquivo só pode citar regiões, entidades e ações que existem em Valdoria, sem ponto duplicado nem ponto que não ancore nada. `go vet` e `go test -count=1 ./scenarios` passam; `--autotest=board` e `--autotest=places` (Jev ligado) passaram com os pontos vindos do JSON, exceto o `forjar` do `places`, recusado por requisitos porque o minério está amaldiçoado neste mundo (regra do motor, como na rodada da F2); mina, ruínas, toca e Pipo funcionaram.

### 22/10/2026 — revisão da F2 contra o plano

Conferido item por item. Faltava "todos sabem dizer quem os conhece": a visão ganhou `knowsYou` em cada pessoa (verdadeiro quando ela acredita conhecer o observador; é público para quem a vê, pois se nota pela saudação) e o cliente pinta o nome de dourado e mostra "[te conhece]" de perto. `TestViewShowsWhoKnowsYou` (motor) e `--autotest=arrival` (Jev ligado): ninguém conhece o recém-chegado ao chegar; depois da conversa com Orin e do quadro, Brom, Elena, Mira, Nino e Orin passam a conhecê-lo; captura conferida.
**Continua sem fazer na F2:** saudações faladas espontâneas ao se aproximar de quem já conhece (hoje só ao conversar); playtest com pessoas de verdade e com 2 jogadores ao mesmo tempo (previsto para F6/F7); latência e custo do Jev não foram medidos nesta fase (o Jev rodou nos testes, sem registro de números).

### 22/10/2026 — saudação espontânea (fecha a lacuna da F2)

Quem conhece o jogador (`knowsYou`) diz uma frase curta ao ele chegar a menos de 4 m, e de novo depois de ele se afastar a mais de 7 m (falas por NPC em `data/presentation.json`, conferidas por `TestClientPresentationMatchesTheUniverse`). `--autotest=arrival` (Jev ligado): afastar-se de Orin e voltar gerou 1 saudação (o intervalo mínimo de 2,5 s entre saudações limita a uma por vez).

## 22/10/2026 — F3: saber

Jev ligado (porta 8095, tick de 15 s; e uma segunda instância em 8097 com tick de 700 ms para ver a história andar). `--autotest=saber`:
- Vestígios da vila aparecem como uma luz pálida com uma frase curta (cenouras roídas, marca na bigorna, lápide; com a doença, a tosse na praça); `E` examina; o relato aparece sobre o personagem e no registro.
- **Caderno (`C`)**: "Perguntas em aberto" ("Quem deixa pegadas pequenas na horta e some para o oeste?"), "O que você sabe" com a **fonte** de cada crença ("vi com meus olhos", "ouvi de X", "foi anunciado a todos"; crença desatualizada aparece como "Acredito que NÃO…"), abas Pessoas (quem conheci, se me conhece, onde) e Lugares. Capturas conferidas.
- **Contar pelo menu:** com o mundo avançado, o menu de Brom listou "Contar a Brom: Há bandidos na Estrada do Leste / O Nino sumiu / O minério… / Lobos rondam…" e a escolha foi aceita (`contar:ok`).
- Regressão: `--autotest=arrival` e `--autotest=board` passaram.
**Feito do plano:** sinais com hora e habilidade, examinar, contar com reações (novidade, já sabia, desatualizado), crenças com fonte no Caderno, esboço de Tomas (motor), "bot de descoberta".
**Não feito da F3:** a lupa com cursor (o vestígio é examinado com `E`, sem lupa); vestígios da moeda e da canção da alvorada (7 dos 11 enigmas do plano têm vestígio; os 4 externos ficam para a F4: pegada branca, veios roxos e mina já estão, mas só se testou o conjunto da vila); crenças erradas ditas por NPCs de propósito; o esboço de Tomas não foi exercitado pela interface (só pelo motor); "mapa desenhado andando" é o mapa em branco que se revela por região, sem traçado de caminhos; nenhuma medição de latência/custo do Jev nesta fase; nenhum playtest com pessoas.
