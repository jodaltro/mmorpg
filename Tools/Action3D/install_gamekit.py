"""Install a pinned official Game Kit checkout locally; never overwrite an installation.

Requires Git LFS and use under the Unity Asset Store EULA. This repository does
not grant a license to the downloaded content. No credentials are read by this tool.
"""
from pathlib import Path
import hashlib
import shutil
import subprocess
import argparse
import os
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
REVISION = "b718622e98eb1a403a4f64d77e448639717d50ec"
URL = "https://github.com/Unity-Technologies/Gamekit3D.git"

def camera_package():
    target = ROOT / "Tools/Action3D/Dependencies/com.unity.cinemachine-2.10.7.tgz"
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve("https://download.packages.unity.com/com.unity.cinemachine/-/com.unity.cinemachine-2.10.7.tgz", target)
    if hashlib.sha1(target.read_bytes()).hexdigest() != "631385387c5a6b317ceb9e4a4687ee55bdaa3565":
        raise SystemExit("Official Cinemachine tarball integrity check failed")

def git(source, *args):
    subprocess.run(["git", "-c", f"safe.directory={source.as_posix()}", "-C", str(source), *args], check=True,
                   env={**os.environ, "GIT_LFS_SKIP_SMUDGE": "1"})

def install(source):
    destination = ROOT / "Assets/3DGamekit"
    if destination.exists():
        raise SystemExit(f"Refusing to overwrite {destination}")
    actual = subprocess.check_output(["git", "-c", f"safe.directory={source.as_posix()}", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if actual != REVISION:
        raise SystemExit(f"Expected {REVISION}; found {actual}")
    for p in (source / "Assets").rglob("*"):
        if "Scenes" in p.parts:
            continue
        if p.is_file() and p.stat().st_size < 200 and p.read_bytes().startswith(b"version https://git-lfs.github.com/spec"):
            raise SystemExit(f"Unresolved LFS pointer: {p}")
    shutil.copytree(source / "Assets/3DGamekit", destination,
                    ignore=shutil.ignore_patterns("Editor", "Editor.meta", "Scenes", "Scenes.meta"))
    for name in ("3DGamekit.meta", "3DGameKit_Third-PartyNotice.txt", "3DGameKit_Third-PartyNotice.txt.meta"):
        shutil.copy2(source / "Assets" / name, ROOT / "Assets" / name)
    # Removed namespaces (unused imports); preserve all original GUIDs.
    for p in destination.rglob("*.cs"):
        text = p.read_text(encoding="utf-8-sig")
        text = text.replace("using UnityEngine.XR.WSA;", "")
        text = text.replace("using UnityEditor.Experimental.SceneManagement;", "using UnityEditor.SceneManagement;")
        p.write_text(text, encoding="utf-8")
    # Replace input only. Movement, camera, animation, enemies and health remain Game Kit.
    shutil.copy2(ROOT / "Tools/Action3D/Runtime/PlayerInput.cs", destination / "Scripts/Game/Player/PlayerInput.cs")
    interaction = destination / "Scripts/Game/Core/InteractOnButton.cs"
    text = interaction.read_text().replace("Input.GetButtonDown(buttonName)", "(UnityEngine.InputSystem.Keyboard.current != null && UnityEngine.InputSystem.Keyboard.current.eKey.wasPressedThisFrame)")
    interaction.write_text(text, encoding="utf-8")
    # The kit's animation events remain visual. Physics is owned by the adapter.
    weapon = destination / "Scripts/Game/Weapon/MeleeWeapon.cs"
    text = weapon.read_text().replace("private void FixedUpdate()", "private void LegacyAnimationDrivenDamageDisabled()")
    weapon.write_text(text, encoding="utf-8")
    # Kit return-to-base may set a destination while its attack disabled the agent.
    enemy = destination / "Scripts/Game/Enemies/Chomper/ChomperBehavior.cs"
    text = enemy.read_text().replace("m_Controller.SetTarget(originalPosition);\n            m_Controller.SetFollowNavmeshAgent(true);",
                                    "m_Controller.SetFollowNavmeshAgent(true);\n            m_Controller.SetTarget(originalPosition);")
    enemy.write_text(text, encoding="utf-8")
    local = ROOT / "Assets/Action3DLocal"
    local.mkdir()
    for p in (ROOT / "Tools/Action3D/Runtime").glob("*.cs"):
        if p.name == "PlayerInput.cs":
            continue
        shutil.copy2(p, local / p.name)
        guid = hashlib.md5(("ValdoriaAction3D/" + p.name).encode()).hexdigest()
        (local / (p.name + ".meta")).write_text(f"fileFormatVersion: 2\nguid: {guid}\n")
    print(f"Installed {REVISION} in {destination}; open Unity and run the scene builder.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "Temp/Action3D/Gamekit3D")
    args = parser.parse_args()
    source = args.source.resolve()
    camera_package()
    if not source.exists():
        source.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--no-checkout", URL, str(source)], check=True)
        git(source, "checkout", REVISION)
        git(source, "lfs", "pull", "--exclude=Assets/3DGamekit/Scenes/**")
    install(source)
