using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
public static class RefineGround13Meshes
{
 public static object Main()
 {
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Ground13Importer.Scene)throw new IOException("Stopped Ground13 scene required");
  var groups=JObject.Parse(File.ReadAllText(Ground13Importer.Source+"ReliefV3/visual-relief.json"))["groups"].ToDictionary(g=>"Strata_"+(int)g["row"]+"_"+(string)g["kind"]);
  int updated=0,empty=0;
  foreach(var f in UnityEngine.Object.FindObjectsByType<MeshFilter>().Where(f=>f.name.StartsWith("Strata_")))
  {
   var mesh=f.sharedMesh;mesh.Clear();
   if(groups.TryGetValue(f.name,out var g)){
    mesh.SetVertices(g["vertices"].Select(v=>new Vector3((float)v[0],(float)v[1],(float)v[2])).ToList());
    mesh.SetUVs(0,g["uv"].Select(v=>new Vector2((float)v[0],(float)v[1])).ToList());
    mesh.SetColors(g["colors"].Select(v=>new Color((float)v[0],(float)v[1],(float)v[2],(float)v[3])).ToList());
    mesh.SetTriangles(g["triangles"].Select(v=>(int)v).ToArray(),0);mesh.RecalculateBounds();updated++;
   }else{f.GetComponent<Renderer>().enabled=false;empty++;}
   EditorUtility.SetDirty(mesh);
  }
  AssetDatabase.SaveAssets();EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());return new{updated,empty,physicalChange=false};
 }
}
