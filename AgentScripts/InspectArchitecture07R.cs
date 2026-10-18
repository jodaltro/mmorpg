using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Mmorpg.Runtime;
public static class InspectArchitecture07R
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");ArchitectureArt07RImporter.Verify();var data=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();var env=UnityEngine.Object.FindAnyObjectByType<EnvironmentRegionData>();Physics2D.SyncTransforms();int mismatches=0,samples=0;
  for(int y=0;y<data.Height;y++)for(int x=0;x<data.Width;x++){var point=new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f);bool blocked=Physics2D.OverlapPoint(point,1<<8)!=null;bool expected=!data.CellWalkable(x,y);samples++;if(blocked!=expected)mismatches++;}
  var houses=UnityEngine.Object.FindObjectsByType<ArchitectureBuilding>();var buildingQA=houses.Select(h=>new{id=h.Id,archetype=h.Archetype,entry=h.Entrance.ToString(),approach=h.Approach.ToString(),mainFootprintVertices=h.GetComponent<PolygonCollider2D>().GetPath(0).Length,colliders=h.GetComponentsInChildren<Collider2D>().Length,noRoofCollider=h.transform.Find("Authored volumes - projected ground depth").GetComponentsInChildren<Collider2D>().Length==0,projectedGroundSorting=h.GetComponent<ReferenceHouseDepth>()!=null}).ToArray();
  var meshes=UnityEngine.Object.FindObjectsByType<MeshFilter>().Where(m=>m.name.StartsWith("Baked-")).Select(m=>m.sharedMesh).Distinct().ToArray();var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{ArchitectureArt07RImporter.Art.TrimEnd('/')}).Select(g=>AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(g))).ToArray();var memory=textures.Select(t=>new{name=t.name,t.width,t.height,bytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t),point=t.filterMode==FilterMode.Point,mips=t.mipmapCount,format=t.format.ToString()}).ToArray();int plantCount=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Length;
  string scenePath=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path;bool refused=false;EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaVegetationLab.unity");try{ArchitectureArt07RImporter.Build();}catch(IOException e){refused=e.Message.Contains("Refuse existing");}finally{EditorSceneManager.OpenScene(scenePath);}
  var result=new{scene=scenePath,navSamples=samples,navMismatches=mismatches,buildings=buildingQA,plantCount,bakedMeshes=meshes.Length,bakedMeshBytes=meshes.Sum(m=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(m)),architectureTextureBytes=memory.Sum(t=>t.bytes),textures=memory,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=UnityEngine.Object.FindObjectsByType<Camera>().Length==1,oneEnvironment=UnityEngine.Object.FindObjectsByType<EnvironmentRegionData>().Length==1,oneArchitectureData=UnityEngine.Object.FindObjectsByType<ArchitectureRegionData>().Length==1,noLegacyVegetationData=UnityEngine.Object.FindObjectsByType<VegetationRegionData>().Length==0,destinationRefused=refused,playStopped=!EditorApplication.isPlaying,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("Architecture07RQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),fixedViewOverride=SessionState.GetBool("Roads02.FixedView",false),timeScale=Time.timeScale,background=InputSystem.settings.backgroundBehavior.ToString(),editorInput=InputSystem.settings.editorInputBehaviorInPlayMode.ToString()};
  Directory.CreateDirectory("Docs/Validation/ValdoriaWorldStudio07R");File.WriteAllText("Docs/Validation/ValdoriaWorldStudio07R/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
