# Valdoria production promotion R10

**Date:** 2026-10-17  
**Result:** Quaternius R8 is the active protagonist in the existing official world scene. The Iron Knight is no longer assigned to the active player. The Iron Knight source package and historic scenes remain available as reference.

## Entry-point diagnosis

`ProjectSettings/EditorBuildSettings.asset` has `Assets/Mmorpg/Scenes/MmorpgWorld.unity` enabled at build index 0. It remains the official game entry; this change does not promote the B11 test scene or alter build scene ordering. The official world contains the existing `Player`, world, camera, HUD, interactions, missions, combat, and journey persistence flow. The B11 scene remains a validation fixture.

The official scene's existing `Player` GameObject was preserved. Its `ProductionSpriteAnimator` and `ProductionCharacterStates` now reference the production copy `Assets/Mmorpg/Art/Production/ValdoriaProtagonist/ValdoriaProtagonist.asset`, id `valdoria-protagonist-quaternius-r8`, with 64 clips/528 frames. The existing movement, Rigidbody/collider, health/authority, `SwordSwing`, missions, interactions and persistence components remain attached. The existing sword visual/gameplay asset is reused, and the R8 procedural contact-mask presentation is connected to the body/sword renderer. The local profile path was not changed and no personal save was opened during QA.

## Environment integration

The official scene displays the 1536×800, 32-PPU detailed village backdrop from `Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png`. It is visual only. The camera bounds were expanded for the new map; the previous border scenery SpriteRenderers are hidden where they overlapped the full-scene backdrop, while their GameObjects/colliders and gameplay actors remain. The backdrop has no collision data. The new art is AI-generated and Aseprite-prepared; it remains subject to user art review.

## Verification evidence

- Unity Editor: 6000.6.5f1, connected to this project.
- `unity recompile`: `up_to_date`; `recompile_status`: `up_to_date`.
- Official entry Play smoke test with a temporary isolated profile: passed. The active scene was `MmorpgWorld`, region `Valdoria`, active character id `valdoria-protagonist-quaternius-r8`, 64 clips/528 frames. Synthetic directional input advanced the character 0.778 world units, played walk (`pose_112`), returned to idle, and Unity frames advanced.
- Evidence: [`gameplay/protagonist-play-smoke.json`](ValdoriaProductionR10/gameplay/protagonist-play-smoke.json) and [`gameplay/official-quaternius-start.png`](ValdoriaProductionR10/gameplay/official-quaternius-start.png).
- A captured Game view showed the promoted protagonist in the detailed scene with HUD and world actors after fixing the backdrop sorting order. That screenshot is a QA capture, not art approval. The earlier Pipeline timeout was resolved by accepting the external-scene reload dialog. The final visual scale is 75%; see ValdoriaProtagonistScaleR10.md.
- Unity console after smoke test: 0 errors, 0 warnings; no compilation failure. The Editor was stopped from Play and temporary input/editor settings and profile override were restored.

## Scope and remaining review

This was a protagonist/environment presentation promotion. It did not rewrite combat rules, sweep geometry, collision authority, mission logic, world progression, or persistence. This short smoke test verifies start, movement animation, and return to idle; it is not a full combat/dodge/death/interactions/save regression. Existing NPC sprites remain at their previous smaller scale and are not migrated in this checkpoint. The Quaternius base walk had prior user approval, while the updated weapon/combat presentation and generated environment should receive their own art review. The generated environment is a single flat backdrop and does not yet provide per-object depth/occlusion layers; actors always render in front of the flat backdrop; correct object-by-object occlusion needs separate layers. Treat this scene composition as a technical candidate pending a layered environment pass and user visual feedback, not a finished level.
