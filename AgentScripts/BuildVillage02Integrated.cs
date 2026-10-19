using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class BuildVillage02Integrated
{
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Integrated.unity";
 const string Source="ArtSource/World/PlayableVillage02/IntegrationV1/",Art="Assets/Mmorpg/Art/World/Village02Integrated/",QA="Docs/Validation/ValdoriaVillage02-Integration/QA/";
 static Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();static GameObject actor;static Material wallMaterial;static int meshIndex;
 static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
 static string Hash(string p){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
 static Sprite Import(string source,string id,Vector2 anchor)
 {
  if(sprites.TryGetValue(id,out var cached))return cached;string path=Art+id+".png";File.Copy(source,path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
  var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Single;importer.spritePixelsPerUnit=32;importer.npotScale=TextureImporterNPOTScale.None;importer.filterMode=FilterMode.Point;importer.mipmapEnabled=false;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.maxTextureSize=4096;importer.alphaIsTransparency=true;
  if(id.StartsWith("river-"))importer.maxTextureSize=16384;
  var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=anchor;settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();return sprites[id]=AssetDatabase.LoadAssetAtPath<Sprite>(path);
 }
 static SpriteRenderer Draw(string name,Sprite sprite,Vector2 p,int order,Transform parent=null)
 {var go=new GameObject(name);go.transform.SetParent(parent,false);go.transform.position=p;var rr=go.AddComponent<SpriteRenderer>();rr.sprite=sprite;rr.sortingOrder=order;return rr;}
 static void Depth(GameObject go,Vector2[] outline)
 {var group=go.AddComponent<SortingGroup>();go.AddComponent<OpaqueStructureDepth>().Configure(actor.transform,actor.GetComponent<ProductionSpriteAnimator>().Body,group,outline);}
 static void CloseWallMesh(Mesh mesh,Vector2[] outline)
 {
  if(mesh.name.EndsWith(" closed"))throw new IOException("Curtain already closed");
  var vertices=mesh.vertices.ToList();var uv=mesh.uv.ToList();var tris=mesh.triangles.ToList();
  void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d){int k=vertices.Count;vertices.AddRange(new[]{a,b,c,d});uv.AddRange(new[]{new Vector2(80f/417,1-140f/278),new Vector2(140f/417,1-140f/278),new Vector2(140f/417,1-110f/278),new Vector2(80f/417,1-110f/278)});tris.AddRange(new[]{k,k+1,k+2,k,k+2,k+3});}
  // A closed 1.5u base and coping remain visible when the curtain runs north/
  // south, where a single vertical billboard would collapse to zero width.
  for(int i=0;i<outline.Length;i++){Vector3 a=outline[i],b=outline[(i+1)%outline.Length];Quad(a,b,b+Vector3.up*3,a+Vector3.up*3);}
  Quad((Vector3)outline[0]+Vector3.up*3,(Vector3)outline[1]+Vector3.up*3,(Vector3)outline[2]+Vector3.up*3,(Vector3)outline[3]+Vector3.up*3);
  mesh.vertices=vertices.ToArray();mesh.uv=uv.ToArray();mesh.triangles=tris.ToArray();mesh.RecalculateBounds();mesh.name+=" closed";
 }
 static void Wall(JToken spec)
 {
  var a=V(spec["a"]);var b=V(spec["b"]);var root=new GameObject((string)spec["id"]);var mesh=new Mesh{name=root.name};int columns=32;var vv=new Vector3[(columns+1)*2];var uv=new Vector2[vv.Length];var tt=new int[columns*6];
  // Repeat the approved stone face at native texel height. Only the ground
  // direction follows the perimeter; no house/castle raster is deformed.
  for(int i=0;i<=columns;i++){float t=i/(float)columns;float x=Mathf.Lerp(28,335,t);float foot=158+(x-10)*.34f;var p=Vector2.Lerp(a,b,t);vv[2*i]=p;vv[2*i+1]=p+Vector2.up*foot/32;uv[2*i]=new Vector2(x/417,(278-foot)/278);uv[2*i+1]=new Vector2(x/417,1);if(i<columns){int j=i*6,k=i*2;tt[j]=k;tt[j+1]=k+1;tt[j+2]=k+2;tt[j+3]=k+2;tt[j+4]=k+1;tt[j+5]=k+3;}}
  mesh.vertices=vv;mesh.uv=uv;mesh.triangles=tt;mesh.RecalculateBounds();CloseWallMesh(mesh,spec["polygon"].Select(V).ToArray());AssetDatabase.CreateAsset(mesh,Art+"Wall-"+(meshIndex++)+".asset");root.AddComponent<MeshFilter>().sharedMesh=mesh;root.AddComponent<MeshRenderer>().sharedMaterial=wallMaterial;Depth(root,spec["polygon"].Select(V).ToArray());
 }
 public static object Main()
 {
  var before=EditorSceneManager.GetActiveScene();if(EditorApplication.isPlaying||before.isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse dirty/playing/existing integration destination");
  var manifest=JObject.Parse(File.ReadAllText(Source+"manifest.json"));foreach(var p in ((JObject)manifest["files"]).Properties())if(Hash(Source+p.Name)!=(string)p.Value)throw new IOException("Integration hash mismatch: "+p.Name);
  var catalog=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/ArtProductionV1/ExportV1/catalog.json"));foreach(var a in catalog["assets"])if(Hash((string)a["source"])!=(string)a["sourceSHA256"]||Hash((string)a["composite"])!=(string)a["compositeSHA256"])throw new IOException("Approved art changed");
  Directory.CreateDirectory(Art);Directory.CreateDirectory(QA);File.WriteAllText(QA+"editor-before.json",JsonConvert.SerializeObject(new{scene=before.path,dirty=before.isDirty,buildSettings=EditorBuildSettings.scenes.Select(s=>new{s.path,s.enabled})},Formatting.Indented));
  var src=EditorSceneManager.OpenScene(PlayableVillage01Builder.Scene);EditorSceneManager.SaveScene(src,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);actor=GameObject.Find("Player");var camera=Camera.main;var isolation=Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>();var keep=new[]{actor,camera.gameObject,GameObject.Find("OfflineAuthority"),isolation.gameObject};foreach(var g in scene.GetRootGameObjects().Where(g=>!keep.Contains(g)).ToArray())Object.DestroyImmediate(g);foreach(var c in actor.GetComponents<MonoBehaviour>().Where(c=>c.GetType().Name.Contains("Debug")).ToArray())Object.DestroyImmediate(c);
  var d=JObject.Parse(File.ReadAllText(Source+"layout.json"));File.Copy(Source+"layout.json",Art+"layout.json",false);AssetDatabase.ImportAsset(Art+"layout.json");new GameObject("Village02 integrated semantic region").AddComponent<PlayableVillageRegion>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"layout.json"),V(d["spawn"]),new Rect(0,0,282,335));
  foreach(var p in d["groundChunks"]){var r=p["rect"];Draw("Ground "+(string)p["file"],Import(Source+(string)p["file"],Path.GetFileNameWithoutExtension((string)p["file"]),Vector2.zero),new Vector2((float)r[0]/32,335-((float)r[1]+(float)r[3])/32),-20000);}
  foreach(var b in d["buildings"]){var root=new GameObject("Building:"+(string)b["id"]);var canvas=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/ArtProductionV1/SourceV1/"+(string)b["id"]+"/house-source.json"))["canvas"];var pivot=new Vector2((float)b["anchorPixels"][0]/(float)canvas[0],1-(float)b["anchorPixels"][1]/(float)canvas[1]);Draw("Approved "+(string)b["id"],Import((string)b["composite"],(string)b["id"],pivot),V(b["position"]),0,root.transform);Depth(root,b["polygons"][0].Select(V).ToArray());}
  foreach(var b in d["pieces"]){string id=(string)b["id"];var canvas=JObject.Parse(File.ReadAllText(Source+"DepthArt/"+id+"/provenance.json"))["canvas"];var pivot=new Vector2((float)b["anchorPixels"][0]/(float)canvas[0],1-(float)b["anchorPixels"][1]/(float)canvas[1]);foreach(var p in b["parts"]){string name=id+"-"+(string)p["id"];var root=new GameObject("Volume:"+name);Draw("Approved partition "+name,Import(Source+"DepthArt/"+id+"/"+(string)p["id"]+".png",name,pivot),V(b["position"]),(bool)p["ground"]?-19800:0,root.transform);if(!(bool)p["ground"])Depth(root,p["depth"].Select(V).ToArray());}}
  var wall=Import("ArtSource/World/PlayableVillage02/ArtProductionV1/ExportV1/wall/composite.png","curtain-source",Vector2.zero);wallMaterial=new Material(Shader.Find("Sprites/Default")){mainTexture=wall.texture};AssetDatabase.CreateAsset(wallMaterial,Art+"Curtain.mat");foreach(var p in d["townWalls"])Wall(p);
  var physics=new GameObject("Semantic physical boundaries");foreach(var p in d["physical"]){var go=new GameObject("Physics:"+(string)p["id"]);go.transform.SetParent(physics.transform,false);go.layer=8;go.AddComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
  // Ground13's water presentation is compiled separately from its collision.
  var frames=Enumerable.Range(0,4).Select(f=>Import(Source+"river-"+f+".png","river-"+f,Vector2.zero).texture).ToArray();
  var water=new GameObject("River - semantic animated channel");var waterMesh=new Mesh{name="River band"};waterMesh.vertices=new[]{new Vector3(0,55),new Vector3(282,55),new Vector3(282,100),new Vector3(0,100)};waterMesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};waterMesh.triangles=new[]{0,1,2,0,2,3};waterMesh.RecalculateBounds();AssetDatabase.CreateAsset(waterMesh,Art+"River.asset");water.AddComponent<MeshFilter>().sharedMesh=waterMesh;var wr=water.AddComponent<MeshRenderer>();var wm=new Material(Shader.Find("Sprites/Default")){mainTexture=frames[0]};AssetDatabase.CreateAsset(wm,Art+"River.mat");wr.sharedMaterial=wm;wr.sortingOrder=-19950;water.AddComponent<WaterSurfaceAnimator>().Configure(wr,frames,.18f);
  actor.transform.position=V(d["spawn"]);actor.GetComponent<Rigidbody2D>().position=V(d["spawn"]);actor.GetComponent<Rigidbody2D>().collisionDetectionMode=CollisionDetectionMode2D.Continuous;isolation.ConfigureTemporaryProfile("Village02Integration/IsolatedProfile");camera.orthographicSize=14.0625f;camera.transform.position=new Vector3((float)d["spawn"][0],(float)d["spawn"][1]+4,-10);var follow=camera.GetComponent<CameraFollow>();follow.Configure(actor.transform);follow.ConfigureBounds(new Rect(0,0,282,335));follow.ConfigurePixelGrid(32);follow.enabled=true;
  EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();var receipt=new{scene=Scene,buildings=7,compoundParts=d["pieces"].Sum(p=>p["parts"].Count()),physical=d["physical"].Count(),wallSegments=meshIndex,groundChunks=d["groundChunks"].Count(),players=Object.FindObjectsByType<PlayerController>().Length,cameras=Object.FindObjectsByType<Camera>().Count(c=>c.enabled),worldIntegrated=true,promoted=false};File.WriteAllText(QA+"build.json",JsonConvert.SerializeObject(receipt,Formatting.Indented));return receipt;
 }
 public static object Restore()
 {if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Stopped clean editor required");if(SessionState.GetBool("Village02Integration.FPSOverride",false)){Application.targetFrameRate=SessionState.GetInt("Village02Integration.PreviousFPS",-1);SessionState.SetBool("Village02Integration.FPSOverride",false);}var b=JObject.Parse(File.ReadAllText(QA+"editor-before.json"));EditorSceneManager.OpenScene((string)b["scene"]);var r=new{scene=EditorSceneManager.GetActiveScene().path,playing=EditorApplication.isPlaying,dirty=EditorSceneManager.GetActiveScene().isDirty,timeScale=Time.timeScale,targetFrameRate=Application.targetFrameRate,promoted=EditorBuildSettings.scenes.Any(s=>s.path==Scene)};File.WriteAllText(QA+"editor-restored.json",JsonConvert.SerializeObject(r,Formatting.Indented));return r;}
 public static object CloseOwnedCurtains()
 {
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped owned integration required");var d=JObject.Parse(File.ReadAllText(Source+"layout.json"));int count=0;foreach(var p in d["townWalls"]){var go=GameObject.Find((string)p["id"]);var mesh=go.GetComponent<MeshFilter>().sharedMesh;if(!AssetDatabase.GetAssetPath(mesh).StartsWith(Art))throw new IOException("Unowned curtain");CloseWallMesh(mesh,p["polygon"].Select(V).ToArray());EditorUtility.SetDirty(mesh);count++;}AssetDatabase.SaveAssets();File.WriteAllText(QA+"closed-curtains.json",JsonConvert.SerializeObject(new{count,physicalUnchanged=true,reason="Keep north/south wall base visible instead of an edge-on billboard"},Formatting.Indented));return count;
 }
 public static object AddSolidGateLeaves()
 {
  const string revision="ArtSource/World/PlayableVillage02/IntegrationV2/";
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||EditorSceneManager.GetActiveScene().isDirty||File.Exists(Art+"LeafV2-gate-wood-west.png"))throw new IOException("Clean owned candidate and new leaf revision required");
  var m=JObject.Parse(File.ReadAllText(revision+"manifest.json"));foreach(var f in ((JObject)m["files"]).Properties())if(Hash(revision+f.Name)!=(string)f.Value)throw new IOException("Leaf revision mismatch");if(Hash(Source+"manifest.json")!=(string)m["base"]["sha256"])throw new IOException("Base changed");
  actor=GameObject.Find("Player");var d=JObject.Parse(File.ReadAllText(revision+"layout.json"));
  foreach(var b in d["pieces"].Where(b=>(string)b["id"]!="bridge")){
   string id=(string)b["id"];foreach(var g in EditorSceneManager.GetActiveScene().GetRootGameObjects().Where(g=>g.name.StartsWith("Volume:"+id+"-")).ToArray())Object.DestroyImmediate(g);
   var canvas=JObject.Parse(File.ReadAllText(revision+"DepthArt/"+id+"/provenance.json"))["canvas"];var pivot=new Vector2((float)b["anchorPixels"][0]/(float)canvas[0],1-(float)b["anchorPixels"][1]/(float)canvas[1]);
   foreach(var p in b["parts"]){string name=id+"-"+(string)p["id"];var root=new GameObject("Volume:"+name);Draw("Approved partition V2 "+name,Import(revision+"DepthArt/"+id+"/"+(string)p["id"]+".png","LeafV2-"+name,pivot),V(b["position"]),(bool)p["ground"]?-19800:0,root.transform);if(!(bool)p["ground"])Depth(root,p["depth"].Select(V).ToArray());}
  }
  var physics=GameObject.Find("Semantic physical boundaries");int added=0;foreach(var p in d["physical"].Where(p=>((string)p["id"]).Contains("-wood-"))){var go=new GameObject("Physics:"+(string)p["id"]);go.transform.SetParent(physics.transform,false);go.layer=8;go.AddComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());added++;}
  File.Copy(revision+"layout.json",Art+"layout.json",true);AssetDatabase.ImportAsset(Art+"layout.json",ImportAssetOptions.ForceSynchronousImport);EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());AssetDatabase.SaveAssets();var receipt=new{addedSolidLeafPlanes=added,physical=d["physical"].Count(),baseGeometryUnchanged=true,source=revision,pixelsUnchanged=true,promoted=false};File.WriteAllText(QA+"solid-leaves.json",JsonConvert.SerializeObject(receipt,Formatting.Indented));return receipt;
 }
}
