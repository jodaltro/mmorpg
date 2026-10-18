using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
[InitializeOnLoad]
public static class GroundFinish11Importer
{
 public const string Source="ArtSource/Labs/World2026/Ground11/",Art="Assets/Mmorpg/Art/Experimental/ValdoriaGround11/",Scene="Assets/Mmorpg/Scenes/ValdoriaGroundFinishLab.unity",Court="Assets/Mmorpg/Scenes/ValdoriaSurfaceGrammarLab.unity";
 const string Pending="Ground11.Queued";
 static GroundFinish11Importer(){EditorApplication.update+=Tick;}
 public static object Queue(){if(File.Exists(Scene)||File.Exists(Court)||Directory.Exists(Art))throw new IOException("Refuse existing ground scene/art destination");if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Editor required");SessionState.SetBool(Pending,true);return "Queued import in persistent Editor callback; receipt Temp/Ground11-build.json";}
 static void Tick(){if(!SessionState.GetBool(Pending,false)||EditorApplication.isCompiling||EditorApplication.isUpdating)return;SessionState.SetBool(Pending,false);bool refresh=SessionState.GetBool("Ground11.Refresh",false);SessionState.SetBool("Ground11.Refresh",false);string receipt=refresh?"Temp/Ground11-paint-refresh.json":"Temp/Ground11-build.json";try{var result=refresh?RefreshPaint():Build();File.WriteAllText(receipt,JsonConvert.SerializeObject(new{success=true,result},Formatting.Indented));}catch(Exception e){File.WriteAllText(receipt,JsonConvert.SerializeObject(new{success=false,error=e.ToString()},Formatting.Indented));}}
 public static object QueuePaintRefresh(){var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(EditorApplication.isPlaying||scene.isDirty||(scene.path!=Scene&&scene.path!=Court))throw new IOException("Clean stopped Ground11 scene required");SessionState.SetBool("Ground11.Refresh",true);SessionState.SetBool(Pending,true);return "Queued explicit reimport of derived Ground11 pixels; geometry and approved objects preserved";}
 static object RefreshPaint()
 {
  foreach(string folder in new[]{"ExportV2/","WorldFinal/","CourtFinalV2/"})NatureReference10Importer.Verify(Source+folder);
  var paths=new List<string[]>();foreach(string family in new[]{"WorldFinal","CourtFinalV2"})foreach(string stage in family=="WorldFinal"?new[]{"base","transitions","final"}:new[]{"before","base","transitions","final"})
  {
   string path=Art+family+"-"+stage+".png";var texture=AssetDatabase.LoadAssetAtPath<Texture2D>(path);if(!texture||texture.width!=(family=="WorldFinal"?2048:1920)||texture.height!=(family=="WorldFinal"?1536:1200))throw new IOException("Explicit rebuild required for a changed texture domain");paths.Add(new[]{Source+family+"/"+stage+".png",path});
  }
  foreach(var pair in paths){File.Copy(pair[0],pair[1],true);AssetDatabase.ImportAsset(pair[1],ImportAssetOptions.ForceSynchronousImport);}AssetDatabase.SaveAssets();return new{changed="Derived material pixels only",geometryChanged=false};
 }
 static Texture2D Texture(string input,string name){string path=Art+name+".png";File.Copy(input,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Default;i.npotScale=TextureImporterNPOTScale.None;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.maxTextureSize=4096;i.isReadable=false;var p=i.GetDefaultPlatformTextureSettings();p.format=TextureImporterFormat.RGBA32;i.SetPlatformTextureSettings(p);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(path);}
 static Material Material(Material template,string folder,string stage){var m=new Material(template){name=folder+"-"+stage,mainTexture=Texture(Source+folder+"/"+stage+".png",folder+"-"+stage)};AssetDatabase.CreateAsset(m,Art+folder+"-"+stage+".mat");return m;}
 public static object Build()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty||Directory.Exists(Art)||File.Exists(Scene)||File.Exists(Court))throw new IOException("Refuse dirty/playing/existing destination");
  foreach(var folder in new[]{"ExportV2/","WorldFinal/","CourtFinalV2/"})NatureReference10Importer.Verify(Source+folder);Directory.CreateDirectory(Art);AssetDatabase.Refresh();
  var template=AssetDatabase.LoadAssetAtPath<Material>(NatureReference10Importer.Art+"Ground-final.mat");var wm=new[]{"base","transitions","final"}.Select(s=>Material(template,"WorldFinal",s)).ToArray();var cm=new[]{"before","base","transitions","final"}.Select(s=>Material(template,"CourtFinalV2",s)).ToArray();
  var scene=EditorSceneManager.OpenScene(NatureReference10Importer.Scene);EditorSceneManager.SaveScene(scene,Scene,true);scene=EditorSceneManager.OpenScene(Scene);var old=Object.FindAnyObjectByType<NatureReferenceLab>();old.Select(3);Object.DestroyImmediate(old.gameObject);var before=AssetDatabase.LoadAssetAtPath<Material>(NatureReference10Importer.Art+"Ground-final.mat");var bindings=Object.FindObjectsByType<MeshRenderer>().Where(r=>r.sharedMaterial==before).Select(r=>new GroundFinishLab.Surface{renderer=r,before=before,baseLayer=wm[0],transitions=wm[1],final=wm[2]}).ToArray();if(bindings.Length==0)throw new IOException("No authoritative ground mesh");
  var access=GameObject.Find("Reference pedestrian access").GetComponent<SpriteRenderer>();new GameObject("Ground finish - 1 before 2 base 3 banks 4 final").AddComponent<GroundFinishLab>().Configure(bindings,access);Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaGround11/IsolatedProfile");Camera.main.orthographicSize=14.0625f;Camera.main.transform.position=new Vector3(28.5f,14.25f,-10);EditorSceneManager.SaveScene(scene);
  var court=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);var ground=new GameObject("Noncanonical material grammar - no world collision or navigation");var mesh=new Mesh{name="Surface grammar plane 32px per unit"};mesh.vertices=new[]{new Vector3(0,0),new Vector3(60,0),new Vector3(60,37.5f),new Vector3(0,37.5f)};mesh.uv=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(1,1),new Vector2(0,1)};mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,Art+"GrammarPlane.asset");ground.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=ground.AddComponent<MeshRenderer>();renderer.sharedMaterial=cm[3];new GameObject("Same surface components - comparison").AddComponent<GroundFinishLab>().Configure(new[]{new GroundFinishLab.Surface{renderer=renderer,before=cm[0],baseLayer=cm[1],transitions=cm[2],final=cm[3]}},null);var camera=new GameObject("Main Camera").AddComponent<Camera>();camera.tag="MainCamera";camera.orthographic=true;camera.orthographicSize=20;camera.transform.position=new Vector3(30,18.75f,-10);camera.backgroundColor=new Color(.15f,.19f,.14f);camera.clearFlags=CameraClearFlags.SolidColor;EditorSceneManager.SaveScene(court,Court);AssetDatabase.SaveAssets();EditorSceneManager.OpenScene(Scene);return new{scene=Scene,court=Court,groundMeshes=bindings.Length,geometryChanged=false,approvedObjectsRepainted=false};
 }
}
