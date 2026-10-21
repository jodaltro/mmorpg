# Validação — cliente Unreal

Só o que realmente rodou. Máquina: Windows 10 19045, AMD Radeon RX 5700 XT (driver 32.0.21045.16010), Unreal 5.8.3 (CL 58902052) em `C:\Program Files\Epic Games\UE_5.8`, VS 2022 MSVC 14.44, projeto `C:\UnrealProjects\WorldSimDemo` (template Third Person BP, fora do repositório).

## 21/10/2026

### Compilação do plugin `WorldSim`

- `tools/unreal/build.ps1` (sync do plugin + `Build.bat UnrealEditor Win64 Development`): **Succeeded**, 0 erros, 0 avisos (237 s na primeira compilação em C:).
- Com o editor aberto a compilação falha: `Unable to build while Live Coding is active` (exit 6). É preciso fechar o editor ou desligar o Live Coding (Ctrl+Alt+F11).
- `ServerUrl=http://...` no `DefaultGame.ini` virava `http:`: o parser de ini da Unreal trata `//` como comentário. Trocado por `ServerHost` + `ServerPort`; a URL é montada no código. Log confirmado: `WorldSim: client for http://127.0.0.1:8095 as ana`.

### Play test headless contra o motor

Motor: `worldsim serve -universe ../universes/valdoria/universe.json -data ../data -tick 1s -advisor deterministic -listen 127.0.0.1:8095`.

Jogo: `UnrealEditor-Cmd.exe WorldSimDemo.uproject /Game/ThirdPerson/Lvl_ThirdPerson -game -nullrhi -unattended -nosplash -nosound "-ExecCmds=ws.sequence 4 ws.status | ws.act examinar-poco | ws.move floresta | ws.status | ws.act descansar | ws.status | quit"`.

| Passo | Resultado |
|---|---|
| conexão | `client for http://127.0.0.1:8095 as ana` |
| join (1ª rodada) | `join accepted` |
| join (2ª rodada) | `409 rejected: actor exists` (Ana já existia; o cliente segue) |
| ofertas recebidas | `[E] Minerio para a forja` (Brom), `[E] Os aldeoes estao adoecendo` e `[E] Ervas para a curandeira` (Mira); estados `expired` e `withdrawn` chegaram ao cliente |
| habilidade | `SKILL Ouvido de Taverna (rara)` + evento público `fame` |
| `ws.status` | `tick 467` → `479` → `487`, 3 quests |
| `ws.act examinar-poco` | `act accepted` |
| `ws.move floresta` | `move accepted` |
| `ws.act descansar` na floresta | `409 rejected: requirements` (autoridade do motor recusou, correto) |
| `quit` | o jogo saiu sozinho, exit 0 |

Defeito encontrado e corrigido: no PowerShell 5.1, `Start-Process -ArgumentList @(...)` não põe aspas nos itens, e `-ExecCmds=ws.sequence 4 ...` chegava partido (a Unreal recebia só `ws.sequence`). O `play-test.ps1` passa a montar uma linha única com aspas.

### Unreal MCP

- Editor aberto com `tools/unreal/editor.ps1` (`-ModelContextProtocolStartServer -ModelContextProtocolPort=8000`): `initialize` em `http://127.0.0.1:8000/mcp` respondeu 200 em 30 s.
- Com a sessão reconectada (`/mcp`), `list_toolsets` listou 40+ toolsets (cena, assets, Blueprint, material, PCG, Sequencer, automação, logs, Slate) e `SceneTools.get_current_level` retornou `/Game/ThirdPerson/Lvl_ThirdPerson`.
- O editor caiu às 17:23 sem ação nossa: `DXGI_ERROR_DEVICE_REMOVED`, com 2,6 de 7,3 GB de VRAM em uso (não é falta de memória). Provável reset do driver da RX 5700 XT.

### Assets CC0

Baixados em `C:\UnrealProjects\WorldSimDemo\Downloads` (fora do repositório; não versionar):

