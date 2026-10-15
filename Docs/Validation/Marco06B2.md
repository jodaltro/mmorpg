# Marco 06B.2 — personagem, movimento, espada e HUD

14/10/2026 · Unity 6000.6.5f1. Entrega para avaliação manual do usuário; as inspeções abaixo não constituem aprovação automática de gameplay, arte ou balanceamento.

## Jogar

Abra `Assets/Mmorpg/Scenes/Marco06B2World.unity` e pressione Play. A cena foi criada como cópia da `Marco06B1World.unity`, que foi preservada. A B2 está no primeiro lugar dos Build Settings. As cinco regiões, NPCs, criaturas, coleta, inventário e acontecimentos anteriores continuam nos sistemas existentes. Não há dependência de Go, Supabase ou Jev para jogar.

| Controle | Ação |
|---|---|
| WASD / setas | Movimento físico livre em oito direções |
| Mouse | Orientação do personagem e da espada, independente do movimento |
| Clique esquerdo / J | Ataque básico |
| Clique direito | Golpe pesado existente |
| Espaço / Shift esquerdo | Esquiva, incluindo diagonais |
| E | Interagir, coletar ou fechar diálogo |
| I | Inventário |
| Tab | Diário |
| Esc | Fechar diálogo; fora dele, pausar / continuar |
| Q / F / C | Leitura, contra-ataque e marca existentes, respeitando os desbloqueios |
| R após morrer | Retomar no ponto seguro da região |

F9 continua restrito ao Editor como ferramenta de técnicas isoladas; não grava desbloqueios. Debug administrativo fica desativado na cena de gameplay. Nenhuma interface de propostas de missões foi implementada.

## Diretrizes e componentes reutilizados

`Docs/GameVision.md` registra os quinze princípios obrigatórios: action RPG em tempo real; mundo com memória; Jev contextual e assíncrono; oportunidades proativas que podem ser aceitas, recusadas ou ignoradas; uma missão ativa e uma proposta pendente por personagem; elegibilidade após conclusão/abandono; candidatos baseados em acontecimentos confirmados e validados pelo domínio; progressão sem leveling; múltiplas formas de descoberta e evolução; diversão offline. `AGENTS.md` exige consultar essa visão antes de alterar gameplay ou progressão. O novo modelo de missões permanece apenas documentado.

Foram reutilizados `ActorMotor`, `PlayerController`, `CombatState`, `OfflineAuthority`, `ActionCombat`, `ActorHealth`, os brains existentes, `ExplorationWorld`, a interação, os painéis de inventário/diário e os indicadores de marca. A espada é um adaptador espacial da mesma autoridade, não outro motor de combate. Nenhum serviço, quest, habilidade ou criatura foi adicionado.

## Movimento e esquiva

O motor action existente usa `Vector2.ClampMagnitude`, `Rigidbody2D.linearVelocity` e aceleração/desaceleração serializadas (65 / 85 por padrão). Velocidade normal: 3,5 unidades/s tanto nas diagonais quanto nos eixos. Não há prioridade vertical. O Rigidbody do jogador usa interpolação. O controle mira novamente após aplicar a intenção de movimento, preservando a independência entre mira e deslocamento.

Durante a espada, o multiplicador de movimento configurável é 0,55: aproximadamente 1,93 unidades/s. A esquiva continua com duração 0,22 s, velocidade 9 e cooldown 0,9 s, com invulnerabilidade da regra existente. Cancelar a animação pela esquiva não devolve o cooldown consumido.

## Espada, hitbox e animação

`SwordSwing` anima preparação, arco ativo e recuperação pelo mesmo relógio usado para a detecção. Básico: 0,06 / 0,14 / 0,16 s, cooldown 0,4 s e alcance 1,25. Pesado: preparação existente de 0,38 s, mesma janela ativa/recuperação, cooldown 1,2 s e alcance 1,65. O arco padrão é 110 graus. Durações, arco, espessura, posição da mão, cooldown e movimento durante o ataque são configuráveis nas referências serializadas existentes e novas.

