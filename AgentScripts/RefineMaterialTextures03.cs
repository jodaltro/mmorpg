using System;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
public static class RefineMaterialTextures03
{
 public static object Run()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");
  string destination="Assets/Mmorpg/Art/Experimental/ValdoriaOrganicMaterials03/TextureRevision/";if(Directory.Exists(destination))throw new IOException("Refuse material texture revision overwrite");
  Directory.CreateDirectory(destination);AssetDatabase.Refresh();var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();var so=new SerializedObject(lab);
  var import=typeof(OrganicRoadStudioImporter).GetMethod("ImportMaterialTexture",BindingFlags.Static|BindingFlags.NonPublic);int index=0;
  foreach(string style in new[]{"A","B","C"})foreach(string stage in new[]{"base","transitions","final"})
  {
   var texture=(Texture2D)import.Invoke(null,new object[]{"ArtSource/Labs/World2026/WorldStudio03/BuildR7/"+style+"/"+stage+"-atlas.png",destination+style+"-"+stage+"-atlas.png"});
   var material=(Material)so.FindProperty("stageMaterials").GetArrayElementAtIndex(index++).objectReferenceValue;material.mainTexture=texture;EditorUtility.SetDirty(material);
  }
  File.Copy("ArtSource/Labs/World2026/WorldStudio03/BuildR7/A/composition.json",destination+"composition.json");AssetDatabase.ImportAsset(destination+"composition.json",ImportAssetOptions.ForceSynchronousImport);so.FindProperty("composition").objectReferenceValue=AssetDatabase.LoadAssetAtPath<TextAsset>(destination+"composition.json");so.ApplyModifiedPropertiesWithoutUndo();
  lab.Select(0,2);lab.ResetPose();EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());AssetDatabase.SaveAssets();return new{textures=index,geometryChanged=false,source="BuildR7"};
 }
}
