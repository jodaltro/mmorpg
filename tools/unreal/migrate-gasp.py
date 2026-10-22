# Run inside the GameAnimationSample project:
#   UnrealEditor-Cmd.exe GameAnimationSample.uproject -run=pythonscript -script=<this> -nullrhi -unattended
# Migrates the sandbox player (CMC version) with all dependencies into WorldSimDemo.
import json
import os
import unreal

ROOTS = ["/Game/Blueprints/GM_Sandbox", "/Game/Blueprints/PC_Sandbox", "/Game/Blueprints/SandboxCharacter_CMC"]
DEST = os.environ.get("WORLDSIM_UE_PROJECT", "D:/UnrealProjects/WorldSimDemo").replace("\\", "/") + "/Content"
reg = unreal.AssetRegistryHelpers.get_asset_registry()
opts = unreal.AssetRegistryDependencyOptions(include_soft_package_references=True, include_hard_package_references=True,
                                             include_searchable_names=False, include_soft_management_references=False,
                                             include_hard_management_references=False)
seen, todo = set(), list(ROOTS)
while todo:
    p = todo.pop()
    if p in seen or not p.startswith("/Game/"):
        continue
    seen.add(p)
    for d in reg.get_dependencies(p, opts) or []:
        d = str(d)
        if d.startswith("/Game/") and d not in seen:
            todo.append(d)
pkgs = sorted(seen)
report = {"packages": len(pkgs), "top": {}}
for p in pkgs:
    top = "/".join(p.split("/")[:3])
    report["top"][top] = report["top"].get(top, 0) + 1
mopts = unreal.MigrationOptions()
for k, v in [("prompt", False), ("ignore_dependencies", True)]:
    try:
        mopts.set_editor_property(k, v)
    except Exception as e:
        report.setdefault("warnings", []).append(str(e))
unreal.AssetToolsHelpers.get_asset_tools().migrate_packages(pkgs, DEST, mopts)
with open(DEST[: -len("Content")] + "Saved/migrate-report.json", "w") as fh:
    json.dump(report, fh, indent=1)
unreal.log("WSMIGRATE " + json.dumps(report))
