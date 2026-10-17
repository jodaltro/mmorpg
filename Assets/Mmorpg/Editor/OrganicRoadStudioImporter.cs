using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Tilemaps;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class OrganicRoadStudioImporter
{
    const string Source="ArtSource/Labs/World2026/WorldStudio02/RoadsR3/";
    const string BaseRegion="ArtSource/Labs/World2026/WorldStudio01/Regions/B/world-region.json";
    const string Atlas="ArtSource/Labs/World2026/WorldStudio01/Materials/surfaces.png";
    const string Destination="Assets/Mmorpg/Art/Experimental/ValdoriaOrganicRoads02/";
    const string Scene="Assets/Mmorpg/Scenes/ValdoriaOrganicRoadsLab.unity";
    static string Hash(byte[] bytes){using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    public static void VerifyArtifacts()
    {
        string regionHash=Hash(File.ReadAllBytes(BaseRegion));
        foreach(string style in new[]{"A","B","C"})
        {
            string directory=Source+style+"/";var manifest=JObject.Parse(File.ReadAllText(directory+"manifest.json"));
            if((string)manifest["schema"]!="valdoria-road-build/v1"||(string)manifest["inputRegionSha256"]!=regionHash)throw new IOException("Road input terrain mismatch");
            if((string)manifest["studyAtlasSha256"]!=Hash(File.ReadAllBytes(Atlas)))throw new IOException("Study atlas mismatch");
            foreach(var file in ((JObject)manifest["outputs"]).Properties())
            {
                if(Path.GetFileName(file.Name)!=file.Name)throw new IOException("Invalid manifest artifact name");
                if(Hash(File.ReadAllBytes(directory+file.Name))!=(string)file.Value)throw new IOException("Artifact hash mismatch "+file.Name);
            }
            var road=JObject.Parse(File.ReadAllText(directory+"road.json"));
            if((string)road["schema"]!="valdoria-organic-road/v1"||!(bool)road["qa"]["mandatoryWaypointsConnected"]||!(bool)road["qa"]["visualCoreContinuous"])throw new IOException("Invalid road contract/QA");
            if((float)road["qa"]["minNavigableWidth"]<(float)road["qa"]["minimumRequested"])throw new IOException("Road below minimum width");
            if((int)road["seed"]!=710202)throw new IOException("Comparable study requires shared seed");
        }
    }
    static Sprite ImportOverlay(string style)
    {
        return ImportOverlayFrom(Source+style+"/road-overlay.png",Destination+style+"-road.png");
    }
    static Sprite ImportOverlayFrom(string sourceFile,string path)
    {
        File.Copy(sourceFile,path);
        AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;
        importer.spriteImportMode=SpriteImportMode.Single;importer.spritePixelsPerUnit=32;importer.filterMode=FilterMode.Point;
        importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;
        importer.alphaIsTransparency=true;importer.maxTextureSize=2048;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;
        settings.spriteAlignment=(int)SpriteAlignment.Center;settings.spritePivot=new Vector2(.5f,.5f);importer.SetTextureSettings(settings);importer.SaveAndReimport();
        return AssetDatabase.LoadAssetAtPath<Sprite>(path);
    }
    [MenuItem("Valdoria/World Studio/04 - Build Organic Roads Lab (new destination)")]
    public static void BuildMenu()=>Build();
    public static object Build()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play before import");
        var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(original.isDirty||original.path!="Assets/Mmorpg/Scenes/ValdoriaTerrainLab.unity")throw new InvalidOperationException("Open the clean World Studio 01 terrain lab");
        if(File.Exists(Scene)||Directory.Exists(Destination))throw new IOException("Refuse existing scene/art destination");
        VerifyArtifacts();Directory.CreateDirectory(Destination);AssetDatabase.Refresh();
        // Save a NEW copy: original scene and its asset GUIDs remain intact.
        if(!EditorSceneManager.SaveScene(original,Scene,true))throw new IOException("Scene copy failed");
        var scene=EditorSceneManager.OpenScene(Scene);
        var controller=Object.FindAnyObjectByType<TerrainLabController>();
        var source=scene.GetRootGameObjects().First(g=>g.name=="valdoria-studio01-B");
        // Dependency audit: only the former comparison controller owns these alternative roots.
        // This new copied scene has no other consumers. Keep the single B terrain and its data.
        Object.DestroyImmediate(controller.gameObject);
        foreach(var obsolete in scene.GetRootGameObjects().Where(g=>g.name=="valdoria-studio01-A"||g.name=="valdoria-studio01-C").ToArray())Object.DestroyImmediate(obsolete);
        source.SetActive(true);source.name="Shared terrain - World Studio 01 B";
        var baseData=source.GetComponent<TerrainRegionData>().WorldRegion;
        if(Hash(File.ReadAllBytes(AssetDatabase.GetAssetPath(baseData)))!=Hash(File.ReadAllBytes(BaseRegion)))throw new IOException("Scene data differs from recipe region");
        var region=JObject.Parse(baseData.text);int w=(int)region["size"][0],h=(int)region["size"][1];
        var before=source.transform.Find("Surfaces").gameObject;before.name="Before - whole-cell road tiles";
        var after=Object.Instantiate(before,source.transform);after.name="Shared ground - road removed from tiles";
        var map=after.GetComponent<Tilemap>();
        for(int i=0;i<w*h;i++)
            if((bool)region["layers"]["route"][i])
            {
                int variant=(int)region["presentation"]["tileIndices"][i]%4;
                var tile=AssetDatabase.LoadAssetAtPath<Tile>("Assets/Mmorpg/Art/Experimental/ValdoriaTerrainStudio01/Tile_"+variant.ToString("000")+".asset");
                map.SetTile(new Vector3Int(i%w,h-1-i/w,0),tile);
            }
        var material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/Experimental/ValdoriaTerrainStudio01/TerrainUnlit.mat");
        var overlays=new List<GameObject>();var data=new List<TextAsset>();
        foreach(var style in new[]{"A","B","C"})
        {
            string path=Destination+style+"-road.json";File.Copy(Source+style+"/road.json",path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            var go=new GameObject(style+" - organic road overlay (no collider)");go.transform.SetParent(source.transform);go.transform.localPosition=new Vector3(w*.5f,h*.5f,0);
            var renderer=go.AddComponent<SpriteRenderer>();renderer.sprite=ImportOverlay(style);renderer.sharedMaterial=material;renderer.sortingOrder=-1990;
            overlays.Add(go);data.Add(AssetDatabase.LoadAssetAtPath<TextAsset>(path));
        }
        var player=GameObject.Find("Player");var lab=new GameObject("Organic Roads - 0 Before 1 Rural 2 Worn 3 Trail").AddComponent<OrganicRoadLabController>();
        lab.Configure(before,after,overlays.ToArray(),data.ToArray(),player.transform,new Vector3(33.5f,23.5f,0));
        var isolation=Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>();isolation.ConfigureTemporaryProfile("ValdoriaOrganicRoads02/IsolatedProfile");
        var camera=Camera.main;camera.orthographicSize=11.25f;camera.transform.position=new Vector3(33.5f,23.5f,-10);
        EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
        return new {scene=Scene,terrainSha256=Hash(File.ReadAllBytes(BaseRegion)),seed=710202,roadRenderers=overlays.Count,
           terrainObjects=1,playerScale=player.GetComponentInChildren<ProductionVisualDefinition>().transform.localScale.ToString()};
    }
    [MenuItem("Valdoria/World Studio/05 - Generate road recipe to NEW output")]
    public static void GenerateRecipe()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        string recipe=EditorUtility.OpenFilePanel("Organic road recipe",Source,"json");if(string.IsNullOrEmpty(recipe))return;
        string region=EditorUtility.OpenFilePanel("Source WorldRegion","ArtSource/Labs/World2026/WorldStudio01/Regions/B","json");if(string.IsNullOrEmpty(region))return;
        string output=EditorUtility.SaveFilePanel("NEW road output directory","ArtSource/Labs/World2026/WorldStudio02","RoadRevision","");if(string.IsNullOrEmpty(output))return;
        if(Directory.Exists(output)||File.Exists(output))throw new IOException("Refuse output overwrite");
        var info=new System.Diagnostics.ProcessStartInfo("python"){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Directory.GetCurrentDirectory()};
        foreach(var a in new[]{"Tools/ArtPipeline/WorldGen/organic_roads.py","generate","--region",region,"--recipe",recipe,"--output",output})info.ArgumentList.Add(a);
        using(var process=System.Diagnostics.Process.Start(info)){process.WaitForExit();if(process.ExitCode!=0)throw new IOException("Road authoring failed; inspect CLI diagnostics");}
        Debug.Log("Authored new road revision: "+output+"; terrain unchanged");
    }
    public static object RefineTrail()
    {
        if(EditorApplication.isPlaying)throw new IOException("Stop Play first");
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(scene.path!=Scene||scene.isDirty)throw new IOException("Open clean organic roads lab");
        VerifyArtifacts();string revision=Destination+"TrailRevision/";if(Directory.Exists(revision))throw new IOException("Refuse revision overwrite");
        Directory.CreateDirectory(revision);AssetDatabase.Refresh();
        var sprite=ImportOverlayFrom(Source+"C/road-overlay.png",revision+"C-road.png");
        File.Copy(Source+"C/road.json",revision+"C-road.json");AssetDatabase.ImportAsset(revision+"C-road.json",ImportAssetOptions.ForceSynchronousImport);
        var controller=Object.FindAnyObjectByType<OrganicRoadLabController>();var so=new SerializedObject(controller);
        so.FindProperty("roadData").GetArrayElementAtIndex(2).objectReferenceValue=AssetDatabase.LoadAssetAtPath<TextAsset>(revision+"C-road.json");
        var go=(GameObject)so.FindProperty("roads").GetArrayElementAtIndex(2).objectReferenceValue;
        go.GetComponent<SpriteRenderer>().sprite=sprite;so.ApplyModifiedPropertiesWithoutUndo();EditorUtility.SetDirty(go.GetComponent<SpriteRenderer>());
        EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return "Trail updated with two additional valley guides; same terrain/seed and original mandatory points";
    }

}
