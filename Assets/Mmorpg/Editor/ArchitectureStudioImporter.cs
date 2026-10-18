using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class ArchitectureStudioImporter
{
 public const string Source="ArtSource/Labs/World2026/WorldStudio07/BuildR5/";
 public const string Library="ArtSource/Labs/World2026/WorldStudio07/LibraryR7/";
 public const string Art="Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture07/";
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaArchitectureLab.unity";
 static string Hash(byte[] b){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 static void VerifyManifest(string folder){var m=JObject.Parse(File.ReadAllText(folder+"manifest.json"));foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(folder+p.Name))!=(string)p.Value)throw new IOException("Architecture artifact hash: "+p.Name);if(m["inputs"] is JObject inputs)foreach(var p in inputs.Properties())if(Hash(File.ReadAllBytes((string)p.Value["path"]))!=(string)p.Value["sha256"])throw new IOException("Architecture input hash: "+p.Name);}
 public static void Verify(){VerifyManifest(Source);VerifyManifest(Library);var composition=JObject.Parse(File.ReadAllText(Source+"vegetation.json"));foreach(var v in ((JObject)composition["sourceBuilds"]).Properties())if(Hash(File.ReadAllBytes((string)v.Value["path"]))!=(string)v.Value["sha256"])throw new IOException("Regenerated vegetation manifest hash");foreach(string s in new[]{"A","B","C"})VerifyManifest(Source+"Vegetation/"+s+"/");}
 static Sprite ImportSprite(string source,string name){string path=Art+name+".png";File.Copy(source,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Sprite;i.spriteImportMode=SpriteImportMode.Single;i.spritePixelsPerUnit=32;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;var platform=i.GetDefaultPlatformTextureSettings();platform.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(platform);var settings=new TextureImporterSettings();i.ReadTextureSettings(settings);settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=Vector2.zero;i.SetTextureSettings(settings);i.alphaIsTransparency=true;i.maxTextureSize=2048;i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Sprite>(path);}
 public static object Build()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(original.isDirty||original.path!="Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity")throw new IOException("Open clean Vegetation Lab");if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing Architecture scene/art destination");Verify();string prior=original.path;
  try{
   Directory.CreateDirectory(Art);EditorSceneManager.SaveScene(original,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);var vegetationController=Object.FindAnyObjectByType<VegetationLabController>();Object.DestroyImmediate(vegetationController.gameObject);foreach(var root in scene.GetRootGameObjects().Where(g=>g.name.StartsWith("Vegetation ")).ToArray())Object.DestroyImmediate(root);var oldData=Object.FindAnyObjectByType<VegetationRegionData>();if(oldData!=null)Object.DestroyImmediate(oldData);
   var actor=GameObject.Find("Player").transform;var env=Object.FindAnyObjectByType<EnvironmentRegionData>();var atlas=AssetDatabase.LoadAllAssetsAtPath(VegetationStudioImporter.Art+"vegetation-atlas.png").OfType<Sprite>().ToDictionary(v=>v.name);var vegMat=AssetDatabase.LoadAssetAtPath<Material>(VegetationStudioImporter.Art+"Vegetation.mat");var vegMeta=JObject.Parse(File.ReadAllText(VegetationStudioImporter.Library+"sprites.json"));var selected=JObject.Parse(File.ReadAllText(Source+"vegetation.json"));var plants=VegetationStudioImporter.CreateComposition(selected,vegMeta,atlas,vegMat,"Architecture ecotone - A field C reeds B grove");VegetationStudioImporter.BakeStaticDetails(plants,"Architecture07",vegMat,Art);
   var modules=JObject.Parse(File.ReadAllText(Library+"modules.json"));var sprites=new Dictionary<string,Sprite>();foreach(var part in modules["parts"])sprites[(string)part["id"]]=ImportSprite(Library+(string)part["trimmedFile"],(string)part["id"]);
   var build=JObject.Parse(File.ReadAllText(Source+"architecture.json"));var houses=new GameObject("Architecture - semantic buildings");
   foreach(var b in build["buildings"])
   {
    var root=new GameObject((string)b["id"]);root.transform.SetParent(houses.transform);root.transform.position=new Vector3((float)b["position"][0],48-(float)b["position"][1],0);root.layer=8;var foot=root.AddComponent<PolygonCollider2D>();foot.pathCount=1;foot.SetPath(0,b["footprint"].Select(p=>new Vector2((float)p[0]-root.transform.position.x,48-(float)p[1]-root.transform.position.y)).ToArray());
    foreach(var post in b["porchPosts"]){var go=new GameObject("Physical porch post");go.layer=8;go.transform.SetParent(root.transform);go.transform.position=new Vector3((float)post["point"][0],48-(float)post["point"][1],0);go.AddComponent<CircleCollider2D>().radius=(float)post["radius"];}
    root.AddComponent<ArchitectureBuilding>().Configure((string)b["id"],(string)b["archetype"],new Vector2((float)b["entry"][0],48-(float)b["entry"][1]),new Vector2((float)b["approach"][0],48-(float)b["approach"][1]));var graphics=new GameObject("Exterior volumes - depth at ground");graphics.transform.SetParent(root.transform,false);graphics.AddComponent<SortingGroup>().sortingOrder=100-Mathf.RoundToInt(root.transform.position.y*16);var roof=new List<SpriteRenderer>();var walls=new List<SpriteRenderer>();var bounds=new Bounds(root.transform.position,Vector3.zero);int local=0;
    foreach(var part in b["parts"]){string id=(string)part["module"];var m=modules["parts"].Single(p=>(string)p["id"]==id);bool shadow=(string)m["part"]=="shadow";var go=new GameObject((string)m["part"]);go.transform.SetParent(shadow?root.transform:graphics.transform,false);go.transform.localPosition=new Vector3((float)m["offsetUnits"][0],(float)m["offsetUnits"][1],0);var renderer=go.AddComponent<SpriteRenderer>();renderer.sprite=sprites[id];renderer.sortingOrder=shadow?-1976:local++;if((bool)part["hideWithRoof"])roof.Add(renderer);else if(!shadow&&(string)m["part"]!="foundation"&&(string)m["part"]!="porch")walls.Add(renderer);bounds.Encapsulate(renderer.bounds);}
    root.AddComponent<ArchitectureOcclusion>().Configure(actor,roof.ToArray(),walls.ToArray(),bounds);
   }
   var accessData=JObject.Parse(File.ReadAllText(Source+"access-render.json"));foreach(var surface in accessData["surfaces"]){var sprite=ImportSprite(Source+(string)surface["file"],"access-"+(string)surface["id"]);var go=new GameObject("Pedestrian approach "+(string)surface["id"]);go.transform.position=new Vector3((float)surface["originUnity"][0],(float)surface["originUnity"][1],0);var renderer=go.AddComponent<SpriteRenderer>();renderer.sprite=sprite;renderer.sortingOrder=-1988;}
   string path=Art+"architecture.json";File.Copy(Source+"architecture.json",path);AssetDatabase.ImportAsset(path);var n=JObject.Parse(File.ReadAllText(Source+"navigation.json"));env.gameObject.AddComponent<ArchitectureRegionData>().Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(path),(int)n["size"][0],(int)n["size"][1],n["walkable"].Select(v=>(byte)((bool)v?1:0)).ToArray());
   actor.position=new Vector3(28,48-31,0);var body=actor.GetComponent<Rigidbody2D>();body.position=actor.position;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaArchitecture07/IsolatedProfile");EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,buildings=build["buildings"].Count(),plants=selected["instances"].Count(),parts=sprites.Count};
  }catch{EditorSceneManager.OpenScene(prior);AssetDatabase.DeleteAsset(Scene);AssetDatabase.DeleteAsset(Art.TrimEnd('/'));throw;}
 }
}
