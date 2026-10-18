using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class InspectGround12
{
 public static object Main()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped scene required");
  var result=new {scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,roots=UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects().Select(g=>new{g.name,active=g.activeSelf,anchors=g.GetComponentsInChildren<VegetationAnchor>(true).Length}),renderers=Object.FindObjectsByType<Renderer>().Select(r=>new{r.name,type=r.GetType().Name,material=r.sharedMaterial?AssetDatabase.GetAssetPath(r.sharedMaterial):null,texture=r.sharedMaterial&&r.sharedMaterial.mainTexture?AssetDatabase.GetAssetPath(r.sharedMaterial.mainTexture):null,bounds=r.bounds.ToString(),mesh=r is MeshRenderer?AssetDatabase.GetAssetPath(r.GetComponent<MeshFilter>().sharedMesh):null}),plants=Object.FindObjectsByType<VegetationAnchor>().Select(v=>new{v.InstanceId,v.name,position=v.transform.position.ToString()})};
  Directory.CreateDirectory("Docs/Validation/ValdoriaGround12/QA");File.WriteAllText("Docs/Validation/ValdoriaGround12/QA/initial-scene.json",JsonConvert.SerializeObject(result,Formatting.Indented));return new{saved=true,scene=result.scene,plants=result.plants.Count(),renderers=result.renderers.Count()};
 }
}