A direção é capturada ao iniciar o golpe. Durante os frames ativos, cápsulas de overlap cobrem a lâmina entre a mão e a ponta, amostrando todo o intervalo angular desde o frame anterior em passos de até 3 graus e deslocamentos de até 0,04 unidade. A margem da cápsula cobre espaços entre amostras. Um buffer de 48 colliders é reutilizado; um HashSet reutilizado impede mais de um impacto por alvo no golpe. Linhas de visão a partir do corpo e da mão bloqueiam paredes. A autoridade conserva validações de facção, vida, invulnerabilidade, área segura, dano e bônus existentes. Não há HTTP na decisão de acerto.

A espada fornecida tem pivô no cabo, rotação local calibrada pelo vetor cabo/ponta e comprimento equivalente a uma unidade antes de aplicar o alcance do golpe. A ordem de renderização alterna à frente/atrás do corpo. A arma continua orientável em ângulos intermediários às oito orientações do corpo.

Os assets de `assets_para_usar` foram integrados em `Assets/Mmorpg/Art/Provided06B2`: personagem com idle e duas poses de locomoção em oito direções, espada, quatro frames de impacto, NPCs, criaturas existentes, pisos e props, além de ícones dos slots existentes. As malhas dos frames do personagem ocultam a espada embutida para utilizar uma lâmina separada. Os PNGs originais e suas cópias permanecem idênticos por hash. Detalhes de origem, importação e recortes: `Docs/ProvidedArt06B2.md`.

## HUD, câmera e feedback

Vida compacta no canto superior esquerdo; região no canto superior direito; seis slots inferiores com ícones e preenchimento visual de cooldown. Técnicas indisponíveis permanecem esmaecidas. Não foi criada barra de recurso porque este recorte não possui um recurso consumível de combate. Inventário, diário, pausa, interação contextual, coleta e indicação de alvo existentes foram preservados. Nomes de NPCs e estados do diário usam apresentação legível, sem IDs internos. Canvas Scaler: Scale With Screen Size, referência 960×540 e match 0,5, com âncoras nos cantos e centro inferior.

Câmera com SmoothDamp curto de 0,045 s e acompanhamento quantizado na grade de 16 PPU; URP PixelPerfectCamera existente no pipeline correto, referência 320×180, PixelSnapping e Windowbox. HDR, MSAA e resolução dinâmica da câmera desativados. Assets fornecidos: Point, sem mipmaps/compressão, 128 PPU, com escala visual ajustada e colisões preservadas. Pisos de 64 pixels usam matrizes de célula 2× para preencher uma unidade.

Locomoção tem frames direcionais; ataque tem brilho e rastro leve; acerto tem animação de impacto; dano usa o flash existente; esquiva usa a apresentação ciano existente; morte tem impacto, aviso e estado visual existente. `PlayerCombatFeedback` disponibiliza eventos e clips serializados para passos, ataque, acerto, esquiva e morte. Nenhum áudio adequado foi fornecido: os hooks estão prontos, mas os clips continuam vazios.

## Arquivos criados e alterados

- Criados: `Docs/GameVision.md`, `Docs/ProvidedArt06B2.md`, este relatório e evidências `m06b2-*` nesta pasta.
- Criados: `Runtime/SwordSwing.cs`, `RpgSkillBar.cs`, `PlayerCombatFeedback.cs`, `DirectionalSpriteAnimation.cs`, `SheetImpactFeedback.cs` e `WorldArtSorting.cs`, em `Assets/Mmorpg`.
- Criados: `Assets/Mmorpg/Scenes/Marco06B2World.unity`, `Assets/Mmorpg/Art/Provided06B2/*`, a espada/frames provisórios `Sword06B2.png` e `HeroWalk06B2_*.png` (substituídos visualmente pelos assets fornecidos), e respectivos `.meta` gerados pelo Editor.
- Criados: `AgentScripts/PolishActionCharacter.cs`, `IntegrateProvidedArt.cs` e `InspectCharacterPolish.cs`.
- Alterados: `AGENTS.md`, `ProjectSettings/EditorBuildSettings.asset`, `Domain/CombatState.cs`, `Domain/JourneyEngine.cs`, `Runtime/PlayerController.cs`, `OfflineAuthority.cs`, `ActionCombat.cs`, `ActorVisual.cs`, `CameraFollow.cs` e `JourneyHud.cs`.

`CombatState` ganhou consultas de cooldown; `JourneyEngine` ganhou uma consulta sem cópia de snapshot para a defesa confirmada, evitando a alocação de snapshots completos por frame na HUD. Não mudam progressão, dano ou persistência. O pesado mantém o caminho anterior nas cenas sem o componente de espada.

