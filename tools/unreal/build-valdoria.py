# Builds /Game/Valdoria/Maps/Lvl_Valdoria from the imported CC0 packs.
# Run: UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<this> -nullrhi -unattended
import json, math, random, re
import unreal

MAP = "/Game/Valdoria/Maps/Lvl_Valdoria"
rng = random.Random(7)
eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
report = {"actors": 0, "missing": []}
_cache = {}
SOFT = re.compile(r"^(Grass|Flower|Clover|Fern|Bush|Plant|Mushroom|Petal)")


def mesh(pack, name):
    p = "/Game/Valdoria/%s/%s/StaticMeshes/%s" % (pack, name, name)
    if p not in _cache:
        _cache[p] = unreal.load_asset(p)
        if not _cache[p]:
            report["missing"].append(p)
    return _cache[p]


def spawn_mesh(m, x, y, z, yaw):
    # spawn_actor_from_object spawns nothing in a commandlet; the class route works.
    a = eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(x, y, z), unreal.Rotator(0, 0, yaw))
    if a:
        a.static_mesh_component.set_static_mesh(m)
    return a


def put(pack, name, x, y, z=0.0, yaw=0.0, scale=1.0, folder="Vila", label=None):
    m = mesh(pack, name)
    if not m:
        return None
    a = spawn_mesh(m, x, y, z, yaw)
    if not a:
        return None
    if scale != 1.0:
        a.set_actor_scale3d(unreal.Vector(scale, scale, scale))
    a.set_actor_label(label or name)
    if SOFT.match(name):  # walk-through vegetation: BlockAll would make invisible walls
        a.static_mesh_component.set_collision_profile_name("NoCollision")
    a.set_folder_path(folder)
    report["actors"] += 1
    return a


def local(cx, cy, yaw, lx, ly):
    r = math.radians(yaw)
    return cx + lx * math.cos(r) - ly * math.sin(r), cy + lx * math.sin(r) + ly * math.cos(r)


def house(cx, cy, yaw, label, wall="Plaster"):
    folder = "Vila/" + label
    sides = [  # (local x, local y, local yaw, piece)
        (-100, -200, 0, "Wall_%s_Window_Wide_Round" % wall), (100, -200, 0, "Wall_%s_Door_Round" % wall),
        (-100, 200, 180, "Wall_%s_Straight" % wall), (100, 200, 180, "Wall_%s_Window_Wide_Round" % wall),
        (200, -100, 90, "Wall_%s_Straight" % wall), (200, 100, 90, "Wall_%s_Window_Wide_Round" % wall),
        (-200, -100, 270, "Wall_%s_Window_Wide_Round" % wall), (-200, 100, 270, "Wall_%s_Straight" % wall),
    ]
    for lx, ly, lyaw, piece in sides:
        x, y = local(cx, cy, yaw, lx, ly)
        put("Village", piece, x, y, 0, yaw + lyaw, folder=folder)
    for lx, ly, lyaw in [(-200, -200, 0), (200, -200, 90), (200, 200, 180), (-200, 200, 270)]:
        x, y = local(cx, cy, yaw, lx, ly)
        put("Village", "Corner_Exterior_Wood", x, y, 0, yaw + lyaw, folder=folder)
    put("Village", "Floor_WoodDark", cx, cy, 0, yaw, scale=2.0, folder=folder)
    put("Village", "Roof_RoundTiles_4x4", cx, cy, 312, yaw, folder=folder)
    x, y = local(cx, cy, yaw, 100, -360)
    put("Props", "Lantern_Wall", x, y, 240, yaw + 180, folder=folder)


unreal.EditorAssetLibrary.make_directory("/Game/Valdoria/Maps")
if unreal.EditorAssetLibrary.does_asset_exist(MAP):
    unreal.EditorAssetLibrary.delete_asset(MAP)
les.new_level(MAP, False)

