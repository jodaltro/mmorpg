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
public static class InspectVegetation06
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");VegetationStudioImporter.Verify();var lab=UnityEngine.Object.FindAnyObjectByType<VegetationLabController>();var nav=UnityEngine.Object.FindAnyObjectByType<VegetationRegionData>();var env=UnityEngine.Object.FindAnyObjectByType<EnvironmentRegionData>();var styles=new List<object>();string scenePath=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path;
  for(int i=0;i<3;i++)
  {
   lab.Select(i);Physics2D.SyncTransforms();int mismatches=0,samples=0;for(int y=0;y<env.Height;y++)for(int x=0;x<env.Width;x++){var p=new Vector2((x+.5f)*env.StepUnits,48-(y+.5f)*env.StepUnits);bool blocked=Physics2D.OverlapPoint(p,1<<8)!=null;bool expected=!nav.CellWalkable(x,y);samples++;if(blocked!=expected)mismatches++;}
   var anchors=UnityEngine.Object.FindObjectsByType<VegetationAnchor>();var trees=anchors.Where(a=>a.FootprintRadius>0).ToArray();bool footprints=trees.All(t=>t.GetComponentsInChildren<Collider2D>().Length==1&&t.GetComponent<CircleCollider2D>()!=null&&Mathf.Abs(t.GetComponent<CircleCollider2D>().radius-t.FootprintRadius)<1e-5f);bool sorting=trees.All(t=>t.GetComponentInChildren<UnityEngine.Rendering.SortingGroup>().sortingOrder==100-Mathf.RoundToInt(t.transform.position.y*16));var meshes=UnityEngine.Object.FindObjectsByType<MeshFilter>().Where(m=>m.name.StartsWith("Baked-")).Select(m=>m.sharedMesh).Distinct().ToArray();
   styles.Add(new{style="ABC"[i].ToString(),instances=anchors.Length,trees=trees.Length,navSamples=samples,navMismatches=mismatches,treeFootprintsOnly=footprints,treeSortingAtGround=sorting,bakedMeshCount=meshes.Length,bakedMeshMemory=meshes.Sum(m=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(m)),vegetationSpriteRenderers=anchors.Sum(a=>a.GetComponentsInChildren<SpriteRenderer>().Length),totalActiveRenderers=UnityEngine.Object.FindObjectsByType<Renderer>().Length});
  }
  lab.Select(0,true);Physics2D.SyncTransforms();int beforeCircles=UnityEngine.Object.FindObjectsByType<CircleCollider2D>().Count(c=>c.GetComponent<VegetationAnchor>()!=null);bool overlayDisabled=nav.ActiveComposition==-1;lab.Select(0);lab.ResetPose();var atlas=AssetDatabase.LoadAssetAtPath<Texture2D>(VegetationStudioImporter.Art+"vegetation-atlas.png");var texture=new{atlas.width,atlas.height,memoryBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(atlas),point=atlas.filterMode==FilterMode.Point,mips=atlas.mipmapCount,format=atlas.format.ToString()};
  bool refused=false;EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaHydrologyLab.unity");try{VegetationStudioImporter.Build();}catch(IOException e){refused=e.Message.Contains("Refuse existing");}finally{EditorSceneManager.OpenScene(scenePath);}
  var result=new{scene=scenePath,styles,atlas=texture,baselineVegetationColliders=beforeCircles,baselineOverlayDisabled=overlayDisabled,destinationRefused=refused,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneEnvironment=UnityEngine.Object.FindObjectsByType<EnvironmentRegionData>().Length==1,oneVegetationData=UnityEngine.Object.FindObjectsByType<VegetationRegionData>().Length==1,cameras=UnityEngine.Object.FindObjectsByType<Camera>().Length,playStopped=!EditorApplication.isPlaying,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("VegetationQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),fixedViewOverride=SessionState.GetBool("Roads02.FixedView",false),timeScale=Time.timeScale,background=InputSystem.settings.backgroundBehavior.ToString(),editorInput=InputSystem.settings.editorInputBehaviorInPlayMode.ToString()};
  Directory.CreateDirectory("Docs/Validation/ValdoriaWorldStudio06/Final");File.WriteAllText("Docs/Validation/ValdoriaWorldStudio06/Final/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