## Validação rápida executada

Editor conectado pela Unity CLI, com `--caller plugin --skill unity-pipeline`, autotick, recompilação e consulta a `recompile_status`. Nenhuma suíte EditMode/PlayMode, teste Go/SQL, build nova ou chamada paga foi executada.

- Movimento observado em oito direções: 3,5 unidades/s; diagonais normalizadas.
- Dezesseis orientações de ataque com teclado/mouse sintéticos, incluindo ângulos intermediários e janela ativa observada.
- Esquiva diagonal observada: aproximadamente (6,36; 6,36), velocidade 9 e janela de invulnerabilidade ativa.
- Reposicionamento durante ataque com mira independente: aproximadamente (0; 1,93), mirando à direita.
- Golpe intencionalmente errado contra o lobo real, combate, derrota e coleta sem duplicação.
- Colisão física contra RockWest e percurso ao redor, sem atribuir posição ao jogador durante a caminhada.
- I, Tab e Esc: abrir/fechar inventário e diário, pausar/retomar verificados. Captura compositada da HUD inspecionada.
- Percurso Valdoria → floresta → Valdoria → minas → ruínas → pântano → floresta → Valdoria, incluindo coleta de ferro.
- Frames avançando e Console atual consultada; resultados finais nos JSONs citados abaixo.

Evidências principais: `m06b2-compile-final.json`, `m06b2-delivery-directions.json`, `m06b2-delivery-combat.json`, `m06b2-assets-ui-controls.json`, `m06b2-reposition.json`, `m06b2-assets-collision.json`, `m06b2-assets-mines-ruins.json`, `m06b2-assets-swamp-return.json`, `m06b2-console-final.json`, `m06b2-console-status.json` e `m06b2-ui.png`.

Histórico: as primeiras inspeções perderam eventos dos dispositivos sintéticos devido ao foco do Editor; a ferramenta passou a isolar/restaurar também a configuração de input em Play. Uma comparação de título das ruínas tinha encoding incorreto na ferramenta copiada e foi corrigida. A integração encontrou dois objetos chamados Ground; a seleção passou a exigir Tilemap. A primeira inspeção visual dos pisos mostrou escala de célula incompleta, corrigida antes das inspeções finais. Falhas anteriores foram conservadas nos relatórios; não são apresentadas como verificações aprovadas.

Todas as novas inspeções usaram diretórios únicos em `Temp/Marco06B2`, com factories de persistência, configurações de Play e dispositivos restaurados ao sair. A sessão já em Play no início do trabalho foi encerrada normalmente. Nenhum save pessoal foi manualmente editado, apagado, migrado ou importado. A B2 mantém o formato e os nomes de save anteriores ao ser jogada normalmente. Nenhum commit foi feito.

## Limitações conhecidas

- Aprovação de sensação, encaixe dos recortes, transições direcionais, áudio e balanceamento depende do usuário. Algumas props/recursos e o boneco ainda usam arte anterior.
- O corpo usa oito orientações e locomoção da sheet; a espada tem animação procedural contínua. Não foi integrado um Animator completo com as poses de espada embutidas da sheet.
- Os assets fornecidos têm pixels e transparências mais finos que os placeholders anteriores; Point evita filtragem borrada, mas não há uma única densidade artística de pixel em todo o cenário.
- O buffer de 48 colliders atende a população atual; multidões maiores exigirão uma política explícita de saturação.
- Hooks de áudio sem clips. Nenhuma nova autoridade multiplayer foi implementada; o futuro servidor deverá validar posições, colisões, acertos e vida independentemente.
- Inspeção rápida, sem benchmark extensivo, suíte completa ou aprovação automática de qualidade.

Autoria inicial: `PolishActionCharacter.Build` recusa sobrescrever a cena de destino. `IntegrateProvidedArt.Apply` importa os assets para uma cena B2 salva e recusa arquivos/integração existentes. As correções incrementais são entradas específicas. Inspeção: `InspectCharacterPolish.Prepare`, Play, `Setup`, métodos de inspeção, Stop e `Cleanup`. Não execute sobre uma sessão pessoal sem preparar a persistência temporária.
