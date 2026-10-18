using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class InspectArchitectureModels
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");
  string scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path;var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();bool castle=house.Id.Contains("castle");string kind=castle?"Castle":"Barn",root="ArtSource/Labs/World2026/WorldStudio08/"+kind+"/";ArchitectureArt07RImporter.VerifyReference(root+(castle?"ReviewV1/":"RegionV1/"),root+"ExportV1/",castle);
  var nav=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int mismatches=0,samples=0;float height=nav.Height*.25f;
  for(int y=0;y<nav.Height;y++)for(int x=0;x<nav.Width;x++){bool blocked=Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,height-(y+.5f)*.25f),1<<8)!=null;if(blocked==nav.CellWalkable(x,y))mismatches++;samples++;}
  var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{"Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/"+kind}).Select(g=>AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(g))).ToArray();var memory=textures.Select(t=>new{name=t.name,t.width,t.height,bytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t),point=t.filterMode==FilterMode.Point,mips=t.mipmapCount,format=t.format.ToString()}).ToArray();
  var result=new{scene,samples,navMismatches=mismatches,physicalPaths=house.GetComponents<PolygonCollider2D>().Sum(c=>c.pathCount),physicalVertices=house.GetComponents<PolygonCollider2D>().Sum(c=>Enumerable.Range(0,c.pathCount).Sum(i=>c.GetPath(i).Length)),colliders=house.GetComponentsInChildren<Collider2D>().Length,depthVolumes=house.GetComponentsInChildren<ReferenceHouseDepth>().Length,textureBytes=memory.Sum(t=>t.bytes),textures=memory,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=UnityEngine.Object.FindObjectsByType<Camera>().Length==1,plants=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Length,reviewOnly=castle,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("ArchitectureModelsQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),timeScale=Time.timeScale};
  bool refused=false;EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity");try{ArchitectureArt07RImporter.BuildReference(root+(castle?"ReviewV1/":"RegionV1/"),root+"ExportV1/","Assets/Mmorpg/Art/Experimental/ValdoriaArchitecture08/"+kind+"/",scene,castle);}catch(IOException e){refused=e.Message.Contains("Refuse existing");}finally{EditorSceneManager.OpenScene(scene);}
  var output=new{result,destinationRefused=refused};File.WriteAllText("Docs/Validation/ValdoriaWorldStudio08/"+kind+"QA/editor-qa.json",JsonConvert.SerializeObject(output,Formatting.Indented));return output;
 }
}
