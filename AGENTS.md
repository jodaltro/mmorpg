# Mmorpg

Unity 6000.6.5f1, C#, Input System. Preserve the existing project and sample assets.

## Boundaries
Antes de modificar gameplay ou progressão, todos os agentes devem ler `Docs/GameVision.md` e seguir seus princípios obrigatórios. O modelo de propostas de missões está apenas documentado no Marco 06B.2; não implementá-lo neste marco.
- `Assets/Mmorpg/Domain`: pure C# rules; no Unity, networking or presentation dependencies.
- `Assets/Mmorpg/Runtime`: offline authority, physics adapters, input and presentation.
- `Assets/Mmorpg/Tests`: EditMode rule tests and PlayMode integration tests.
- `AgentScripts`: repeatable Editor authoring tools invoked through Unity CLI Pipeline.
- `Docs`: architecture, controls and validation evidence.

Keep MonoBehaviours small and in files matching their class names. Use serialized references.
Client input expresses intentions; the offline authority validates damage/cooldowns. A future Go/Nakama authority must validate movement, collision, hits and health independently; never accept client damage values as truth.
Do not add progression, XP, levels, Nakama or Jev in this milestone.

## Official protagonist — Marco 06B.12
Entrada oficial: `Assets/Mmorpg/Scenes/MmorpgWorld.unity`, primeiro índice global de build. Iron Knight aprovado B10/B11: `Assets/Mmorpg/Art/Production/IronKnight/IronKnight.asset`, prefab visual `PlayerVisual.prefab` na mesma pasta e manifesto `ArtSource/Characters/IronKnight/manifest.json`. Preservar seus 36 clips, 264 sprites, canvas nativo 256×256 e 32 PPU. Reimportar com `IronKnight06B9.ImportProduction`; não regenerar desenhos nem sobrescrever arquivos B10/B11. O perfil pessoal continua em `DevelopmentJourneys/marco06b4`; não renomear, resetar ou fundir saves ao alterar apresentação.

## Project direction — larger humanoids (2026-10-16)
O usuário pediu uma nova família de corpos maiores e com proporções humanas como padrão futuro de todos os humanoides, incluindo o protagonista, e autorizou ampliar/retrabalhar o cenário para essa escala. Manter pixel art com apresentação mais moderna. A altura histórica de aproximadamente 48 px não limita essa pesquisa. Consultar `Docs/Art/HumanoidStandard.md` e o checkpoint R4. Isso autoriza estudar/substituir os visuais em uma migração validada, mas não constitui aprovação artística de um modelo específico; proteger saves, identidades, gameplay e os arquivos históricos aprovados. A prova Quaternius possui integração experimental em `HumanoidScale2026.unity`; a migração de produção continua pendente. Após testar o jogador e a correção lateral `dc36f56`, o usuário aprovou a caminhada e escolheu continuar com essa base Quaternius; preservar a referência aprovada e aguardar suas próximas instruções de aprimoramento. A caminhada tem registro em `Docs/Validation/HumanoidWalkApproval2026.md`. O figurino medieval R5 também foi aprovado explicitamente pelo usuário: `Docs/Validation/HumanoidOutfit2026.md`, cena experimental `HumanoidOutfit2026.unity`. Preservar essas duas referências aprovadas; combate, espada e promoção ao mundo oficial continuam pendentes.

## Verification
Para trabalhos de pixel art, usar a skill local `.agents/skills/aseprite-pixel-art/SKILL.md` (invocação `$aseprite-pixel-art`) e o Aseprite local via CLI/Lua. Consultar `Docs/Art/AsepriteWorkflow.md`; preservar fontes de produção e não executar a migração B3 para atualizar desenhos. Não usar geração externa/paga de arte neste fluxo.

Use the connected Editor through Unity CLI; pass `--caller plugin --skill unity-pipeline`.
Enable `set_autotick`, recompile, poll `recompile_status`. Marco 06B.5 prioritizes short real Play/input and visual inspections; do not automatically run extensive EditMode/PlayMode or backend suites.
Check console errors and advancing frames in Play mode. Never report unexecuted tests as passed.
Scene generation must refuse to overwrite an existing scene. Preserve unrelated user changes.

## Project memory — user authorization (2026-10-14)
Standing user authorization: paid calls when useful, commits and pushes for project work, including publishing all intended project changes to `main`; no repeated confirmation is needed within that authorized scope. This supersedes the original pasted milestone's no-paid-calls/no-commit restriction. Preserve secrets, personal saves, unrelated changes and authentication/persistence safeguards. Do not spend on repeated unsuccessful art generation.

Preferência permanente do usuário (2026-10-15): ao concluir trabalhos no projeto, sempre fazer commit e push das alterações da tarefa. Preservar alterações alheias e informar qualquer impedimento ao push.

## Project memory — refactoring authorization (2026-10-15)
O usuário autoriza explicitamente ações destrutivas no projeto quando úteis ao objetivo da tarefa: refatorar, recriar, substituir ou remover código, assets, cenas e ferramentas. Não é necessário preservar implementações anteriores nem pedir confirmação apenas pelo caráter destrutivo da mudança. Esta autorização substitui exigências anteriores de preservação quando conflitantes; mantenha o escopo solicitado e proteja segredos e credenciais. Continue fazendo commit e push ao concluir cada tarefa. Autorização técnica não equivale a aprovação artística de um resultado.