| Pacote | Origem | Bytes |
|---|---|---|
| Medieval Village MegaKit [Standard] | quaternius.itch.io | 161.003.471 |
| Stylized Nature MegaKit [Standard] | quaternius.itch.io | 104.088.529 |
| Fantasy Props MegaKit [Standard] | quaternius.itch.io | 150.213.360 |
| Universal Base Characters [Standard] | quaternius.itch.io | 128.968.391 |
| Modular Character Outfits - Fantasy [Standard] | quaternius.itch.io | 294.347.394 |
| Universal Animation Library [Standard] | quaternius.itch.io | 15.904.933 |
| Fantasy Town Kit 2.0 | kenney.nl | 3.854.691 |
| kloofendal_48d_partly_cloudy_puresky 2k HDR | polyhaven.com | 5.451.493 (md5 confere) |

Importação headless (`UnrealEditor-Cmd -run=pythonscript -nullrhi`, Interchange glTF/GLB/HDR, ~16 min), **0 falhas**:

| Destino | Arquivos | Objetos | s |
|---|---|---|---|
| /Game/Valdoria/Village | 176 | 1330 | 360 |
| /Game/Valdoria/Nature | 68 | 264 | 159 |
| /Game/Valdoria/Props | 94 | 706 | 256 |
| /Game/Valdoria/Kenney | 167 | 528 | 43 |
| /Game/Valdoria/Characters/Base | 2 | 31 | 5 |
| /Game/Valdoria/Characters/Hair | 8 | 48 | 8 |
| /Game/Valdoria/Characters/Outfits | 4 | 84 | 26 |
| /Game/Valdoria/Characters/Parts | 20 | 163 | 103 |
| /Game/Valdoria/Animations | 2 | 96 | 10 |
| /Game/Valdoria/Sky | 1 | 1 | 0 |

Escala medida: Quaternius em tamanho real (parede 2 × 3,12 m, árvores ~7 m); Kenney em 1 m (usado com escala 2,5–3). As roupas modulares vieram com um esqueleto por peça: montar NPCs exige esqueleto compartilhado (pendente).

### Nível `Lvl_Valdoria`

Montado por script headless (`spawn_actor_from_object` não gera atores em commandlet; `spawn_actor_from_class(StaticMeshActor)` + `set_static_mesh` funciona; `save_current_level` falha em nível novo, `EditorLoadingAndSavingUtils.save_map` funciona): 892 meshes, 902 atores, 0 assets faltando. Praça com fonte e Poço Antigo, Forja do Brom, Casa da Mira, Taverna, 2 casas, feira, cerca, estrada até a Floresta Cinzenta (140 árvores + 220 detalhes, semente fixa), céu (SkyAtmosphere, nuvens, neblina, sol), `BP_ThirdPersonGameMode` e volumes `WorldSimRegionVolume` para `vila`, `estrada` e `floresta`.

Via MCP com o editor aberto: `load_level`, `CaptureViewport` (imagem conferida), `ProgrammaticToolset.execute_tool_script` reescalou 401 plantas, e o nível foi salvo clicando em "Salvar nível atual" pelo `SlateInspectorToolset` (Ctrl+S por `PressKey` não salvou: o foco estava na janela "Log de Mensagens").

Template incompleto: o projeto não tinha os pacotes compartilhados do `TP_ThirdPersonBP` (`TemplateDefs.ini`: `Characters`, `Input`, `LevelPrototyping`), daí os erros de `IA_Jump`/`IA_Move`/`SKM_Quinn_Simple`. Copiados de `Templates\TemplateResources\High\*\Content`: erros de Blueprint no jogo caíram de dezenas para **0**.

Play test headless em `Lvl_Valdoria` (`ws.sequence 5 ws.status | ws.move vila | ws.act examinar-poco | ws.status | quit`): `move accepted`, `act accepted`, e em seguida **OFFER from Velho Tomas: [S] Cenario Unico: A Origem da Maldicao** com a quest da Mira retirada; jogo saiu com exit 0.

Defeito encontrado e corrigido: o `WorldSimRegionVolume` não reportava a região quando o jogador **nasce** dentro dele (o overlap acontece antes de o pawn ser possuído e era descartado). Agora o `BeginPlay` agenda uma checagem de 1 s com `IsOverlappingActor(GetPlayerPawn(0))`. Build: Succeeded (61 s). Verificação com `play-test.ps1` (mapa padrão `Lvl_Valdoria`):

1. `ws.sequence 4 ws.move floresta`: `move accepted` + evento `moved: Floresta Cinzenta`.
2. Nova sessão, nascendo na vila, sem comando de movimento: `move accepted` 1 s após nascer; depois `ws.act examinar-poco` → `act accepted` (só vale na vila) e `SKILL Olho de Curandeira (incomum)`; `ws.status` → tick 4905, 6 quests; saída limpa.

