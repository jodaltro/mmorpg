using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class InspectVisualUnification09
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();int index=Array.IndexOf(VisualUnification09Importer.Scenes,scene.path);if(index<0||index>2)throw new IOException("Requires 09 world or castle sublab");
  var nav=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int mismatches=0,samples=0;float height=nav.Height*.25f;
  for(int y=0;y<nav.Height;y++)for(int x=0;x<nav.Width;x++){bool blocked=Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,height-(y+.5f)*.25f),1<<8)!=null;if(blocked==nav.CellWalkable(x,y))mismatches++;samples++;}
  var deps=EditorUtility.CollectDependencies(scene.GetRootGameObjects().Cast<UnityEngine.Object>().ToArray());var textures=deps.OfType<Texture2D>().Distinct().ToArray();
  var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();var controller=UnityEngine.Object.FindAnyObjectByType<VisualUnificationLab>();
  var result=new{scene=scene.path,sceneClean=!scene.isDirty,samples,navMismatches=mismatches,colliders=house.GetComponents<PolygonCollider2D>().Length,vertices=house.GetComponents<PolygonCollider2D>().Sum(c=>c.points.Length),depthGroups=house.GetComponentsInChildren<ReferenceHouseDepth>().Length,plants=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Length,comparisonResidentTextureCount=textures.Length,comparisonResidentTextureBytes=textures.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)),onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=UnityEngine.Object.FindObjectsByType<Camera>().Length==1,defaultStage=controller.Stage,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("VisualDirection09QA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),timeScale=Time.timeScale,reviewOnly=index==2};
  string output="Docs/Validation/ValdoriaWorldStudio09/"+new[]{"House","Barn","Castle"}[index]+"QA/editor-qa.json";if(File.Exists(output))throw new IOException("Refuse editor evidence overwrite");File.WriteAllText(output,JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
 public static object GalleryFraming()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var scene=EditorSceneManager.OpenScene(VisualUnification09Importer.Scenes[3]);Camera.main.orthographicSize=39;Camera.main.transform.position=new Vector3(67.5f,52,-10);var renderer=GameObject.Find("COMPARISON GARDEN - not a world castle lot").GetComponent<MeshRenderer>();string path=VisualUnification09Importer.Art+"GalleryGround.mat";var ground=AssetDatabase.LoadAssetAtPath<Material>(path);if(!ground){ground=new Material(renderer.sharedMaterial){mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/Castle/ReviewFloor.png")};AssetDatabase.CreateAsset(ground,path);}renderer.sharedMaterial=ground;AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(scene);return "Gallery framing and neutral ground adjusted; architecture scale unchanged";
 }
}