# Ground material: earthy green, rough.
tools = unreal.AssetToolsHelpers.get_asset_tools()
mpath = "/Game/Valdoria/Maps/M_Ground"
mat = unreal.load_asset(mpath)
if not mat:
    mat = tools.create_asset("M_Ground", "/Game/Valdoria/Maps", unreal.Material, unreal.MaterialFactoryNew())
    mel = unreal.MaterialEditingLibrary
    c = mel.create_material_expression(mat, unreal.MaterialExpressionConstant3Vector, -400, 0)
    c.set_editor_property("constant", unreal.LinearColor(0.16, 0.22, 0.08, 1))
    mel.connect_material_property(c, "", unreal.MaterialProperty.MP_BASE_COLOR)
    r = mel.create_material_expression(mat, unreal.MaterialExpressionConstant, -400, 200)
    r.set_editor_property("r", 0.95)
    mel.connect_material_property(r, "", unreal.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(mat)
    unreal.EditorAssetLibrary.save_asset(mpath)

plane = unreal.load_asset("/Engine/BasicShapes/Plane")
g = spawn_mesh(plane, 0, -3000, 0, 0)
g.set_actor_scale3d(unreal.Vector(300, 300, 1))
g.set_actor_label("Ground")
g.static_mesh_component.set_material(0, mat)
g.set_folder_path("Mundo")

# Sky and light.
sun = eas.spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0, 0, 2000), unreal.Rotator(0, -38, 135))
sun.set_actor_label("Sol")
lc = sun.light_component
lc.set_editor_property("atmosphere_sun_light", True)
lc.set_editor_property("intensity", 8.0)
lc.set_mobility(unreal.ComponentMobility.MOVABLE)
eas.spawn_actor_from_class(unreal.SkyAtmosphere, unreal.Vector(0, 0, 0)).set_actor_label("Atmosfera")
sky = eas.spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0, 0, 1000))
sky.set_actor_label("LuzDoCeu")
sky.light_component.set_mobility(unreal.ComponentMobility.MOVABLE)
sky.light_component.set_editor_property("real_time_capture", True)
fog = eas.spawn_actor_from_class(unreal.ExponentialHeightFog, unreal.Vector(0, 0, 0))
fog.set_actor_label("Neblina")
for prop, val in [("fog_density", 0.02), ("enable_volumetric_fog", True)]:
    try:
        fog.component.set_editor_property(prop, val)
    except Exception as e:
        report.setdefault("warnings", []).append(str(e))
eas.spawn_actor_from_class(unreal.VolumetricCloud, unreal.Vector(0, 0, 0)).set_actor_label("Nuvens")
for a in eas.get_all_level_actors():
    if a.get_class() in (unreal.SkyAtmosphere, unreal.SkyLight, unreal.ExponentialHeightFog, unreal.VolumetricCloud, unreal.DirectionalLight):
        a.set_folder_path("Mundo")

# Plaza with the fountain (Poco Antigo stands beside it).
for i in range(-3, 3):
    for j in range(-3, 3):
        put("Village", "Floor_UnevenBrick", i * 200 + 100, j * 200 + 100, 1, 0, folder="Vila/Praca")
put("Kenney", "fountain-round", 0, 0, 2, 0, 2.5, folder="Vila/Praca", label="Fonte")
put("Kenney", "fountain-center", 0, 0, 2, 0, 2.5, folder="Vila/Praca", label="FonteCentro")
put("Props", "Bucket_Wooden_1", 260, 40, 2, 20, folder="Vila/Praca", label="PocoAntigo_Balde")

# Houses: forge (Brom), healer (Mira), tavern, two homes.
house(1300, 300, 270, "Forja_Brom", "UnevenBrick")
house(-1300, 300, 90, "Casa_Mira")
house(0, 1500, 180, "Taverna")
house(1300, 1500, 225, "Casa_1")
house(-1300, 1500, 135, "Casa_2", "UnevenBrick")

# Forge yard.
for name, x, y, yaw in [("Anvil_Log", 900, 150, 90), ("Anvil", 900, 150, 90), ("Workbench", 900, 520, 0),
                        ("Barrel", 980, -120, 0), ("Crate_Wooden", 900, -220, 15), ("WeaponStand", 1000, 650, 270),
                        ("Pickaxe_Bronze", 880, 600, 30), ("Torch_Metal", 820, -40, 0)]:
    z = 50 if name == "Anvil" else 0
    put("Props", name, x, y, z, yaw, folder="Vila/Forja_Brom")
# Healer yard.
for name, x, y, yaw in [("Cauldron", -900, 150, 0), ("Shelf_Small_Bottles", -900, 520, 90), ("Potion_1", -880, 300, 0),
                        ("Barrel_Apples", -980, -150, 0), ("Bench", -900, -300, 90)]:
    put("Props", name, x, y, 0, yaw, folder="Vila/Casa_Mira")
# Market (feira).
for k, (x, y) in enumerate([(-500, -800), (0, -900), (500, -800)]):
    put("Kenney", ["stall-red", "stall-green", "stall"][k], x, y, 0, 0, 3.0, folder="Vila/Feira")
