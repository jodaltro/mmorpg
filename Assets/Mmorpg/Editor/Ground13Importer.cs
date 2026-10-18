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
public static class Ground13Importer
{
 public const string Source="ArtSource/Labs/World2026/Ground13/",Art="Assets/Mmorpg/Art/Experimental/ValdoriaGround13Final/",Scene="Assets/Mmorpg/Scenes/ValdoriaGround13RefinementLab.unity";
 static Ground13Importer(){EditorApplication.update+=Tick;}
 public static object Queue(){if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty||Directory.Exists(Art)||File.Exists(Scene))throw new IOException("Refuse playing/dirty/existing destination");SessionState.SetBool("Ground13.Build",true);return "Queued Ground13; receipt Temp/Ground13-build.json";}
 static void Tick(){if(!SessionState.GetBool("Ground13.Build",false)||EditorApplication.isCompiling||EditorApplication.isUpdating)return;SessionState.SetBool("Ground13.Build",false);try{File.WriteAllText("Temp/Ground13-build.json",JsonConvert.SerializeObject(new{success=true,result=Build()},Formatting.Indented));}catch(Exception e){File.WriteAllText("Temp/Ground13-build.json",JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}}
 static Texture2D Texture(string input,string name,bool repeat=false)
 {
  string path=Art+name+".png";File.Copy(input,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Default;i.npotScale=TextureImporterNPOTScale.None;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.maxTextureSize=4096;i.wrapMode=repeat?TextureWrapMode.Repeat:TextureWrapMode.Clamp;var p=i.GetDefaultPlatformTextureSettings();p.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(p);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
 }
 static Material Mat(Material template,string name,Texture texture){var m=new Material(template){name=name,mainTexture=texture};AssetDatabase.CreateAsset(m,Art+name+".mat");return m;}
 sealed class Batch
 {
  public List<Vector3> vertices=new List<Vector3>();public List<Vector2> uv=new List<Vector2>();public List<Color> colors=new List<Color>();public List<int> indices=new List<int>();
  public void Mesh(MeshRenderer renderer,JToken entry,int width,int height)
  {
   var mesh=renderer.GetComponent<MeshFilter>().sharedMesh;int start=vertices.Count;vertices.AddRange(mesh.vertices.Select(v=>renderer.transform.TransformPoint(v)));var rect=entry["rect"];var source=entry["originalSize"];var sourceRect=entry["sourceRect"];bool identity=entry["identityForProtectedRects"]!=null;
   foreach(var p in mesh.uv)uv.Add(identity?p:new Vector2(((float)rect[0]+p.x*(float)source[0]-(float)sourceRect[0])/width,(height-(float)rect[1]-(float)rect[3]+p.y*(float)source[1]-((float)source[1]-(float)sourceRect[3]))/height));
   colors.AddRange(mesh.colors.Length==mesh.vertexCount?mesh.colors:Enumerable.Repeat(Color.white,mesh.vertexCount));indices.AddRange(mesh.triangles.Select(i=>start+i));
  }
  public void Shadow(SpriteRenderer renderer,JToken entry,int width,int height)
  {
   var s=renderer.sprite;var box=entry["sourceRect"];var size=entry["originalSize"];var rect=entry["rect"];float ppu=s.pixelsPerUnit;float x0=((float)box[0]-s.pivot.x)/ppu,x1=((float)box[2]-s.pivot.x)/ppu,y0=((float)size[1]-(float)box[3]-s.pivot.y)/ppu,y1=((float)size[1]-(float)box[1]-s.pivot.y)/ppu;int n=vertices.Count;
   vertices.AddRange(new[]{new Vector3(x0,y0),new Vector3(x1,y0),new Vector3(x1,y1),new Vector3(x0,y1)}.Select(v=>renderer.transform.TransformPoint(v)));float u0=(float)rect[0]/width,u1=((float)rect[0]+(float)rect[2])/width,v0=(height-(float)rect[1]-(float)rect[3])/height,v1=(height-(float)rect[1])/height;uv.AddRange(new[]{new Vector2(u0,v0),new Vector2(u1,v0),new Vector2(u1,v1),new Vector2(u0,v1)});colors.AddRange(Enumerable.Repeat(renderer.color,4));indices.AddRange(new[]{n,n+2,n+1,n,n+3,n+2});
  }
  public MeshRenderer Save(Transform parent,string name,Material material,int order,int layer=0)
  {
   if(indices.Count==0)return null;var mesh=new Mesh{name=name,indexFormat=IndexFormat.UInt32};mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,Art+name+".asset");var go=new GameObject(name);go.transform.SetParent(parent,false);var r=go.AddComponent<MeshRenderer>();go.AddComponent<MeshFilter>().sharedMesh=mesh;r.sharedMaterial=material;r.sortingOrder=order;r.sortingLayerID=layer;return r;
  }
 }
 static object Build()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty||Directory.Exists(Art)||File.Exists(Scene))throw new IOException("Refuse playing/dirty/existing destination");
  foreach(string name in new[]{"ExportV2/","AtlasV1/","ReliefV3/","WaterV2/"})NatureReference10Importer.Verify(Source+name);Directory.CreateDirectory(Art);AssetDatabase.Refresh();var scene=EditorSceneManager.OpenScene(EnvironmentFinish12Importer.Scene);EditorSceneManager.SaveScene(scene,Scene,true);scene=EditorSceneManager.OpenScene(Scene);var previous=Object.FindAnyObjectByType<EnvironmentFinishLab>();previous.Select(true);Object.DestroyImmediate(previous.gameObject);
  var atlas=JObject.Parse(File.ReadAllText(Source+"AtlasV1/atlas.json"));var entries=atlas["entries"];int width=(int)atlas["size"][0],height=(int)atlas["size"][1];var oldMat=AssetDatabase.LoadAssetAtPath<Material>(VisualUnification09Importer.Art+"Vegetation09.mat");var packedMaterial=Mat(oldMat,"PlantsPacked",Texture(Source+"AtlasV1/plants-shared.png","PlantsPacked"));
  var low=GameObject.Find("Ground12 low plants - existing ecological points");var oldLow=low.GetComponentsInChildren<MeshRenderer>().ToArray();var shadows=Object.FindObjectsByType<SpriteRenderer>().Where(r=>r.enabled&&r.sprite&&AssetDatabase.GetAssetPath(r.sprite.texture).StartsWith(EnvironmentFinish12Importer.Art)&&AssetDatabase.GetAssetPath(r.sprite.texture).EndsWith("-shadow.png")).ToArray();var allPlants=oldLow.Cast<Renderer>().Concat(shadows).ToArray();var retained=Ground13PackingSafety.Preserve(allPlants);var oldPlants=allPlants.Where(r=>!retained.Contains(r)).ToArray();var packedRoot=new GameObject("Ground13 lossless packed vegetation - same sorting bands");var batches=new Dictionary<string,Batch>();var orders=new Dictionary<string,int[]>();
  foreach(var renderer in oldPlants.OrderBy(r=>r.sortingOrder).ThenBy(r=>r.name,StringComparer.Ordinal))
  {
   string texture=AssetDatabase.GetAssetPath(renderer is SpriteRenderer sprite?sprite.sprite.texture:renderer.sharedMaterial.mainTexture);if(entries[texture]==null)throw new IOException("Atlas source not declared: "+texture);if(renderer.GetComponentInParent<SortingGroup>())throw new IOException("Cannot batch a shadow across a live SortingGroup");string key=renderer.sortingLayerID+"_"+renderer.sortingOrder;if(!batches.ContainsKey(key)){batches[key]=new Batch();orders[key]=new[]{renderer.sortingLayerID,renderer.sortingOrder};}if(renderer is MeshRenderer mesh)batches[key].Mesh(mesh,entries[texture],width,height);else batches[key].Shadow((SpriteRenderer)renderer,entries[texture],width,height);
  }
  foreach(var pair in batches)pair.Value.Save(packedRoot.transform,"Plants_"+pair.Key,packedMaterial,orders[pair.Key][1],orders[pair.Key][0]);
  var oldRelief=Object.FindObjectsByType<MeshRenderer>().Where(r=>r.name.StartsWith("ContinuousTop_")||r.name.StartsWith("ContinuousFace_")).Cast<Renderer>().ToArray();var reliefRoot=new GameObject("Ground13 visual strata - physical foot unchanged");var stone=Mat(oldMat,"StratifiedFace",Texture(Source+"ExportV2/stratified-face.png","StratifiedFace",true));var grass=Mat(oldMat,"UplandSward",Texture(Source+"ExportV2/upland-sward.png","UplandSward",true));var white=new Texture2D(1,1,TextureFormat.RGBA32,false);white.SetPixel(0,0,Color.white);white.Apply();AssetDatabase.CreateAsset(white,Art+"ClayWhite.asset");var clay=Mat(oldMat,"Clay",white);var bindings=new List<Ground13Lab.Surface>();
  var geometry=JObject.Parse(File.ReadAllText(Source+"ReliefV3/visual-relief.json"));foreach(var group in geometry["groups"]){var b=new Batch();b.vertices=group["vertices"].Select(v=>new Vector3((float)v[0],(float)v[1],(float)v[2])).ToList();b.uv=group["uv"].Select(v=>new Vector2((float)v[0],(float)v[1])).ToList();b.colors=group["colors"].Select(v=>new Color((float)v[0],(float)v[1],(float)v[2],(float)v[3])).ToList();b.indices=group["triangles"].Select(v=>(int)v).ToList();int row=(int)group["row"];string kind=(string)group["kind"];var material=kind=="grass"?grass:stone;var renderer=b.Save(reliefRoot.transform,"Strata_"+row+"_"+kind,material,100-Mathf.RoundToInt((48-(row+1))*16)+(kind=="stone"?1:0));if(renderer)bindings.Add(new Ground13Lab.Surface{renderer=renderer,after=material});}
  var oldGround=AssetDatabase.LoadAssetAtPath<Material>(EnvironmentFinish12Importer.Art+"WetBankGround.mat");var newGround=Mat(oldGround,"GroundBanks",Texture(Source+"WaterV2/bank-ground.png","GroundBanks"));var ground=Object.FindObjectsByType<MeshRenderer>().Where(r=>r.sharedMaterial==oldGround).Select(r=>new Ground13Lab.Surface{renderer=r,before=oldGround,after=newGround}).ToArray();
  var waterMeta=JObject.Parse(File.ReadAllText(Source+"WaterV2/water.json"));var water=new List<Ground13Lab.Water>();foreach(var chunk in waterMeta["chunks"]){string id=(string)chunk["id"];var animator=Object.FindObjectsByType<WaterSurfaceAnimator>().Single(a=>a.name=="Water chunk "+id);water.Add(new Ground13Lab.Water{animator=animator,renderer=animator.GetComponent<MeshRenderer>(),before=chunk["frames"].Select(f=>AssetDatabase.LoadAssetAtPath<Texture2D>(EnvironmentFinish12Importer.Art+(string)f)).ToArray(),after=chunk["frames"].Select(f=>Texture(Source+"WaterV2/"+(string)f,Path.GetFileNameWithoutExtension((string)f))).ToArray()});}
  new GameObject("Ground13 - 1 baseline 2 packing proof 3 clay 4 final 5 unpacked final").AddComponent<Ground13Lab>().Configure(oldPlants,oldRelief,packedRoot,reliefRoot,ground,bindings.ToArray(),water.ToArray(),clay);Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaGround13Final/IsolatedProfile");EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,sourcePlantRenderers=oldPlants.Length,packedPlantRenderers=packedRoot.GetComponentsInChildren<Renderer>().Length,oldReliefRenderers=oldRelief.Length,newReliefRenderers=bindings.Count,physicalChange=false,atlasSize=new[]{width,height}};
 }
}
