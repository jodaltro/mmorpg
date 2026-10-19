# Mmorpg — instruções para agentes (Codex, DeepSeek Harness e outros)

Unity **6000.6.5f1**, C#, **Input System**, URP 2D, pixel art com autoria Blender/Aseprite. Repositório `jodaltro/mmorpg`; branch de trabalho/publicação do projeto: **`main`** (especificar a branch nas operações GitHub, não presumir a branch padrão da API).

- **Antes de iniciar uma tarefa, conferir o worktree e executar `git pull --ff-only origin main` na `main`.** Preservar alterações locais; se a atualização falhar ou houver divergência, informar o impedimento antes de concluir que ferramentas/skills estão ausentes.

## Estado atual — vila jogável 01 (18/10/2026)

`Assets/Mmorpg/Scenes/ValdoriaPlayableVillage01.unity` é a primeira cena habilitada de inicialização após QA técnico. `MmorpgWorld.unity` permanece preservada e habilitada como rollback; as medições de 17/10 abaixo são históricas. A nova composição e as peças de ponte/muralha continuam candidatas à avaliação artística. Receita: `ArtSource/World/PlayableVillage01/recipe.json`; contrato: `Docs/WorldGen/PlayableVillage01Contract.md`; resultados e limitações reais: `Docs/Validation/ValdoriaPlayableVillage01.md`. Não executar o importador inicial sobre o destino existente.

## Diretriz vigente — reconstrução autorizada de Valdoria

> **Decisão do usuário:** a postura de preservação de legado foi **substituída**. O objetivo é **construir a melhor versão futura de Valdoria**, não manter intactas todas as versões anteriores. Refatoração destrutiva está autorizada.

Isto **revoga** as restrições anteriores de preservação e de compatibilidade que constavam deste arquivo (preservação do Iron Knight, imutabilidade de saves `marco06b4`, obrigatoriedade de cena experimental separada, preservação de históricos B3–B13 R9). Onde o texto antigo conflitar com esta seção, **esta seção prevalece**.

- **Pode remover, substituir ou reconstruir** código legado, cenas antigas, prefabs, assets, ferramentas e pipelines quando isso simplificar o projeto.
- **Sem compatibilidade** com Iron Knight nem com sistemas de personagem anteriores.
- **Saves antigos são descartáveis:** podem ser resetados, migrados ou substituídos. **Não** desenvolver camadas de retrocompatibilidade apenas para mantê-los.
- **`MmorpgWorld.unity` pode ser modificada diretamente.** Cena experimental separada é escolha técnica, não obrigação.
- **Pode simplificar ou reconstruir** cenário, câmera, colisão, personagem e persistência.
- **Não manter duas arquiteturas** quando uma implementação única e mais limpa resolve o problema.

### Limites que permanecem (não revogados)

- **Antes de remover, identificar dependências** — evitar eliminar materiais necessários à nova implementação.
- **Preservar segredos, credenciais, requisitos de licenciamento e trabalho não relacionado.**
- **Validar a arquitetura resultante com testes reais na Unity** — nunca declarar teste não executado como aprovado.
- **Commit e push das alterações pertinentes para `main`, informando o SHA.** Se houver impedimento, informar sem alegar sucesso.
- **Autorização destrutiva não é aprovação artística.** Aprovação estética continua exigindo feedback explícito do usuário.

## Prioridade artística atual — Valdoria World Studio (17/10/2026)

**Nova decisão do usuário:** a trajetória de reconstruir o cenário a partir de um panorama R10 por recortes, silhuetas e colliders manuais **não é a direção desejada**. A prioridade passa a ser um sistema de **agentes/skills especializados em autoria ambiental com IA e geradores procedurais reproduzíveis**: terreno/relevo, materiais, água/hidrologia, clima, arquitetura, vegetação e estruturas (pedras, muros, cercas). O panorama R10 pode servir como referência artística, **não** como mapa canônico de geometria.

- **Primeiro especialista implementado:** `.agents/skills/terrain-generation/SKILL.md` (Terrain Agent) e `Tools/ArtPipeline/WorldGen/terrain_agent.py`; contrato `Docs/WorldGen/WorldRegionContract.md`. É uma skill carregável no Codex com gerador semântico Python. Não afirmar subagentes executáveis, integração Unity ou textura de produção já existentes.
- O Terrain Agent gera `WorldRegion`, elevação, inclinação, umidade, classes de solo, rotas/zonas planas, candidatos a água, patches de edição local e imagens de diagnóstico. **Essas imagens não são arte final.** As próximas etapas precisam de Material Agent/Aseprite, Water Agent, World Builder Unity e QA visual.
- Priorizar **mundo -> topografia/semântica -> materiais e objetos -> arte -> colisão/oclusão -> QA Unity**, em vez de interpretar pixels do panorama como altura/obstáculos.
- A implementação inicial produz artefatos em diretório novo sob `Temp/WorldGen/` e não altera `MmorpgWorld.unity`. Antes de promover novo mundo à cena principal, demonstrar acabamento pixel art à altura do Quaternius, navegação, escala, performance e evidências reais no Unity Editor.
- As seções e relatórios R10/Fase 2 abaixo são **estado histórico** e não ordens para continuar seu método visual. A autorização de reconstrução destrutiva e as restrições de segurança/licença continuam válidas.