### Game Animation Sample (motion matching) como jogador

- Projeto `C:\UnrealProjects\GameAnimationSample` (Fab, `EngineAssociation` 5.8, só Blueprint, 6,95 GB) criado pelo usuário no Launcher.
- `tools/unreal/migrate-gasp.py`, rodado headless **no projeto do sample**: dependências fortes e fracas de `GM_Sandbox`, `PC_Sandbox` e `SandboxCharacter_CMC` → **2.861 pacotes** migrados para o WorldSimDemo, sem erro (`/Game/Characters` 2051, `/Game/MetaHumans` 365, `/Game/Audio` 278, `/Game/Blueprints` 126, `/Game/Levels` 21, `/Game/Input` 19, `/Game/Misc` 1). O C: foi de 14,1 para 9,8 GB livres.
- Configuração copiada à mão no projeto (backups `*.bak-gasp`): canais `Traversable`, `Mouse` e `Obstacle` + perfil `Ragdoll` no `DefaultEngine.ini`; os 20 plugins do sample no `.uproject` (PoseSearch, Chooser, MotionWarping, Mover etc.); `DefaultGameplayTags.ini` e `DefaultNetworkPrediction.ini`.
- `tools/unreal/use-gasp.py`: `Lvl_Valdoria` passa a usar `GM_Sandbox` (pawn `SandboxCharacter_Mover`, controller `PC_Sandbox`); salvo. 0 erros de Blueprint.
- Play test headless: a primeira rodada levou ~57 s no quadro 0 (carga dos assets novos) e todos os passos dispararam juntos antes da sincronização (`tick 0`); a segunda, com cache quente (79 s no total): volume → `move accepted` ao nascer, `ws.move floresta` / `ws.move vila` aceitos, `ws.act examinar-poco` aceito, **OFFER [S] Cenario Unico: A Origem da Maldicao**; tick 6136 → 6151; 0 erros de Blueprint/script.
- Play no editor via MCP (`StartPIE`, `CaptureEditorImage`, `StopPIE`): o manequim do sample aparece na estrada da vila, com câmera de gameplay do sample.
- Aviso não bloqueante: `GameFeatureData` não está em `PrimaryAssetTypesToScan` (vem do plugin GameplayInteractions).
- Pendente: andar com o personagem por entrada real (o teste headless não move o pawn), checar travessia (`Traversable`) nas casas da vila e montar os NPCs da Quaternius com esqueleto compartilhado.

### Testes de movimento sem teclado (input injetado)

Pesquisa: a Unreal tem CLI (`UnrealEditor-Cmd` para commandlets e jogo headless, `RunUAT` para BuildCookRun e Gauntlet, `Build.bat`), mas nada que mova o personagem. O caminho escolhido foi a API do Enhanced Input, `StartContinuousInputInjectionForAction`, que injeta valor numa Input Action a cada tick passando pelos mesmos modifiers e triggers do teclado. Alternativas vistas: Gauntlet controllers (C++, para builds empacotadas e multi-processo), Functional Tests, Automation Driver (UI) e ferramentas comerciais (GameDriver, modl:test).

Plugin: novo `WorldSimTestCommands.cpp` com `ws.input <ação> x [y] [z] [seconds=N]`, `ws.inputstop`, `ws.face <yaw>`, `ws.pos` e `ws.track <intervalo> <n>`. O `ws.sequence` passou a esperar o pawn existir e a encadear os passos (antes, um primeiro quadro de ~57 s fazia todos dispararem juntos). Dependência `EnhancedInput`. Build: Succeeded.

Caminhada vila → floresta (`ws.sequence 3 ws.face -90 | ws.track 2 20 | ws.input IA_Move 0 1 seconds=36 | ...`, sem janela):

1. Primeira rodada: entrou na estrada (`moved: Estrada do Leste`) e parou em y ≈ -2492 com velocidade pedida de 500. Um script headless listou o que cruzava o caminho: duas árvores da coroa em volta da vila em cima da estrada e capim/trevo com colisão `BlockAll`.
2. Correções no `build-valdoria.py`: vegetação baixa sem colisão (`NoCollision`), nenhuma árvore no corredor da estrada, carroça fora do caminho, escala das plantas reduzida e `GM_Sandbox` como game mode quando o sample foi migrado. Nível recriado: 890 meshes, 0 faltando.
3. Segunda rodada: `TRACK` de 2 em 2 s de y -1300 até -6856 a 500 cm/s; os volumes reportaram sozinhos `Vila Cinzenta` → `Estrada do Leste` → `Floresta Cinzenta`; ofertas do mundo continuaram chegando no caminho (`[C] As Ruinas de Asterion`, `[S] Cenario Unico: A Origem da Maldicao`). Parou contra uma árvore na entrada da floresta.

