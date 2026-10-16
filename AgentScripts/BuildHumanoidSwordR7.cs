using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
public static class BuildHumanoidSwordR7
{
 const string Scene="Assets/Mmorpg/Scenes/HumanoidSwordR7.unity",Art="Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/";
 public static string Create(){
 if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||File.Exists(Scene))throw new Exception("Clean stopped scene and unused R7 path required");
 if(!(bool)JObject.Parse(File.ReadAllText("Docs/Validation/HumanoidSwordR7/near-gate.json"))["passed"])throw new Exception("Near physical gate required");
 Directory.CreateDirectory(Art);AssetDatabase.Refresh();
 if(!AssetDatabase.CopyAsset("Assets/Mmorpg/Art/Experimental/HumanoidCombat8Dir2026/ValdoriaCombatCandidate.asset",Art+"ValdoriaSwordR7.asset"))throw new Exception("Copy failed");
 var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaSwordR7.asset");set.characterId="quaternius-r7-planar-sword-attack-hurt";foreach(var c in set.clips)c.status="r7-technical-candidate-artistic-review-pending";EditorUtility.SetDirty(set);AssetDatabase.SaveAssets();
 if(!AssetDatabase.CopyAsset("Assets/Mmorpg/Scenes/HumanoidCombat8Dir2026.unity",Scene))throw new Exception("Scene copy failed");EditorSceneManager.OpenScene(Scene);
 set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaSwordR7.asset");var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();var so=new SerializedObject(animator);so.FindProperty("art").objectReferenceValue=set;so.ApplyModifiedPropertiesWithoutUndo();
 animator.GetComponent<SwordSwing>().ConfigureSweepOrigin(SwordSwing.SweepOriginPolicy.PlanarSweepOrigin);animator.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.SetActive(true);
 EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());
 var scenes=EditorBuildSettings.globalScenes.ToList();if(scenes[0].path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity")throw new Exception("Entry changed");scenes.Add(new EditorBuildSettingsScene(Scene,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();EditorUtility.SetDirty(Resources.FindObjectsOfTypeAll<EditorBuildSettings>()[0]);EditorApplication.ExecuteMenuItem("File/Save Project");return "R7 created after near gate; immutable R6 sprites reused; sword active; only R7 opts into planar policy.";
 }
}
