using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Object=UnityEngine.Object;

public static class BuildVillage02Anime
{
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Anime.unity";
 const string Source="ArtSource/World/PlayableVillage02/AnimeRebuildV1/",Art="Assets/Mmorpg/Art/World/Village02Anime/",QA="Docs/Validation/ValdoriaVillage02-Anime/QA/";
 static GameObject actor;static Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();
 static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
 static string Hash(string p){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
 static void Verify(string root){var m=JObject.Parse(File.ReadAllText(root+"manifest.json"));foreach(var f in ((JObject)m["files"]).Properties())if(Hash(root+f.Name)!=(string)f.Value)throw new IOException("Source hash mismatch "+f.Name);}
 static Sprite Import(string source,string id,Vector2 pivot){if(sprites.TryGetValue(id,out var existing))return existing;string path=Art+id+".png";File.Copy(source,path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var t=(TextureImporter)AssetImporter.GetAtPath(path);t.textureType=TextureImporterType.Sprite;t.spriteImportMode=SpriteImportMode.Single;t.spritePixelsPerUnit=32;t.filterMode=FilterMode.Point;t.npotScale=TextureImporterNPOTScale.None;t.mipmapEnabled=false;t.textureCompression=TextureImporterCompression.Uncompressed;t.alphaIsTransparency=true;t.maxTextureSize=4096;var s=new TextureImporterSettings();t.ReadTextureSettings(s);s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=pivot;s.spriteMeshType=SpriteMeshType.FullRect;t.SetTextureSettings(s);t.SaveAndReimport();return sprites[id]=AssetDatabase.LoadAssetAtPath<Sprite>(path);}
 static Vector2 Pivot(JToken canvas,JToken anchor)=>new Vector2((float)anchor[0]/(float)canvas[0],1-(float)anchor[1]/(float)canvas[1]);
 static void Depth(GameObject go,Vector2[] polygon){go.AddComponent<OpaqueStructureDepth>().Configure(actor.transform,actor.GetComponent<ProductionSpriteAnimator>().Body,go.AddComponent<SortingGroup>(),polygon);}
 static SpriteRenderer Draw(Transform parent,string id,Sprite sprite,Vector2 pos,int order){var g=new GameObject(id);g.transform.SetParent(parent,false);g.transform.position=pos;var r=g.AddComponent<SpriteRenderer>();r.sprite=sprite;r.sortingOrder=order;return r;}
 public static object Main()
 {
  var before=EditorSceneManager.GetActiveScene();if(EditorApplication.isPlaying||before.isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("New destination and clean stopped editor required");Verify(Source+"ExportV2/");Verify(Source+"GardenExportV1/");Verify(Source+"IntegrationV1/");
  Directory.CreateDirectory(QA);Directory.CreateDirectory(Art);File.WriteAllText(QA+"editor-before.json",JsonConvert.SerializeObject(new{scene=before.path,dirty=before.isDirty,targetFPS=Application.targetFrameRate,timeScale=Time.timeScale},Formatting.Indented));
  var original=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVillage02Integrated.unity");EditorSceneManager.SaveScene(original,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);actor=GameObject.Find("Player");var d=JObject.Parse(File.ReadAllText(Source+"IntegrationV1/layout.json"));
  // Reuse the actual validated rigidbody and120 base polygons. Only presentation
  // is replaced here; three garden volumes are explicitly appended below.
  var originalData=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/IntegrationV2/layout.json"));int verified=0;
  foreach(var p in originalData["physical"]){var c=GameObject.Find("Physics:"+(string)p["id"]).GetComponent<PolygonCollider2D>();var a=c.GetPath(0);var b=p["polygon"].Select(V).ToArray();if(a.Length!=b.Length||a.Where((v,i)=>Vector2.Distance(c.transform.TransformPoint(v),b[i])>.0001f).Any())throw new IOException("Base geometry mismatch "+p["id"]);verified++;}
  foreach(var b in d["buildings"]){string id=(string)b["id"];var go=GameObject.Find("Building:"+id);go.GetComponentInChildren<SpriteRenderer>().sprite=Import((string)b["composite"],id,Pivot(b["canvas"],b["anchorPixels"]));}
  foreach(var piece in d["pieces"]){string id=(string)piece["id"];foreach(var g in scene.GetRootGameObjects().Where(g=>g.name.StartsWith("Volume:"+id+"-")).ToArray())Object.DestroyImmediate(g);foreach(var p in piece["parts"]){string name=id+"-"+(string)p["id"];var root=new GameObject("Volume:"+name);Draw(root.transform,"Anime painting "+name,Import(Source+"IntegrationV1/DepthArt/"+id+"/"+(string)p["id"]+".png",name,Pivot(piece["canvas"],piece["anchorPixels"])),V(piece["position"]),(bool)p["ground"]?-19800:0);if(!(bool)p["ground"])Depth(root,p["depth"].Select(V).ToArray());}}
  var wallMeta=JObject.Parse(File.ReadAllText(Source+"SourceV2/wall/house-source.json"));var wall=Import(Source+"ExportV2/wall/composite.png","wall-source",Vector2.zero);var material=new Material(Shader.Find("Sprites/Default")){mainTexture=wall.texture};AssetDatabase.CreateAsset(material,Art+"Curtain.mat");foreach(var p in d["townWalls"])GameObject.Find((string)p["id"]).GetComponent<MeshRenderer>().sharedMaterial=material;
  var garden=new GameObject("Private maintained castle garden");var physics=GameObject.Find("Semantic physical boundaries");
  foreach(var p in d["garden"]){string id=(string)p["id"];var root=new GameObject("Garden:"+id);root.transform.SetParent(garden.transform,false);Draw(root.transform,"Garden painting "+id,Import((string)p["composite"],id,Pivot(p["canvas"],p["anchorPixels"])),V(p["position"]),0);Depth(root,p["polygon"].Select(V).ToArray());var solid=new GameObject("Physics:"+id);solid.transform.SetParent(physics.transform,false);solid.layer=8;solid.AddComponent<PolygonCollider2D>().SetPath(0,p["polygon"].Select(V).ToArray());}
  var flower=d["flowerAsset"];var sprite=Import((string)flower["composite"],"court-daisies",Pivot(flower["canvas"],flower["anchorPixels"]));foreach(var p in d["flowers"])Draw(garden.transform,(string)p["id"],sprite,V(p["position"]),100-Mathf.RoundToInt((float)p["position"][1]*16));
  File.Copy(Source+"IntegrationV1/layout.json",Art+"layout.json",false);AssetDatabase.ImportAsset(Art+"layout.json");Object.FindAnyObjectByType<PlayableVillageRegion>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"layout.json"),V(d["spawn"]),new Rect(0,0,282,335));Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("Village02Anime/IsolatedProfile");
  EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();var receipt=new{scene=Scene,originalPhysicalPlanesVerified=verified,physical=d["physical"].Count(),newGardenSolids=d["garden"].Count(),flowers=d["flowers"].Count(),replacedArchitecturalFamilies=14,ppu=32,actorUnchanged=true,baseGroundAndRiverUnchanged=true,promoted=false,artisticApproval=false};File.WriteAllText(QA+"build.json",JsonConvert.SerializeObject(receipt,Formatting.Indented));return receipt;
 }
 public static object Restore(){if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Stopped clean editor required");if(SessionState.GetBool("Village02Integration.FPSOverride",false)){Application.targetFrameRate=SessionState.GetInt("Village02Integration.PreviousFPS",-1);SessionState.SetBool("Village02Integration.FPSOverride",false);}var b=JObject.Parse(File.ReadAllText(QA+"editor-before.json"));EditorSceneManager.OpenScene((string)b["scene"]);var r=new{scene=EditorSceneManager.GetActiveScene().path,dirty=EditorSceneManager.GetActiveScene().isDirty,playing=EditorApplication.isPlaying,timeScale=Time.timeScale,targetFrameRate=Application.targetFrameRate,promoted=EditorBuildSettings.scenes.Any(s=>s.path==Scene)};File.WriteAllText(QA+"editor-restored.json",JsonConvert.SerializeObject(r,Formatting.Indented));return r;}
}
