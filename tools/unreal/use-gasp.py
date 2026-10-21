# Makes Lvl_Valdoria use the Game Animation Sample game mode (motion matching player).
import json
import unreal

MAP = "/Game/Valdoria/Maps/Lvl_Valdoria"
out = {}
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level(MAP)
world = unreal.EditorLevelLibrary.get_editor_world()
gm = unreal.EditorAssetLibrary.load_blueprint_class("/Game/Blueprints/GM_Sandbox")
out["gm"] = bool(gm)
if gm:
    world.get_world_settings().set_editor_property("default_game_mode", gm)
    cdo = unreal.get_default_object(gm)
    out["pawn"] = str(cdo.get_editor_property("default_pawn_class"))
    out["pc"] = str(cdo.get_editor_property("player_controller_class"))
out["saved"] = bool(unreal.EditorLoadingAndSavingUtils.save_map(world, MAP))
unreal.log("WSGASP " + json.dumps(out))