for name, x, y in [("FarmCrate_Apple", -620, -620), ("FarmCrate_Carrot", 620, -620), ("Stall_Cart_Empty", 900, -900),
                   ("Barrel", -900, -800), ("Crate_Wooden", -820, -900)]:
    put("Props", name, x, y, 0, rng.uniform(0, 360), folder="Vila/Feira")
for x in (-700, 700):
    put("Props", "Banner_1", x, -1100, 0, 0, folder="Vila/Feira")
# Fence around the village edge.
for i in range(-10, 11):
    for x, y, yaw in [(i * 200, 2400, 0), (2200, i * 200 + 400, 90), (-2200, i * 200 + 400, 90)]:
        if abs(x) <= 2200:
            put("Village", "Prop_WoodenFence_Single", x, y, 0, yaw, folder="Vila/Cerca")

# Road to the forest (Estrada do Leste runs south from the plaza).
for k in range(30):
    y = -1300 - k * 160
    x = 120 * math.sin(k / 4.0)
    put("Nature", rng.choice(["RockPath_Round_Wide", "RockPath_Square_Wide"]), x, y, 1, rng.uniform(0, 360), folder="Estrada")
for k in range(0, 30, 5):
    put("Props", "Torch_Metal", 420, -1400 - k * 160, 0, 0, folder="Estrada")  # clear of the walkable road
put("Kenney", "cart", -750, -2600, 0, 30, 3.0, folder="Estrada", label="Carroca_Lia")  # off the road: it blocks the player

# Forest (Floresta Cinzenta): seeded scatter south of the road end.
trees = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "CommonTree_1", "CommonTree_2", "CommonTree_3",
         "TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "DeadTree_1", "DeadTree_2"]
small = ["Bush_Common", "Fern_1", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Mushroom_Common",
         "Grass_Wispy_Tall", "Plant_1_Big", "Plant_7_Big"]
placed = 0
while placed < 140:
    x, y = rng.uniform(-6000, 6000), rng.uniform(-14000, -6200)
    if abs(x) < 300 and y > -7000:
        continue
    put("Nature", rng.choice(trees), x, y, 0, rng.uniform(0, 360), rng.uniform(0.8, 1.4), folder="Floresta")
    placed += 1
for _ in range(220):
    x, y = rng.uniform(-6000, 6000), rng.uniform(-14000, -5800)
    put("Nature", rng.choice(small), x, y, 0, rng.uniform(0, 360), rng.uniform(0.5, 1.0), folder="Floresta")
# Trees and grass around the village for life.
for _ in range(40):
    a, d = rng.uniform(0, 2 * math.pi), rng.uniform(2800, 5000)
    if abs(d * math.cos(a)) < 700 and 400 + d * math.sin(a) < -1000:
        continue  # keep the road to the forest clear
    put("Nature", rng.choice(["CommonTree_1", "CommonTree_2", "CommonTree_4", "CommonTree_5"]), d * math.cos(a), 400 + d * math.sin(a), 0,
        rng.uniform(0, 360), rng.uniform(0.9, 1.3), folder="Arredores")
for _ in range(260):
    x, y = rng.uniform(-2400, 2400), rng.uniform(-5500, 2600)
    if abs(x) < 650 and -700 < y < 650:
        continue
    put("Nature", rng.choice(["Grass_Common_Short", "Grass_Common_Tall", "Flower_3_Group", "Flower_4_Group", "Clover_1"]),
        x, y, 0, rng.uniform(0, 360), rng.uniform(0.5, 0.9), folder="Arredores")

# Things the player uses with [E] (AWorldSimInteractable): NPCs with a body,
# landmarks and spots. A player intention or, when the game itself is the
# judge (the trail was reached, the boar was killed), a confirmed occurrence.
MANNY = unreal.load_asset("/Game/Characters/Mannequins/Meshes/SKM_Manny_Simple")
QUINN = unreal.load_asset("/Game/Characters/Mannequins/Meshes/SKM_Quinn_Simple")
IDLE = unreal.EditorAssetLibrary.load_blueprint_class("/Game/Characters/Mannequins/Anims/Unarmed/ABP_Unarmed")


