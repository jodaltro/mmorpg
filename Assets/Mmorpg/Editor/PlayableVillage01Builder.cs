using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.Rendering;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

[InitializeOnLoad]
public static class PlayableVillage01Builder
{
    static PlayableVillage01Builder(){EditorApplication.update+=ImportTick;}
    static void ImportTick(){if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;if(SessionState.GetBool("Village01.BuildPlayer",false)){SessionState.SetBool("Village01.BuildPlayer",false);BuildPlayer();return;}if(SessionState.GetBool("Village01.LayoutRevision",false)){SessionState.SetBool("Village01.LayoutRevision",false);try{File.WriteAllText("Temp/PlayableVillage01-revision.json",JsonConvert.SerializeObject(new{success=true,result=ImportLayoutRevision()},Formatting.Indented));}catch(Exception e){File.WriteAllText("Temp/PlayableVillage01-revision.json",e.ToString());}return;}if(!SessionState.GetBool("Village01.Import",false))return;SessionState.SetBool("Village01.Import",false);try{File.WriteAllText("Temp/PlayableVillage01-build.json",JsonConvert.SerializeObject(new{success=true,result=Build()},Formatting.Indented));}catch(Exception e){File.WriteAllText("Temp/PlayableVillage01-build.json",JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}}
    public const string Source="ArtSource/World/PlayableVillage01/BuildV4/";
    public const string Art="Assets/Mmorpg/Art/World/PlayableVillage01/";
    public const string Structures="ArtSource/World/PlayableVillage01/ExportStructuresV2/";
    public const string Scene="Assets/Mmorpg/Scenes/ValdoriaPlayableVillage01.unity";
    static GameObject actor;
    static readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();
    static JObject data;
    static string Hash(string p){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
    static void VerifyFiles(string folder){var m=JObject.Parse(File.ReadAllText(folder+"manifest.json"));foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(folder+p.Name)!=(string)p.Value)throw new IOException("Village source hash mismatch "+p.Name);if(m["source"]!=null&&Hash((string)m["source"]["path"])!=(string)m["source"]["sha256"])throw new IOException("Aseprite authority changed without export");if(m["inputs"]?["recipe.json"]!=null&&Hash("ArtSource/World/PlayableVillage01/recipe.json")!=(string)m["inputs"]["recipe.json"])throw new IOException("Recipe changed without regeneration");}
    static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
    static Sprite Import(string input,string name)
    {
        if(sprites.TryGetValue(name,out var cached))return cached;
        string path=Art+name+".png";if(File.Exists(path))throw new IOException("Refuse asset overwrite "+path);
        File.Copy(input,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Sprite;
        i.spritePixelsPerUnit=32;i.spriteImportMode=SpriteImportMode.Single;i.npotScale=TextureImporterNPOTScale.None;
        i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;
        i.maxTextureSize=4096;i.alphaIsTransparency=true;var s=new TextureImporterSettings();i.ReadTextureSettings(s);
        s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=Vector2.zero;i.SetTextureSettings(s);i.SaveAndReimport();
        return sprites[name]=AssetDatabase.LoadAssetAtPath<Sprite>(path);
    }
    static SpriteRenderer Draw(string name,Sprite sprite,Vector2 position,int order,Transform parent=null)
    {
        var go=new GameObject(name);if(parent)go.transform.SetParent(parent,false);go.transform.position=position;
        var r=go.AddComponent<SpriteRenderer>();r.sprite=sprite;r.sortingOrder=order;return r;
    }
    static PolygonCollider2D Polygon(GameObject go,IEnumerable<Vector2> points)
    {go.layer=8;var c=go.AddComponent<PolygonCollider2D>();c.SetPath(0,points.Select(v=>v-(Vector2)go.transform.position).ToArray());return c;}
    static Vector2 Move(JToken p,JObject meta,Vector2 offset)=>new Vector2((float)p[0],(float)meta["sizeUnits"][1]-(float)p[1])+offset;
    static void Building(JToken b)
    {
        var meta=JObject.Parse(File.ReadAllText((string)b["metadata"]));var export=JObject.Parse(File.ReadAllText((string)b["export"]));
        string folder=Path.GetDirectoryName((string)b["export"])+"/";
        string family=(string)b["family"];string art=family=="house"?ArchitectureArt07RImporter.Art:"Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/"+(family=="barn"?"Barn/":"Castle/");
        var root=new GameObject((string)b["id"]);root.transform.position=V(b["position"]);var offset=V(b["offset"]);
        root.AddComponent<ArchitectureBuilding>().Configure((string)b["id"],family,V(b["entry"]),V(b["approach"]));
        var split=meta["depthGroups"] as JArray;var groups=new Dictionary<string,GameObject>();
        if(split==null){var g=new GameObject("Authored volumes");g.transform.SetParent(root.transform,false);g.AddComponent<SortingGroup>();groups.Add("main",g);}
        else foreach(var spec in split){var g=new GameObject((string)spec["id"]);g.transform.SetParent(root.transform,false);g.AddComponent<SortingGroup>();groups.Add((string)spec["id"],g);}
        var metadata=JObject.Parse(File.ReadAllText((string)export["sourceMetadata"]["path"]));
        var groundNames=metadata["groundLayers"]==null?new HashSet<string>{"Shadow"}:metadata["groundLayers"].Select(t=>(string)t).ToHashSet();
        int order=0;
        foreach(var p in export["parts"])
        {
            string id=(string)p["id"];var sprite=AssetDatabase.LoadAssetAtPath<Sprite>(art+id+".png");
            if(!sprite)throw new IOException("Missing existing authored part "+art+id);
            bool floor=groundNames.Contains(id);string key=split==null||floor?"main":(string)split.Single(s=>s["parts"].Any(v=>(string)v==id))["id"];
            Draw(id,sprite,V(b["position"])+V(p["offsetUnits"]),floor?-19000:order++,floor?root.transform:groups[key].transform);
        }
        foreach(var pair in groups)
        {
            var outline=split==null?meta["footprint"]:split.Single(s=>(string)s["id"]==pair.Key)["outline"];
            var rr=pair.Value.GetComponentsInChildren<SpriteRenderer>();
            var roles=rr.Select(r=>(byte)((string)export["parts"].Single(p=>(string)p["id"]==r.name)["role"]=="roof"?1:2)).ToArray();
            root.AddComponent<ReferenceHouseDepth>().Configure(actor.transform,actor.GetComponent<ProductionSpriteAnimator>().Body,pair.Value.GetComponent<SortingGroup>(),outline.Select(p=>Move(p,meta,offset)).ToArray(),rr,roles);
        }
        PrefabUtility.SaveAsPrefabAsset(root,Art+"Building-"+(string)b["id"]+".prefab");
    }
    static void Gate()
    {
        var root=new GameObject("Main gate - authored castle arch");root.transform.position=new Vector3(56,34,0);
        var group=root.AddComponent<SortingGroup>();var rr=new List<SpriteRenderer>();
        var export=JObject.Parse(File.ReadAllText("ArtSource/Labs/World2026/WorldStudio08/Castle/ExportV1/export.json"));
        foreach(string name in new[]{"GateArch","GateTimber"})
        {
            var p=export["parts"].Single(t=>(string)t["id"]==name);rr.Add(Draw(name,AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/Castle/"+name+".png"),new Vector2(56,34)+V(p["offsetUnits"]),rr.Count,root.transform));
        }
        root.AddComponent<ReferenceHouseDepth>().Configure(actor.transform,actor.GetComponent<ProductionSpriteAnimator>().Body,group,new[]{new Vector2(51.5f,34),new Vector2(63,31.2f),new Vector2(63,34),new Vector2(51.5f,36)},rr.ToArray(),new byte[]{1,2});
        PrefabUtility.SaveAsPrefabAsset(root,Art+"Gate.prefab");
    }
    static void Wall(string name,Vector2 position,bool vertical,int length)
    {
        var root=new GameObject(name);root.transform.position=position;
        var sprite=Import(Structures+(vertical?"wall-vertical.png":"wall-horizontal.png"),vertical?"wall-vertical":"wall-horizontal");
        int step=12;
        for(int k=0;k<length;k+=step)
        {
            Vector2 pos=position+(vertical?new Vector2(-1.5f,k):new Vector2(k,0));
            var r=Draw("Stone curtain "+k,sprite,pos,100-Mathf.RoundToInt((position.y+(vertical?k:0))*16),root.transform);
            float span=Math.Min(step,length-k);if(span<step)r.transform.localScale=vertical?new Vector3(1,span/step,1):new Vector3(span/step,1,1);
        }
        PrefabUtility.SaveAsPrefabAsset(root,Art+name+".prefab");
    }
    public static object Build()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse dirty, playing, or existing destination");
        VerifyFiles(Source);VerifyFiles(Structures);
        // Scene official is retained unchanged and remains a rollback entry.
        Directory.CreateDirectory(Art);Directory.CreateDirectory("Docs/Validation/ValdoriaPlayableVillage01/QA");
        File.Copy("ProjectSettings/EditorBuildSettings.asset","Docs/Validation/ValdoriaPlayableVillage01/QA/build-settings-before.txt",false);
        data=JObject.Parse(File.ReadAllText(Source+"layout.json"));var source=EditorSceneManager.OpenScene(Ground13RImporter.Scene);
        EditorSceneManager.SaveScene(source,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);actor=GameObject.Find("Player");
        var keep=new HashSet<GameObject>{actor,Camera.main.gameObject,GameObject.Find("OfflineAuthority"),Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().gameObject};
        foreach(var root in scene.GetRootGameObjects().Where(g=>!keep.Contains(g)).ToArray())Object.DestroyImmediate(root);
        foreach(var c in actor.GetComponents<MonoBehaviour>().Where(c=>c.GetType().Name.Contains("Debug")).ToArray())Object.DestroyImmediate(c);
        File.Copy(Source+"layout.json",Art+"layout.json");AssetDatabase.Refresh();
        new GameObject("Village semantic region - baked offline").AddComponent<PlayableVillageRegion>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"layout.json"),V(data["spawn"]),new Rect(0,0,112,144));
        foreach(var chunk in data["groundChunks"]){var rect=chunk["rect"];Draw("Ground "+(string)chunk["file"],Import(Source+(string)chunk["file"],Path.GetFileNameWithoutExtension((string)chunk["file"])),new Vector2((float)rect[0]/32,144-((float)rect[1]+(float)rect[3])/32),-20000);}
        // Dedicated mesh for existing four-frame water playback component.
        var water=new GameObject("Defensive river - four authored phases");var mf=water.AddComponent<MeshFilter>();var mesh=new Mesh();mesh.vertices=new[]{new Vector3(0,17),new Vector3(112,17),new Vector3(112,35),new Vector3(0,35)};mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.colors=Enumerable.Repeat(Color.white,4).ToArray();mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,Art+"River.asset");mf.sharedMesh=mesh;
        var frames=Enumerable.Range(0,4).Select(f=>Import(Source+"river-"+f+".png","river-"+f).texture).ToArray();
        var mat=new Material(Shader.Find("Sprites/Default")){mainTexture=frames[0]};AssetDatabase.CreateAsset(mat,Art+"River.mat");var mr=water.AddComponent<MeshRenderer>();mr.sharedMaterial=mat;mr.sortingOrder=-19990;water.AddComponent<WaterSurfaceAnimator>().Configure(mr,frames,.18f);
        Draw("Bridge deck - traversable",Import(Structures+"bridge-deck.png","bridge-deck"),new Vector2(51,17),-19900);
        foreach(string name in new[]{"bridge-left","bridge-right"})Draw("Bridge rail",Import(Structures+name+".png",name),new Vector2(51,17),-19900);
        var physics=new GameObject("Semantic physical boundaries");foreach(var p in data["physical"]){var go=new GameObject("Physics:"+(string)p["id"]);go.transform.SetParent(physics.transform,false);Polygon(go,p["polygon"].Select(V));}
        foreach(var b in data["buildings"])Building(b);
        Gate();Wall("West curtain",new Vector2(12,34),true,84);Wall("East curtain",new Vector2(100,34),true,84);Wall("North curtain",new Vector2(12,116),false,88);Wall("South west curtain",new Vector2(12,33),false,42);Wall("South east curtain",new Vector2(59,33),false,42);
        foreach(var p in data["props"])
        {
            string id=(string)p["asset"];var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(NatureReference10Importer.Art+id+".prefab");var go=(GameObject)PrefabUtility.InstantiatePrefab(prefab);go.name=(string)p["id"];go.transform.position=V(p["point"]);
            var depth=go.GetComponent<NaturePropDepth>();if(depth)depth.Configure(actor.transform,go.GetComponentInChildren<SortingGroup>(),go.GetComponent<PolygonCollider2D>().points);
            // Tree collider is already declared by the semantic recipe.
            foreach(var c in go.GetComponents<Collider2D>())Object.DestroyImmediate(c);
        }
        // Sparse approved Ground12 low plants reused as actual geometry/material,
        // never duplicate its comparison controllers or runtime generation.
        var originalScene=EditorSceneManager.OpenScene(Ground13RImporter.Scene,OpenSceneMode.Additive);
        var plants=originalScene.GetRootGameObjects().Single(g=>g.name.StartsWith("Ground13 lossless packed"));
        var reliefSource=originalScene.GetRootGameObjects().Single(g=>g.name.StartsWith("Ground13R geology"));var relief=Object.Instantiate(reliefSource);relief.name="Ground13R northern bedrock - beyond closed village wall";UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(relief,scene);relief.transform.position+=new Vector3(0,98,0);foreach(var r in relief.GetComponentsInChildren<Renderer>())r.sortingOrder-=98*16;
        foreach(var mf0 in plants.GetComponentsInChildren<MeshFilter>(true).Where(f=>f.sharedMesh&&f.sharedMesh.bounds.size.x<60).Take(10))
        {var go=new GameObject("Reused Ground12 verge "+mf0.name);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(go,scene);go.transform.position=new Vector3(10,0);go.AddComponent<MeshFilter>().sharedMesh=mf0.sharedMesh;var rr=go.AddComponent<MeshRenderer>();rr.sharedMaterial=mf0.GetComponent<MeshRenderer>().sharedMaterial;rr.sortingOrder=mf0.GetComponent<MeshRenderer>().sortingOrder;}
        EditorSceneManager.CloseScene(originalScene,true);EditorSceneManager.SetActiveScene(scene);
        actor.transform.position=V(data["spawn"]);actor.GetComponent<Rigidbody2D>().position=V(data["spawn"]);
        var camera=Camera.main;camera.orthographicSize=14.0625f;camera.backgroundColor=new Color(.26f,.33f,.18f);camera.transform.position=new Vector3(56,14.0625f,-10);
        var follow=camera.GetComponent<CameraFollow>();follow.enabled=true;follow.Configure(actor.transform);follow.ConfigureBounds(new Rect(0,0,112,144));follow.ConfigurePixelGrid(32);
        Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("PlayableVillage01/IsolatedProfile");
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();Physics2D.SyncTransforms();RefineIntegration();
        return new{scene=Scene,buildings=data["buildings"].Count(),groundChunks=data["groundChunks"].Count(),colliders=Object.FindObjectsByType<Collider2D>().Length,officialUnchanged=true,promoted=false};
    }
    public static object Queue()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing destination");
        SessionState.SetBool("Village01.Import",true);
        return "Queued persistent Editor import; receipt Temp/PlayableVillage01-build.json";
    }
    public static object Promote()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped candidate required");
        if(!File.Exists("Docs/Validation/ValdoriaPlayableVillage01/QA/play-qa.json"))throw new IOException("Real Play QA receipt required");
        var qa=JObject.Parse(File.ReadAllText("Docs/Validation/ValdoriaPlayableVillage01/QA/play-qa.json"));if(!(bool)qa["passed"])throw new IOException("QA did not pass");
        var collision=JObject.Parse(File.ReadAllText("Docs/Validation/ValdoriaPlayableVillage01/QA/collision-qa.json"));if(collision["error"].Type!=JTokenType.Null||collision["results"].Any(r=>!(bool)r["pass"]))throw new IOException("Directed QA did not pass");
        EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Scene,true)}.Concat(EditorBuildSettings.scenes.Where(s=>s.path!=Scene)).ToArray();return new{firstScene=EditorBuildSettings.scenes[0].path,rollback="Assets/Mmorpg/Scenes/MmorpgWorld.unity",artisticStatus="candidate"};
    }
    public static object RefineModules()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped owned scene required");
        const string revised="ArtSource/World/PlayableVillage01/ExportStructuresV2/";
        foreach(string name in new[]{"wall-horizontal","wall-vertical","bridge-left","bridge-deck","bridge-right"}){string path=Art+name+".png";if(!File.Exists(path))throw new IOException("Expected owned derivative missing");File.Copy(revised+name+".png",path,true);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);}
        foreach(Transform child in GameObject.Find("Semantic physical boundaries").transform)if(!child.name.StartsWith("Physics:"))child.name="Physics:"+child.name;
        Camera.main.orthographicSize=14.0625f;Camera.main.transform.position=new Vector3(56,14.0625f,-10);
        EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());AssetDatabase.SaveAssets();return "Explicit source V2 re-export imported; pixels/gaps corrected, physical coordinates unchanged";
    }
    public static object RefineIntegration()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped village required");
        foreach(var a in Object.FindObjectsByType<VegetationAnchor>())
        {var group=a.GetComponentInChildren<SortingGroup>();if(group)group.sortingOrder=100-Mathf.RoundToInt(a.transform.position.y*16);a.Configure(a.name,"authored-oak",a.Variant,.5f);}
        var wallImporter=(TextureImporter)AssetImporter.GetAtPath(Art+"wall-horizontal.png");var wallSettings=new TextureImporterSettings();wallImporter.ReadTextureSettings(wallSettings);wallSettings.spriteMeshType=SpriteMeshType.FullRect;wallImporter.SetTextureSettings(wallSettings);wallImporter.SaveAndReimport();
        // Partial wall pieces crop the same stone pixels, never compress merlons.
        foreach(var r in Object.FindObjectsByType<SpriteRenderer>().Where(r=>r.name.StartsWith("Stone curtain")&&r.transform.localScale.x<.999f))
        {float width=r.sprite.bounds.size.x*r.transform.localScale.x;r.transform.localScale=Vector3.one;r.drawMode=SpriteDrawMode.Tiled;r.size=new Vector2(width,r.sprite.bounds.size.y);r.tileMode=SpriteTileMode.Continuous;}
        var road=new Texture2D(2,2);road.LoadImage(File.ReadAllBytes(Source+"road-coverage.png"));int changed=0,removed=0;
        foreach(var f in Object.FindObjectsByType<MeshFilter>().Where(f=>f.name.StartsWith("Reused Ground12 verge")))
        {
            string destination=Art+"ContextVerge-"+changed+".asset";if(File.Exists(destination))continue;
            f.transform.position=new Vector3(10,35,0);var mesh=f.sharedMesh;var points=mesh.vertices;var triangles=mesh.triangles;var kept=new List<int>();
            if(triangles.Length%6!=0)throw new IOException("Expected baked sprite quad groups");
            for(int t=0;t<triangles.Length;t+=6)
            {
                var ids=triangles.Skip(t).Take(6).Distinct().ToArray();if(ids.Length!=4)throw new IOException("Expected quad topology");
                var local=new Vector3(ids.Average(i=>points[i].x),ids.Min(i=>points[i].y),0);Vector2 p=f.transform.TransformPoint(local);
                bool keep=p.x>14&&p.x<98&&p.y>38&&p.y<112&&Physics2D.OverlapCircle(p,.6f,1<<8)==null;
                foreach(var delta in new[]{Vector2.zero,Vector2.right*.75f,Vector2.left*.75f,Vector2.up*.75f,Vector2.down*.75f}){Vector2 q=p+delta;if(road.GetPixel(Mathf.Clamp((int)(q.x*32),0,road.width-1),Mathf.Clamp((int)(q.y*32),0,road.height-1)).r>.05f)keep=false;}
                if(keep)kept.AddRange(triangles.Skip(t).Take(6));else removed++;
            }
            var clone=Object.Instantiate(mesh);clone.name="Contextual Ground12 verge "+changed;clone.triangles=kept.ToArray();clone.RecalculateBounds();AssetDatabase.CreateAsset(clone,destination);f.sharedMesh=clone;f.GetComponent<MeshRenderer>().sortingOrder-=35*16;if(kept.Count==0)f.gameObject.SetActive(false);changed++;
        }
        Object.DestroyImmediate(road);foreach(string name in new[]{"West curtain","East curtain","North curtain","South west curtain","South east curtain"})PrefabUtility.SaveAsPrefabAsset(GameObject.Find(name),Art+name+".prefab");EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());AssetDatabase.SaveAssets();return new{correctedStaticTreeDepth=true,partialWalls="cropped, no scaled merlons",contextualVergeMeshes=changed,excludedVergeQuads=removed,physicsChanged=false};
    }
    public static object QueuePlayer()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty||Directory.Exists("Temp/Builds/ValdoriaVillage01"))throw new IOException("New stopped standalone destination required");SessionState.SetBool("Village01.BuildPlayer",true);return "Development Player build queued; receipt QA/standalone-build.json";
    }
    public static object ImportLayoutRevision()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped owned village required");
        VerifyFiles(Source);VerifyFiles(Structures);
        var revision=JObject.Parse(File.ReadAllText(Source+"layout.json"));
        var b=revision["buildings"].Single(x=>(string)x["id"]=="barn");var barn=GameObject.Find("barn");Vector2 delta=V(b["position"])-(Vector2)barn.transform.position;barn.transform.position=V(b["position"]);
        foreach(var depth in barn.GetComponents<ReferenceHouseDepth>()){var so=new SerializedObject(depth);var polygon=so.FindProperty("groundOutline");for(int i=0;i<polygon.arraySize;i++)polygon.GetArrayElementAtIndex(i).vector2Value+=delta;so.ApplyModifiedPropertiesWithoutUndo();}
        barn.GetComponent<ArchitectureBuilding>().Configure("barn","barn",V(b["entry"]),V(b["approach"]));PrefabUtility.SaveAsPrefabAsset(barn,Art+"Building-barn.prefab");
        foreach(var p in revision["physical"].Where(p=>((string)p["id"]).StartsWith("barn-"))){var go=GameObject.Find("Physics:"+(string)p["id"]);go.GetComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
        foreach(var chunk in revision["groundChunks"]){string name=(string)chunk["file"];File.Copy(Source+name,Art+name,true);AssetDatabase.ImportAsset(Art+name,ImportAssetOptions.ForceSynchronousImport);}
        File.Copy(Source+"layout.json",Art+"layout.json",true);AssetDatabase.ImportAsset(Art+"layout.json",ImportAssetOptions.ForceSynchronousImport);
        EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());AssetDatabase.SaveAssets();Physics2D.SyncTransforms();return new{barn=V(b["position"]).ToString(),delta=delta.ToString(),bridgeChanged=false,perimeterChanged=false,source=Source};
    }
    public static object QueueRevision(){if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped owned village required");SessionState.SetBool("Village01.LayoutRevision",true);return "Explicit lot revision queued, receipt Temp/PlayableVillage01-revision.json";}
    public static object Inspect()
    {
        if(EditorSceneManager.GetActiveScene().path!=Scene)throw new IOException("Village scene required");VerifyFiles(Source);VerifyFiles(Structures);var layout=JObject.Parse(File.ReadAllText(Source+"layout.json"));int mismatch=0;
        foreach(var p in layout["physical"]){var c=GameObject.Find("Physics:"+(string)p["id"]).GetComponent<PolygonCollider2D>();var wanted=p["polygon"].Select(V).ToArray();var actual=c.GetPath(0);if(actual.Length!=wanted.Length||actual.Where((v,i)=>Vector2.Distance(c.transform.TransformPoint(v),wanted[i])>.0001f).Any())mismatch++;}
        bool refusal=false;if(!EditorApplication.isPlaying)try{Queue();}catch(IOException){refusal=true;}
        var result=new{scene=Scene,playing=EditorApplication.isPlaying,dirty=EditorSceneManager.GetActiveScene().isDirty,physicalPolygons=layout["physical"].Count(),mismatch,colliders=Object.FindObjectsByType<Collider2D>().Length,players=Object.FindObjectsByType<PlayerController>().Length,cameras=Object.FindObjectsByType<Camera>().Count(c=>c.enabled),actors=Object.FindObjectsByType<ActorHealth>().Length,comparativeControllers=Object.FindObjectsByType<MonoBehaviour>().Count(c=>c&&new[]{"Ground13RLab","Ground13Lab","GroundFinishLab","VegetationLabController","VisualUnificationLab"}.Contains(c.GetType().Name)),refusesExistingDestination=refusal,spawn=GameObject.Find("Player").transform.position.ToString(),profile=LocalJourneyProfile.Root};
        File.WriteAllText("Docs/Validation/ValdoriaPlayableVillage01/QA/scene-integrity.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
    }
    static void BuildPlayer()
    {
        const string receipt="Docs/Validation/ValdoriaPlayableVillage01/QA/standalone-build.json";
        try{var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=new[]{Scene},locationPathName="Temp/Builds/ValdoriaVillage01/ValdoriaVillage01.exe",target=BuildTarget.StandaloneWindows64,options=BuildOptions.Development});File.WriteAllText(receipt,JsonConvert.SerializeObject(new{result=report.summary.result.ToString(),errors=report.summary.totalErrors,warnings=report.summary.totalWarnings,bytes=report.summary.totalSize,seconds=report.summary.totalTime.TotalSeconds,path=report.summary.outputPath,development=true,smokeHarnessOptIn="-village-smoke",scene=Scene},Formatting.Indented));}catch(Exception e){File.WriteAllText(receipt,JsonConvert.SerializeObject(new{error=e.ToString()},Formatting.Indented));}
    }
}
