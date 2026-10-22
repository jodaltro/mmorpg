# Retargets Paragon combat animations (Greystone: warrior, Gideon: mage) to
# the player's skeleton (UEFN Mannequin, used by the Game Animation Sample
# character) and makes a montage for each, so the game can play them over the
# motion-matching locomotion.
# Run: UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<this> -nullrhi -unattended
import json, re
import unreal

OUT = "/Game/Valdoria/Combat"
TARGET_MESH = "/Game/Characters/UEFN_Mannequin/Meshes/SKM_UEFN_Mannequin"
TARGET_RIG = "/Game/Characters/UEFN_Mannequin/Rigs/IK_UEFN_Mannequin"
HEROES = {
    "Greystone": ("/Game/ParagonGreystone/Characters/Heroes/Greystone/Meshes/Greystone",
                  "/Game/ParagonGreystone/Characters/Heroes/Greystone/Animations"),
    "Gideon": ("/Game/ParagonGideon/Characters/Heroes/Gideon/Meshes/Gideon",
               "/Game/ParagonGideon/Characters/Heroes/Gideon/Animations"),
}
# What the game needs: attacks, abilities, hit reactions, death, block, stun.
WANT = re.compile(r"^(Attack_Primary[A-D]?(_Montage)?|Primary_?Attack.*|Ability_(Q|E|R|Ultimate)(_.*)?|Cast|RMB_Cast|Burden|PortalBlast|CosmicRift_Execute|Blackhole_Start|Torn_Space|Knock_Fwd|HitReact_(Front|Back)|Death.*|Deflect_InPlace|Stun_Start|Jump_Melee)$", re.I)
SKIP = re.compile(r"(_MSA|FrozenPose|_Fast|_Slow|_Med|Recovery)$", re.I)

tools = unreal.AssetToolsHelpers.get_asset_tools()
eal = unreal.EditorAssetLibrary
reg = unreal.AssetRegistryHelpers.get_asset_registry()
report = {"heroes": {}}


def fresh(name, cls, factory, path=OUT):
    # Reuse on a rerun: the asset is regenerated below (it may be referenced).
    full = path + "/" + name
    if eal.does_asset_exist(full):
        return unreal.load_asset(full)
    return tools.create_asset(name, path, cls, factory)


target_mesh = unreal.load_asset(TARGET_MESH)
target_rig = unreal.load_asset(TARGET_RIG)
eal.make_directory(OUT)
for hero, (mesh_path, anim_path) in HEROES.items():
    info = report["heroes"].setdefault(hero, {})
    mesh = unreal.load_asset(mesh_path)
    if not mesh:
        info["error"] = "mesh not found"
        continue
    # Source IK rig, generated from the mesh.
    rig = fresh("IK_" + hero, unreal.IKRigDefinition, unreal.IKRigDefinitionFactory())
    rc = unreal.IKRigController.get_controller(rig)
    rc.set_skeletal_mesh(mesh)
    rc.apply_auto_generated_retarget_definition()
    info["chains"] = len(rc.get_retarget_chains())
    # Retargeter hero -> player.
    rtg = fresh("RTG_" + hero + "_to_Player", unreal.IKRetargeter, unreal.IKRetargetFactory())
    tc = unreal.IKRetargeterController.get_controller(rtg)
    tc.set_ik_rig(unreal.RetargetSourceOrTarget.SOURCE, rig)
    tc.set_ik_rig(unreal.RetargetSourceOrTarget.TARGET, target_rig)
    tc.remove_all_ops()
    tc.add_default_ops()
    tc.assign_ik_rig_to_all_ops(unreal.RetargetSourceOrTarget.SOURCE, rig)
    tc.assign_ik_rig_to_all_ops(unreal.RetargetSourceOrTarget.TARGET, target_rig)
    tc.auto_map_chains(unreal.AutoMapChainType.FUZZY, True)
    try:
        tc.auto_align_all_bones(unreal.RetargetSourceOrTarget.TARGET)
    except Exception as e:  # pose alignment is a refinement; keep going
        info["align"] = str(e)
    eal.save_loaded_asset(rig)
    eal.save_loaded_asset(rtg)
    # Animations to retarget.
    assets = reg.get_assets(unreal.ARFilter(package_paths=[anim_path], recursive_paths=False))
    picked = [a for a in assets if WANT.match(str(a.asset_name)) and not SKIP.search(str(a.asset_name))
              and str(a.asset_class_path.asset_name) in ("AnimSequence", "AnimMontage")]
    info["picked"] = sorted(str(a.asset_name) for a in picked)
    done = unreal.IKRetargetBatchOperation.duplicate_and_retarget(
        picked, mesh, target_mesh, rtg, search="", replace="", prefix=hero + "_", suffix="",
        target_path=OUT + "/" + hero, use_source_path=False, include_referenced_assets=True, overwrite_existing_files=True)
    made = []
    for a in done:
        obj = a.get_asset()
        if not obj:
            continue
        dest = OUT + "/" + hero + "/" + str(a.asset_name)
        made.append(obj.get_path_name())
        # A montage for each loose sequence (montages play over locomotion).
        if isinstance(obj, unreal.AnimSequence) and not eal.does_asset_exist(dest + "_Montage"):
            f = unreal.AnimMontageFactory()
            f.set_editor_property("source_animation", obj)
            f.set_editor_property("target_skeleton", obj.get_editor_property("skeleton"))
            m = tools.create_asset(str(a.asset_name) + "_Montage", OUT + "/" + hero, unreal.AnimMontage, f)
            if m:
                eal.save_loaded_asset(m)
                made.append(m.get_path_name())
    info["made"] = sorted(made)
    eal.save_directory(OUT, only_if_is_dirty=True, recursive=True)

with open(unreal.Paths.project_saved_dir() + "retarget-combat.json", "w") as fh:
    json.dump(report, fh, indent=1)
unreal.log("WSRETARGET " + json.dumps({h: {"chains": v.get("chains"), "picked": len(v.get("picked", [])), "made": len(v.get("made", []))} for h, v in report["heroes"].items()}))
