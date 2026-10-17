# Mmorpg — instruções para agentes (Codex, DeepSeek Harness e outros)

Unity **6000.6.5f1**, C#, **Input System**, URP 2D, pixel art com autoria Blender/Aseprite. Repositório `jodaltro/mmorpg`; branch de trabalho/publicação do projeto: **`main`** (especificar a branch nas operações GitHub, não presumir a branch padrão da API).

> **Prioridade:** o estado atual documentado abaixo prevalece sobre relatos históricos de B3–B13 R9. Antes de mudar arte, escala ou gameplay, consultar os relatórios indicados e inspecionar a cena/arquivos reais. Documentação histórica não autoriza desfazer uma decisão posterior.

## Estado atual confirmado — R10, 17/10/2026

- **Entrada oficial:** `Assets/Mmorpg/Scenes/MmorpgWorld.unity`, primeira cena habilitada do Build Settings.
- **Protagonista ativo:** Quaternius masculino R8, `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/ValdoriaProtagonist.asset`, **64 clips, 528 frames, oito direções**. A cena oficial utiliza o `Player` existente, preservando componentes de movimento, saúde, combate, mundo, missões e persistência.
- **Iron Knight** B10/B11/B12 é **referência histórica preservada**, não o jogador ativo da cena oficial. Não restaurá-lo por engano ao refazer prefabs, cenas ou importações; preservar seus 36 clips/264 sprites e fontes.
- **Aprovado artisticamente pelo usuário:** caminhada Quaternius, figurino medieval R5, esquiva expressiva R8, Hurt e Death R8; arco V4 **somente puxada frontal/lateral** em laboratório. As diagonais R6 passaram gate técnico, mas não têm aprovação artística explícita registrada. **Empunhadura/pose da espada ainda precisa de ajuste**: menos reta, um pouco à frente do corpo, com palma/braço/dedos naturais. Aprovação dos movimentos individuais não equivale a aprovação global de combate.
- **Cenário atual:** imagem detalhada de Valdoria `Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png`, 1536×800, 32 PPU e Point; backdrop visual único, **não** um Tilemap modular nem um nível físico completo. Referência gerada por imagem sob pedido do usuário, preparada no Aseprite; não declarar desenho manual integral. A composição detalhada agradou, porém a integração física e artística ainda é incompleta.
- **Calibração atual, ainda não aprovada:** grupo visual do jogador **1.25** (raiz física **1**), fundo **1.74**, câmera ortográfica **7.03125**, proporção avaliada pelo **poço**. PixelPerfectCamera e AdaptivePixelViewport foram desativados **somente na câmera oficial** para obter zoom intermediário; Point permanece, mas pixel perfect inteiro não está garantido.
- **NPCs:** objetos/visuais de diálogo temporariamente **desativados** para comparar proporções. Não foram excluídos, mas as interações respectivas estão indisponíveis; não declarar testes de NPC aprovados nessa condição. Restaurar/adaptar posteriormente com identidade, posição, colisor e narrativa preservados.
- **Risco pendente:** o `SwordSwing` oficial ainda usa **LegacyGrip**, cuja origem física depende da mão visual; escalar o grupo visual pode afetar os acertos. O R7 validou `PlanarSweepOrigin` no laboratório, **não** automaticamente na cena oficial. Antes de concluir integração do mundo, testar básico 20, pesado 36, oito direções, alcance, parede, LOS, um hit por golpe, esquiva, Hurt, Death e F5, com perfil isolado. Não mudar dano/alcance/colisores para mascarar falha.
- A última rodada R10 validou inicialização, caminhada, idle e Console; **não** certificou regressão completa de combate, missões, interações ou save/load.

**Fontes de verdade recentes:** `Docs/Validation/Marco06B13R10Consolidado.md`, `Docs/Validation/ValdoriaProductionR10.md`, `Docs/Validation/ValdoriaWellProportionR10.md`, `Docs/Art/HumanoidStandard.md`, `Docs/Validation/HumanoidStatesR8Feedback.md` e `Docs/Art/ProceduralWeapons.md`. Para histórico de aprovações, consultar R5/R6/R7/R8 e seus GIFs/QA.

