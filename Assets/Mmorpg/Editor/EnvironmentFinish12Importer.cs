using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
[InitializeOnLoad]
public static class EnvironmentFinish12Importer
{
 public const string Source="ArtSource/Labs/World2026/Ground12/",Art="Assets/Mmorpg/Art/Experimental/ValdoriaGround12/",Scene="Assets/Mmorpg/Scenes/ValdoriaEnvironmentFinishLab.unity";
 static EnvironmentFinish12Importer(){EditorApplication.update+=Tick;}
 public static object QueueRefresh(){if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=Scene||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Ground12 only");SessionState.SetBool("Ground12.Refresh",true);return "Queued explicit derived-paint refresh; receipt Temp/Ground12-refresh.json";}
 public static object Refresh()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=Scene||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Ground12 only");
  NatureReference10Importer.Verify(Source+"BuildV2/");
  var pairs=new List<string[]>{new[]{"ground-bank.png","WetBankGround.png"},new[]{"relief-top.png","ReliefTop.png"},new[]{"relief-face.png","ReliefFace.png"}};
  foreach(var p in JObject.Parse(File.ReadAllText(Source+"BuildV2/manifest.json"))["files"].Children<JProperty>().Where(p=>p.Name.StartsWith("water-")&&p.Name.EndsWith(".png")))pairs.Add(new[]{p.Name,p.Name});
  foreach(var p in pairs){var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(Art+p[1]);if(!texture)throw new IOException("Missing existing derived target");File.Copy(Source+"BuildV2/"+p[0],Art+p[1],true);AssetDatabase.ImportAsset(Art+p[1],ImportAssetOptions.ForceSynchronousImport);}return new{refreshed=pairs.Count,geometryChanged=false};
 }
 public static object Queue(){if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Editor required");if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing destination");SessionState.SetBool("Ground12.Build",true);return "Queued Ground12 build; receipt Temp/Ground12-build.json";}
 static void Tick(){bool refresh=SessionState.GetBool("Ground12.Refresh",false);if((!SessionState.GetBool("Ground12.Build",false)&&!refresh)||EditorApplication.isUpdating||EditorApplication.isCompiling)return;SessionState.SetBool("Ground12.Build",false);SessionState.SetBool("Ground12.Refresh",false);string receipt=refresh?"Temp/Ground12-refresh.json":"Temp/Ground12-build.json";try{File.WriteAllText(receipt,JsonConvert.SerializeObject(new{success=true,result=refresh?Refresh():Build()},Formatting.Indented));}catch(Exception e){File.WriteAllText(receipt,JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}}
 static Texture2D Texture(string input,string name,bool sprite=false,Vector2 pivot=default)
 {
  string path=Art+name+".png";File.Copy(input,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=sprite?TextureImporterType.Sprite:TextureImporterType.Default;i.spriteImportMode=SpriteImportMode.Single;i.spritePixelsPerUnit=32;i.npotScale=TextureImporterNPOTScale.None;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.maxTextureSize=4096;i.alphaIsTransparency=sprite;var s=new TextureImporterSettings();i.ReadTextureSettings(s);s.spriteMeshType=SpriteMeshType.FullRect;s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=pivot;i.SetTextureSettings(s);var p=i.GetDefaultPlatformTextureSettings();p.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(p);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
 }
 static Material Mat(Material template,string file,string name){var m=new Material(template){name=name,mainTexture=Texture(Source+"BuildV2/"+file,name)};AssetDatabase.CreateAsset(m,Art+name+".mat");return m;}
 static SpriteRenderer Sprite(Transform parent,string name,Sprite sprite,Vector3 offset,Material material,int order){var go=new GameObject(name);go.transform.SetParent(parent,false);go.transform.localPosition=offset;var r=go.AddComponent<SpriteRenderer>();r.sprite=sprite;r.sharedMaterial=material;r.sortingOrder=order;return r;}
 public static object Build()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty||File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse playing/dirty/existing destination");
  NatureReference10Importer.Verify(Source+"ExportV1/");NatureReference10Importer.Verify(Source+"BuildV2/");Directory.CreateDirectory(Art);AssetDatabase.Refresh();var scene=EditorSceneManager.OpenScene(GroundFinish11Importer.Scene);EditorSceneManager.SaveScene(scene,Scene,true);scene=EditorSceneManager.OpenScene(Scene);var controller=Object.FindAnyObjectByType<GroundFinishLab>();controller.Select(3);Object.DestroyImmediate(controller.gameObject);
  var ground=AssetDatabase.LoadAssetAtPath<Material>(GroundFinish11Importer.Art+"WorldFinal-final.mat");var face=AssetDatabase.LoadAssetAtPath<Material>(NatureReference10Importer.Art+"RockFaces.mat");var groundNew=Mat(ground,"ground-bank.png","WetBankGround");var topNew=Mat(ground,"relief-top.png","ReliefTop");var faceNew=Mat(face,"relief-face.png","ReliefFace");var bindings=new List<EnvironmentFinishLab.Binding>();
  foreach(var r in Object.FindObjectsByType<MeshRenderer>())if(r.sharedMaterial==face)bindings.Add(new EnvironmentFinishLab.Binding{renderer=r,before=face,after=faceNew});else if(r.sharedMaterial==ground)bindings.Add(new EnvironmentFinishLab.Binding{renderer=r,before=ground,after=r.name.StartsWith("ContinuousTop_")?topNew:groundNew});
  var oldMat=AssetDatabase.LoadAssetAtPath<Material>(VisualUnification09Importer.Art+"Vegetation09.mat");var mat=new Material(oldMat){name="Ground12 Plants"};AssetDatabase.CreateAsset(mat,Art+"Plants.mat");var source=JObject.Parse(File.ReadAllText(Source+"ExportV1/sprites.json"));var sprites=new Dictionary<string,Sprite>();
  foreach(var spec in source["assets"].Where(s=>(string)s["kind"]!="material"))foreach(var part in new[]{"body","shadow"}){string id=(string)spec["id"]+"-"+part;float w=(float)spec["canvas"][0],h=(float)spec["canvas"][1];Texture(Source+"ExportV1/"+((string)spec["kind"]=="low"&&part=="body"?(string)spec["id"]:id)+".png",id,true,new Vector2((float)spec["anchor"][0]/w,1-(float)spec["anchor"][1]/h));sprites[id]=AssetDatabase.LoadAssetAtPath<Sprite>(Art+id+".png");}
  // Every replacement consumes the original ecological anchor. No new collider.
  var root=scene.GetRootGameObjects().Single(g=>g.activeSelf&&g.name.StartsWith("Nature study"));var previous=root.GetComponentsInChildren<Renderer>().Where(r=>r.sharedMaterial==oldMat).ToArray();var graphics=new List<GameObject>();var low=new GameObject("Ground12 low plants - existing ecological points");graphics.Add(low);
  var lowMaterials=new Dictionary<string,Material>();foreach(var spec in source["assets"].Where(s=>(string)s["kind"]=="low")){string key=(string)spec["id"];var lm=new Material(mat){name=key,mainTexture=sprites[key+"-body"].texture};AssetDatabase.CreateAsset(lm,Art+key+".mat");lowMaterials[key]=lm;}
  var legacy=JObject.Parse(File.ReadAllText(VegetationStudioImporter.Library+"sprites.json"));var legacySprites=AssetDatabase.LoadAllAssetsAtPath(VisualUnification09Importer.Art+"vegetation-atlas.png").OfType<Sprite>().ToDictionary(s=>s.name);int trees=0,replaced=0,preserved=0;
  foreach(var anchor in root.GetComponentsInChildren<VegetationAnchor>())
  {
   if(anchor.Species=="authored-oak")continue;
   bool tree=anchor.FootprintRadius>0;string id=tree?(anchor.Species=="elm"?"elm-vase":"hornbeam-open"):anchor.Species=="hazel"?"hazel-layered":anchor.Species=="reeds"?"reeds-open":anchor.Species=="fern"||anchor.Species=="plantgroup"?"fern-"+(anchor.Variant%2):null;
   GameObject holder;
   if(tree){holder=new GameObject("Ground12 authored replacement graphics");holder.transform.SetParent(anchor.transform,false);graphics.Add(holder);trees++;}
   else{holder=new GameObject(anchor.InstanceId);holder.transform.SetParent(low.transform);holder.transform.position=anchor.transform.position;holder.AddComponent<VegetationAnchor>().Configure(anchor.InstanceId,anchor.Species,anchor.Variant,0);}
   var visual=new GameObject("Trunk and crown - depth at ground anchor");visual.transform.SetParent(holder.transform,false);visual.AddComponent<SortingGroup>().sortingOrder=100-Mathf.RoundToInt(anchor.transform.position.y*16);
   if(id!=null){Sprite(visual.transform,"crown",sprites[id+"-body"],Vector3.zero,tree?mat:lowMaterials[id],1);if(tree)Sprite(holder.transform,"shadow",sprites[id+"-shadow"],Vector3.zero,mat,-1977);replaced++;}
   else{foreach(string part in new[]{"shadow","trunk","crown"}){string name=anchor.Species+"-v"+anchor.Variant+"-"+part;if(!legacySprites.ContainsKey(name))continue;var spec=legacy["sprites"].Single(s=>(string)s["id"]==name);Sprite(part=="shadow"?holder.transform:visual.transform,part,legacySprites[name],new Vector3((float)spec["offsetUnits"][0],(float)spec["offsetUnits"][1]),oldMat,part=="shadow"?-1977:1);}preserved++;}
  }
  // Separate batches by texture: the helper records UVs, not arbitrary material changes.
  foreach(var materialGroup in lowMaterials.Values.Concat(new[]{oldMat}))
  {
   var groupRoot=new GameObject("Bake "+materialGroup.name);groupRoot.transform.SetParent(low.transform);
   foreach(var child in low.GetComponentsInChildren<VegetationAnchor>().Where(a=>a.GetComponentsInChildren<SpriteRenderer>().Any(r=>r.sharedMaterial==materialGroup)).ToArray())child.transform.SetParent(groupRoot.transform,true);
   VegetationStudioImporter.BakeStaticDetails(groupRoot,"Ground12-"+materialGroup.name,materialGroup,Art);
   foreach(var a in groupRoot.GetComponentsInChildren<VegetationAnchor>())Object.DestroyImmediate(a.gameObject);
  }
  foreach(var spec in source["assets"].Where(s=>(string)s["kind"]!="material"))
  {
   string id=(string)spec["id"];var go=new GameObject(id+" - visual only, host owns footprint");var visual=new GameObject("Trunk and crown - depth at ground anchor");visual.transform.SetParent(go.transform,false);var group=visual.AddComponent<SortingGroup>();Sprite(visual.transform,"crown",sprites[id+"-body"],Vector3.zero,mat,1);if((string)spec["kind"]=="tree")Sprite(go.transform,"shadow",sprites[id+"-shadow"],Vector3.zero,mat,-1977);go.AddComponent<PlantVisualDepth>().Configure(group);PrefabUtility.SaveAsPrefabAsset(go,Art+id+".prefab");Object.DestroyImmediate(go);
  }
  var composition=JObject.Parse(File.ReadAllText(Source+"BuildV2/composition.json"));var water=new List<EnvironmentFinishLab.Water>();
  foreach(var chunk in composition["waterChunks"]){string id=(string)chunk["id"];var animator=Object.FindObjectsByType<WaterSurfaceAnimator>().Single(a=>a.name=="Water chunk "+id);var r=animator.GetComponent<MeshRenderer>();var old=chunk["frames"].Select(f=>AssetDatabase.LoadAssetAtPath<Texture2D>(HydrologyStudioImporter.Art+(string)f)).ToArray();var fresh=chunk["frames"].Select(f=>Texture(Source+"BuildV2/"+(string)f,Path.GetFileNameWithoutExtension((string)f))).ToArray();water.Add(new EnvironmentFinishLab.Water{animator=animator,renderer=r,before=old,after=fresh});}
  var lab=new GameObject("Ground12 - 1 Ground11 baseline, 2 candidate").AddComponent<EnvironmentFinishLab>();lab.Configure(bindings.ToArray(),previous,graphics.ToArray(),water.ToArray());Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaGround12/IsolatedProfile");EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,trees,replaced,preserved,anchorsUnchanged=true,physicsChanged=false,bindings=bindings.Count,waterChunks=water.Count};
 }
}
