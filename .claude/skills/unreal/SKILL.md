---
name: unreal
description: Drive Unreal Engine 5.8 on this PC - build the WorldSimDemo project, launch the editor with the Unreal MCP server, run headless game tests against the World Simulation Engine, read logs. Use for any Unreal task in this repo.
---

# Unreal on this machine

| Item | Path |
|---|---|
| Engine | `C:\Program Files\Epic Games\UE_5.8` (installed by the Epic Launcher) |
| Editor | `C:\Program Files\Epic Games\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe` |
| Commandlet/headless | `C:\Program Files\Epic Games\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe` |
| Build | `C:\Program Files\Epic Games\UE_5.8\Engine\Build\BatchFiles\Build.bat` |
| UAT | `C:\Program Files\Epic Games\UE_5.8\Engine\Build\BatchFiles\RunUAT.bat` |
| Visual Studio 2022 | `D:\VS` (Game development with C++, MSVC 14.44) |
| Demo project | `C:\UnrealProjects\WorldSimDemo\WorldSimDemo.uproject` (outside the repo: Epic template content is not redistributed) |
| Our plugin | `clients/unreal/WorldSim`, copied into `WorldSimDemo\Plugins\WorldSim` by `sync-plugin.ps1` (run by `build.ps1`) |
| World engine | `engine/` (`worldsim serve` on `127.0.0.1:8095`) |
| Demo level | `/Game/Valdoria/Maps/Lvl_Valdoria` (village, road, forest, WorldSim region volumes), built by `tools/unreal/build-valdoria.py` from CC0 packs imported by `tools/unreal/import-assets.py` (downloads in `WorldSimDemo\Downloads`, never in the repo) |

Helper scripts live in `tools/unreal/` (PowerShell). Prefer them over ad-hoc commands. To play like a user: `Jogar Valdoria.bat` (repo root) → `play.ps1` starts the world server (Jev, `-on-universe-change new-world`, world in `data/`) and the game window at the start screen; `play.ps1 -ServerOnly` only starts the server, `-InEditor` opens the editor instead. In-game UI: start screen (continue / new character / new world), [Y]/[N] offers, [E] interact, [J] journal.

## Control channels

1. **CLI** (always available, no editor UI needed):
   - Build editor target: `tools/unreal/build.ps1`
   - Headless game test with console commands: `tools/unreal/play-test.ps1` (runs `-game -nullrhi -unattended -ExecCmds=...`, then greps `LogWorldSim`).
   - Editor Python: `UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<file.py> -nullrhi` (needs the Python Editor Script Plugin, enabled in the demo project). In a commandlet use `spawn_actor_from_class` (not `spawn_actor_from_object`) and `EditorLoadingAndSavingUtils.save_map`.
   - Build needs the editor closed (Live Coding blocks UBT).
   - PowerShell 5.1 does not quote `Start-Process -ArgumentList` arrays: pass one string with `"-ExecCmds=..."` quoted.
2. **Unreal MCP** (official, experimental, UE 5.8): plugins `ModelContextProtocol` + `AllToolsets` enabled in the project. Start the editor with `tools/unreal/editor.ps1`, which passes `-ModelContextProtocolStartServer`. Server: `http://127.0.0.1:8000/mcp` (Streamable HTTP, loopback only, no auth). The repo `.mcp.json` registers it as `unreal-mcp` for Claude Code. In tool-search mode use `list_toolsets`, `describe_toolset`, `call_tool`. Tool calls run serially on the game thread: never overlap calls.
   - If the MCP tools are not loaded in the session, the server can still be called with JSON-RPC over HTTP (`initialize`, then `tools/call`) using curl. Start the editor before the Claude session, or reconnect `unreal-mcp` with `/mcp`.
   - Useful tools: `SceneTools.load_level`, `EditorAppToolset.CaptureViewport` (returns a base64 PNG), `ProgrammaticToolset.execute_tool_script` (batch many calls), `SlateInspectorToolset` (click "Salvar nível atual" to save; the level cannot be saved through `save_actor`).
   - The RX 5700 XT driver has reset the editor once (`DXGI_ERROR_DEVICE_REMOVED`); prefer headless commandlets for heavy work.
3. **Console commands of our plugin** (in PIE, `-game` or via MCP): `ws.join [id] [name]`, `ws.move <region>`, `ws.act <action> [k=v]`, `ws.occur <action> [k=v]`, `ws.accept`, `ws.decline`, `ws.status`. Test commands (drive the player without a keyboard): `ws.input <action> x [y] [seconds=N]` (Enhanced Input injection, e.g. `ws.input IA_Move 0 1 seconds=20` runs forward; `IA_Sprint`, `IA_Jump`, `IA_Traverse` exist in `/Game/Input`), `ws.inputstop <action>`, `ws.face <yaw>` (-90 = south, toward the forest), `ws.pos`, `ws.track <interval> <count>`, and `ws.sequence <gap> <cmd> | <cmd> ...` (starts once the pawn exists; `play-test.ps1` appends `quit`).

## Rules

- Start `worldsim serve` before Play; the client tolerates the engine being offline (the game keeps running).
- The game is the authority of positions and combat: it reports regions (`move`) and confirmed occurrences (`adapter`). Never send damage or HP to the world engine.
- Logs: `C:\UnrealProjects\WorldSimDemo\Saved\Logs\WorldSimDemo.log`. Our lines start with `WorldSim:`.
- Do not commit Epic template content, `Binaries/`, `Intermediate/`, `Saved/` or `DerivedDataCache/`.
- Record only tests that actually ran, in `Docs/Validation/Unreal.md`.