## Direção vigente

1. Manter Quaternius como protagonista e o figurino/movimentos aprovados; correções artísticas novas exigem revisão do usuário.
2. Trabalhar escala e contato dos pés com o solo por comparação **poço → portas → cercas → árvores**, no mesmo plano de chão; não decidir só por zoom ou porcentagem de `Transform`.
3. Transformar a ilustração detalhada de Valdoria em **nível jogável**: colisões, caminhos, footprints, sorting por âncora, camadas de oclusão e navegação sem obstáculos invisíveis. O cenário único não cria colisão/oclusão automaticamente.
4. Evoluir para módulos ambientais e **geração procedural determinística de autoria offline**, com receitas/seed, arte de boa qualidade, pontos narrativos protegidos e ferramentas reproduzíveis. Não substituir uma referência elaborada por ruído aleatório ou gerar terreno novo a cada Play.
5. NPCs antigos permanecem temporariamente ocultos até alinhamento visual e físico; não apagar seus dados, IDs, fatos ou diálogos.
6. Estudo de arco V4 é **prévia estacionária** nas cenas experimentais (sem projéteis/dano/arma persistente); não anunciar combate à distância completo.

## Arquitetura e regras de segurança

- Ler `Docs/GameVision.md` **antes de qualquer mudança de gameplay, mundo persistente ou progressão**. Não implementar XP/níveis, Nakama, Jev, backend novo ou missões adicionais sem pedido específico. Jogo offline deve funcionar sem serviços externos.
- `Assets/Mmorpg/Domain`: regras C# puras, sem dependências Unity/apresentação/rede. `Runtime`: input, autoridade offline, física e apresentação. `Tests`: regras e integrações. `AgentScripts`: autoria repetível pelo Editor. `ArtSource`: fontes e proveniência. `Docs`: contratos e validação.
- Input comunica intenções; a autoridade valida dano, cooldowns, LOS e consequências. Nunca usar animação ou `AnimationEvent` como fonte de dano. Um futuro servidor precisará revalidar física/acertos independentemente.
- `MonoBehaviour` pequeno e em arquivo homônimo; referências serializadas; evitar duplicar Player, Camera, EventSystem, Animator, `SwordSwing`, autoridade ou sistemas de pause/save.
- **Salvar dados pessoais é prioridade:** não renomear, apagar, resetar, migrar ou abrir para teste `DevelopmentJourneys/marco06b4` nem saves reais. Testes com perfil isolado em `Temp/` e restore do override em `finally`/cleanup. Não versionar saves, segredos, credenciais, tokens, executáveis/caches.
- Preservar arquivos aprovados, licenças e hashes; alterações pertinentes em fonte devem usar versão nova e registrar origem. Não sobrescrever cenas/atlas históricos com scripts de primeira criação. Respeitar mudanças alheias no worktree.
- A autorização do usuário inclui refatorações e substituições **dentro do escopo da tarefa**, além de commit/push ao finalizar; **não equivale a aprovação artística** ou licença para alterar saves/segredos. Publicar alterações pertinentes em `main` e informar SHA; se houver impedimento, informar sem alegar sucesso.

## Pipeline Unity — validação real obrigatória

- Usar o **Unity Editor conectado** via Unity CLI com `--caller plugin --skill unity-pipeline` no fluxo já estabelecido, ou ferramentas equivalentes comprovadamente conectadas do DeepSeek Harness (`unity_status`, `unity_command`, `unity_eval`, `unity_cli`).
- Antes: confirmar projeto `D:\unity\Mmorpg`, versão, cena aberta, status da compilação e alterações não salvas. `set_autotick`, `recompile`, polling de `recompile_status`, Console.
- Executar **Play real** e Input System real para controles/colisões/transições relevantes; registrar frames, traces e capturas após o frame renderizado. Cenas em Play e capturas Blender/Aseprite devem ser identificadas separadamente; **nunca declarar teste não executado como aprovado**.
- Usar QA curto e dirigido; não iniciar automaticamente suítes longas/backends. Guardar perfil isolado; ao terminar parar Play e restaurar Input System, timeScale, overrides, opções do Editor, câmeras temporárias e dispositivos sintéticos.
- Cena nova e importador **devem recusar sobrescrita de destino**. Não executar `Apply` de `ScaleValdoriaProtagonistR10`, `ScaleValdoriaWorldR10` ou `CalibratePlayerToWellR10` em sequência como pipeline: representam checkpoints com números conflitantes e podem reverter a calibração atual.
- Antes de promover uma experiência à `MmorpgWorld`, verificar entrada oficial, controles, câmera, HUD, combate, interações efetivamente ativas, F5, save/load isolado e regressões visuais.

