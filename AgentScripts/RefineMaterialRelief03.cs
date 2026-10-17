using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
public static class RefineMaterialRelief03
{
 public static object Run()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();var so=new SerializedObject(lab);var root=((GameObject)so.FindProperty("generatedVisuals").objectReferenceValue);
  string dest="Assets/Mmorpg/Art/Experimental/ValdoriaOrganicMaterials03/GroupedRelief";
  if(Directory.Exists(dest))throw new IOException("Refuse grouped relief overwrite");
  var old=root.GetComponentsInChildren<MeshRenderer>().Where(r=>r.name.StartsWith("ContinuousTop_")||r.name.StartsWith("ContinuousFace_")).ToArray();
  var ground=root.GetComponentsInChildren<MeshRenderer>().First(r=>r.name.StartsWith("Surface -"));
  var field=JObject.Parse(File.ReadAllText("ArtSource/Labs/World2026/WorldStudio03/BuildR5/A/relief-field.json"));
  var built=TerrainReliefBuilder.AddContinuous(root,field,dest,ground.sharedMaterial,AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/Experimental/ValdoriaOrganicMaterials03/DetailedFace.mat"));
  var tops=new[]{ground}.Concat(built.tops).ToArray();var a=so.FindProperty("surfaces");a.arraySize=tops.Length;for(int i=0;i<tops.Length;i++)a.GetArrayElementAtIndex(i).objectReferenceValue=tops[i];
  var b=so.FindProperty("faces");b.arraySize=built.faces.Length;for(int i=0;i<built.faces.Length;i++)b.GetArrayElementAtIndex(i).objectReferenceValue=built.faces[i];so.ApplyModifiedPropertiesWithoutUndo();
  foreach(var r in old)UnityEngine.Object.DestroyImmediate(r.gameObject);lab.Select(0,2);EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());AssetDatabase.SaveAssets();return new{previous=old.Length,now=built.tops.Length+built.faces.Length,tops=built.tops.Length,faces=built.faces.Length};
 }
}
