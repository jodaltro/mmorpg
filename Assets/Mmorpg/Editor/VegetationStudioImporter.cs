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
using UnityEditor.U2D.Sprites;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class VegetationStudioImporter
{
 public const string Source="ArtSource/Labs/World2026/WorldStudio06/BuildR6/";
 public const string Library="ArtSource/Labs/World2026/WorldStudio06/LibraryR5/";
 public const string Art="Assets/Mmorpg/Art/Experimental/ValdoriaVegetation06/";
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity";
 static string Hash(byte[] b){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 public static void Verify()
 {
  foreach(var style in new[]{"A","B","C"}){var m=JObject.Parse(File.ReadAllText(Source+style+"/manifest.json"));if((string)m["schema"]!="valdoria-vegetation-build/v1")throw new IOException("Vegetation build schema");foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(Source+style+"/"+p.Name))!=(string)p.Value)throw new IOException("Vegetation artifact hash");foreach(var p in ((JObject)m["inputs"]).Properties())if(Hash(File.ReadAllBytes((string)p.Value["path"]))!=(string)p.Value["sha256"])throw new IOException("Vegetation input hash");}
  var lib=JObject.Parse(File.ReadAllText(Library+"library.json"));foreach(var p in ((JObject)lib["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(Library+p.Name))!=(string)p.Value)throw new IOException("Vegetation source hash");
 }
 static Dictionary<string,Sprite> ImportSprites(JObject metadata)
 {
  string path=Art+"vegetation-atlas.png";File.Copy(Library+"vegetation-atlas.png",path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;importer.filterMode=FilterMode.Point;importer.mipmapEnabled=false;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.alphaIsTransparency=true;importer.maxTextureSize=2048;importer.SaveAndReimport();
  var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();var capability=provider.GetDataProvider<ISpriteFrameEditCapability>();if(capability==null||!capability.GetEditCapability().HasCapability(EEditCapability.CreateAndDeleteSprite))throw new IOException("Sprite slicing capability unavailable; aborted");
  int height=(int)metadata["atlasSize"][1];var rects=metadata["sprites"].Select(s=>{var r=s["rectPixels"];return new SpriteRect{name=(string)s["id"],rect=new Rect((int)r[0],height-(int)r[1]-(int)r[3],(int)r[2],(int)r[3]),alignment=SpriteAlignment.Custom,pivot=Vector2.zero,spriteID=GUID.Generate()};}).ToArray();provider.SetSpriteRects(rects);var names=provider.GetDataProvider<ISpriteNameFileIdDataProvider>();names.SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();return AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
 }
 sealed class StaticBatch
 {
  public readonly List<Vector3> points=new List<Vector3>();public readonly List<Vector2> uv=new List<Vector2>();public readonly List<Color> colors=new List<Color>();public readonly List<int> triangles=new List<int>();
  public void Add(SpriteRenderer renderer){int start=points.Count;var sprite=renderer.sprite;var vertices=sprite.vertices;foreach(var p in vertices)points.Add(renderer.transform.TransformPoint(p));uv.AddRange(sprite.uv);colors.AddRange(Enumerable.Repeat(renderer.color,vertices.Length));triangles.AddRange(sprite.triangles.Select(i=>start+i));}
  public void Save(Transform root,string name,int order,Material material,string directory){var mesh=new Mesh{name=name};if(points.Count>65535)mesh.indexFormat=IndexFormat.UInt32;mesh.SetVertices(points);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,directory+name+".asset");var go=new GameObject(name);go.transform.SetParent(root);go.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.sortingOrder=order;}
 }
 public static void BakeStaticDetails(GameObject root,string style,Material material,string directory=Art)
 {
  var shadows=new StaticBatch();var rows=new Dictionary<int,StaticBatch>();var anchors=root.GetComponentsInChildren<VegetationAnchor>(true).OrderByDescending(a=>a.transform.position.y).ToArray();
  foreach(var anchor in anchors)
  {
   foreach(var renderer in anchor.GetComponentsInChildren<SpriteRenderer>())
   {
    if(renderer.name=="shadow"){shadows.Add(renderer);Object.DestroyImmediate(renderer.gameObject);}
    else if(anchor.FootprintRadius==0){int row=Mathf.RoundToInt(anchor.transform.position.y*4);if(!rows.ContainsKey(row))rows[row]=new StaticBatch();rows[row].Add(renderer);Object.DestroyImmediate(renderer.gameObject);}
   }
   if(anchor.FootprintRadius==0){var graphics=anchor.transform.Find("Trunk and crown - depth at ground anchor");if(graphics!=null)Object.DestroyImmediate(graphics.gameObject);}
  }
  shadows.Save(root.transform,"Baked-"+style+"-ground-shadows",-1977,material,directory);foreach(var row in rows.OrderBy(r=>r.Key))row.Value.Save(root.transform,"Baked-"+style+"-low-row-"+row.Key,100-row.Key*4,material,directory);
 }
 public static GameObject CreateComposition(JObject build,JObject meta,Dictionary<string,Sprite> sprites,Material material,string name)
 {
  var root=new GameObject(name);
    foreach(var instance in build["instances"])
    {
     string species=(string)instance["species"];int variant=(int)instance["variant"];float x=(float)instance["point"][0],y=(float)build["sizeUnits"][1]-(float)instance["point"][1],radius=(float)instance["footprintRadius"];var plant=new GameObject((string)instance["id"]);plant.transform.SetParent(root.transform);plant.transform.position=new Vector3(x,y,0);plant.AddComponent<VegetationAnchor>().Configure((string)instance["id"],species,variant,radius);
     var visuals=new GameObject("Trunk and crown - depth at ground anchor");visuals.transform.SetParent(plant.transform,false);var group=visuals.AddComponent<SortingGroup>();group.sortingOrder=100-Mathf.RoundToInt(y*16);
     foreach(var part in new[]{"shadow","trunk","crown"})
     {
      string id=species+"-v"+variant+"-"+part;if(!sprites.ContainsKey(id))continue;var descriptor=meta["sprites"].Single(d=>(string)d["id"]==id);var child=new GameObject(part);child.transform.SetParent(part=="shadow"?plant.transform:visuals.transform,false);child.transform.localPosition=new Vector3((float)descriptor["offsetUnits"][0],(float)descriptor["offsetUnits"][1],0);var renderer=child.AddComponent<SpriteRenderer>();renderer.sprite=sprites[id];renderer.sharedMaterial=material;renderer.sortingOrder=part=="shadow"?-1977:part=="trunk"?0:1;
     }
     if(radius>0){plant.layer=8;plant.AddComponent<CircleCollider2D>().radius=radius;}
    }
  return root;
 }
 public static object Build()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(original.isDirty||original.path!="Assets/Mmorpg/Scenes/ValdoriaHydrologyLab.unity")throw new IOException("Open clean Hydrology Lab");if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing Vegetation scene/art destination");Verify();string originalPath=original.path;
  try{
   Directory.CreateDirectory(Art);AssetDatabase.Refresh();var meta=JObject.Parse(File.ReadAllText(Library+"sprites.json"));var sprites=ImportSprites(meta);var material=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(Art+"vegetation-atlas.png")};AssetDatabase.CreateAsset(material,Art+"Vegetation.mat");
   EditorSceneManager.SaveScene(original,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);var hydro=Object.FindAnyObjectByType<HydrologyLabController>();hydro.SetWater(true);Object.DestroyImmediate(hydro.gameObject);var roots=new List<GameObject>();var sources=new List<TextAsset>();var masks=new List<byte[]>();
   foreach(var style in new[]{"A","B","C"})
   {
    var build=JObject.Parse(File.ReadAllText(Source+style+"/vegetation.json"));var root=CreateComposition(build,meta,sprites,material,"Vegetation "+style+" - semantic anchors");roots.Add(root);
    string dataPath=Art+style+"-vegetation.json";File.Copy(Source+style+"/vegetation.json",dataPath);AssetDatabase.ImportAsset(dataPath);sources.Add(AssetDatabase.LoadAssetAtPath<TextAsset>(dataPath));var nav=JObject.Parse(File.ReadAllText(Source+style+"/navigation.json"));masks.Add(nav["vegetationBlocked"].Select(v=>(byte)((bool)v?1:0)).ToArray());
   }
   for(int i=0;i<roots.Count;i++)BakeStaticDetails(roots[i],"ABC"[i].ToString(),material);
   var terrain=Object.FindAnyObjectByType<TerrainRegionData>();var data=terrain.gameObject.AddComponent<VegetationRegionData>();data.Configure(Object.FindAnyObjectByType<EnvironmentRegionData>(),sources.ToArray(),masks.ToArray());var controller=new GameObject("Vegetation lab - 0 before 1 Field A 2 Grove B 3 Living banks C").AddComponent<VegetationLabController>();controller.Configure(roots.ToArray(),data,GameObject.Find("Player").transform);controller.ResetPose();Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaVegetation06/IsolatedProfile");EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,sprites=sprites.Count,atlas=meta["atlasSize"].ToString(),instances=roots.Select(r=>r.GetComponentsInChildren<VegetationAnchor>(true).Length).ToArray()};
  }catch{EditorSceneManager.OpenScene(originalPath);AssetDatabase.DeleteAsset(Scene);AssetDatabase.DeleteAsset(Art.TrimEnd('/'));throw;}
 }
}