## Prioridade atual — integração de Valdoria

1. **Consolidar Quaternius como único protagonista principal.**
2. **Refatorar as estruturas antigas** que dificultam sua integração.
3. **Alinhar geometria, colisões, câmera e apresentação visual** do cenário atual.
4. **Preparar a base** para cenários modulares e procedurais.
5. **Simplificar a persistência** conforme o jogo atual, sem compromisso com formatos antigos.
6. **Verificar input, movimento, combate, esquiva, morte e reinício** no novo contrato.

## Estado técnico verificado — 17/10/2026

Números abaixo foram **medidos no repositório real**, não herdados de relato histórico.

- **Entrada oficial:** `Assets/Mmorpg/Scenes/MmorpgWorld.unity` (~68.460 linhas), primeira cena habilitada do Build Settings. **Único** consumidor do backdrop de produção.
- **Protagonista ativo:** Quaternius masculino R8, `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/ValdoriaProtagonist.asset`, **64 clips, 528 frames, oito direções**.
- **Dimensões do código:**
  - `Runtime`: **75** arquivos · `Domain`: **12** · `Editor`: **1** · `Tests`: **15** · **185** `.cs` versionados no total.
  - **20** cenas versionadas, **6.081** arquivos rastreados, **~663 MB**.
- **Cenário:** `Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png`, **1536×800**, 32 PPU, Point, sem mipmaps/compressão. É **backdrop visual único** — não é Tilemap modular e **não fornece colisão, oclusão ou geometria de navegação**.
  - Atenção à ambiguidade de resolução: as **fontes Aseprite** (`ArtSource/Labs/World2026/R10/Aseprite/*.aseprite`) medem **1536×1024**; o **asset integrado** mede **1536×800**. São objetos diferentes — não tratar um número como erro do outro. O PNG de produção tem **SpriteRect `{0,0,1536,800}`** com pivô normalizado `(0.5208, 0.4625)`; **não houve recorte nem pivô desalinhado**.
- **Calibração atual (candidata, sem aprovação artística):** grupo visual do jogador **1.25** (raiz física **1**), fundo **1.74**, câmera ortográfica **7.03125** (≈ 43,50 u de altura de backdrop contra 14,06 u de visão). `PixelPerfectCamera` e `AdaptivePixelViewport` foram desativados **somente na câmera oficial**; Point permanece, mas pixel perfect inteiro não está garantido.
- **Iron Knight** (B10/B11/B12) **não é o protagonista** e seus assets de personagem não são referência artística. Medido: **0** referências em `Runtime`, `Domain`, `Tests` e `Editor` — o runtime nunca dependeu dele; as **41** ocorrências estão em `AgentScripts/` (ferramentas B9–B12). **Mas atenção ao caminho enganoso:** `Art/Production/IronKnight/PlayerVisual.prefab` é infraestrutura de produção do Quaternius (ver bullet abaixo). Candidatos reais a remoção: `Art/Experimental/IronKnightB9|B10|B11` e os 6 `AgentScripts` correspondentes.
- **`SwordSwing`**: origem física **única e definitiva** = `Rigidbody2D.position` do ator. A política `SweepOriginPolicy` foi **removida** na Fase 1. O caminho legado `Grip()` injetava a mão do sprite (`frame.hand`, espaço de pixel) como offset de mundo — 1,78 u, idêntico em todas as direções, sem dividir por PPU. Arte **nunca** alimenta física. Detalhes e testes: `Docs/Validation/ValdoriaReconstructionPhase1.md`.
- **Escala visual 1.25** é uma override de cena em `VisualRoot` dentro da `PrefabInstance` de `IronKnight/PlayerVisual.prefab` — **não** no `Player`. Esse prefab é **infraestrutura de produção** do protagonista Quaternius (fornece `VisualRoot/BodySprite/WeaponPivot/EquippedSword/GroundShadow`), apesar do caminho histórico. **Não remover** `Art/Production/IronKnight/PlayerVisual.prefab` nem `IronKnight.asset`: a cena oficial instancia o prefab e 2 cenas Wardrobe do Build Settings referenciam o asset.
- **Biblioteca ambiental canônica:** `Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm` (schema v2). `village-scene-v3.png` é byte-idêntico ao backdrop de produção. Os kits `ValdoriaEnvironmentR10` e `R10Detail` eram clones entre si e foram **removidos** na Fase 1.
- **Persistência:** `LocalJourneyProfile` usa `DevelopmentJourneys/marco06b4` com allowlist estrita de arquivos e backup verificado por bytes. `ValdoriaR9ProfileIsolation` redireciona o perfil para `Temp/ValdoriaEnvironmentR9/IsolatedProfile` durante Play — **esse é o padrão útil a manter**, mesmo que o perfil pessoal seja descartado conforme a nova diretriz.
- **`Docs/GameVision.md` existe** e continua sendo leitura obrigatória antes de mudar gameplay, mundo persistente ou progressão. **Não** implementar XP/níveis, backend novo, Nakama ou missões adicionais sem pedido específico. O jogo offline deve funcionar sem serviços externos.

