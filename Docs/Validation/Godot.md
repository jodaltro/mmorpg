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
