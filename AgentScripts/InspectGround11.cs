using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using Newtonsoft.Json;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class InspectGround11
{
 static string Hash(string value){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(System.Text.Encoding.UTF8.GetBytes(value))).Replace("-","").ToLowerInvariant();}
 static string Hierarchy(Transform t)=>t.parent?Hierarchy(t.parent)+"/"+t.name:t.name;
 static string Colliders()=>JsonConvert.SerializeObject(Object.FindObjectsByType<Collider2D>().Where(c=>c.enabled&&c.gameObject.activeInHierarchy).OrderBy(c=>Hierarchy(c.transform)).Select(c=>new{path=Hierarchy(c.transform),type=c.GetType().Name,position=new[]{c.transform.position.x,c.transform.position.y,c.transform.position.z},scale=new[]{c.transform.lossyScale.x,c.transform.lossyScale.y},layer=c.gameObject.layer,c.isTrigger,offset=new[]{c.offset.x,c.offset.y},radius=c is CircleCollider2D circle?circle.radius:0,box=c is BoxCollider2D box?new[]{box.size.x,box.size.y}:null,paths=c is PolygonCollider2D poly?Enumerable.Range(0,poly.pathCount).Select(i=>poly.GetPath(i).Select(p=>new[]{p.x,p.y}).ToArray()).ToArray():null}));
 static string Navigation(){var n=Object.FindAnyObjectByType<ArchitectureRegionData>();return string.Concat(Enumerable.Range(0,n.Width*n.Height).Select(i=>n.CellWalkable(i%n.Width,i/n.Width)?'1':'0'));}
 static string ColliderSignature()=>string.Join("\n",Newtonsoft.Json.Linq.JArray.Parse(Colliders()).Select(t=>t.ToString(Formatting.None)).OrderBy(s=>s,StringComparer.Ordinal));
 static int NavMismatch(){var n=Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int m=0;for(int y=0;y<n.Height;y++)for(int x=0;x<n.Width;x++)if((Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f),1<<8)!=null)==n.CellWalkable(x,y))m++;return m;}
 public static object Baseline()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped scene required");EditorSceneManager.OpenScene(NatureReference10Importer.Scene);Object.FindAnyObjectByType<NatureReferenceLab>().Select(3);File.WriteAllText("Temp/Ground11-colliders-baseline.json",Colliders());var d=new{colliders=Hash(ColliderSignature()),navigation=Hash(Navigation()),count=Object.FindObjectsByType<Collider2D>().Count(c=>c.enabled&&c.gameObject.activeInHierarchy)};File.WriteAllText("Temp/Ground11-physics-baseline.json",JsonConvert.SerializeObject(d));EditorSceneManager.OpenScene(GroundFinish11Importer.Scene);return d;
 }
 public static object Main()
 {
  var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(EditorApplication.isPlaying||scene.path!=GroundFinish11Importer.Scene||scene.isDirty)throw new IOException("Clean stopped Ground11 scene required");foreach(string folder in new[]{"ExportV2/","WorldFinal/","CourtFinalV2/"})NatureReference10Importer.Verify(GroundFinish11Importer.Source+folder);
  File.WriteAllText("Temp/Ground11-colliders-current.json",Colliders());var baseline=Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText("Temp/Ground11-physics-baseline.json"));var lab=Object.FindAnyObjectByType<GroundFinishLab>();var rows=new List<object>();int initial=lab.Stage;
  for(int i=0;i<4;i++){lab.Select(i);rows.Add(new{stage=i,samples=49152,mismatch=NavMismatch(),colliderHash=Hash(ColliderSignature()),navigationHash=Hash(Navigation()),sameColliders=Hash(ColliderSignature())==(string)baseline["colliders"],sameNavigation=Hash(Navigation())==(string)baseline["navigation"]});}lab.Select(initial);
  var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{GroundFinish11Importer.Art.TrimEnd('/')}).Select(g=>AssetDatabase.GUIDToAssetPath(g)).Select(p=>new{path=p,importer=(TextureImporter)AssetImporter.GetAtPath(p)}).ToArray();var allTextures=EditorUtility.CollectDependencies(scene.GetRootGameObjects().Cast<Object>().ToArray()).OfType<Texture2D>().Distinct().ToArray();
  var result=new{scene=scene.path,stages=rows,onePlayer=Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=Object.FindObjectsByType<Camera>().Length==1,profileOverride=LocalJourneyProfile.ValidationRootOverride,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("Ground11QA")),allKeyboardsEnabled=InputSystem.devices.OfType<Keyboard>().All(k=>k.enabled),timeScale=Time.timeScale,playing=EditorApplication.isPlaying,resolutionOverride=SessionState.GetBool("Nature10.FixedView",false),comparisonResidentTextureBytes=allTextures.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)),textures=textures.Select(t=>new{t.path,point=t.importer.filterMode==FilterMode.Point,mips=t.importer.mipmapEnabled,uncompressed=t.importer.textureCompression==TextureImporterCompression.Uncompressed})};
  File.WriteAllText("Docs/Validation/ValdoriaGround11/editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