## Direção de arte e cenário

1. **Quaternius é o único protagonista.** Correções artísticas novas ainda exigem revisão do usuário.
2. Trabalhar escala e contato dos pés com o solo por comparação **poço → portas → cercas → árvores**, no mesmo plano de chão; não decidir só por zoom ou porcentagem de `Transform`.
3. Transformar a ilustração de Valdoria em **nível jogável**: colisões, caminhos, footprints, sorting por âncora, camadas de oclusão e navegação sem obstáculos invisíveis. O cenário único **não cria colisão/oclusão automaticamente**.
4. Evoluir para módulos ambientais e **geração procedural determinística de autoria offline**, com receitas/seed, qualidade, pontos narrativos e ferramentas reproduzíveis. Não substituir uma referência elaborada por ruído aleatório nem gerar terreno novo a cada Play.
5. NPCs antigos podem ser **reconstruídos do zero** sob a nova arquitetura, com identidade e narrativa coerentes. Não é obrigatório preservar objetos, IDs ou diálogos legados.
6. Estudo de arco V4 é **prévia estacionária** (sem projéteis/dano/arma persistente); não anunciar combate à distância completo.

## Arquitetura e regras de engenharia

- `Assets/Mmorpg/Domain`: regras C# puras, sem dependências Unity/apresentação/rede. `Runtime`: input, autoridade offline, física e apresentação. `Tests`: regras e integrações. `AgentScripts`: autoria repetível pelo Editor. `ArtSource`: fontes e proveniência. `Docs`: contratos e validação. **Preservar essa separação ao refatorar** — ela é o que torna a próxima reconstrução barata.
- **Input comunica intenções; a autoridade valida** dano, cooldowns, LOS e consequências. **Nunca** usar animação ou `AnimationEvent` como fonte de dano. Um futuro servidor revalidará física/acertos independentemente.
- `MonoBehaviour` pequeno e em arquivo homônimo; referências serializadas; **evitar duplicar** Player, Camera, EventSystem, Animator, `SwordSwing`, autoridade ou sistemas de pause/save.
- **Ao remover, seguir esta ordem:** (1) localizar referências no código, (2) localizar referências em cenas/prefabs por GUID, (3) confirmar que nada necessário à nova implementação depende do alvo, (4) só então remover. Preferir remoção em commit isolado e descritível.
- **Persistência:** simplificar conforme o jogo atual. Formatos antigos **não** precisam ser lidos. Manter mesmo assim: **allowlist estrita** de arquivos (nunca enumerar `persistentDataPath` para deletar), **backup verificado por bytes** antes de apagar, e **perfil isolado em `Temp/`** para qualquer teste em Play.
- **Não versionar** saves, segredos, credenciais, tokens, executáveis ou caches.
- Respeitar mudanças alheias no worktree.

## Pipeline Unity — validação real obrigatória

- Usar o **Unity Editor conectado** via Unity CLI com `--caller plugin --skill unity-pipeline`, ou as ferramentas equivalentes do DeepSeek Harness (`unity_status`, `unity_command`, `unity_eval`, `unity_cli`).
- Antes: confirmar projeto `D:\unity\Mmorpg`, versão, cena aberta, status da compilação e alterações não salvas. `set_autotick`, `recompile`, polling de `recompile_status`, Console.
- Executar **Play real** e Input System real para controles/colisões/transições relevantes; registrar frames, traces e capturas **após o frame renderizado**. Cenas em Play e capturas Blender/Aseprite devem ser identificadas separadamente; **nunca declarar teste não executado como aprovado**.
- **Atribuir erros do Console à origem.** Erros introduzidos por probes `unity_eval` do próprio agente (stack em `PipelineEvaluation.PipelineEval_*`) **não** são defeitos do jogo. Separar erro histórico de erro novo pelo `seq`/`cursor` do Console.
- Usar QA curto e dirigido; não iniciar automaticamente suítes longas/backends. Guardar perfil isolado; ao terminar **parar Play e restaurar** Input System, timeScale, overrides, opções do Editor, câmeras temporárias e dispositivos sintéticos.
- Cena nova e importador **devem recusar sobrescrita de destino**.
- **Ferramenta de captura grava em `Assets/`.** `capture_game_view`/`screenshot` com `save_path` resolvem para `Assets/<path>`; apagar o PNG **e** o `.meta` gerado depois de usar, para não poluir o projeto.

