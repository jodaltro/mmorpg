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
public static partial class OrganicRoadStudioImporter
{
 const string RefinedSource="ArtSource/Labs/World2026/WorldStudio04/BuildR6/";
 const string RefinedArt="Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/";
 const string RefinedScene="Assets/Mmorpg/Scenes/ValdoriaArtisticTerrainLab.unity";
 public static object VerifyRefinementArtifacts()
 {
  string libraryRoot="ArtSource/Labs/World2026/WorldStudio04/Library/";var lib=JObject.Parse(File.ReadAllText(libraryRoot+"library.json"));
  foreach(var f in ((JObject)lib["files"]).Properties())if(Path.GetFileName(f.Name)!=f.Name||Hash(File.ReadAllBytes(libraryRoot+f.Name))!=(string)f.Value)throw new IOException("Refined library hash mismatch");
  string region=Hash(File.ReadAllBytes(BaseRegion)),road=Hash(File.ReadAllBytes(Source+"A/road.json"));
  string relief=Hash(File.ReadAllBytes(MaterialsSource+"A/relief-field.json"));
  foreach(var style in new[]{"A","B","C"})
  {
   var dir=RefinedSource+style+"/";var manifest=JObject.Parse(File.ReadAllText(dir+"manifest.json"));
   if((string)manifest["regionSha256"]!=region||(string)manifest["roadSha256"]!=road||(string)manifest["librarySha256"]!=Hash(File.ReadAllBytes(libraryRoot+"library.json")))throw new IOException("Refinement input provenance mismatch");
   if((string)manifest["recipeSha256"]!=Hash(File.ReadAllBytes("ArtSource/Labs/World2026/WorldStudio04/Recipes/recipe-"+style+".json")))throw new IOException("Refined recipe mismatch");
   foreach(var f in ((JObject)manifest["files"]).Properties())if(Path.GetFileName(f.Name)!=f.Name||Hash(File.ReadAllBytes(dir+f.Name))!=(string)f.Value)throw new IOException("Refined artifact mismatch");
   if(Hash(File.ReadAllBytes(dir+"relief-field.json"))!=relief)throw new IOException("Refinement must preserve Marco03 relief geometry");
   var c=JObject.Parse(File.ReadAllText(dir+"composition.json"));foreach(var mask in ((JObject)c["roadRef"]["masks"]).Properties())if(Hash(File.ReadAllBytes(Source+"A/"+mask.Name+".png"))!=(string)mask.Value)throw new IOException("Road mask changed");
  }
  return new{region,road,relief,geometryInvariant=true};
 }
 [MenuItem("Valdoria/World Studio/08 - Build Artistic Terrain Lab (new destination)")]
 public static void BuildRefinementMenu()=>BuildRefinement();
 public static object BuildRefinement()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
  if(original.path!=MaterialsScene||original.isDirty)throw new IOException("Open clean Marco03 materials scene");
  if(File.Exists(RefinedScene)||Directory.Exists(RefinedArt))throw new IOException("Refuse existing refinement scene/art destination");
  VerifyRefinementArtifacts();Directory.CreateDirectory(RefinedArt);AssetDatabase.Refresh();EditorSceneManager.SaveScene(original,RefinedScene,true);var scene=EditorSceneManager.OpenScene(RefinedScene);
  var old=Object.FindAnyObjectByType<TerrainMaterialLabController>();old.Select(0,2);var oldSo=new SerializedObject(old);var previous=(GameObject)oldSo.FindProperty("generatedVisuals").objectReferenceValue;
  var terrain=Object.FindAnyObjectByType<TerrainRegionData>();var parent=terrain.transform;
  // In this NEW copied scene, previousVisuals and old controller are the only consumers of obsolete comparison objects.
  Object.DestroyImmediate(old.gameObject);
  foreach(Transform child in parent.Cast<Transform>().ToArray())if(child.gameObject!=previous&&child.GetComponentsInChildren<Renderer>(true).Length>0&&child.GetComponentsInChildren<Collider2D>(true).Length==0)Object.DestroyImmediate(child.gameObject);
  previous.name="Before - Marco03 A material reference";
  var generated=Object.Instantiate(previous,parent);generated.name="Refined materials - same meshes and semantic geometry";
  var finalMaterials=new List<Material>();
  foreach(var style in new[]{"A","B","C"})
  {
   var tex=ImportMaterialTexture(RefinedSource+style+"/final-atlas.png",RefinedArt+style+"-final-atlas.png");var mat=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=tex};AssetDatabase.CreateAsset(mat,RefinedArt+style+"-final.mat");finalMaterials.Add(mat);
  }
  var faceTexture=ImportMaterialTexture(RefinedSource+"A/cliff-atlas.png",RefinedArt+"cliff-atlas.png");var face=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=faceTexture};AssetDatabase.CreateAsset(face,RefinedArt+"Faces.mat");
  var all=generated.GetComponentsInChildren<MeshRenderer>();var walls=all.Where(r=>r.name.StartsWith("ContinuousFace_")).ToArray();var tops=all.Except(walls).ToArray();
  var data=RefinedArt+"composition.json";File.Copy(RefinedSource+"A/composition.json",data);AssetDatabase.ImportAsset(data,ImportAssetOptions.ForceSynchronousImport);
  var player=GameObject.Find("Player");var lab=new GameObject("Artistic Terrain - 0 Marco03 A - 1 Refined A 2 Medieval B 3 Organic C").AddComponent<TerrainMaterialLabController>();lab.ConfigureFinalOnly(previous,generated,finalMaterials.ToArray(),face,tops,walls,player.transform,AssetDatabase.LoadAssetAtPath<TextAsset>(data));lab.ResetPose();
  Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaArtisticTerrain04/IsolatedProfile");
  // Concrete production strategy: export ONE selected final visual prefab with no comparison controller or baseline textures.
  var copy=Object.Instantiate(generated);copy.name="FinalOnlyVisuals-A - experimental candidate";PrefabUtility.SaveAsPrefabAsset(copy,RefinedArt+"FinalOnlyVisuals-A.prefab");Object.DestroyImmediate(copy);
  File.WriteAllText(RefinedArt+"FinalOnlyVisuals-A.contract.json",new JObject{["schema"]="valdoria-final-material-visuals/v1",["artStatus"]="candidate-not-approved",["requiresHostWorldRegion"]=true,["physicalDataOwnedByHost"]=true,["comparisonStatesIncluded"]=false,["generatorRunsInPlay"]=false}.ToString());AssetDatabase.ImportAsset(RefinedArt+"FinalOnlyVisuals-A.contract.json");
  EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
  return new{scene=RefinedScene,renderers=all.Length,uniqueNewTextures=4,reusedMeshes=all.Select(r=>r.GetComponent<MeshFilter>().sharedMesh).Distinct().Count(),productionCandidate=RefinedArt+"FinalOnlyVisuals-A.prefab"};
 }
}
