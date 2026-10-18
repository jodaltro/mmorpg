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
public static class InspectArtisticTerrain04
{
 const string Art="Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/";
 static string Collision(TerrainRegionData data)=>JsonConvert.SerializeObject(data.GetComponentsInChildren<BoxCollider2D>(true).Select(c=>new{position=c.transform.position.ToString("F6"),offset=c.offset.ToString("F6"),size=c.size.ToString("F6"),layer=c.gameObject.layer,trigger=c.isTrigger,enabled=c.enabled}).OrderBy(x=>JsonConvert.SerializeObject(x)));
 static object[] TextureStats(IEnumerable<Material> materials)=>materials.Select(m=>m.mainTexture).OfType<Texture2D>().Where(t=>!string.IsNullOrEmpty(AssetDatabase.GetAssetPath(t))).Distinct().Select(t=>(object)new{path=AssetDatabase.GetAssetPath(t),t.width,t.height,format=t.format.ToString(),point=t.filterMode==FilterMode.Point,mips=t.mipmapCount,memoryBytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)}).ToArray();
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();string scenePath=scene.path;
  var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();var so=new SerializedObject(lab);var current=(GameObject)so.FindProperty("generatedVisuals").objectReferenceValue;var previous=(GameObject)so.FindProperty("previousVisuals").GetArrayElementAtIndex(0).objectReferenceValue;
  var currentMeshes=current.GetComponentsInChildren<MeshFilter>().Select(f=>AssetDatabase.GetAssetPath(f.sharedMesh)).OrderBy(x=>x).ToArray();var beforeMeshes=previous.GetComponentsInChildren<MeshFilter>(true).Select(f=>AssetDatabase.GetAssetPath(f.sharedMesh)).OrderBy(x=>x).ToArray();bool sharedMeshIdentity=currentMeshes.SequenceEqual(beforeMeshes);
  var mats=current.GetComponentsInChildren<Renderer>(true).Concat(previous.GetComponentsInChildren<Renderer>(true)).SelectMany(r=>r.sharedMaterials).ToList();
  for(int i=0;i<9;i++)mats.Add((Material)so.FindProperty("stageMaterials").GetArrayElementAtIndex(i).objectReferenceValue);
  var labTextures=TextureStats(mats);var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(Art+"FinalOnlyVisuals-A.prefab");var productionTextures=TextureStats(prefab.GetComponentsInChildren<Renderer>(true).SelectMany(r=>r.sharedMaterials));
  var dependencies=AssetDatabase.GetDependencies(Art+"FinalOnlyVisuals-A.prefab",true).Where(p=>p.EndsWith(".png",StringComparison.OrdinalIgnoreCase)).OrderBy(p=>p).ToArray();
  bool noBaselineOrUnused=dependencies.Length==2&&dependencies.All(p=>p.StartsWith(Art))&&dependencies.All(p=>!p.Contains("B-final")&&!p.Contains("C-final"));
  int newColliders=current.GetComponentsInChildren<Collider2D>(true).Length;int rendererCount=current.GetComponentsInChildren<Renderer>(true).Length;var data=UnityEngine.Object.FindAnyObjectByType<TerrainRegionData>();var collision=Collision(data);bool unchanged=false;
  var reference=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaOrganicMaterialsLab.unity",OpenSceneMode.Additive);
  try{var old=reference.GetRootGameObjects().SelectMany(g=>g.GetComponentsInChildren<TerrainRegionData>(true)).Single();unchanged=collision==Collision(old)&&data.WorldRegion.text==old.WorldRegion.text;}finally{EditorSceneManager.CloseScene(reference,true);UnityEngine.SceneManagement.SceneManager.SetActiveScene(scene);}
  bool refused=false;string reason=null;EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ValdoriaOrganicMaterialsLab.unity");
  try{OrganicRoadStudioImporter.BuildRefinement();}catch(IOException e){reason=e.Message;refused=reason.Contains("Refuse existing");}finally{EditorSceneManager.OpenScene(scenePath);}
  var result=new{scene=scenePath,sceneClean=!UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,sharedMeshIdentity,meshCount=currentMeshes.Length,topographyAndCollisionsUnchanged=unchanged,collisionBoxes=JsonConvert.DeserializeObject<object[]>(collision).Length,newVisualColliders=newColliders,renderers=rendererCount,labTextures,productionTextures,productionDependencies=dependencies,productionExcludesComparisonAssets=noBaselineOrUnused,productionHasNoController=prefab.GetComponent<TerrainMaterialLabController>()==null,productionHasNoColliders=prefab.GetComponentsInChildren<Collider2D>(true).Length==0,destinationRefused=refused,reason,onePlayer=UnityEngine.Object.FindObjectsByType<PlayerController>().Length==1,oneTerrain=UnityEngine.Object.FindObjectsByType<TerrainRegionData>().Length==1,cameras=UnityEngine.Object.FindObjectsByType<Camera>().Length,playStopped=!EditorApplication.isPlaying,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("ArtisticMaterialsQA")||d.name.Contains("ArtisticContactQA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),background=InputSystem.settings.backgroundBehavior.ToString(),editorInput=InputSystem.settings.editorInputBehaviorInPlayMode.ToString(),profileOverride=LocalJourneyProfile.ValidationRootOverride,fixedViewOverride=SessionState.GetBool("Roads02.FixedView",false),timeScale=Time.timeScale};
  File.WriteAllText("Docs/Validation/ValdoriaWorldStudio04/Final/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