### Sessão pela Unreal com o Jev decidindo no servidor

Servidor: `worldsim serve -advisor jev -env-file .env -tick 1s` (modelo `typesafe/jev-1.13-20260917`, prazo de 5 s por chamada), mesmo mundo em `data/` (tick 7667 no início).

Roteiro (`play-test.ps1`, sem janela, personagem do Game Animation Sample): `ws.accept`, `ws.face -90`, `ws.input IA_Move 0 1 seconds=11` até a floresta, `ws.occur colher-ervas-campo` ×3, `ws.occur cacar-javali`, volta com `ws.face 90` e `ws.input`, `ws.act examinar-poco`.

- O Jev escolheu a oferta do **Velho Tomás, [S] Cenário Único: A Origem da Maldição** (a da Mira foi retirada); `ws.accept` → `QUEST -> active`.
- Regiões reportadas pelos volumes: vila → estrada → floresta; ervas ×3 e javali confirmados (`herbs`, `boar`); habilidade **Andarilho (comum)**.
- Na volta a Ana parou numa tocha na beira da estrada (x = 260) e `examinar-poco` foi recusado com `requirements` (ainda na estrada, correto). Tochas movidas para x = 420 no `build-valdoria.py`; nova ida e volta: vila → estrada → floresta → estrada → vila e `examinar-poco` → `act accepted`.

Decisões gravadas no log durante a sessão (lidas de `data/valdoria.jsonl` a partir do offset do início): **26, todas `provider: jev`, nenhuma pelo padrão determinístico**.

| Tipo | n | latência média | máxima | custo |
|---|---|---|---|---|
| world (diretor) | 22 | 566 ms | 1.390 ms | US$ 0,000909 |
| offer (Ana) | 4 | 534 ms | 575 ms | US$ 0,000266 |

Confiança das ofertas: 0,91–0,99. Diretor: 0,07 (`feira-magos`) a 0,73 (`crianca-perdida`). Nenhuma decisão de história (`story`) ocorreu nesse intervalo.

### Várias jornadas pela Unreal com o Jev (seis personas)

`tools/unreal/scenarios.ps1` joga seis jogadores, um por execução headless (`ws.join`), cada um com um estilo: **ana** (arco principal), **bruno** (combate), **clara** (curandeira, fica na vila), **davi** (recusa tudo), **elisa** (exploradora) e **fabio** (artesão). Movimento no nível por input injetado; outras regiões por `ws.move`; confirmações do servidor de jogo por `ws.occur`. `tools/unreal/journeys.ps1` compara as visões (`/v1/views/{id}`) e as decisões no log.

**Rodada 1, mundo existente (Ana já com o Cenário Único ativo).** 108 decisões, todas do Jev (83 world, 24 offer, 1 story), média ~530 ms, máxima 679 ms, US$ 0,005. Ana concluiu **A Origem da Maldição** seguindo o rastro; o Jev escolheu o capítulo seguinte (`story:maldicao:origem -> restaurar`, conf 0,68); **Restaurar o Selo** foi oferecido a bruno, davi e elisa (bruno e elisa aceitaram e disputam o capítulo); fabio entrou no arco do ferreiro (**A Bigorna Esquecida**); clara concluiu a quest do poço; davi recusou 7 quests e ganhou **Teimosia Lendária (absurda)**; elisa ganhou **Chá Morno (absurda)**. Estilos medidos: ana mistério/exploração, bruno combate, clara social/mistério, elisa exploração, fabio artesanato, davi nenhum.

**Defeito encontrado:** os seis ganharam **Ouvido de Taverna (rara)** só por ouvir 12 boatos (boatos chegam a todos; o Brom conta 5 na entrada). Correção no universo: 20 boatos **e** `descansar` 2 vezes (só à noite, na vila). Teste `TestTavernEarNeedsNightsInTheVillage` (600 ticks parado não ensina; duas noites de descanso ensinam). `worldsim validate` ok; `simulate -ticks 600 -players 6`: 3 de 6 bots aprenderam (eles descansam à noite).

