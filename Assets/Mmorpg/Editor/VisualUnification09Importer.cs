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

public static class VisualUnification09Importer
{
 public const string Source="ArtSource/Labs/World2026/WorldStudio09/",Art="Assets/Mmorpg/Art/Experimental/ValdoriaVisual09/";
 public static readonly string[] Scenes={"Assets/Mmorpg/Scenes/ValdoriaVisualHouse09.unity","Assets/Mmorpg/Scenes/ValdoriaVisualBarn09.unity","Assets/Mmorpg/Scenes/ValdoriaVisualCastle09.unity","Assets/Mmorpg/Scenes/ValdoriaVisualGallery09.unity"};
 static string Hash(byte[] b){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 static void Verify(string folder,string manifest){var m=JObject.Parse(File.ReadAllText(folder+manifest));foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(folder+p.Name))!=(string)p.Value)throw new IOException("Direction09 artifact hash: "+p.Name);}
 static Texture2D Texture(string source,string target)
 {
  File.Copy(source,target);AssetDatabase.ImportAsset(target,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(target);i.textureType=TextureImporterType.Default;i.npotScale=TextureImporterNPOTScale.None;i.maxTextureSize=4096;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.isReadable=false;i.alphaIsTransparency=true;var p=i.GetDefaultPlatformTextureSettings();p.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(p);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(target);
 }
 static Dictionary<string,Sprite> Atlas(string source,string target,JObject meta,string list,string id)
 {
  Texture(source,target);var i=(TextureImporter)AssetImporter.GetAtPath(target);i.textureType=TextureImporterType.Sprite;i.spriteImportMode=SpriteImportMode.Multiple;i.spritePixelsPerUnit=32;var settings=new TextureImporterSettings();i.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;i.SetTextureSettings(settings);i.SaveAndReimport();
  var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(i);provider.InitSpriteEditorDataProvider();int height=(int)meta[list=="sprites"&&meta["atlasSize"]!=null?"atlasSize":"size"][1];
  var rects=meta[list].Select(s=>{var r=s["rectPixels"];return new SpriteRect{name=(string)s[id],rect=new Rect((int)r[0],height-(int)r[1]-(int)r[3],(int)r[2],(int)r[3]),alignment=SpriteAlignment.Custom,pivot=Vector2.zero,spriteID=GUID.Generate()};}).ToArray();provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();i.SaveAndReimport();return AssetDatabase.LoadAllAssetsAtPath(target).OfType<Sprite>().ToDictionary(s=>s.name);
 }
 static Material Material(Material original,Texture tex,string name){var m=new Material(original){name=name,mainTexture=tex};AssetDatabase.CreateAsset(m,Art+name+".mat");return m;}
 static Dictionary<string,Sprite>[] maintained,weathered;static Dictionary<string,Sprite> vegetation;static Dictionary<string,Material> changed;
 public static object Build()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Requires stopped Play and clean scene");
  if(Directory.Exists(Art)||Scenes.Any(File.Exists))throw new IOException("Refuse existing Direction09 scene or assets");
  Verify(Source+"Terrain/Build/","manifest.json");Verify(Source+"Vegetation/Export/","library.json");
  Directory.CreateDirectory(Art);AssetDatabase.Refresh();maintained=new Dictionary<string,Sprite>[3];weathered=new Dictionary<string,Sprite>[3];int n=0;
  foreach(string family in new[]{"house","barn","castle"})
  {
   string folder=Source+"Architecture/"+family+"/Atlas/";Verify(folder,"atlas.json");var m=JObject.Parse(File.ReadAllText(folder+"atlas.json"));maintained[n]=Atlas(folder+"maintained.png",Art+family+"-maintained.png",m,"sprites","id");weathered[n]=Atlas(folder+"weathered.png",Art+family+"-weathered.png",m,"sprites","id");n++;
  }
  vegetation=Atlas(Source+"Vegetation/Export/vegetation-atlas.png",Art+"vegetation-atlas.png",JObject.Parse(File.ReadAllText(Source+"Vegetation/Export/sprites.json")),"sprites","id");
  var ground=Texture(Source+"Terrain/Build/final-atlas.png",Art+"terrain-final.png");var face=Texture(Source+"Terrain/Build/cliff-atlas.png",Art+"terrain-cliff.png");
  changed=new Dictionary<string,Material>();
  foreach(var pair in new[]{("Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/A-final.mat",ground,"Terrain09"),("Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/Faces.mat",face,"Rock09"),(VegetationStudioImporter.Art+"Vegetation.mat",AssetDatabase.LoadAssetAtPath<Texture2D>(Art+"vegetation-atlas.png"),"Vegetation09")})changed[pair.Item1]=Material(AssetDatabase.LoadAssetAtPath<Material>(pair.Item1),pair.Item2,pair.Item3);
  string[] parents={"Assets/Mmorpg/Scenes/ValdoriaArchitectureArtLab07R.unity","Assets/Mmorpg/Scenes/ValdoriaBarnLab.unity","Assets/Mmorpg/Scenes/ValdoriaCastleLab.unity"};
  var results=new List<object>();
  for(int j=0;j<3;j++)
  {
   var old=EditorSceneManager.OpenScene(parents[j]);if(old.isDirty)throw new IOException("Source scene dirty");EditorSceneManager.SaveScene(old,Scenes[j],true);var scene=EditorSceneManager.OpenScene(Scenes[j]);
   foreach(var r in scene.GetRootGameObjects().Where(g=>g.name.StartsWith("REJECTED OLD A")).ToArray())Object.DestroyImmediate(r);
   foreach(var c in Object.FindObjectsByType<TerrainMaterialLabController>(FindObjectsInactive.Include))Object.DestroyImmediate(c);
   AddChoices(scene.GetRootGameObjects(),j);
   Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaVisual09/"+j+"/IsolatedProfile");EditorSceneManager.SaveScene(scene);results.Add(new{scene=Scenes[j],original=parents[j],physicalGeometry="unchanged source scene"});
  }
  Gallery();AssetDatabase.SaveAssets();ConnectCatalog();EditorSceneManager.OpenScene(Scenes[0]);return results;
 }
 public static object ConnectCatalog()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Catalog binding requires clean stopped labs");
  if(File.Exists(Art+"catalog.json"))throw new IOException("Refuse existing catalog bindings");
  var catalog=JObject.Parse(File.ReadAllText(Source+"catalog.json"));if((string)catalog["version"]!="valdoria-visual-direction/1.0.0")throw new IOException("Unsupported catalog version");
  File.Copy(Source+"catalog.json",Art+"catalog.json",true);AssetDatabase.ImportAsset(Art+"catalog.json");var recipes=new List<TextAsset>();var selections=new List<TextAsset>();
  foreach(string family in new[]{"house","barn","castle"})
  {
   var recipe=JObject.Parse(File.ReadAllText(Source+"Recipes/"+family+".json"));var selection=JObject.Parse(File.ReadAllText(Source+"Architecture/"+family+"/Region/selection.json"));Verify(Source+"Architecture/"+family+"/Region/","manifest.json");
   if((string)recipe["catalogVersion"]!=(string)catalog["version"]||(string)selection["recipe"]["sha256"]!=Hash(File.ReadAllBytes(Source+"Recipes/"+family+".json"))||(string)selection["catalog"]["sha256"]!=Hash(File.ReadAllBytes(Source+"catalog.json")))throw new IOException("Recipe/catalog selection mismatch");
   foreach(var pair in new[]{(Source+"Recipes/"+family+".json",Art+family+"-recipe.json"),(Source+"Architecture/"+family+"/Region/selection.json",Art+family+"-selection.json")}){File.Copy(pair.Item1,pair.Item2,true);AssetDatabase.ImportAsset(pair.Item2);}
   recipes.Add(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+family+"-recipe.json"));selections.Add(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+family+"-selection.json"));
  }
  foreach(string path in Scenes){var scene=EditorSceneManager.OpenScene(path);Object.FindAnyObjectByType<VisualUnificationLab>().ConfigureCatalog(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"catalog.json"),recipes.ToArray(),selections.ToArray());EditorSceneManager.SaveScene(scene);}
  AssetDatabase.SaveAssets();return "Versioned catalog, three recipes and verified selections bound to 09 labs";
 }
 static void AddChoices(GameObject[] roots,int family)
 {
  var sprites=new List<VisualUnificationLab.SpriteChoice>();var mats=new List<VisualUnificationLab.MaterialChoice>();
  foreach(var r in roots.SelectMany(g=>g.GetComponentsInChildren<SpriteRenderer>(true)))
  {
   if(!r.sprite)continue;string path=AssetDatabase.GetAssetPath(r.sprite);var old=r.sprite;
   if(r.GetComponentInParent<ArchitectureBuilding>()!=null)
   {
    int index=family;if(family<0){string id=r.GetComponentInParent<ArchitectureBuilding>().Id;index=id.Contains("castle")?2:id.Contains("barn")?1:0;}
    if(maintained[index].ContainsKey(r.name))sprites.Add(new VisualUnificationLab.SpriteChoice{renderer=r,original=old,materialRevision=maintained[index][r.name],vegetationRevision=maintained[index][r.name],weathered=weathered[index][r.name]});
   }
   else if(path==VegetationStudioImporter.Art+"vegetation-atlas.png"&&vegetation.ContainsKey(old.name))sprites.Add(new VisualUnificationLab.SpriteChoice{renderer=r,original=old,materialRevision=old,vegetationRevision=vegetation[old.name]});
  }
  foreach(var r in roots.SelectMany(g=>g.GetComponentsInChildren<Renderer>(true)))
  {
   var old=r.sharedMaterials;if(old.Length==0)continue;bool differs=false;var b=old.ToArray();var c=old.ToArray();
   for(int i=0;i<old.Length;i++)if(old[i]){string key=AssetDatabase.GetAssetPath(old[i]);if(changed.ContainsKey(key)){differs=true;c[i]=changed[key];if(!key.Contains("Vegetation06"))b[i]=changed[key];}}
   if(differs)mats.Add(new VisualUnificationLab.MaterialChoice{renderer=r,original=old,materialRevision=b,vegetationRevision=c});
  }
  new GameObject("09 visual comparison - 1 old 2 materials 3 vegetation V weathering F1-F4 labs").AddComponent<VisualUnificationLab>().Configure(sprites.ToArray(),mats.ToArray(),Scenes);
 }
 static void Gallery()
 {
  // Separate comparative yard: zero geographic-placement claim for the castle.
  var original=EditorSceneManager.OpenScene(Scenes[0]);EditorSceneManager.SaveScene(original,Scenes[3],true);var scene=EditorSceneManager.OpenScene(Scenes[3]);
  var templates=new List<GameObject>();var deltas=new List<Vector3>();
  for(int j=0;j<3;j++)
  {
   var source=j==0?scene:EditorSceneManager.OpenScene(Scenes[j],OpenSceneMode.Additive);var building=source.GetRootGameObjects().SelectMany(g=>g.GetComponentsInChildren<ArchitectureBuilding>()).Single();var copy=Object.Instantiate(building.gameObject);copy.name="Gallery "+building.Id;UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(copy,scene);templates.Add(copy);
   var bounds=copy.GetComponentsInChildren<SpriteRenderer>().Select(s=>s.bounds).Aggregate((a,b)=>{a.Encapsulate(b);return a;});
   float left=j==0?5:j==1?40:78;deltas.Add(new Vector3(left-bounds.min.x,30-bounds.min.y,0));
   if(j!=0)EditorSceneManager.CloseScene(source,true);
  }
  UnityEngine.SceneManagement.SceneManager.SetActiveScene(scene);
  var actor=GameObject.Find("Player");var keep=new HashSet<GameObject>{actor.transform.root.gameObject,Camera.main.transform.root.gameObject,Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().transform.root.gameObject,GameObject.Find("OfflineAuthority")};foreach(var t in templates)keep.Add(t);
  foreach(var root in scene.GetRootGameObjects().Where(g=>!keep.Contains(g)).ToArray())Object.DestroyImmediate(root);
  for(int j=0;j<3;j++)
  {
   var g=templates[j];UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(g,scene);g.transform.position+=deltas[j];var building=g.GetComponent<ArchitectureBuilding>();var so=new SerializedObject(building);var entry=so.FindProperty("entrance");entry.vector2Value+=(Vector2)deltas[j];var approach=so.FindProperty("approach");approach.vector2Value+=(Vector2)deltas[j];so.ApplyModifiedPropertiesWithoutUndo();
   foreach(var depth in g.GetComponentsInChildren<ReferenceHouseDepth>())
   {
    var data=new SerializedObject(depth);data.FindProperty("actor").objectReferenceValue=actor.transform;data.FindProperty("actorBody").objectReferenceValue=actor.GetComponent<ProductionSpriteAnimator>().Body;var outline=data.FindProperty("groundOutline");for(int k=0;k<outline.arraySize;k++)outline.GetArrayElementAtIndex(k).vector2Value+=(Vector2)deltas[j];data.ApplyModifiedPropertiesWithoutUndo();
   }
  }
  // Neutral comparison ground: the real environmental context is in F1/F2.
  var floor=new GameObject("COMPARISON GARDEN - not a world castle lot");floor.transform.position=new Vector3(0,0,1);var mesh=new Mesh{name="Gallery floor"};mesh.vertices=new[]{new Vector3(0,0),new Vector3(140,0),new Vector3(0,100),new Vector3(140,100)};mesh.uv=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(0,1),new Vector2(1,1)};mesh.triangles=new[]{0,2,1,2,3,1};AssetDatabase.CreateAsset(mesh,Art+"GalleryFloor.asset");floor.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=floor.AddComponent<MeshRenderer>();renderer.sharedMaterial=changed["Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/A-final.mat"];renderer.sortingOrder=-2000;
  renderer.sharedMaterial=Material(renderer.sharedMaterial,AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/Castle/ReviewFloor.png"),"GalleryGround");
  var camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=39;camera.transform.position=new Vector3(67.5f,52,-10);camera.backgroundColor=new Color(.20f,.25f,.18f);actor.transform.position=new Vector3(24,29,0);actor.GetComponent<Rigidbody2D>().position=actor.transform.position;
  AddChoices(scene.GetRootGameObjects(),-1);Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaVisual09/Gallery/IsolatedProfile");EditorSceneManager.SaveScene(scene);
 }
}
