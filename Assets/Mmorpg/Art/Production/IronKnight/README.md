# Iron Knight — official protagonist

CharacterSet: `IronKnight.asset`, 36 clips, 264 unique sprites in `Sprites/`.
Visual-only prefab: `PlayerVisual.prefab`, connected in `Assets/Mmorpg/Scenes/MmorpgWorld.unity`.
The actor's health, motor, input, authority and colliders remain on the scene's Player root.

Source: Hormelz, 8-Directional Iron Knight, CC0-1.0.
https://hormelz.itch.io/8-directional-iron-knight
Approved B10 walking/attacks/occlusion and B11 dodge/hurt/death are preserved verbatim.
No redraw, recolor, trimming, root motion or new Animator. Native 256x256 cels, 32 PPU, Point, no compression/mipmaps.

Canonical import manifest: `ArtSource/Characters/IronKnight/manifest.json`.
It references the immutable approved PNGs and editable Aseprite documents in ArtSource/Labs/IronKnight2026/B10 and B11.
These are archival source paths; runtime assets have no dependency on Assets/Mmorpg/Art/Experimental.
Walking retains 11 cels per view at 53.333ms, Slash retains its approved phase map, Dodge follows 0.22s confirmed authority, Hurt/Death retain B11 presentation.

Reimport outside Play:
`unity command run_script --file AgentScripts/IronKnight06B9.cs --entry IronKnight06B9.ImportProduction --caller plugin --skill unity-pipeline --format json`

Preserve .meta files when updating. Never run production.py over these approved sources.
Scene creation in PromoteIronKnight06B12.CreateOfficial refuses an existing scene/prefab.
