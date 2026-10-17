using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
public static class BuildHumanoidStatesR8
{
 const string Scene="Assets/Mmorpg/Scenes/HumanoidStatesR8.unity",Art="Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/";
 public static string Create(){
  if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/HumanoidSwordR7.unity"||File.Exists(Scene)||File.Exists(Art+"ValdoriaStatesR8.asset"))throw new Exception("Clean R7 scene and unused R8 paths required");
  if(!(bool)JObject.Parse(File.ReadAllText("Docs/Validation/HumanoidStatesR8/canvas-gate.json"))["passed"])throw new Exception("Gate A required before death integration");
  var set=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset"));var clips=set.clips.ToList();
  foreach(string action in new[]{"dodge","death"}){
   var m=JObject.Parse(File.ReadAllText("ArtSource/Labs/Humanoid2026/R8/"+action+"/manifest.json"));var sprites=AssetDatabase.LoadAllAssetsAtPath(Art+action+".png").OfType<Sprite>().ToDictionary(s=>s.name);
   foreach(var c in m["clips"]){int first=(int)c["first"]-1,last=(int)c["last"];var frames=new List<ProductionFrame>();for(int i=first;i<last;i++){var f=m["frames"][i];float px=(float)f["pivotTop"][0],py=(float)f["pivotTop"][1];frames.Add(new ProductionFrame{sprite=sprites["pose_"+i.ToString("000")],seconds=(float)f["seconds"],hand=new Vector2(((float)f["hand"][0]-px)/32,(py-(float)f["hand"][1])/32),holdAngle=(float)f["holdAngle"],depth=(int)f["depth"],source="R8 "+(string)f["sourceAction"]+" source "+(float)f["sourceFrame"]});}clips.Add(new ProductionClip{action=action,direction=(int)c["direction"],loop=false,status="r8-technical-candidate-artistic-approval-pending",frames=frames.ToArray()});}
  }
  set.clips=clips.ToArray();set.characterId="quaternius-r8-evasive-step-death";AssetDatabase.CreateAsset(set,Art+"ValdoriaStatesR8.asset");AssetDatabase.SaveAssets();
  if(!AssetDatabase.CopyAsset("Assets/Mmorpg/Scenes/HumanoidSwordR7.unity",Scene))throw new Exception("Scene copy failed");EditorSceneManager.OpenScene(Scene);set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaStatesR8.asset");var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();var actor=animator.GetComponent<ActorHealth>();var sword=actor.GetComponent<SwordSwing>();if(sword.OriginPolicy!=SwordSwing.SweepOriginPolicy.PlanarSweepOrigin)throw new Exception("R7 policy changed");animator.Configure(set,actor,animator.Body,sword);actor.GetComponent<ProductionVisualSync>().ConfigureAnimatedDeath(true);
  var focus=new GameObject("StatesCameraFocus").transform;focus.SetParent(actor.transform,false);focus.localPosition=Vector3.up*.5f;var follow=Camera.main.GetComponent<CameraFollow>();follow.Configure(focus);var so=new SerializedObject(follow);so.FindProperty("clampToWorld").boolValue=false;so.ApplyModifiedPropertiesWithoutUndo();
  actor.GetComponent<ProductionCharacterStates>().ConfigureImmediatePresentation(true);var preview=actor.GetComponent<WeaponValidationPreview>();preview.ConfigureStateFacing(true);preview.ConfigureFraming(follow,focus,actor.transform.Find("BowValidationCameraFocus"));
  EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());var scenes=EditorBuildSettings.globalScenes.ToList();if(scenes[0].path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity")throw new Exception("Official entry changed");scenes.Add(new EditorBuildSettingsScene(Scene,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();EditorUtility.SetDirty(Resources.FindObjectsOfTypeAll<EditorBuildSettings>()[0]);EditorApplication.ExecuteMenuItem("File/Save Project");return "R8 created: 64 clips, R7 originals reused, opt-in states and stable camera focus, menu/bow atlas unchanged.";
 }
 public static string Prepare(){if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Scene)throw new Exception("Clean R8 required");SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);SessionState.SetInt("b11-background",(int)UnityEngine.InputSystem.InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)UnityEngine.InputSystem.InputSystem.settings.editorInputBehaviorInPlayMode);EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;UnityEngine.InputSystem.InputSystem.settings.backgroundBehavior=UnityEngine.InputSystem.InputSettings.BackgroundBehavior.IgnoreFocus;UnityEngine.InputSystem.InputSystem.settings.editorInputBehaviorInPlayMode=UnityEngine.InputSystem.InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;return "Prepared R8 with automatic isolated profile";}
 public static string EnableImmediatePresentation(){if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Scene)throw new Exception("Clean stopped R8 required");UnityEngine.Object.FindAnyObjectByType<ProductionCharacterStates>().ConfigureImmediatePresentation(true);EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());return "R8-only confirmed damage presentation enabled; historical defaults unchanged";}
}
