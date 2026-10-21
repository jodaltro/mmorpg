# Imports the CC0 packs downloaded into WorldSimDemo/Downloads.
# Run: UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<this> -nullrhi -unattended
import json, os, time
import unreal

D = r"D:\UnrealDownloads\WorldSimDemo"  # downloads live on D: (C: is short on space); never in the repo
Q = os.path.join
JOBS = [
    (Q(D, r"quaternius-medieval-village-megakit\x\Medieval Village MegaKit[Standard]\glTF"), "/Game/Valdoria/Village", (".gltf",)),
    (Q(D, r"quaternius-stylized-nature-megakit\x\glTF"), "/Game/Valdoria/Nature", (".gltf",)),
    (Q(D, r"quaternius-fantasy-props-megakit\x\Exports\glTF"), "/Game/Valdoria/Props", (".gltf",)),
    (Q(D, r"kenney-fantasy-town\x\Models\GLB format"), "/Game/Valdoria/Kenney", (".glb",)),
    (Q(D, r"quaternius-universal-base-characters\x\Universal Base Characters[Standard]\Base Characters\Godot - UE"), "/Game/Valdoria/Characters/Base", (".gltf",)),
    (Q(D, r"quaternius-universal-base-characters\x\Universal Base Characters[Standard]\Hairstyles\Rigged to Head Bone\glTF (Godot -Unreal)"), "/Game/Valdoria/Characters/Hair", (".gltf",)),
    (Q(D, r"quaternius-modular-character-outfits-fantasy\x\Modular Character Outfits - Fantasy[Standard]\Exports\glTF (Godot-Unreal)\Outfits"), "/Game/Valdoria/Characters/Outfits", (".gltf",)),
    (Q(D, r"quaternius-modular-character-outfits-fantasy\x\Modular Character Outfits - Fantasy[Standard]\Exports\glTF (Godot-Unreal)\Modular Parts"), "/Game/Valdoria/Characters/Parts", (".gltf",)),
    (Q(D, r"quaternius-universal-animation-library\x\Universal Animation Library[Standard]\Unreal-Godot"), "/Game/Valdoria/Animations", (".glb",)),
    (Q(D, r"polyhaven-sky"), "/Game/Valdoria/Sky", (".hdr",)),
    # Universal Animation Library 2 (CC0): sword combos, shield, knockback, farming. Quaternius skeleton (retarget to the player).
    (Q(D, r"quaternius-universal-animation-library-2\x\Universal Animation Library 2[Standard]\Unreal-Godot"), "/Game/Valdoria/Animations/UAL2", (".glb",)),
]

report = {"jobs": [], "started": time.time()}
tools = unreal.AssetToolsHelpers.get_asset_tools()
for src, dest, exts in JOBS:
    files = sorted(f for f in os.listdir(src) if f.lower().endswith(exts)) if os.path.isdir(src) else []
    tasks = []
    for f in files:
        t = unreal.AssetImportTask()
        t.filename = Q(src, f)
        t.destination_path = dest
        t.automated = True
        t.replace_existing = True
        t.save = True
        tasks.append(t)
    t0 = time.time()
    if tasks:
        tools.import_asset_tasks(tasks)
    made = sum(len(t.imported_object_paths or []) for t in tasks)
    failed = [os.path.basename(t.filename) for t in tasks if not t.imported_object_paths]
    job = {"dest": dest, "files": len(files), "objects": made, "failed": failed[:20], "nfailed": len(failed), "seconds": round(time.time() - t0, 1), "found": os.path.isdir(src)}
    report["jobs"].append(job)
    unreal.log("WSIMPORT " + json.dumps(job))

report["seconds"] = round(time.time() - report["started"], 1)
with open(r"C:\UnrealProjects\WorldSimDemo\Saved\import-report.json", "w") as fh:
    json.dump(report, fh, indent=1)
unreal.log("WSIMPORT done")
