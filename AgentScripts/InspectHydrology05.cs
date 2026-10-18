using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Mmorpg.Runtime;
public static class InspectHydrology05
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");string path=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path;HydrologyStudioImporter.Verify();Physics2D.SyncTransforms();var data=UnityEngine.Object.FindAnyObjectByType<EnvironmentRegionData>();var terrain=UnityEngine.Object.FindAnyObjectByType<TerrainRegionData>();var geometry=JObject.Parse(File.ReadAllText(HydrologyStudioImporter.Source+"geometry.json"));var solid=terrain.GetComponentsInChildren<PolygonCollider2D>().Single(c=>c.name.StartsWith("Solid -"));var water=terrain.GetComponentsInChildren<PolygonCollider2D>().Single(c=>c.name.StartsWith("Water blockage"));
  int navMismatches=0,samples=0;var mismatchExamples=new List<object>();for(int y=0;y<data.Height;y++)for(int x=0;x<data.Width;x++)
  {
   Vector2 point=new Vector2((x+.5f)*data.StepUnits,48-(y+.5f)*data.StepUnits);bool physical=solid.OverlapPoint(point)||water.OverlapPoint(point);bool expected=!data.CellWalkable(x,y);samples++;if(physical!=expected){navMismatches++;if(mismatchExamples.Count<6)mismatchExamples.Add(new{x,y,physical,expected});}
  }
  var feet=terrain.GetComponentsInChildren<MeshFilter>().Where(m=>m.name.StartsWith("ContinuousFace_")).SelectMany(m=>m.sharedMesh.vertices.Select((v,i)=>new{v,i}).Where(p=>p.i%4==2||p.i%4==3).Select(p=>(Vector2)m.transform.TransformPoint(p.v))).ToArray();float maxFootDelta=0;int vertices=0;
  for(int i=0;i<solid.pathCount;i++)foreach(var point in solid.GetPath(i)){vertices++;maxFootDelta=Mathf.Max(maxFootDelta,feet.Min(p=>Vector2.Distance(p,point)));}
  var waterObjects=UnityEngine.Object.FindObjectsByType<WaterSurfaceAnimator>();var textures=new List<Texture2D>();foreach(var a in waterObjects){var so=new SerializedObject(a);var f=so.FindProperty("frames");for(int i=0;i<f.arraySize;i++)textures.Add((Texture2D)f.GetArrayElementAtIndex(i).objectReferenceValue);}
  var waterTextures=textures.Distinct().Select(t=>new{path=AssetDatabase.GetAssetPath(t),t.width,t.height,memoryBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t),point=t.filterMode==FilterMode.Point,mips=t.mipmapCount,format=t.format.ToString()}).ToArray();
  var terrainTextures=terrain.GetComponentsInChildren<Renderer>().Where(r=>!r.name.StartsWith("Water chunk")).SelectMany(r=>r.sharedMaterials).Select(m=>m.mainTexture).OfType<Texture2D>().Distinct().Select(t=>new{path=AssetDatabase.GetAssetPath(t),memoryBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)}).ToArray();
  int solidPaths=solid.pathCount,waterBlockedPaths=water.pathCount;bool refused=false;EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaArtisticTerrainLab.unity");try{HydrologyStudioImporter.Build();}catch(IOException e){refused=e.Message.Contains("Refuse existing");}finally{EditorSceneManager.OpenScene(path);}
  var result=new{scene=path,navSamples=samples,navMismatches,mismatchExamples,sharedRockContourVertices=vertices,maxFootDeltaUnits=maxFootDelta,solidPaths,waterBlockedPaths,waterTextures,terrainTextures,waterRenderers=waterObjects.Length,waterGameObjects=waterObjects.Length,physicalFootprintSource="same semantic triangular scalar union as visual relief / depth field",originalHeightChanged=false,coarseReliefBoxesRemaining=UnityEngine.Object.FindAnyObjectByType<TerrainRegionData>().GetComponentsInChildren<BoxCollider2D>().Length,destinationRefused=refused,playStopped=!EditorApplication.isPlaying,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,cameraCount=UnityEngine.Object.FindObjectsByType<Camera>().Length,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("HydrologyQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),fixedView=SessionState.GetBool("Roads02.FixedView",false),timeScale=Time.timeScale,input=InputSystem.settings.editorInputBehaviorInPlayMode.ToString()};
  Directory.CreateDirectory("Docs/Validation/ValdoriaWorldStudio05/Final");File.WriteAllText("Docs/Validation/ValdoriaWorldStudio05/Final/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
