using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using Mmorpg.Runtime;
public static class ValidateGround12Prefabs
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stopped Editor required");var rows=new System.Collections.Generic.List<object>();
  foreach(string id in new[]{"elm-vase","hornbeam-open","hazel-layered","reeds-open","fern-0","fern-1"})
  {
   string path=EnvironmentFinish12Importer.Art+id+".prefab";var root=PrefabUtility.LoadPrefabContents(path);
   try{if(id!="elm-vase"&&id!="hornbeam-open"){var shadow=root.transform.Find("shadow");if(shadow)UnityEngine.Object.DestroyImmediate(shadow.gameObject);PrefabUtility.SaveAsPrefabAsset(root,path);}rows.Add(new{id,colliders=root.GetComponentsInChildren<Collider2D>(true).Length,bodySprites=root.GetComponentsInChildren<SpriteRenderer>(true).Count(s=>s.name=="crown"),depth=root.GetComponent<PlantVisualDepth>()!=null});}finally{PrefabUtility.UnloadPrefabContents(root);}
  }
  File.WriteAllText("Docs/Validation/ValdoriaGround12/QA/prefabs.json",JsonConvert.SerializeObject(rows,Formatting.Indented));return rows;
 }
}
