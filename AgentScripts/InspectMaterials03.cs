using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class InspectMaterials03
{
 static string Collision(TerrainRegionData data)=>JsonConvert.SerializeObject(data.GetComponentsInChildren<BoxCollider2D>(true).Select(c=>new{position=c.transform.position.ToString("F6"),offset=c.offset.ToString("F6"),size=c.size.ToString("F6"),layer=c.gameObject.layer,trigger=c.isTrigger,enabled=c.enabled}).OrderBy(x=>JsonConvert.SerializeObject(x)));
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new Exception("Stop Play first");var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();string scenePath=scene.path;var data=UnityEngine.Object.FindAnyObjectByType<TerrainRegionData>();var current=Collision(data);
  bool same=false;var baseline=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaOrganicRoadsLab.unity",OpenSceneMode.Additive);
  try {var old=baseline.GetRootGameObjects().SelectMany(g=>g.GetComponentsInChildren<TerrainRegionData>(true)).Single();same=current==Collision(old)&&data.WorldRegion.text==old.WorldRegion.text;}
  finally {EditorSceneManager.CloseScene(baseline,true);UnityEngine.SceneManagement.SceneManager.SetActiveScene(scene);}
  var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();var so=new SerializedObject(lab);var mats=Enumerable.Range(0,9).Select(i=>(Material)so.FindProperty("stageMaterials").GetArrayElementAtIndex(i).objectReferenceValue).ToArray();
  var face=Enumerable.Range(0,9).Select(i=>(Material)so.FindProperty("faceMaterials").GetArrayElementAtIndex(i).objectReferenceValue).ToArray();
  var textures=mats.Concat(face).Select(m=>m.mainTexture).OfType<Texture2D>().Where(t=>AssetDatabase.GetAssetPath(t).StartsWith("Assets/Mmorpg/Art/Experimental/ValdoriaOrganicMaterials03/")).Distinct().ToArray();
  var generated=(GameObject)so.FindProperty("generatedVisuals").objectReferenceValue;
  int visualColliders=generated.GetComponentsInChildren<Collider2D>(true).Length;int rendererCount=generated.GetComponentsInChildren<MeshRenderer>(true).Length;
  bool refused=false;string reason=null;
  var sourceScene=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaOrganicRoadsLab.unity");
  try{OrganicRoadStudioImporter.BuildMaterials();}catch(IOException e){reason=e.Message;refused=reason.Contains("Refuse existing");}
  finally{EditorSceneManager.OpenScene(scenePath);}
  var result=new{scene=scenePath,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,topographyAndCollidersUnchanged=same,terrainColliders=JsonConvert.DeserializeObject<object[]>(current).Length,oneTerrain=UnityEngine.Object.FindObjectsByType<TerrainRegionData>().Length==1,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,cameras=UnityEngine.Object.FindObjectsByType<Camera>().Length,newVisualColliders=visualColliders,renderers=rendererCount,textures=textures.Select(t=>new{path=AssetDatabase.GetAssetPath(t),t.width,t.height,format=t.format.ToString(),point=t.filterMode==FilterMode.Point,mips=t.mipmapCount,runtimeMemoryBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)}).ToArray(),destinationRefused=refused,reason,playStopped=!EditorApplication.isPlaying,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("MaterialsQA")||d.name.Contains("MaterialContactQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),background=InputSystem.settings.backgroundBehavior.ToString(),editorInput=InputSystem.settings.editorInputBehaviorInPlayMode.ToString(),profileOverride=LocalJourneyProfile.ValidationRootOverride,fixedViewOverride=SessionState.GetBool("Roads02.FixedView",false),timeScale=Time.timeScale};
  File.WriteAllText("Docs/Validation/ValdoriaWorldStudio03/Final/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
