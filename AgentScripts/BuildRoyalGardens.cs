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

public static class BuildRoyalGardens
{
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Anime.unity";
 const string Source="ArtSource/World/PlayableVillage02/RoyalGardensV1/",Art="Assets/Mmorpg/Art/World/RoyalGardensV1/",QA="Docs/Validation/ValdoriaRoyalGardens/QA/";
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
  var before=EditorSceneManager.GetActiveScene();if(EditorApplication.isPlaying||before.isDirty||Directory.Exists(Art))throw new IOException("Clean stopped editor and absent art destination required");
  var manifest=JObject.Parse(File.ReadAllText(Source+"manifest.json"));foreach(var p in ((JObject)manifest["files"]).Properties())if(Hash(Source+p.Name)!=(string)p.Value)throw new IOException("Source hash mismatch "+p.Name);
  Directory.CreateDirectory(Art);Directory.CreateDirectory(QA);Directory.CreateDirectory("Temp/RoyalGardensBackup");File.Copy(Scene,"Temp/RoyalGardensBackup/Before.unity",false);File.WriteAllText(QA+"editor-before.json",JsonConvert.SerializeObject(new{scene=before.path,dirty=before.isDirty,sceneBeforeSHA256=Hash(Scene),buildSettings=EditorBuildSettings.scenes.Select(s=>new{s.path,s.enabled})},Formatting.Indented));
  var scene=EditorSceneManager.OpenScene(Scene);actor=GameObject.Find("Player");var d=JObject.Parse(File.ReadAllText(Source+"layout.json"));var original=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/AnimeRebuildV1/IntegrationV2/layout.json"));int verified=0;
  foreach(var p in original["physical"].Take(120)){var c=GameObject.Find("Physics:"+(string)p["id"]).GetComponent<PolygonCollider2D>();var a=c.GetPath(0);var b=p["polygon"].Select(V).ToArray();if(a.Length!=b.Length||a.Where((v,i)=>Vector2.Distance(c.transform.TransformPoint(v),b[i])>.0001f).Any())throw new IOException("Original changed "+p["id"]);verified++;}
  var floor=d["royalPrecinct"]["floor"];var cv=floor["canvas"];var an=floor["anchorPixels"];Draw("Royal garden lawns and promenades",Import((string)floor["composite"],"garden-floor",new Vector2((float)an[0]/(float)cv[0],1-(float)an[1]/(float)cv[1])),V(floor["position"]),-19900);
  var garden=GameObject.Find("Private maintained castle garden");var physics=GameObject.Find("Semantic physical boundaries");
  foreach(var p in d["garden"].Where(g=>(string)g["id"]=="court-fountain"||((string)g["id"]).StartsWith("royal-"))){string id=(string)p["id"];if(id=="court-fountain")Object.DestroyImmediate(GameObject.Find("Garden:"+id));var root=new GameObject("Garden:"+id);root.transform.SetParent(garden.transform,false);cv=p["canvas"];an=p["anchorPixels"];Draw("Royal garden "+id,Import((string)p["composite"],id,new Vector2((float)an[0]/(float)cv[0],1-(float)an[1]/(float)cv[1])),V(p["position"]),0,root.transform);Depth(root,p["polygon"].Select(V).ToArray());var target=GameObject.Find("Physics:"+id);if(!target){target=new GameObject("Physics:"+id);target.transform.SetParent(physics.transform,false);target.layer=8;target.AddComponent<PolygonCollider2D>();}target.GetComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
  var flowers=d["flowerAsset"];cv=flowers["canvas"];an=flowers["anchorPixels"];var flower=Import((string)flowers["composite"],"daisies",new Vector2((float)an[0]/(float)cv[0],1-(float)an[1]/(float)cv[1]));foreach(var p in d["flowers"].Where(p=>((string)p["id"]).StartsWith("royal-")))Draw((string)p["id"],flower,V(p["position"]),100-Mathf.RoundToInt((float)p["position"][1]*16),garden.transform);
  var wall=Import("ArtSource/World/PlayableVillage02/AnimeRebuildV1/ExportV2/wall/composite.png","wall-source",Vector2.zero);wallMaterial=new Material(Shader.Find("Sprites/Default")){mainTexture=wall.texture};AssetDatabase.CreateAsset(wallMaterial,Art+"RoyalCurtain.mat");foreach(var p in d["royalWalls"]){Wall(p);var go=new GameObject("Physics:"+(string)p["id"]);go.transform.SetParent(physics.transform,false);go.layer=8;go.AddComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
  File.Copy(Source+"layout.json",Art+"layout.json",false);AssetDatabase.ImportAsset(Art+"layout.json");Object.FindAnyObjectByType<PlayableVillageRegion>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"layout.json"),V(d["spawn"]),new Rect(0,0,282,335));Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("RoyalGardens/IsolatedProfile");EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();var r=new{scene=Scene,originalArchitectureVerified=verified,physical=d["physical"].Count(),newWalls=d["royalWalls"].Count(),gardenObjects=d["garden"].Count(),fountainDiameter=12.8f,transformScale=1,promoted=false};File.WriteAllText(QA+"build.json",JsonConvert.SerializeObject(r,Formatting.Indented));return r;
 }
 public static object Promote()
 {
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty||EditorSceneManager.GetActiveScene().path!=Scene)throw new IOException("Clean stopped final scene required");var qa=JObject.Parse(File.ReadAllText(QA+"play-qa.json"));if(!(bool)qa["allExecutedPassed"])throw new IOException("Play QA did not pass");
  EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Scene,true)}.Concat(EditorBuildSettings.scenes.Where(s=>s.path!=Scene)).ToArray();AssetDatabase.SaveAssets();var r=new{firstEnabled=EditorBuildSettings.scenes.First(s=>s.enabled).path,explicitUserAuthorization="Pode aplicar cena principal dai",artisticApprovalNotInferred=true};File.WriteAllText(QA+"promotion.json",JsonConvert.SerializeObject(r,Formatting.Indented));return r;
 }
 public static object Restore()
 {
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Stop Play before restore");if(SessionState.GetBool("Village02Integration.FPSOverride",false)){Application.targetFrameRate=SessionState.GetInt("Village02Integration.PreviousFPS",-1);SessionState.SetBool("Village02Integration.FPSOverride",false);}var r=new{scene=EditorSceneManager.GetActiveScene().path,dirty=EditorSceneManager.GetActiveScene().isDirty,playing=EditorApplication.isPlaying,timeScale=Time.timeScale,fps=Application.targetFrameRate,first=EditorBuildSettings.scenes.First(s=>s.enabled).path};File.WriteAllText(QA+"editor-restored.json",JsonConvert.SerializeObject(r,Formatting.Indented));return r;
 }
}
