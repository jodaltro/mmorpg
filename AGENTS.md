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

## Verification
Use the connected Editor through Unity CLI; pass `--caller plugin --skill unity-pipeline`.
Enable `set_autotick`, recompile, poll `recompile_status`, run EditMode and PlayMode tests.
Check console errors and advancing frames in Play mode. Never report unexecuted tests as passed.
Scene generation must refuse to overwrite an existing scene. Preserve unrelated user changes.
