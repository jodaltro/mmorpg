using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Tilemaps;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

// Offline semantic import. Every asset/scene destination must be absent.
public static class TerrainStudioImporter
{
    const string Source="ArtSource/Labs/World2026/WorldStudio01/";
    const string Art="Assets/Mmorpg/Art/Experimental/ValdoriaTerrainStudio01/";
    const string Scene="Assets/Mmorpg/Scenes/ValdoriaTerrainLab.unity";
    static string Sha(byte[] bytes){using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant();}
    static void CheckBuild(string variant)
    {
        var dir=Source+"Regions/"+variant+"/";
        var m=JObject.Parse(File.ReadAllText(dir+"manifest.json"));
        foreach(var group in new[]{"outputs","studioOutputs"})
            foreach(var p in ((JObject)m[group]).Properties())
                if(Sha(File.ReadAllBytes(dir+p.Name))!=(string)p.Value)throw new IOException("Hash mismatch: "+p.Name);
        if(Sha(File.ReadAllBytes(Source+"Materials/materials.json"))!=(string)m["materialSha256"])throw new IOException("Material manifest mismatch");
        var material=JObject.Parse(File.ReadAllText(Source+"Materials/materials.json"));
        foreach(var f in ((JObject)material["files"]).Properties())
            if(Sha(File.ReadAllBytes(Source+"Materials/"+f.Name))!=(string)f.Value)throw new IOException("Material file mismatch "+f.Name);
        var region=JObject.Parse(File.ReadAllText(dir+"world-region.json"));
        ValidateRegion(region);
    }
    static void ValidateRegion(JObject region)
    {
        if((string)region["schema"]!="valdoria-world-region/v1")throw new IOException("Unsupported region schema");
        int w=(int)region["size"][0],h=(int)region["size"][1];
        if(w<16||h<16||w>256||h>256)throw new IOException("Invalid region dimensions");
        int count=w*h;
        foreach(var l in ((JObject)region["layers"]).Properties())if(((JArray)l.Value).Count!=count)throw new IOException("Misaligned layer "+l.Name);
        if(((JArray)region["presentation"]["tileIndices"]).Count!=count)throw new IOException("Misaligned tiles");
        foreach(var id in region["presentation"]["tileIndices"])if((int)id<0||(int)id>=140)throw new IOException("Invalid material tile index");
        for(int i=0;i<count;i++)
        {
            if((bool)region["layers"]["blocked"][i]==(bool)region["layers"]["walkable"][i])throw new IOException("Collision/navigation mismatch");
            int elevation=(int)region["layers"]["elevationMilli"][i];if(elevation<0||elevation>1000)throw new IOException("Invalid elevation");
        }
        if(!(bool)region["navigation"]["routeConnected"])throw new IOException("Disconnected route");
        if((float)region["cellSizeUnits"]!=1)throw new IOException("Studio material contract requires 1-unit/32px cells");
    }
    static Sprite[] ImportSheet(string filename,int width,int height,int count,Vector2 pivot)
    {
        var path=Art+filename;File.Copy(Source+"Materials/"+filename,path);
        AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);
        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;
        importer.spritePixelsPerUnit=32;importer.filterMode=FilterMode.Point;
        importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;
        importer.alphaIsTransparency=true;importer.maxTextureSize=2048;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);
        var factories=new SpriteDataProviderFactories();factories.Init();
        var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        importer.GetSourceTextureWidthAndHeight(out int iw,out int ih); int cols=iw/width;
        var rects=Enumerable.Range(0,count).Select(i=>new SpriteRect{name="tile_"+i.ToString("000"),rect=new Rect((i%cols)*width,ih-(i/cols+1)*height,width,height),pivot=pivot,alignment=SpriteAlignment.Custom,spriteID=GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);
        var names=provider.GetDataProvider<ISpriteNameFileIdDataProvider>();
        names.SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));
        provider.Apply();importer.SaveAndReimport();
        return AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().OrderBy(x=>x.name).ToArray();
    }
    static void Remap(GameObject player, OfflineAuthority previous, OfflineAuthority next)
    {
        foreach(var c in player.GetComponentsInChildren<Component>(true))
        {
            if(c==null)continue;
            var so=new SerializedObject(c);var prop=so.GetIterator();
            while(prop.Next(true))
            {
                if(prop.propertyType!=SerializedPropertyType.ObjectReference)continue;
                var value=prop.objectReferenceValue;
                if(value==previous)prop.objectReferenceValue=next;
                else if(value!=null&&!EditorUtility.IsPersistent(value))
                {
                    var go=value as GameObject;var comp=value as Component;if(comp!=null)go=comp.gameObject;
                    if(go!=null&&go!=player&&!go.transform.IsChildOf(player.transform))prop.objectReferenceValue=null;
                }
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }
    }
    static GameObject BuildRegion(JObject r,Tile[] tiles,Material material,string reliefDestination)
    {
        ValidateRegion(r);int w=(int)r["size"][0],h=(int)r["size"][1];
        var root=new GameObject((string)r["regionId"]);root.AddComponent<Grid>();
        var ground=new GameObject("Surfaces");ground.transform.SetParent(root.transform);
        var map=ground.AddComponent<Tilemap>();var mr=ground.AddComponent<TilemapRenderer>();mr.sharedMaterial=material;mr.sortingOrder=-2000;
        var ids=r["presentation"]["tileIndices"];
        var positions=new Vector3Int[w*h];var selected=new TileBase[w*h];
        for(int i=0;i<w*h;i++){positions[i]=new Vector3Int(i%w,h-1-i/w,0);selected[i]=tiles[(int)ids[i]];}
        map.SetTiles(positions,selected);map.CompressBounds();
        var physics=new GameObject("Collision - blocked semantic cells");physics.transform.SetParent(root.transform);physics.layer=8;
        var blocked=r["layers"]["blocked"];
        // Merge horizontal runs exactly. Surface art never supplies collision geometry.
        for(int y=0;y<h;y++)for(int x=0;x<w;x++)
        {
            if(!(bool)blocked[y*w+x])continue;
            int first=x;while(x+1<w&&(bool)blocked[y*w+x+1])x++;
            var box=physics.AddComponent<BoxCollider2D>();box.offset=new Vector2((first+x+1)*.5f,h-y-.5f);box.size=new Vector2(x-first+1,1);
        }
        var border=new GameObject("Region limits");border.transform.SetParent(root.transform);border.layer=8;
        foreach(var rect in new[]{new Rect(-1,-1,1,h+2),new Rect(w,-1,1,h+2),new Rect(0,-1,w,1),new Rect(0,h,w,1)})
        {var c=border.AddComponent<BoxCollider2D>();c.offset=rect.center;c.size=rect.size;}
        TerrainReliefBuilder.Add(root,r,reliefDestination);
        return root;
    }
    [MenuItem("Valdoria/World Studio/01 - Build Terrain Lab (new destinations)")]
    public static void BuildMenu()=>Build();
    public static object Build()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(original.isDirty||original.path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity")throw new InvalidOperationException("Open clean official scene as character template");
        if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing scene/art destination; use new revision");
        foreach(var v in new[]{"A","B","C"})CheckBuild(v);
        var sourcePlayer=GameObject.Find("Player");var previous=Object.FindAnyObjectByType<OfflineAuthority>();
        Directory.CreateDirectory(Art);AssetDatabase.Refresh();
        var sprites=ImportSheet("surfaces.png",32,32,140,new Vector2(.5f,.5f));
        ImportSheet("cliffs.png",32,64,4,new Vector2(.5f,0));
        var material=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default"));AssetDatabase.CreateAsset(material,Art+"TerrainUnlit.mat");
        var tiles=new Tile[sprites.Length];
        for(int i=0;i<tiles.Length;i++){tiles[i]=ScriptableObject.CreateInstance<Tile>();tiles[i].sprite=sprites[i];tiles[i].colliderType=Tile.ColliderType.None;AssetDatabase.CreateAsset(tiles[i],Art+"Tile_"+i.ToString("000")+".asset");}
        var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Additive);
        UnityEngine.SceneManagement.SceneManager.SetActiveScene(scene);
        var player=Object.Instantiate(sourcePlayer);player.name="Player";
        var authority=new GameObject("OfflineAuthority").AddComponent<OfflineAuthority>();Remap(player,previous,authority);
        // This terrain study keeps the production motor/animation, without HUD-dependent feedback.
        var feedback=player.GetComponent<PlayerCombatFeedback>();if(feedback!=null)Object.DestroyImmediate(feedback);
        var action=player.GetComponent<ActionCombat>();if(action!=null)action.enabled=false;
        player.GetComponent<PlayerController>().Configure(authority);player.GetComponent<PlayerController>().ConfigureAction(null);
        authority.ConfigureSword(player.GetComponent<SwordSwing>());
        var visual=player.GetComponentInChildren<ProductionVisualDefinition>();
        var grouping=visual.GetComponent<SortingGroup>()??visual.gameObject.AddComponent<SortingGroup>();player.GetComponent<ProductionVisualSync>().ConfigureSortingGroup(grouping);
        var camera=new GameObject("Main Camera");camera.tag="MainCamera";
        var cam=camera.AddComponent<Camera>();cam.orthographic=true;cam.orthographicSize=11.25f;cam.clearFlags=CameraClearFlags.SolidColor;cam.backgroundColor=new Color(.15f,.20f,.18f);cam.nearClipPlane=.1f;cam.farClipPlane=100;
        camera.transform.position=new Vector3(14.5f,14.5f,-10);
        var follow=camera.AddComponent<CameraFollow>();follow.Configure(player.transform);follow.ConfigurePixelGrid(32);follow.ConfigureBounds(new Rect(0,0,64,48));
        var isolation=new GameObject("TerrainLab-ProfileIsolation").AddComponent<ValdoriaR9ProfileIsolation>();isolation.ConfigureTemporaryProfile("ValdoriaTerrainStudio01/IsolatedProfile");
        var roots=new List<GameObject>();var data=new List<TextAsset>();
        foreach(var v in new[]{"A","B","C"})
        {
            var path=Art+"WorldRegion-"+v+".json";File.Copy(Source+"Regions/"+v+"/world-region.json",path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            var asset=AssetDatabase.LoadAssetAtPath<TextAsset>(path);data.Add(asset);var generated=BuildRegion(JObject.Parse(asset.text),tiles,material,Art+"Relief/"+v);generated.AddComponent<TerrainRegionData>().Configure(asset);roots.Add(generated);
        }
        var controller=new GameObject("TerrainLab - 1 Plains 2 Hills 3 Valley").AddComponent<TerrainLabController>();
        controller.Configure(roots.ToArray(),data.ToArray(),player.transform,new Vector3(14.5f,14.5f,0));
        EditorSceneManager.SaveScene(scene,Scene);AssetDatabase.SaveAssets();EditorSceneManager.CloseScene(original,true);
        return new{scene=Scene,tiles=tiles.Length,regions=roots.Count,character=visual.Character.characterId,scale=visual.transform.localScale.ToString()};
    }
    [MenuItem("Valdoria/World Studio/02 - Regenerate recipe to NEW output")]
    public static void Regenerate()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var recipe=EditorUtility.OpenFilePanel("Terrain recipe", "ArtSource/Labs/World2026/WorldGen/Recipes", "json");if(string.IsNullOrEmpty(recipe))return;
        var output=EditorUtility.SaveFilePanel("NEW output directory (must not exist)", "ArtSource/Labs/World2026/WorldStudio01", "RegionRevision", "");if(string.IsNullOrEmpty(output))return;
        if(Directory.Exists(output)||File.Exists(output))throw new IOException("Refuse existing output");
        var info=new System.Diagnostics.ProcessStartInfo("python"){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Directory.GetCurrentDirectory()};
        foreach(var a in new[]{"Tools/ArtPipeline/WorldGen/studio01.py","generate","--recipe",recipe,"--output",output})info.ArgumentList.Add(a);
        using(var process=System.Diagnostics.Process.Start(info)){process.WaitForExit();if(process.ExitCode!=0)throw new IOException("Generation failed");}
        Debug.Log("Generated new semantic/material revision: "+output+". Import as a new candidate; existing scenes unchanged.");
    }
    [MenuItem("Valdoria/World Studio/03 - Import revision as NEW prefab")]
    public static void ImportRevision()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var regionFile=EditorUtility.OpenFilePanel("Generated world-region.json",Source+"Regions","json");
        if(string.IsNullOrEmpty(regionFile))return;
        var destination=EditorUtility.SaveFilePanelInProject("NEW region prefab","TerrainRegionRevision","prefab","Choose absent destination");
        if(string.IsNullOrEmpty(destination))return;
        ImportGeneratedRegion(regionFile,destination);
    }
    public static string ImportGeneratedRegion(string regionFile,string destination)
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        if(!destination.StartsWith("Assets/",StringComparison.Ordinal)||!destination.EndsWith(".prefab",StringComparison.Ordinal))throw new IOException("Prefab destination must be inside Assets");
        var absolute=Path.GetFullPath(destination);var assets=Path.GetFullPath("Assets")+Path.DirectorySeparatorChar;
        if(!absolute.StartsWith(assets,StringComparison.OrdinalIgnoreCase))throw new IOException("Destination outside Assets");
        var dataPath=Path.ChangeExtension(destination,".json");
        if(File.Exists(destination)||File.Exists(dataPath)||Directory.Exists(Path.ChangeExtension(destination,null)+"-Relief"))throw new IOException("Refuse existing prefab/data/relief destination");
        var dir=Path.GetDirectoryName(regionFile);var manifest=JObject.Parse(File.ReadAllText(Path.Combine(dir,"manifest.json")));
        foreach(var group in new[]{"outputs","studioOutputs"})foreach(var f in ((JObject)manifest[group]).Properties())
            if(Sha(File.ReadAllBytes(Path.Combine(dir,f.Name)))!=(string)f.Value)throw new IOException("Hash mismatch "+f.Name);
        if((string)manifest["materialSha256"]!=Sha(File.ReadAllBytes(Source+"Materials/materials.json")))throw new IOException("Material revision mismatch");
        var r=JObject.Parse(File.ReadAllText(regionFile));ValidateRegion(r);
        Directory.CreateDirectory(Path.GetDirectoryName(destination));File.Copy(regionFile,dataPath);
        AssetDatabase.ImportAsset(dataPath,ImportAssetOptions.ForceSynchronousImport);
        var tiles=Enumerable.Range(0,140).Select(i=>AssetDatabase.LoadAssetAtPath<Tile>(Art+"Tile_"+i.ToString("000")+".asset")).ToArray();
        if(tiles.Any(t=>t==null))throw new IOException("Build material library first");
        var temporary=EditorSceneManager.NewPreviewScene();GameObject root=null;
        try
        {
            root=BuildRegion(r,tiles,AssetDatabase.LoadAssetAtPath<Material>(Art+"TerrainUnlit.mat"),Path.ChangeExtension(destination,null)+"-Relief");
            root.AddComponent<TerrainRegionData>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(dataPath));
            UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,temporary);
            PrefabUtility.SaveAsPrefabAsset(root,destination);
        }
        finally {EditorSceneManager.ClosePreviewScene(temporary);}
        return "New region prefab imported: "+destination;
    }

}