## Evidências visuais — Ground12 em diante

- Toda validação visual importante entrega PNG original integral de Play e cópia ReviewLite de até **750 KiB** por imagem, com dimensões, bytes, SHA-256, câmera/escala e transformação no manifesto. Originais são a autoridade e não podem ser sobrescritos.
- Seguir `Docs/Art/VisualReviewEvidence.md` e `Tools/ArtPipeline/review_lite.py`. Pares antes/depois usam transformações equivalentes, nearest quando necessário e nenhum dithering. Redução de cores exige registro e inspeção visual; fornecer recortes1:1 para detalhes.
- Depois do push, testar ao menos um ReviewLite pelo mecanismo disponível; separar publicação, recuperação Base64, assinatura/hash PNG e inspeção visual. Nunca declarar leitura pelo conector sem execução.

## Aseprite, Blender e arte

- Aseprite **1.3.18.6** em `D:\Aseprite\Aseprite.exe` (PATH/`ASEPRITE_EXE` podem não estar configurados: localizar/validar antes de executar). Ler `.agents/skills/aseprite-pixel-art/SKILL.md` e `Docs/Art/AsepriteWorkflow.md`.
- Launchers versionados: `python Tools/ArtPipeline/Aseprite/aseprite.py locate`, `validate`, `export`, `verify`, `inspect`; scripts `Tools/ArtPipeline/Aseprite/*.lua`. `inspect` é **somente leitura** e funciona com qualquer canvas.
- `export` **recusa pasta de destino existente**; `verify` escreve `qa.json` e deve rodar **somente em laboratórios**.
- Blender e Python são **autoria offline** para corpo/roupa/arma/cenário. Exportação exige RGBA, Point, PPU/pivô/line-of-ground **por asset**, compressão/mipmaps off, timings e proveniência. A geometria 3D é autoria offline — **não** supor IK 3D rodando em tempo real na Unity.
- Imagem gerada por IA: o cenário R10 foi solicitado pelo usuário. Isso **não** autoriza gerar ou alterar por IA personagens/poses aprovados sem pedido explícito. Checar direitos de uso/publicação e registrar autoria/licença; comercial ≠ redistribuição de sprites.
- Validar estética na escala nativa, GIFs e Play real. **Teste de hash e geometria não substitui aprovação artística.**

## DeepSeek Harness

- Este `AGENTS.md` orienta o agente executado na raiz do projeto, inclusive o Harness; **não presume** que Harness/plugin estejam instalados, autenticados ou testados.
- Instalação/configuração/diagnóstico: **`Docs/Development/DeepSeekHarness.md`**. O plugin Unity é opt-in por perfil e acessa o Editor real; o Aseprite local é usado pelos wrappers/CLI existentes.
- **Nunca** inserir chaves DeepSeek/Unity, senhas ou tokens em `AGENTS.md`, receitas, logs versionados ou arquivos de exemplo. Conectar apps exige ação explícita do usuário na máquina.
- **A autorização de reconstrução já cobre remoções legadas dentro do escopo.** Verificar dependências (código, GUIDs em cenas/prefabs, docs) e então remover — **sem** pedir confirmação adicional para alvos no escopo da tarefa.
- **Confirmar antes de executar** apenas quando: (a) a operação sair do objetivo declarado; (b) envolver material não relacionado ao projeto; (c) a auditoria de dependências revelar consumidores inesperados que mudem o alvo (ex.: um asset sob caminho "legado" que seja infraestrutura de produção).

## Referências

- Visão e regras de jogo: `Docs/GameVision.md`.
- Arte: `Docs/Art/HumanoidStandard.md`, `Docs/Art/ProceduralWeapons.md`, `Docs/Art/AsepriteWorkflow.md`, `Docs/Art/ProductionPipeline.md`.
- Validação recente (R10): `Docs/Validation/Marco06B13R10Consolidado.md`, `Docs/Validation/ValdoriaProductionR10.md`, `Docs/Validation/ValdoriaWellProportionR10.md`.
- Histórico R5–R9 (**contexto, não direção vigente**): `HumanoidWalkApproval2026`, `HumanoidOutfit2026`, `HumanoidCombat8Dir2026` (índices S=0/O=1/N=2/L=3, diagonais 4–7), `HumanoidSwordR7`, `BowAnatomyR7`, `HumanoidStatesR8`, `Marco06B12`.
