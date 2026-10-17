using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;

// Applies only the named official pilot root. Does not recalibrate scale/camera.
public static class BuildValdoriaPhase2
{
    const string Depth = "Assets/Mmorpg/Art/Production/ValdoriaEnvironment/Depth/";
    public static object Main()
    {
        if(EditorApplication.isPlaying) throw new InvalidOperationException("Stop Play before authoring");
        var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(scene.path != "Assets/Mmorpg/Scenes/MmorpgWorld.unity") throw new InvalidOperationException("Open official scene first");
        const string visualPrefab="Assets/Mmorpg/Art/Production/ValdoriaProtagonist/PlayerVisual.prefab";
        var contents=PrefabUtility.LoadPrefabContents(visualPrefab);
        try
        {
            var data=contents.GetComponent<ProductionVisualDefinition>();
            if(contents.GetComponent<SortingGroup>()==null)contents.AddComponent<SortingGroup>();
            data.Body.transform.localPosition=new Vector3(0,18f/32f,0);
            contents.GetComponentsInChildren<Transform>().First(t=>t.name=="GroundShadow").localPosition=Vector3.zero;
            PrefabUtility.SaveAsPrefabAsset(contents,visualPrefab);
        }
        finally {PrefabUtility.UnloadPrefabContents(contents);}
        var backdrop = GameObject.Find("GeneratedValdoriaEnvironmentR10").GetComponent<SpriteRenderer>();
        var recipe = JObject.Parse(File.ReadAllText("Docs/Art/ValdoriaWorldBlueprint.json"));
        var root = GameObject.Find("ValdoriaPilotArea");
        if(root == null) root = new GameObject("ValdoriaPilotArea");
        // The previous pilot objects are authored here and have no external consumers.
        foreach(Transform child in root.transform.Cast<Transform>().ToArray()) Undo.DestroyObjectImmediate(child.gameObject);
        Func<JToken, Vector2> point = token => {
            var px = (float)token[0]; var py = (float)token[1];
            return backdrop.transform.TransformPoint(new Vector3((px-backdrop.sprite.pivot.x)/32f,(800-py-backdrop.sprite.pivot.y)/32f));
        };
        foreach(var item in recipe["objects"])
        {
            string id = (string)item["id"];
            var anchor = new GameObject(id); anchor.transform.SetParent(root.transform);
            anchor.transform.position = point(item["anchorPixel"]);
            anchor.layer = 8;
            var polygon = item["footprintPixels"] as JArray;
            if(polygon != null && polygon.Count >= 3)
            {
                var collider = anchor.AddComponent<PolygonCollider2D>();
                collider.points = polygon.Select(p=>point(p)-(Vector2)anchor.transform.position).ToArray();
            }
            if(item["silhouette"] == null) continue;
            string path = Depth + id + ".png";
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);
            var importer = (TextureImporter)AssetImporter.GetAtPath(path);
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 32;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled = false; importer.alphaIsTransparency = true;
            importer.maxTextureSize = 2048;
            var settings = new TextureImporterSettings(); importer.ReadTextureSettings(settings);
            settings.spriteAlignment = (int)SpriteAlignment.Custom;
            settings.spritePivot = backdrop.sprite.pivot / new Vector2(1536,800);
            settings.spriteMeshType = SpriteMeshType.FullRect;
            importer.SetTextureSettings(settings); importer.SaveAndReimport();
            var layer = new GameObject("DepthSilhouette"); layer.transform.SetParent(anchor.transform);
            layer.transform.position = backdrop.transform.position;
            layer.transform.localScale = backdrop.transform.lossyScale;
            var renderer = layer.AddComponent<SpriteRenderer>();
            renderer.sprite = AssetDatabase.LoadAssetAtPath<Sprite>(path);
            renderer.sharedMaterial = backdrop.sharedMaterial;
            layer.AddComponent<WorldArtSorting>().Configure(renderer,anchor.transform);
        }
        var player = GameObject.Find("Player");
        var definition = player.GetComponentInChildren<ProductionVisualDefinition>();
        var group = definition.GetComponent<SortingGroup>() ?? definition.gameObject.AddComponent<SortingGroup>();
        player.GetComponent<ProductionVisualSync>().ConfigureSortingGroup(group);
        EditorUtility.SetDirty(player.GetComponent<ProductionVisualSync>());
        // R8 idle boots lie 12..23 px below the imported pivot. Centre their contact
        // around the physical root using an 18 px PRESENTATION offset (never physics).
        definition.Body.transform.localPosition = new Vector3(0,18f/32f,0);
        player.GetComponent<ActorVisual>().ConfigurePreparedArt(0);
        var shadow = definition.GetComponentsInChildren<Transform>().First(t=>t.name=="GroundShadow");
        shadow.localPosition = Vector3.zero;
        PrefabUtility.RecordPrefabInstancePropertyModifications(definition.Body.transform);
        PrefabUtility.RecordPrefabInstancePropertyModifications(shadow);
        // Old tiny dressing is visually unrelated to the new composition; it has no gameplay.
        var dressing=GameObject.Find("Art06B3Details");
        if(dressing!=null)dressing.SetActive(false);
        foreach(var collider in UnityEngine.Object.FindObjectsByType<Collider2D>(FindObjectsSortMode.None))
            if(collider.name=="TreeEast" || collider.name=="Árvore cinzenta") collider.gameObject.SetActive(false);
        var qa = GameObject.Find("Phase2-QA-Isolation");
        if(qa != null) Undo.DestroyObjectImmediate(qa);
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
        return new {scene=scene.path, objects=root.transform.childCount, playerScale=definition.transform.localScale.ToString(), camera=Camera.main.orthographicSize};
    }
}
