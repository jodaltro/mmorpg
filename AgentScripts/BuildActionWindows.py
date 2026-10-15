"""Queue a build in the connected Editor; never changes the global scene list."""
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
command = ["unity", "command", "build", "--caller", "plugin", "--skill", "unity-pipeline", "--format", "json", "--",
           "--target", "StandaloneWindows64", "--outputPath", "Builds/ActionVerticalSlice/ActionVerticalSlice.exe",
           "--scenes", json.dumps(["Assets/Mmorpg/Scenes/ActionVerticalSlice.unity"]), "--confirm", "true"]
result = subprocess.run(command, cwd=root, capture_output=True, text=True, encoding="utf-8", timeout=60)
(root / "Docs/Validation/m06a-build-start.json").write_text(result.stdout, encoding="utf-8")
print(result.stdout)
raise SystemExit(result.returncode)
