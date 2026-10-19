using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class BuildVillage02Blockout
{
    const string Source="ArtSource/World/PlayableVillage02/BlockoutV1/";
    const string Art="Assets/Mmorpg/Art/Experimental/Village02Blockout/";
    public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Blockout.unity";
    const string QA="Docs/Validation/ValdoriaVillage02/QA/";
    static Material material;static int meshIndex;
    static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
    static string Hash(string p){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
    static MeshRenderer Face(string name,Vector2[] p,Color color,int order,Transform parent=null)
    {
        var go=new GameObject(name);if(parent)go.transform.SetParent(parent,false);
        var mesh=new Mesh{name=name};mesh.vertices=p.Select(v=>(Vector3)v).ToArray();
        // All generated volume faces are convex. Ground commons is triangulated separately.
        var triangles=new int[(p.Length-2)*3];for(int i=0;i<p.Length-2;i++){triangles[i*3]=0;triangles[i*3+1]=i+1;triangles[i*3+2]=i+2;}
        mesh.triangles=triangles;mesh.colors=Enumerable.Repeat(color,p.Length).ToArray();mesh.RecalculateBounds();
        AssetDatabase.CreateAsset(mesh,Art+"Mesh-"+(meshIndex++)+".asset");go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.sortingOrder=order;return r;
    }
    static void GroundLine(string name,JToken points,float width,Color color,int order)
    {
        var pp=points.Select(V).ToArray();for(int i=0;i<pp.Length-1;i++)
        {
            var a=pp[i];var b=pp[i+1];var n=new Vector2(-(b-a).y,(b-a).x).normalized*width*.5f;
            Face(name+" "+i,new[]{a+n,a-n,b-n,b+n},color,order);
            // Shared discs close joins; no visual gap at a bent street.
            var ring=Enumerable.Range(0,16).Select(k=>b+new Vector2(Mathf.Cos(k*Mathf.PI/8),Mathf.Sin(k*Mathf.PI/8))*width*.5f).ToArray();Face(name+" join",ring,color,order);
        }
    }
    public static object Main()
    {
        var active=EditorSceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||active.isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse dirty/playing/existing blockout destination");
        var m=JObject.Parse(File.ReadAllText(Source+"manifest.json"));foreach(var f in ((JObject)m["files"]).Properties())if(Hash(Source+f.Name)!=(string)f.Value)throw new IOException("Source mismatch "+f.Name);
        if(Hash("ArtSource/World/PlayableVillage02/recipe.json")!=(string)m["recipe"])throw new IOException("Recipe changed without bake");
        Directory.CreateDirectory(Art);Directory.CreateDirectory(QA);
        File.WriteAllText(QA+"editor-before.json",JsonConvert.SerializeObject(new{scene=active.path,dirty=active.isDirty,buildScenes=EditorBuildSettings.scenes.Select(s=>new{s.path,s.enabled}),timeScale=Time.timeScale},Formatting.Indented));
        var source=EditorSceneManager.OpenScene(PlayableVillage01Builder.Scene);EditorSceneManager.SaveScene(source,Scene,true);
        var scene=EditorSceneManager.OpenScene(Scene);var actor=GameObject.Find("Player");var camera=Camera.main;
        var keep=new[]{actor,camera.gameObject,GameObject.Find("OfflineAuthority"),Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().gameObject};
        foreach(var go in scene.GetRootGameObjects().Where(g=>!keep.Contains(g)).ToArray())Object.DestroyImmediate(go);
        foreach(var c in actor.GetComponents<MonoBehaviour>().Where(c=>c.GetType().Name.Contains("Debug")).ToArray())Object.DestroyImmediate(c);
        material=new Material(Shader.Find("Sprites/Default"));AssetDatabase.CreateAsset(material,Art+"Neutral.mat");meshIndex=0;
        var d=JObject.Parse(File.ReadAllText(Source+"layout.json"));File.Copy(Source+"layout.json",Art+"layout.json",false);AssetDatabase.Refresh();
        new GameObject("Village02 semantic blockout").AddComponent<PlayableVillageRegion>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"layout.json"),V(d["spawn"]),new Rect(0,0,128,152));
        Face("Neutral ground",new[]{Vector2.zero,new Vector2(128,0),new Vector2(128,152),new Vector2(0,152)},new Color(.34f,.37f,.32f),-20000);
        foreach(var s in d["surfaces"])
        {
            string tone=(string)s["tone"];Color c=tone=="water"?new Color(.24f,.38f,.42f):tone=="bridge"?new Color(.54f,.50f,.42f):new Color(.50f,.49f,.43f);
            if(tone=="water")
            {
                var p=s["polygon"].Select(V).ToArray();int half=p.Length/2;
                for(int i=0;i<half-1;i++)Face("River study "+i,new[]{p[i],p[i+1],p[p.Length-2-i],p[p.Length-1-i]},c,-19950);
            }
            else Face((string)s["id"],s["polygon"].Select(V).ToArray(),c,tone=="bridge"?-19800:-19900);
        }
        foreach(var r in d["roads"])GroundLine((string)r["id"],r["points"],(float)r["width"],new Color(.56f,.53f,.46f),-19900);
        foreach(var lot in d["lots"])
        {
            var p=new JArray(lot["lot"].Select(x=>x.DeepClone()));p.Add(lot["lot"][0].DeepClone());GroundLine("Lot boundary "+(string)lot["id"],p,.12f,new Color(.64f,.67f,.57f),-19850);
        }
        foreach(var line in d["terrain"]["contours"])GroundLine("Contour study",line,.18f,new Color(.42f,.45f,.38f),-19980);
        foreach(var v in d["volumes"])
        {
            var root=new GameObject((string)v["id"]);var group=root.AddComponent<SortingGroup>();int order=0;
            foreach(var f in v["faces"]){float t=(float)f["tone"];Face("Neutral face",f["polygon"].Select(V).ToArray(),new Color(t,t*.98f,t*.92f),order++,root.transform);}
            var outline=v["footprint"].Select(V).ToArray();root.AddComponent<VillageBlockoutDepth>().Configure(actor.transform,group,outline);
            // Door scale marks are part of the neutral study, never navigable interiors.
            var spec=d["lots"].Concat(d["castle"]["volumes"]).FirstOrDefault(s=>(string)s["id"]==(string)v["id"]);
            if(spec!=null){var p=V(spec["anchor"]);Face("Door 4.85u",new[]{p+new Vector2(-1.05f,.189f),p+new Vector2(1.05f,-.189f),p+new Vector2(1.05f,4.661f),p+new Vector2(-1.05f,5.039f)},new Color(.26f,.27f,.26f),order++,root.transform);}
        }
        var physics=new GameObject("Semantic physical boundaries");
        foreach(var p in d["physical"]){var go=new GameObject("Physics:"+(string)p["id"]);go.transform.SetParent(physics.transform,false);go.layer=8;go.AddComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
        actor.transform.position=V(d["spawn"]);actor.GetComponent<Rigidbody2D>().position=V(d["spawn"]);
        camera.orthographicSize=14.0625f;camera.backgroundColor=new Color(.24f,.26f,.23f);camera.transform.position=new Vector3(53,14.0625f,-10);
        var follow=camera.GetComponent<CameraFollow>();follow.enabled=true;follow.Configure(actor.transform);follow.ConfigureBounds(new Rect(0,0,128,152));follow.ConfigurePixelGrid(32);
        Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("Village02Blockout/IsolatedProfile");
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
        var result=new{scene=Scene,volumes=d["volumes"].Count(),physical=d["physical"].Count(),meshes=meshIndex,promoted=false,neutralStudy=true};
        File.WriteAllText(QA+"build.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
    }
}
