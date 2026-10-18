using System;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
public static class FinishArtisticMaterials04
{
 public static object Main()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");string destination="Assets/Mmorpg/Art/Experimental/ValdoriaArtisticTerrain04/AuthoredFinish/";if(Directory.Exists(destination))throw new IOException("Refuse pixel finish overwrite");Directory.CreateDirectory(destination);AssetDatabase.Refresh();
  OrganicRoadStudioImporter.VerifyRefinementArtifacts();var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();var so=new SerializedObject(lab);var import=typeof(OrganicRoadStudioImporter).GetMethod("ImportMaterialTexture",BindingFlags.Static|BindingFlags.NonPublic);
  for(int i=0;i<3;i++)
  {
   string style="ABC"[i].ToString();var texture=(Texture2D)import.Invoke(null,new object[]{"ArtSource/Labs/World2026/WorldStudio04/BuildR6/"+style+"/final-atlas.png",destination+style+"-final-atlas.png"});var mat=(Material)so.FindProperty("stageMaterials").GetArrayElementAtIndex(i*3+2).objectReferenceValue;mat.mainTexture=texture;EditorUtility.SetDirty(mat);
  }
  var faceTexture=(Texture2D)import.Invoke(null,new object[]{"ArtSource/Labs/World2026/WorldStudio04/BuildR6/A/cliff-atlas.png",destination+"cliff-atlas.png"});var face=(Material)so.FindProperty("faceMaterials").GetArrayElementAtIndex(2).objectReferenceValue;face.mainTexture=faceTexture;EditorUtility.SetDirty(face);
  File.Copy("ArtSource/Labs/World2026/WorldStudio04/BuildR6/A/composition.json",destination+"composition.json");AssetDatabase.ImportAsset(destination+"composition.json");so.FindProperty("composition").objectReferenceValue=AssetDatabase.LoadAssetAtPath<TextAsset>(destination+"composition.json");so.ApplyModifiedPropertiesWithoutUndo();
  lab.Select(0,2);lab.ResetPose();AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());return new{surfaceTextures=3,sharedFaceTexture=1,meshesAndPhysicsChanged=false,revision="AuthoredFinish"};
 }
}
