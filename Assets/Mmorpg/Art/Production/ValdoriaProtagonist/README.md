# Valdoria protagonist — Quaternius R8

This folder contains the production copy of the humanoid set now bound to the `Player` in `MmorpgWorld`. Its upstream model and animation sources are CC0 and are recorded with hashes and retrieval notes in `ArtSource/Labs/Humanoid2026/provenance.json` and licenses in that folder. The source remains outside `Assets`; files here are Unity-ready copies and remapped references, not edits to the upstream package.

`ValdoriaProtagonist.asset` identifies the set as `valdoria-protagonist-quaternius-r8`: 64 directional clips and 528 frames across eight directions. The sprite sheets include the approved R8 body/contact poses. `fingers-*.png` is the generated contact-mask atlas paired frame-by-frame to the body mask atlas to make the sword grip legible. The sword itself remains the existing production auxiliary sword and gameplay sweep/authority components remain on the existing `Player`.

The official scene keeps its existing movement, collision, health, combat, mission, interaction, camera, and local-save components. The old Iron Knight set is no longer assigned to this player, but its original production package is retained as historical source material. The Quaternius base walk was previously approved; this production promotion does not claim approval of every updated combat/weapon pose or the generated environment art.