**Rodada 2, mundo novo** (`-data %TEMP%\worldsim-fresh`, universo corrigido, Jev). 123 decisões, todas do Jev (88 world, 34 offer, 1 story), média ~530 ms, máxima 669 ms, US$ 0,0058.

| Jogador | Estilo medido | Jornada |
|---|---|---|
| ana | mystery 4, explore 1 | conquistou **origem** no tick 94 (chegou ao selo antes da oferta; a crônica pública credita "Ana"); aceitou **Restaurar o Selo**; concluiu a quest do poço |
| bruno | combat 4 | aceitou **Restaurar o Selo** (disputa com Ana) |
| clara | mystery 3, social 2 | concluiu **Os aldeões estão adoecendo**; ervas ativas |
| davi | nenhum | 16 ofertas, recusou 6 e deixou expirar o resto; **Teimosia Lendária (absurda)** |
| elisa | mystery 3, explore 3 | concluiu a quest do poço; **Restaurar o Selo** oferecido |
| fabio | craft 6 | concluiu **A primeira peça: minério corrompido** (arco do ferreiro); **Achar Botões (absurda)** |

Story: `maldicao:origem -> restaurar` (conf 0,88). Ninguém aprendeu Ouvido de Taverna nessa rodada. Rejeições do motor por requisitos (ações fora de lugar, hora ou habilidade) aconteceram em todas as personas e são esperadas (ex.: `descansar` de dia, `diagnosticar` sem a habilidade).

### Interface de jogo (sem console) e tela inicial

Plugin: `WorldSimHUD` (Slate, sem assets) e `WorldSimInteractable`. Tela inicial: **Continuar** (lista `GET /v1/players`), **Novo personagem** (nome digitado → id, nunca reaproveita o de outro) e **Novo mundo** com confirmação (`POST /v1/world/reset`, o mundo anterior é arquivado). HUD: personagem/região/dia, missão ativa, janela de sistema da oferta com **[Y] Aceitar / [N] Recusar**, feed do mundo, avisos (inclusive recusas do motor), banner de região, toast de habilidade por raridade, prompt **[E]** e diário **[J]**. Execuções `-unattended` continuam com auto-join (scripts de teste intactos). `build-valdoria.py` coloca 15 interativos: NPCs com corpo (Brom, Mira, Elena, Orin, Tomás, Lia, Kael — manequim com `ABP_Unarmed`), Poço, Bigorna, Banco, Tenda dos Magos, Telhado, e na floresta Rastro, Ervas e Javali (confirmados pelo jogo). `Jogar Valdoria.bat` → `tools/unreal/play.ps1`: sobe o servidor (Jev, `-on-universe-change new-world`) e abre o jogo em janela própria.

Verificado no editor via MCP (PIE + `SlateInspector` + `CaptureEditorImage`), servidor com Jev em mundo novo:

1. Tela inicial sem servidor novo: mensagem "Servidor do mundo fora do ar" (o binário antigo não tinha `/v1/players`). Com o servidor novo: "Nenhum personagem neste mundo ainda".
2. Nome "Jodaltro" digitado + "Criar e jogar" → `GET /v1/players` = `jodaltro`, Vila Cinzenta.
3. HUD: nome, região e dia; janela de sistema "Mira, a curandeira chama voce — Ervas para a curandeira, Rank E, objetivo, recompensa, [Y]/[N]"; feed com boatos; nomes flutuantes no cenário.
4. Tecla **Y** (enviada ao jogo) → a missão ficou `active` no servidor e o painel de missão mostrou o objetivo.
5. Perto da tenda apareceu "[E] Trocar magias na Tenda dos Magos". A tecla E em si não foi enviada nesse teste (o foco estava no console do editor).
6. `play-test.ps1` (unattended) continuou entrando sozinho como `ana`, andando e reportando a estrada.

Servidor: o mundo salvo em `data/` tinha sido criado com uma versão anterior do universo e o `serve` recusava (`log_belongs_to_another_universe`). Nova opção `-on-universe-change new-world`: arquiva (`valdoria-20261021-231555.jsonl`, 921 KB, intacto) e começa um mundo novo; sem a opção continua recusando, agora com mensagem explicando o que fazer.
