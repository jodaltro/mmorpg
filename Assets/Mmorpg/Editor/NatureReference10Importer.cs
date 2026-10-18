using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class NatureReference10Importer
{
 public const string Source="ArtSource/Labs/World2026/Nature10/",Art="Assets/Mmorpg/Art/Experimental/ValdoriaNature10/",Scene="Assets/Mmorpg/Scenes/ValdoriaNatureRefinementLab.unity";
 static string Hash(byte[] b){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 public static void Verify(string folder)
 {
  var m=JObject.Parse(File.ReadAllText(folder+"manifest.json"));foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(folder+p.Name))!=(string)p.Value)throw new IOException("Nature artifact hash: "+p.Name);
  foreach(var p in ((JObject)m["inputs"]).Properties())if(Hash(File.ReadAllBytes((string)p.Value["path"]))!=(string)p.Value["sha256"])throw new IOException("Nature input hash: "+p.Name);
 }
 static Texture2D Texture(string source,string name)
 {
  string path=Art+name+".png";File.Copy(source,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Default;i.npotScale=TextureImporterNPOTScale.None;i.maxTextureSize=4096;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.alphaIsTransparency=true;i.isReadable=false;var p=i.GetDefaultPlatformTextureSettings();p.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(p);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
 }
 static Dictionary<string,Sprite> ImportSprites(JObject meta)
 {
  string path=Art+"nature-atlas.png";Texture(Source+"ExportV3/nature-atlas.png","nature-atlas");var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Sprite;i.spriteImportMode=SpriteImportMode.Multiple;i.spritePixelsPerUnit=32;var settings=new TextureImporterSettings();i.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;i.SetTextureSettings(settings);i.SaveAndReimport();
  var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(i);provider.InitSpriteEditorDataProvider();int height=(int)meta["atlasSize"][1];var rects=meta["sprites"].Select(s=>{var r=s["rectPixels"];return new SpriteRect{name=(string)s["id"],rect=new Rect((int)r[0],height-(int)r[1]-(int)r[3],(int)r[2],(int)r[3]),alignment=SpriteAlignment.Custom,pivot=Vector2.zero,spriteID=GUID.Generate()};}).ToArray();provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();i.SaveAndReimport();return AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
 }
 static Sprite Single(string source,string name)
 {
  Texture(source,name);string path=Art+name+".png";var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Sprite;i.spriteImportMode=SpriteImportMode.Single;i.spritePixelsPerUnit=32;var s=new TextureImporterSettings();i.ReadTextureSettings(s);s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=Vector2.zero;s.spriteMeshType=SpriteMeshType.FullRect;i.SetTextureSettings(s);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Sprite>(path);
 }
 static Material Material(Material source,Texture texture,string name){var m=new Material(source){mainTexture=texture,name=name};AssetDatabase.CreateAsset(m,Art+name+".mat");return m;}
 static Vector3 Offset(JToken p)=>new Vector3((float)p["offsetUnits"][0],(float)p["offsetUnits"][1],0);
 static void Contact(Transform parent,string id,Vector2 point,int order,JObject meta,Dictionary<string,Sprite> sprites,Material material)
 {
  var entry=meta["sprites"].Single(p=>(string)p["id"]==id);var go=new GameObject("Authored ground contact "+id);go.transform.SetParent(parent,false);go.transform.localPosition=(Vector3)point+Offset(entry);var r=go.AddComponent<SpriteRenderer>();r.sprite=sprites[id];r.sharedMaterial=material;r.sortingOrder=order;
 }
 static void Prefab(GameObject source,string id)
 {
  var clone=Object.Instantiate(source);clone.name=id;clone.transform.SetParent(null);clone.transform.position=Vector3.zero;var anchor=clone.GetComponent<VegetationAnchor>();if(anchor)anchor.Configure("template:"+id,"authored-oak",id.Contains("fork")?1:0,.5f);var depth=clone.GetComponent<NaturePropDepth>();if(depth){var group=clone.GetComponentInChildren<SortingGroup>();depth.Configure(null,group,clone.GetComponent<PolygonCollider2D>().points);}PrefabUtility.SaveAsPrefabAsset(clone,Art+id+".prefab");Object.DestroyImmediate(clone);
 }
 public static object Build()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Requires stopped Play and clean scene");if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing nature scene/art");foreach(var p in new[]{"ExportV3/","SurfaceFinal/","PlacementFinal/"})Verify(Source+p);
  Directory.CreateDirectory(Art);AssetDatabase.Refresh();var meta=JObject.Parse(File.ReadAllText(Source+"ExportV3/sprites.json"));var sprites=ImportSprites(meta);var recipe=JObject.Parse(File.ReadAllText(Source+"PlacementFinal/placement.json"));
  var original=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVisualHouse09.unity");EditorSceneManager.SaveScene(original,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);var oldControl=Object.FindAnyObjectByType<VisualUnificationLab>();oldControl.Apply(2);Object.DestroyImmediate(oldControl.gameObject);
  var actor=GameObject.Find("Player");var oldPlants=scene.GetRootGameObjects().Single(g=>g.GetComponentsInChildren<VegetationAnchor>(true).Length>100);var oldVegetationMaterial=AssetDatabase.LoadAssetAtPath<Material>(VisualUnification09Importer.Art+"Vegetation09.mat");var natureMaterial=Material(oldVegetationMaterial,AssetDatabase.LoadAssetAtPath<Texture2D>(Art+"nature-atlas.png"),"Nature10");
  var plantData=JObject.Parse(File.ReadAllText(ArchitectureArt07RImporter.Source+"vegetation.json"));var plantMeta=JObject.Parse(File.ReadAllText(VegetationStudioImporter.Library+"sprites.json"));var plantSprites=AssetDatabase.LoadAllAssetsAtPath(VisualUnification09Importer.Art+"vegetation-atlas.png").OfType<Sprite>().ToDictionary(s=>s.name);var after=VegetationStudioImporter.CreateComposition(plantData,plantMeta,plantSprites,oldVegetationMaterial,"Nature study - same ecological points, two authored trees");
  foreach(var replacement in recipe["treeReplacements"])
  {
   string id=(string)replacement["asset"];var tree=after.GetComponentsInChildren<VegetationAnchor>().Single(t=>t.InstanceId==(string)replacement["instance"]);tree.Configure(tree.InstanceId,"authored-oak",id.Contains("forked")?1:0,.5f);tree.GetComponent<CircleCollider2D>().radius=.5f;
   foreach(var renderer in tree.GetComponentsInChildren<SpriteRenderer>())
   {
    string part=renderer.name;var entry=meta["sprites"].Single(p=>(string)p["id"]==id+"-"+part);renderer.sprite=sprites[id+"-"+part];renderer.sharedMaterial=natureMaterial;renderer.transform.localPosition=Offset(entry);if(part=="shadow")renderer.name="Authored projected crown shadow";
   }
   var graphics=tree.GetComponentInChildren<SortingGroup>().transform;Contact(graphics,"grass-contact-v0",new Vector2(-.42f,-.45f),2,meta,sprites,natureMaterial);Contact(graphics,"grass-contact-v3",new Vector2(.38f,-.48f),3,meta,sprites,natureMaterial);Prefab(tree.gameObject,id);
  }
  VegetationStudioImporter.BakeStaticDetails(after,"Nature10",oldVegetationMaterial,Art);
  var rocks=new GameObject("Declared nature study rock footprints");
  foreach(var prop in recipe["rocks"])
  {
   string id=(string)prop["asset"];var source=meta["assets"].Single(a=>(string)a["id"]==id);var go=new GameObject((string)prop["id"]);go.transform.SetParent(rocks.transform);go.transform.position=new Vector3((float)prop["point"][0],48-(float)prop["point"][1],0);go.layer=8;
   var poly=source["footprintPixels"].Select(p=>new Vector2((float)p[0]/32,-(float)p[1]/32)).ToArray();go.AddComponent<PolygonCollider2D>().SetPath(0,poly);var graphics=new GameObject("Authored stone volume");graphics.transform.SetParent(go.transform,false);var sorting=graphics.AddComponent<SortingGroup>();go.AddComponent<NaturePropDepth>().Configure(actor.transform,sorting,poly);
   foreach(string part in new[]{"shadow","body"}){var entry=meta["sprites"].Single(p=>(string)p["id"]==id+"-"+part);var child=new GameObject(part);child.transform.SetParent(part=="shadow"?go.transform:graphics.transform,false);child.transform.localPosition=Offset(entry);var r=child.AddComponent<SpriteRenderer>();r.sprite=sprites[id+"-"+part];r.sharedMaterial=natureMaterial;r.sortingOrder=part=="shadow"?-1977:0;}
   Contact(graphics.transform,"grass-contact-v2",new Vector2(poly.Min(p=>p.x)*.6f,poly.Min(p=>p.y)),2,meta,sprites,natureMaterial);Contact(graphics.transform,"grass-contact-v4",new Vector2(poly.Max(p=>p.x)*.7f,poly.Min(p=>p.y)),3,meta,sprites,natureMaterial);
   if(!File.Exists(Art+id+".prefab"))Prefab(go,id);
  }
  var oldGround=AssetDatabase.LoadAssetAtPath<Material>(VisualUnification09Importer.Art+"Terrain09.mat");var oldFace=AssetDatabase.LoadAssetAtPath<Material>(VisualUnification09Importer.Art+"Rock09.mat");var mats=new Material[3];for(int j=0;j<3;j++){string name=new[]{"base","transitions","final"}[j];mats[j]=Material(oldGround,Texture(Source+"SurfaceFinal/"+name+".png","ground-"+name),"Ground-"+name);}var face=Material(oldFace,Texture(Source+"SurfaceFinal/cliff.png","cliff"),"RockFaces");var bindings=new List<NatureReferenceLab.Surface>();
  foreach(var renderer in Object.FindObjectsByType<MeshRenderer>(FindObjectsInactive.Include)){if(renderer.sharedMaterial==oldGround)bindings.Add(new NatureReferenceLab.Surface{renderer=renderer,before=oldGround,baseLayer=mats[0],transitions=mats[1],final=mats[2]});else if(renderer.sharedMaterial==oldFace)bindings.Add(new NatureReferenceLab.Surface{renderer=renderer,before=oldFace,baseLayer=face,transitions=face,final=face});}
  var access=GameObject.Find("Reference pedestrian access").GetComponent<SpriteRenderer>();var accessSprite=Single(Source+"SurfaceFinal/access.png","access-refined");
  var navs=new List<TextAsset>();var masks=new List<byte[]>();foreach(string name in new[]{"before","after"}){string path=Art+"navigation-"+name+".json";File.Copy(Source+"PlacementFinal/navigation-"+name+".json",path);AssetDatabase.ImportAsset(path);navs.Add(AssetDatabase.LoadAssetAtPath<TextAsset>(path));masks.Add(JObject.Parse(File.ReadAllText(path))["walkable"].Select(v=>(byte)((bool)v?1:0)).ToArray());}
  new GameObject("Nature reference - 1 before 2 base 3 transitions 4 final").AddComponent<NatureReferenceLab>().Configure(oldPlants,after,rocks,bindings.ToArray(),access,accessSprite,Object.FindAnyObjectByType<ArchitectureRegionData>(),navs[0],navs[1],masks[0],masks[1]);
  Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaNature10/IsolatedProfile");var approach=Object.FindAnyObjectByType<ArchitectureBuilding>().Approach;actor.transform.position=approach;actor.GetComponent<Rigidbody2D>().position=approach;Camera.main.orthographicSize=14.0625f;Camera.main.transform.position=new Vector3(28.5f,14.25f,-10);Camera.main.GetComponent<CameraFollow>().ConfigurePixelGrid(32);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,trees=2,rocks=recipe["rocks"].Count(),unchangedEcologicalPoints=plantData["instances"].Count(),atlas=meta["atlasSize"].ToString(),newSceneOnly=true};
 }
}
