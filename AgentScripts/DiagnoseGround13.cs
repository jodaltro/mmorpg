using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
public static class DiagnoseGround13
{
 static string PathOf(Transform t)=>t.parent?PathOf(t.parent)+"/"+t.name:t.name;
 public static object Main()
 {
  var rr=UnityEngine.Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();
  var rows=rr.Select(r=>new{path=PathOf(r.transform),type=r.GetType().Name,r.sortingLayerID,r.sortingOrder,material=r.sharedMaterial?AssetDatabase.GetAssetPath(r.sharedMaterial):null,texture=r is SpriteRenderer s&&s.sprite?AssetDatabase.GetAssetPath(s.sprite.texture):r.sharedMaterial&&r.sharedMaterial.mainTexture?AssetDatabase.GetAssetPath(r.sharedMaterial.mainTexture):null,mesh=r.GetComponent<MeshFilter>()?AssetDatabase.GetAssetPath(r.GetComponent<MeshFilter>().sharedMesh):null,vertices=r.GetComponent<MeshFilter>()?r.GetComponent<MeshFilter>().sharedMesh.vertexCount:-1,sortingGroup=r.GetComponentInParent<SortingGroup>()?PathOf(r.GetComponentInParent<SortingGroup>().transform):null});
  var result=new{scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,playing=EditorApplication.isPlaying,rendererCount=rr.Length,groups=rows.GroupBy(r=>new{r.type,r.material,r.texture}).Select(g=>new{g.Key,count=g.Count(),rows=g.Select(r=>r.sortingOrder).Distinct().Count(),vertices=g.Sum(r=>Math.Max(0,r.vertices))}),renderers=rows};Directory.CreateDirectory("Docs/Validation/ValdoriaGround13/QA");File.WriteAllText("Docs/Validation/ValdoriaGround13/QA/renderer-diagnosis.json",JsonConvert.SerializeObject(result,Formatting.Indented));return new{result.scene,result.rendererCount,result.groups};
 }
}
