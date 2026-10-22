"""Copy the Quaternius packs the Godot client uses into assets/ (gitignored).

The packs are CC0 but large, so they stay out of the repository. Download them
from https://quaternius.com and point SRC at the folder that holds them
(default: D:/UnrealDownloads/WorldSimDemo). Run: python tools/fetch_assets.py
"""
import os
import shutil
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else r"D:\UnrealDownloads\WorldSimDemo"
DST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

VILLAGE = "quaternius-medieval-village-megakit/x/Medieval Village MegaKit[Standard]"
NATURE = "quaternius-stylized-nature-megakit/x"
PROPS = "quaternius-fantasy-props-megakit/x"
CHARS = "quaternius-universal-base-characters/x/Universal Base Characters[Standard]/Base Characters/Godot - UE"
OUTFITS = "quaternius-modular-character-outfits-fantasy/x/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits"
UAL1 = "quaternius-universal-animation-library/x/Universal Animation Library[Standard]/Unreal-Godot"
UAL2 = "quaternius-universal-animation-library-2/x/Universal Animation Library 2[Standard]/Unreal-Godot"

# (pack folder holding the glTF files, destination subfolder, model names)
MODELS = [
    (VILLAGE + "/glTF", "village", [
        "Wall_Plaster_Straight", "Wall_Plaster_Door_Round", "Wall_Plaster_Window_Wide_Round",
        "Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Door_Round", "Corner_Exterior_Wood",
        "Floor_Brick", "Floor_UnevenBrick", "Floor_WoodDark", "Roof_RoundTiles_6x6", "Roof_RoundTiles_6x8",
        "Roof_RoundTiles_4x4", "Door_1_Round", "Prop_Crate", "Prop_Wagon", "Prop_WoodenFence_Single",
        "Prop_Chimney", "Stairs_Exterior_Straight", "Wall_Arch", "HoleCover_90Stairs", "Prop_Vine1", "Prop_Vine4",
        "Prop_Brick1", "Prop_Brick2", "Prop_Support"]),
    (NATURE + "/glTF", "nature", [
        "CommonTree_1", "CommonTree_2", "CommonTree_3", "DeadTree_1", "DeadTree_3", "Grass_Common_Short", "Grass_Common_Tall",
        "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Bush_Common", "Bush_Common_Flowers", "Mushroom_Common",
        "Mushroom_Laetiporus", "Flower_3_Group", "Flower_4_Group", "Pebble_Round_1", "Pebble_Round_3", "Fern_1"]),
    (PROPS + "/Exports/glTF", "props", [
        "Barrel", "Chest_Wood", "Table_Large", "Sword_Bronze", "Shield_Wooden", "Bucket_Wooden_1", "Bench", "Anvil",
        "Pickaxe_Bronze", "Torch_Metal", "Crate_Wooden", "Vase_Rubble_Medium", "Lantern_Wall", "Workbench"]),
    (CHARS, "characters", ["Superhero_Male_FullBody", "Superhero_Female_FullBody"]),
    (OUTFITS, "outfits", ["Male_Peasant", "Male_Ranger", "Female_Peasant", "Female_Ranger"]),
]
FILES = [(UAL1 + "/UAL1_Standard.glb", "animations"), (UAL2 + "/UAL2_Standard.glb", "animations")]
CREATURES = ["quaternius-polypizza-animals"]  # Quaternius CC0 animals from poly.pizza
TEXTURE_DIRS = [VILLAGE + "/Textures", NATURE + "/Textures", PROPS + "/Textures"]


def copy(src, dst_dir):
    os.makedirs(dst_dir, exist_ok=True)
    if not os.path.exists(src):
        print("missing:", src)
        return False
    shutil.copy2(src, dst_dir)
    return True


def main():
    for folder, sub, names in MODELS:
        base = os.path.join(SRC, folder)
        if not os.path.isdir(base):  # props keep glTF in a nested folder
            print("missing folder:", base)
            continue
        dst = os.path.join(DST, sub)
        for n in names:
            copy(os.path.join(base, n + ".gltf"), dst)
            copy(os.path.join(base, n + ".bin"), dst)
        for f in os.listdir(base):  # textures that sit next to the models
            if f.lower().endswith(".png"):
                copy(os.path.join(base, f), dst)
    for rel in FILES:
        copy(os.path.join(SRC, rel[0]), os.path.join(DST, rel[1]))
    for c in CREATURES:
        cdir = os.path.join(SRC, c)
        if os.path.isdir(cdir):
            for f in os.listdir(cdir):
                if f.lower().endswith(".glb"):
                    copy(os.path.join(cdir, f), os.path.join(DST, "creatures"))
    for sub in ("village", "nature", "props"):
        for td in TEXTURE_DIRS:
            t = os.path.join(SRC, td)
            if os.path.isdir(t):
                for f in os.listdir(t):
                    if f.lower().endswith(".png"):
                        copy(os.path.join(t, f), os.path.join(DST, sub))
    print("assets ready in", os.path.abspath(DST))


if __name__ == "__main__":
    main()
