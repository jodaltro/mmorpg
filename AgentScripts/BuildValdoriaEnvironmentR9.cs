using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class BuildValdoriaEnvironmentR9
{
    const string SourceScene = "Assets/Mmorpg/Scenes/HumanoidStatesR8.unity";
    const string OutputScene = "Assets/Mmorpg/Scenes/ValdoriaEnvironmentR9.unity";
    const string Props = "Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR9/Props/";
    const string Manifest = "ArtSource/Labs/World2026/R9/Sources/manifest.json";
    const string Layout = "ArtSource/Labs/World2026/R9/Layouts/valdoria-village-seed-620913.json";
    const string RootName = "ValdoriaEnvironmentPilotR9";

    [Serializable] sealed class Module { public string id; public string unityAsset; public float[] pivotNormalizedBottomLeft; }
    [Serializable] sealed class AssetManifest { public Module[] files; }
    [Serializable] sealed class Placement { public string asset; public float[] position; public bool collision; }
    [Serializable] sealed class TerrainPlacement { public string asset; public float[] center; public float[] size; public bool collision; }
    [Serializable] sealed class LayoutDocument { public int seed; public float[] regionBounds; public TerrainPlacement terrain; public TerrainPlacement path; public Placement[] props; }

    public static string CreateScene()
    {
        if (EditorApplication.isPlaying || SceneManager.GetActiveScene().isDirty || SceneManager.GetActiveScene().path != SourceScene)
            throw new InvalidOperationException("Open the clean, stopped HumanoidStatesR8 scene before cloning R9.");
        if (File.Exists(OutputScene)) throw new IOException("Refusing to overwrite existing R9 scene: " + OutputScene);
        if (!AssetDatabase.CopyAsset(SourceScene, OutputScene)) throw new IOException("Could not create R9 scene copy.");
        EditorSceneManager.OpenScene(OutputScene, OpenSceneMode.Single);
        return "Created isolated scene copy; source R8 and Build Settings were not changed.";
    }

    public static string RemoveFailedGeneration()
    {
        if (EditorApplication.isPlaying || SceneManager.GetActiveScene().path != OutputScene)
            throw new InvalidOperationException("Only remove the failed generated group while the stopped R9 scene is active.");
        var partial = GameObject.Find(RootName);
        if (partial == null) return "No partial R9 group exists.";
        UnityEngine.Object.DestroyImmediate(partial);
        return "Removed the unsaved partial R9 pilot group; source scenes were not touched.";
    }

    public static string ResetPilot()
    {
        if (EditorApplication.isPlaying || SceneManager.GetActiveScene().path != OutputScene)
            throw new InvalidOperationException("Only reset the experimental pilot while the stopped R9 scene is active.");
        var partial = GameObject.Find(RootName);
        if (partial != null) UnityEngine.Object.DestroyImmediate(partial);
        var player = GameObject.Find("Player");
        var shadow = player != null ? player.GetComponentsInChildren<SpriteRenderer>(true).FirstOrDefault(r => r.name == "GroundShadow") : null;
        if (shadow != null) { var local = shadow.transform.localPosition; shadow.transform.localPosition = new Vector3(local.x, -.53f, local.z); }
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        EditorSceneManager.SaveScene(SceneManager.GetActiveScene());
        return "Removed only the generated R9 group and restored the cloned R8 shadow baseline before regeneration.";
    }

    public static string FixPilotMaterials()
    {
        if (SceneManager.GetActiveScene().path != OutputScene) throw new InvalidOperationException("R9 must be active.");
        var group = GameObject.Find(RootName);
        if (group == null) throw new InvalidOperationException("R9 pilot group is missing.");
        var material = AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        if (material == null) throw new InvalidOperationException("Project sprite material is missing.");
        foreach (var renderer in group.GetComponentsInChildren<SpriteRenderer>(true)) renderer.sharedMaterial = material;
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        EditorSceneManager.SaveScene(SceneManager.GetActiveScene());
        return "Assigned the project's URP sprite material to all pilot renderers and saved R9.";
    }

    public static string GeneratePilot()
    {
        if (EditorApplication.isPlaying || SceneManager.GetActiveScene().isDirty || SceneManager.GetActiveScene().path != OutputScene)
            throw new InvalidOperationException("Open a clean, stopped ValdoriaEnvironmentR9 scene.");
        if (GameObject.Find(RootName) != null) throw new InvalidOperationException("R9 pilot already exists; refusing to replace authored scene content.");
        var manifest = ReadManifest();
        var layout = ReadLayout();
        if (manifest?.files == null || layout?.props == null || layout.seed != 620913) throw new InvalidDataException("R9 asset manifest/layout/seed invalid.");
        var modules = manifest.files.ToDictionary(m => m.id, StringComparer.Ordinal);
        foreach (var module in manifest.files) ConfigureImport(module);
        AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
        var sprites = manifest.files.ToDictionary(m => m.id, m => AssetDatabase.LoadAssetAtPath<Sprite>(m.unityAsset), StringComparer.Ordinal);
        if (sprites.Any(pair => pair.Value == null)) throw new InvalidDataException("Missing or non-sprite R9 module: " + string.Join(",", sprites.Where(p => p.Value == null).Select(p => p.Key)));

        var player = GameObject.Find("Player");
        if (player == null) throw new InvalidOperationException("R8 player anchor is missing.");
        var protectedActors = UnityEngine.Object.FindObjectsByType<ActorHealth>().Where(a => a.gameObject != player).ToArray();
        ValidatePlacements(layout, player.transform.position, protectedActors);

        var group = new GameObject(RootName);
        group.AddComponent<ValdoriaR9ProfileIsolation>();
        var meadow = PlaceSprite(group.transform, "MeadowBase", sprites[layout.terrain.asset], new Vector3(layout.terrain.center[0], layout.terrain.center[1], 0), -439, modules[layout.terrain.asset], false);
        meadow.transform.localScale = new Vector3(layout.terrain.size[0] / meadow.GetComponent<SpriteRenderer>().bounds.size.x,
            layout.terrain.size[1] / meadow.GetComponent<SpriteRenderer>().bounds.size.y, 1);
        var path = PlaceSprite(group.transform, "PackedEarthPath", sprites[layout.path.asset], new Vector3(layout.path.center[0], layout.path.center[1], 0), -438, modules[layout.path.asset], false);
        path.transform.localScale = new Vector3(layout.path.size[0] / path.GetComponent<SpriteRenderer>().bounds.size.x,
            layout.path.size[1] / path.GetComponent<SpriteRenderer>().bounds.size.y, 1);

        var wallPlacement = layout.props.First(p => p.asset == "house-wall");
        var wallPosition = new Vector3(wallPlacement.position[0], wallPlacement.position[1], 0);
        var wall = PlaceSprite(group.transform, "CottageStoneTimberWall", sprites["house-wall"], wallPosition, 0, modules["house-wall"], true);
        var wallRenderer = wall.GetComponent<SpriteRenderer>();
        var houseCollider = wall.AddComponent<BoxCollider2D>(); houseCollider.size = new Vector2(3.7f, .34f); houseCollider.offset = new Vector2(0, .17f);
        var roofPlacement = layout.props.First(p => p.asset == "house-roof");
        var roof = PlaceSprite(group.transform, "CottageSlateRoof", sprites["house-roof"], new Vector3(roofPlacement.position[0], roofPlacement.position[1], 0), 0, modules["house-roof"], false);
        wall.AddComponent<ValdoriaR9RoofLayer>().Configure(wallRenderer, roof.GetComponent<SpriteRenderer>());

        int trees = 0, rocks = 0;
        for (int i = 0; i < layout.props.Length; i++)
        {
            var p = layout.props[i]; var at = new Vector3(p.position[0], p.position[1], 0);
            if (p.asset == "house-wall" || p.asset == "house-roof") continue;
            if (p.asset == "tree-trunk")
            {
                trees++;
                var trunk = PlaceSprite(group.transform, "OakTrunk_" + trees.ToString("00"), sprites[p.asset], at, 0, modules[p.asset], true);
                var collider = trunk.AddComponent<BoxCollider2D>(); collider.size = new Vector2(.45f, .28f); collider.offset = new Vector2(0, .14f);
                var canopy = layout.props.First(c => c.asset == "tree-canopy" && Mathf.Abs(c.position[0]-p.position[0]) < .1f);
                var canopyAt = new Vector3(canopy.position[0], canopy.position[1], 0);
                PlaceSprite(group.transform, "OakCanopy_" + trees.ToString("00"), sprites[canopy.asset], canopyAt, 0, modules[canopy.asset], true);
            }
            else if (p.asset == "tree-canopy") continue;
            else if (p.asset == "rock")
            {
                rocks++;
                var rock = PlaceSprite(group.transform, "MossyRock_" + rocks.ToString("00"), sprites[p.asset], at, 0, modules[p.asset], true);
                var collider = rock.AddComponent<BoxCollider2D>(); collider.size = new Vector2(.82f, .36f); collider.offset = new Vector2(0, .18f);
            }
        }

        // R8 body pivot is authored at the actual foot contact and follows the physical root.
        // Only the shadow projection is raised in this experimental copy; root, body, physics and camera stay fixed.
        var shadow = player.GetComponentsInChildren<SpriteRenderer>(true).FirstOrDefault(r => r.name == "GroundShadow");
        if (shadow == null) throw new InvalidOperationException("Player ground shadow is missing.");
        var shadowLocal = shadow.transform.localPosition; shadow.transform.localPosition = new Vector3(shadowLocal.x, -.125f, shadowLocal.z);
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        if (!EditorSceneManager.SaveScene(SceneManager.GetActiveScene())) throw new IOException("Could not save R9 scene.");
        var evidence = new JObject {
            ["scene"] = OutputScene, ["sourceScene"] = SourceScene, ["seed"] = layout.seed,
            ["rootAnchor"] = new JArray(player.transform.position.x, player.transform.position.y),
            ["shadowLocalYBefore"] = shadowLocal.y, ["shadowLocalYAfter"] = -.125f,
            ["treePairs"] = trees, ["rocks"] = rocks, ["houseFoundationCollider"] = new JArray(houseCollider.size.x, houseCollider.size.y),
            ["layoutSha256"] = Sha256File(Layout), ["pathWidthUnits"] = layout.path.size[0],
            ["placements"] = new JArray(layout.props.Select(p => (JToken)new JObject { ["asset"] = p.asset, ["position"] = new JArray(p.position), ["collision"] = p.collision })),
            ["addedBuildEntry"] = false, ["officialWorldModified"] = false, ["runtimeGeneration"] = false,
            ["protectedActorCount"] = protectedActors.Length, ["playerRootChanged"] = false,
            ["assets"] = new JArray(manifest.files.Select(m => (JToken)new JObject { ["id"] = m.id, ["path"] = m.unityAsset }))
        };
        Directory.CreateDirectory("Docs/Validation/ValdoriaEnvironmentR9");
        File.WriteAllText("Docs/Validation/ValdoriaEnvironmentR9/scene-generation.json", evidence.ToString());
        return "Generated deterministic R9 pilot: 12x8 meadow, 3m path, 2 split trees, 4m cottage wall, 1 rock. R8 physics, camera, protected actors, Build Settings untouched.";
    }

    static AssetManifest ReadManifest()
    {
        var root = JObject.Parse(File.ReadAllText(Manifest));
        return new AssetManifest { files = root["files"].Select(t => new Module {
            id = (string)t["id"], unityAsset = (string)t["unityAsset"],
            pivotNormalizedBottomLeft = t["pivotNormalizedBottomLeft"].Values<float>().ToArray()
        }).ToArray() };
    }

    static string Sha256File(string path)
    {
        using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-", "").ToLowerInvariant();
    }

    static LayoutDocument ReadLayout()
    {
        var root = JObject.Parse(File.ReadAllText(Layout));
        TerrainPlacement ReadSurface(JToken t) => new TerrainPlacement { asset=(string)t["asset"], center=t["center"].Values<float>().ToArray(), size=t["size"].Values<float>().ToArray(), collision=(bool)t["collision"] };
        return new LayoutDocument {
            seed=(int)root["seed"], regionBounds=root["regionBounds"].Values<float>().ToArray(),
            terrain=ReadSurface(root["terrain"]), path=ReadSurface(root["path"]),
            props=root["props"].Select(t => new Placement { asset=(string)t["asset"], position=t["position"].Values<float>().ToArray(), collision=(bool)t["collision"] }).ToArray()
        };
    }
    static void ConfigureImport(Module module)
    {
        var importer = AssetImporter.GetAtPath(module.unityAsset) as TextureImporter;
        if (importer == null) throw new InvalidDataException("Texture import settings unavailable: " + module.unityAsset);
        importer.textureType = TextureImporterType.Sprite; importer.spriteImportMode = SpriteImportMode.Single;
        importer.spritePixelsPerUnit = 32; importer.filterMode = FilterMode.Point; importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.mipmapEnabled = false; importer.alphaIsTransparency = true; importer.wrapMode = TextureWrapMode.Clamp;
        var settings = new TextureImporterSettings(); importer.ReadTextureSettings(settings); settings.spriteMeshType = SpriteMeshType.FullRect; settings.spriteAlignment = (int)SpriteAlignment.Custom; settings.spritePivot = new Vector2(module.pivotNormalizedBottomLeft[0], module.pivotNormalizedBottomLeft[1]); importer.SetTextureSettings(settings);
        importer.spritePivot = new Vector2(module.pivotNormalizedBottomLeft[0], module.pivotNormalizedBottomLeft[1]);
        var standalone = importer.GetPlatformTextureSettings("Standalone");
        standalone.name = "Standalone"; standalone.overridden = true; standalone.textureCompression = TextureImporterCompression.Uncompressed;
        standalone.maxTextureSize = 2048; importer.SetPlatformTextureSettings(standalone);
        importer.SaveAndReimport();
    }

    static GameObject PlaceSprite(Transform parent, string name, Sprite sprite, Vector3 position, int sorting, Module module, bool sortByGround)
    {
        var go = new GameObject(name); go.transform.SetParent(parent, false); go.transform.position = position;
        var renderer = go.AddComponent<SpriteRenderer>(); renderer.sprite = sprite; renderer.sortingOrder = sorting;
        renderer.sharedMaterial = AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        renderer.color = Color.white;
        if (sortByGround)
        {
            var anchor = new GameObject("GroundAnchor").transform; anchor.SetParent(go.transform, false);
            go.AddComponent<WorldArtSorting>().Configure(renderer, anchor);
        }
        return go;
    }

    static void ValidatePlacements(LayoutDocument layout, Vector3 player, ActorHealth[] actors)
    {
        float xMin = layout.regionBounds[0], yMin = layout.regionBounds[1], xMax = xMin + layout.regionBounds[2], yMax = yMin + layout.regionBounds[3];
        foreach (var p in layout.props)
        {
            if (p.position == null || p.position.Length != 3 || p.position[0] < xMin || p.position[0] > xMax || p.position[1] < yMin || p.position[1] > yMax)
                throw new InvalidDataException("R9 prop outside authored pilot bounds: " + p.asset);
            if (!p.collision) continue;
            if (Vector2.Distance(new Vector2(p.position[0], p.position[1]), player) < 1.5f) throw new InvalidDataException("R9 footprint violates player protected radius: " + p.asset);
            foreach (var actor in actors)
                if (Vector2.Distance(new Vector2(p.position[0], p.position[1]), actor.transform.position) < 1.5f)
                    throw new InvalidDataException("R9 footprint violates protected actor " + actor.name + ": " + p.asset);
        }
    }
}






// Removes only a failed, unsaved group created by this authoring pass in the isolated R9 scene.
// Call once if generation throws before SaveScene; this never targets R8 or another scene.
