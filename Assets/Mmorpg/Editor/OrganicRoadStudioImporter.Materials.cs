using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
// Extends the World Studio importer; one terrain, physics and road contract.
public static partial class OrganicRoadStudioImporter
{
 const string MaterialsSource="ArtSource/Labs/World2026/WorldStudio03/BuildR7/";
 const string MaterialsArt="Assets/Mmorpg/Art/Experimental/ValdoriaOrganicMaterials03/";
 const string MaterialsScene="Assets/Mmorpg/Scenes/ValdoriaOrganicMaterialsLab.unity";
 static Texture2D ImportMaterialTexture(string source,string destination)
 {
  File.Copy(source,destination);AssetDatabase.ImportAsset(destination,ImportAssetOptions.ForceSynchronousImport);
  var ti=(TextureImporter)AssetImporter.GetAtPath(destination);ti.textureType=TextureImporterType.Default;ti.filterMode=FilterMode.Point;ti.mipmapEnabled=false;ti.textureCompression=TextureImporterCompression.Uncompressed;ti.wrapMode=TextureWrapMode.Clamp;ti.maxTextureSize=2048;ti.alphaIsTransparency=false;ti.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(destination);
 }
 public static object VerifyMaterials()
 {
  string regionHash=Hash(File.ReadAllBytes(BaseRegion));string roadHash=Hash(File.ReadAllBytes(Source+"A/road.json"));
  string libraryRoot="ArtSource/Labs/World2026/WorldStudio03/LibraryV2/";string libraryHash=Hash(File.ReadAllBytes(libraryRoot+"library.json"));var library=JObject.Parse(File.ReadAllText(libraryRoot+"library.json"));
  foreach(var f in ((JObject)library["files"]).Properties())if(Path.GetFileName(f.Name)!=f.Name||Hash(File.ReadAllBytes(libraryRoot+f.Name))!=(string)f.Value)throw new IOException("Material library source hash mismatch");
  foreach(var style in new[]{"A","B","C"})
  {
   var dir=MaterialsSource+style+"/";var manifest=JObject.Parse(File.ReadAllText(dir+"manifest.json"));
   if((string)manifest["librarySha256"]!=libraryHash||(string)manifest["recipeSha256"]!=Hash(File.ReadAllBytes("ArtSource/Labs/World2026/WorldStudio03/Recipes/recipe-"+style+".json")))throw new IOException("Material authoring provenance mismatch");
   if((string)manifest["schema"]!="valdoria-material-build/v1"||(string)manifest["regionSha256"]!=regionHash||(string)manifest["roadSha256"]!=roadHash)throw new IOException("Material input invariance failure");
   foreach(var f in ((JObject)manifest["files"]).Properties())
   {if(Path.GetFileName(f.Name)!=f.Name||Hash(File.ReadAllBytes(dir+f.Name))!=(string)f.Value)throw new IOException("Material artifact hash mismatch");}
  }
  return new {regionHash,roadHash,styles=3};
 }
 [MenuItem("Valdoria/World Studio/06 - Build Organic Materials Lab (new destination)")]
 public static void BuildMaterialsMenu()=>BuildMaterials();
 public static object BuildMaterials()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
  if(original.isDirty||original.path!=Scene)throw new IOException("Open clean Organic Roads Lab");
  if(File.Exists(MaterialsScene)||Directory.Exists(MaterialsArt))throw new IOException("Refuse existing materials scene/art destination");
  VerifyMaterials();Directory.CreateDirectory(MaterialsArt);AssetDatabase.Refresh();
  EditorSceneManager.SaveScene(original,MaterialsScene,true);var scene=EditorSceneManager.OpenScene(MaterialsScene);
  var roadLab=Object.FindAnyObjectByType<OrganicRoadLabController>();roadLab.Select(1);
  var so=new SerializedObject(roadLab);var old=new List<GameObject>{(GameObject)so.FindProperty("afterSurface").objectReferenceValue};
  old.Add((GameObject)so.FindProperty("roads").GetArrayElementAtIndex(0).objectReferenceValue);
  var terrain=Object.FindAnyObjectByType<TerrainRegionData>();var relief=terrain.transform.Find("Relief - shared elevation corners (visual only)").gameObject;old.Add(relief);
  Object.DestroyImmediate(roadLab.gameObject);
  var generated=new GameObject("Continuous materials - authored offline");generated.transform.SetParent(terrain.transform);
  var materials=new List<Material>();var sides=new List<Material>();
  var faceTexture=ImportMaterialTexture(MaterialsSource+"A/cliff-atlas.png",MaterialsArt+"cliff-atlas.png");
  var plainFace=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=Texture2D.whiteTexture,color=new Color(.39f,.44f,.40f,1)};AssetDatabase.CreateAsset(plainFace,MaterialsArt+"PlainFace.mat");
  var detailedFace=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=faceTexture};AssetDatabase.CreateAsset(detailedFace,MaterialsArt+"DetailedFace.mat");
  foreach(var style in new[]{"A","B","C"})foreach(var stage in new[]{"base","transitions","final"})
  {
   var texture=ImportMaterialTexture(MaterialsSource+style+"/"+stage+"-atlas.png",MaterialsArt+style+"-"+stage+"-atlas.png");
   var material=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=texture};AssetDatabase.CreateAsset(material,MaterialsArt+style+"-"+stage+".mat");materials.Add(material);
   // Same atlas, shared face material; darkening comes from vertex light, not an extra texture.
   sides.Add(stage=="final"?detailedFace:plainFace);
  }
  var mesh=new Mesh{name="ContinuousWorldSurface"};mesh.vertices=new[]{new Vector3(0,0),new Vector3(64,0),new Vector3(64,48),new Vector3(0,48)};mesh.uv=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(1,1),new Vector2(0,1)};mesh.colors=Enumerable.Repeat(Color.white,4).ToArray();mesh.triangles=new[]{0,1,2,0,2,3};mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,MaterialsArt+"Ground.asset");
  var ground=new GameObject("Surface - continuous world atlas chunks");ground.transform.SetParent(generated.transform);ground.AddComponent<MeshFilter>().sharedMesh=mesh;var gr=ground.AddComponent<MeshRenderer>();gr.sharedMaterial=materials[2];gr.sortingOrder=-2000;
  var field=JObject.Parse(File.ReadAllText(MaterialsSource+"A/relief-field.json"));var built=TerrainReliefBuilder.AddContinuous(generated,field,MaterialsArt+"Relief",materials[2],sides[2]);
  var dataPath=MaterialsArt+"composition.json";File.Copy(MaterialsSource+"A/composition.json",dataPath);AssetDatabase.ImportAsset(dataPath,ImportAssetOptions.ForceSynchronousImport);
  var player=GameObject.Find("Player");var lab=new GameObject("Material lab - 0 Before 1 A 2 B 3 C - B Base T Transitions F Final").AddComponent<TerrainMaterialLabController>();
  lab.Configure(old.ToArray(),generated,materials.ToArray(),sides.ToArray(),new[]{gr}.Concat(built.tops).ToArray(),built.faces,player.transform,AssetDatabase.LoadAssetAtPath<TextAsset>(dataPath));lab.ResetPose();
  Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaOrganicMaterials03/IsolatedProfile");
  EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=MaterialsScene,topDraws=built.tops.Length,faceDraws=built.faces.Length,textures=materials.Count,terrainCount=Object.FindObjectsByType<TerrainRegionData>().Length};
 }
 [MenuItem("Valdoria/World Studio/07 - Generate materials recipe to NEW output")]
 public static void GenerateMaterialsRecipe()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");
  string recipe=EditorUtility.OpenFilePanel("Material recipe","ArtSource/Labs/World2026/WorldStudio03/Recipes","json");if(string.IsNullOrEmpty(recipe))return;
  string library=EditorUtility.OpenFilePanel("Material library manifest","ArtSource/Labs/World2026/WorldStudio03/Library","json");if(string.IsNullOrEmpty(library))return;
  string region=EditorUtility.OpenFilePanel("WorldRegion input","ArtSource/Labs/World2026/WorldStudio01/Regions/B","json");if(string.IsNullOrEmpty(region))return;
  string road=EditorUtility.OpenFilePanel("Organic Road input",Source+"A","json");if(string.IsNullOrEmpty(road))return;
  string output=EditorUtility.SaveFilePanel("NEW materials output directory","ArtSource/Labs/World2026/WorldStudio03","MaterialRevision","");if(string.IsNullOrEmpty(output))return;
  if(Directory.Exists(output)||File.Exists(output))throw new IOException("Refuse materials output overwrite");
  var info=new System.Diagnostics.ProcessStartInfo("python"){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Directory.GetCurrentDirectory()};
  foreach(var arg in new[]{"Tools/ArtPipeline/WorldGen/terrain_materials.py","generate","--recipe",recipe,"--library",Path.GetDirectoryName(library),"--region",region,"--road",Path.GetDirectoryName(road),"--output",output})info.ArgumentList.Add(arg);
  using(var process=System.Diagnostics.Process.Start(info)){process.WaitForExit();if(process.ExitCode!=0)throw new IOException("Material authoring failed");}
  Debug.Log("New material revision generated: "+output);
 }
}