## Aseprite, Blender e arte

- Aseprite **1.3.18.6** instalado historicamente em `D:\Aseprite\Aseprite.exe`. O PATH/`ASEPRITE_EXE` podem não estar configurados: localizar/validar antes de executar. Ler `.agents/skills/aseprite-pixel-art/SKILL.md` e `Docs/Art/AsepriteWorkflow.md`.
- Usar os launchers já versionados: `python Tools/ArtPipeline/Aseprite/aseprite.py locate`, `validate`, `export`, `verify`; scripts `Tools/ArtPipeline/Aseprite/*.lua`. Comandos devem usar destinos novos e não sobrescrever PNGs/editáveis aprovados.
- Blender e Python são ferramentas de **autoria offline** para corpo/roupa/arma/cenário. Exportação para PNG/Aseprite/Unity exige RGBA, Point, PPU/pivô/line-of-ground por asset, compressão/mipmaps off, timings e proveniência. Não supor que a fonte 3D está executando IK em tempo real no Unity.
- O uso de imagem gerada para o **cenário R10 foi solicitado pelo usuário**; isso não autoriza gerar ou alterar por IA personagens/poses aprovados sem pedido explícito. Checar direitos de uso/publicação dos assets e registrar autoria/licença; comercial ≠ redistribuição de sprites.
- Validar estética por comparação na escala nativa, GIFs e Play real. Teste de hash e geometria não substitui aprovação artística.

## DeepSeek Harness

- Este `AGENTS.md` deve orientar o agente executado na raiz do projeto, inclusive o Harness; **não presume que o Harness/plugin estejam instalados, autenticados ou testados**.
- Instruções de instalação/configuração/diagnóstico para Unity e Aseprite: **`Docs/Development/DeepSeekHarness.md`**. O plugin Unity é opt-in por perfil e acessa o Editor real; o Aseprite local é utilizado preferencialmente pelos wrappers/CLI existentes.
- Nunca inserir chaves DeepSeek/Unity, senhas ou tokens em `AGENTS.md`, receitas, logs versionados ou arquivos de exemplo. Conectar apps requer ação explícita do usuário na máquina.
- Antes de confiar no Harness para mudanças grandes, executar apenas smoke **não destrutivo** em cena experimental com Unity + validação Aseprite, e comparar a saída com o estado atual.

## Referências históricas (não sobrescrever a direção atual)

- Iron Knight B10/B11 e promoção B12: `Docs/Validation/Marco06B12.md`, `Assets/Mmorpg/Art/Production/IronKnight/`. Personagem preservado, **não** entrada ativa.
- Walk e outfit Quaternius R5: `Docs/Validation/HumanoidWalkApproval2026.md`, `Docs/Validation/HumanoidOutfit2026.md`.
- Oito direções R6: `Docs/Validation/HumanoidCombat8Dir2026.md`; índices legados S=0/O=1/N=2/L=3 e diagonais 4–7 opt-in.
- R7 físico: `Docs/Validation/HumanoidSwordR7.md`. Arco V4: `Docs/Validation/BowAnatomyR7.md`; menu experimental: `Docs/Validation/WeaponValidationMenuR7.md`.
- R8: `Docs/Validation/HumanoidStatesR8.md`, `Docs/Validation/HumanoidStatesR8Feedback.md`. Hurt/Death e esquiva expressiva aprovados; espada em revisão.
