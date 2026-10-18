using System;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
public static class RepairArchitectureModelColliders
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new Exception("Stop Play");var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(scene.path!="Assets/Mmorpg/Scenes/ValdoriaCastleLab.unity"||scene.isDirty)throw new Exception("Clean castle study only");
  var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();var data=JObject.Parse(UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>().Source.text);float height=(float)data["sizeUnits"][1];foreach(var c in house.GetComponents<PolygonCollider2D>())UnityEngine.Object.DestroyImmediate(c);foreach(var polygon in data["footprints"])house.gameObject.AddComponent<PolygonCollider2D>().SetPath(0,polygon.Select(p=>new Vector2((float)p[0],height-(float)p[1])-(Vector2)house.transform.position).ToArray());Physics2D.SyncTransforms();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return house.GetComponents<PolygonCollider2D>().Length;
 }
}
