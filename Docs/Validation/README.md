# Evidências da validação

Executado em 13/10/2026 no Editor Unity 6000.6.5f1 conectado pela Unity CLI 1.0.0-beta.13 / Pipeline 0.8.0-exp.1.

- `compile.json`: compilação concluída sem erros.
- `editmode.json`: 5/5 testes passaram, sem ignorados.
- `playmode.json`: 6/6 testes passaram, sem ignorados.
- `build.json`: build StandaloneWindows64 **Succeeded**, 0 erros, 2 avisos, aproximadamente 107,5 MB.
- `console.json`: estado final do console, sem erros de compilação ou gameplay.
- `playtest.png`: captura da Game view com HUD de morte/reinício, personagem, lobo e obstáculos; imagem inspecionada.

Executável: `Builds/Windows/Mmorpg.exe`. Distribua a pasta Windows inteira, incluindo `Mmorpg_Data`, UnityPlayer e MonoBleedingEdge; o exe isolado não basta. O build foi compilado, mas não foi aberto manualmente; o comportamento foi validado no Editor pela suite PlayMode e sessão visual.

Os dois avisos do build foram: ausência de RuntimePipelineConfig (ferramenta Pipeline desabilitada no Player) e aviso Unity de mudanças ainda não compiladas em código de pós-processamento/importação. O build terminou com sucesso; a compilação do Editor após o build também terminou sem erros. Nenhum código customizado de pós-processamento/importação foi incluído nesta entrega. O registro histórico Pipeline contém um timeout de eval ocorrido na inspeção inicial; os contadores atuais do console ao validar gameplay indicaram zero erros.

Na sessão visual final, `Time.frameCount` avançou de 390 para 9787, comprovando execução contínua com o Editor sem foco. O HUD mostrou morte após ataques do lobo ao jogador parado, sem exceções de gameplay. PlayMode foi encerrado, deixando a cena jogável aberta.

EditMode cobre morte, limites de vida, janelas de esquiva/imunidade, cooldowns, entradas inválidas e direção cardinal. PlayMode carrega a cena real e cobre física contra obstáculos, teclado do Input System, ataque, esquiva, vida/morte, reinício, visão/ataques bloqueados por parede e máquina de estados do lobo.

A primeira execução PlayMode revelou um problema no helper de reposicionamento dos testes: o Rigidbody era teleportado antes de seu Transform ser atualizado. O helper foi corrigido para atualizar ambos e sincronizar colliders. A suite completa foi executada novamente e passou. A execução em segundo plano foi habilitada para impedir que o Editor sem foco congelasse no primeiro frame.

## Arquivos entregues

- `AGENTS.md`: regras de manutenção do projeto.
- `Docs/Architecture.md`: arquitetura, parâmetros, controles, limites e comandos de teste.
- `AgentScripts/BuildOfflineScene.cs`: gerador de cena/assets via Editor; recusa sobrescrita.
- `Assets/Mmorpg/Domain`: `CombatState.cs`, `CombatRules.cs`, assembly sem Unity.
- `Assets/Mmorpg/Runtime`: `ActorHealth`, `ActorMotor`, `OfflineAuthority`, `PlayerController`, `WolfBrain`, `CameraFollow`, `ActorVisual`, `GameSession`, `HealthHud`, assembly Runtime.
- `Assets/Mmorpg/Tests/EditMode` e `PlayMode`: duas suites e assemblies de teste.
- `Assets/Mmorpg/Scenes/OfflineClearing.unity`: cena jogável serializada.
- `Assets/Mmorpg/Art`: sprites `Hero.png`, `Wolf.png`, `Square.png`, material unlit.
- `Assets/TextMesh Pro`: recursos Essentials importados para o HUD.
- Metadados `.meta` gerados pelo Editor para todos os assets.

Configurações alteradas: `TagManager.asset` (camadas Obstacles e Actors), `EditorBuildSettings.asset` (nova cena em primeiro lugar). SampleScene e dependências existentes preservadas. Nenhum commit foi criado.