def spot(name, verb, x, y, yaw=0.0, action="", game=False, npc="", body=None, radius=300.0, folder="WorldSim/Interativos"):
    a = eas.spawn_actor_from_class(unreal.WorldSimInteractable, unreal.Vector(x, y, 0), unreal.Rotator(0, 0, yaw))
    if not a:
        report["missing"].append("interactable " + name)
        return None
    for k, v in [("display_name", name), ("verb", verb), ("action_id", action), ("confirmed_by_game", game), ("npc_id", npc), ("radius", radius)]:
        a.set_editor_property(k, v)
    a.get_editor_property("label").set_text(name)
    b = a.get_editor_property("body")
    if body:
        b.set_skeletal_mesh_asset(body)
        b.set_relative_rotation(unreal.Rotator(0, 0, -90), False, False)  # mannequin faces +Y
        if IDLE:
            b.set_editor_property("animation_mode", unreal.AnimationMode.ANIMATION_BLUEPRINT)
            b.set_anim_instance_class(IDLE)
    else:
        a.get_editor_property("label").set_relative_location(unreal.Vector(0, 0, 120), False, False)
    a.set_actor_label("Interativo_" + (npc or action or name))
    a.set_folder_path(folder)
    report.setdefault("interactables", []).append(name)
    return a


spot("Poco Antigo", "Examinar", 330, 0, action="examinar-poco")
spot("Brom, o ferreiro", "Falar com", 760, 300, 180, npc="brom", body=MANNY)
spot("Bigorna", "Forjar na", 900, 150, action="forjar", radius=220)
spot("Mira, a curandeira", "Falar com", -760, 300, 0, npc="mira", body=QUINN)
spot("Irma Elena", "Falar com", 250, 1150, -90, npc="elena", body=QUINN)
spot("Orin, o guarda", "Falar com", -250, 1150, -90, npc="orin", body=MANNY)
spot("Banco da taverna", "Descansar no", -900, -300, action="descansar", radius=220)
spot("Tenda dos Magos", "Trocar magias na", 0, -900, action="trocar-magia", radius=260)
spot("Telhado quebrado", "Consertar o", 1050, 1250, action="consertar-telhado", radius=260)
spot("Velho Tomas", "Falar com", 260, -2000, 180, npc="tomas", body=MANNY)
spot("Lia, a comerciante", "Falar com", -560, -2350, 0, npc="lia", body=QUINN)
spot("Rastro estranho", "Seguir o", 0, -6400, action="seguir-rastro", game=True, radius=350)
spot("Ervas medicinais", "Colher", 380, -6700, action="colher-ervas-campo", game=True, radius=250)
spot("Javali", "Cacar o", -420, -7000, action="cacar-javali", game=True, radius=300)
spot("Kael, o cacador", "Falar com", 200, -6250, 180, npc="kael", body=MANNY)
# WorldSim regions: entering a box reports the region to the world engine.
regions = []
for rid, x, y, ex, ey in [("vila", 0, 400, 2300, 2100), ("estrada", 0, -3900, 1200, 2000), ("floresta", 0, -10100, 6200, 4100)]:
    v = eas.spawn_actor_from_class(unreal.WorldSimRegionVolume, unreal.Vector(x, y, 300))
    v.set_editor_property("region_id", rid)
    box = v.get_component_by_class(unreal.BoxComponent)
    box.set_box_extent(unreal.Vector(ex, ey, 600))
    v.set_actor_label("Regiao_" + rid)
    v.set_folder_path("WorldSim")
    regions.append(rid)
report["regions"] = regions

ps = eas.spawn_actor_from_class(unreal.PlayerStart, unreal.Vector(0, -1300, 120), unreal.Rotator(0, 0, 90))
ps.set_actor_label("Inicio")

# Game Animation Sample player when migrated (tools/unreal/migrate-gasp.py), else the template.
gm = (unreal.EditorAssetLibrary.load_blueprint_class("/Game/Blueprints/GM_Sandbox")
      or unreal.EditorAssetLibrary.load_blueprint_class("/Game/ThirdPerson/Blueprints/BP_ThirdPersonGameMode"))
world = unreal.EditorLevelLibrary.get_editor_world()
if gm:
    world.get_world_settings().set_editor_property("default_game_mode", gm)
report["gamemode"] = gm.get_name() if gm else None

report["saved"] = bool(unreal.EditorLoadingAndSavingUtils.save_map(world, MAP))
report["total_level_actors"] = len(eas.get_all_level_actors())
with open(r"C:\UnrealProjects\WorldSimDemo\Saved\village-report.json", "w") as fh:
    json.dump(report, fh, indent=1)
unreal.log("WSVILLAGE " + json.dumps({k: v for k, v in report.items() if k != "missing"}) + " missing=%d" % len(report["missing"]))
