using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class InspectEnvironment12
{
 const string Output="Docs/Validation/ValdoriaGround12/QA/";
 static string Hash(object o){using(var h=System.Security.Cryptography.SHA256.Create())return BitConverter.ToString(h.ComputeHash(System.Text.Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(o)))).Replace("-","").ToLowerInvariant();}
 static string PathOf(Transform t)=>t.parent?PathOf(t.parent)+"/"+t.name:t.name;
 static object Geometry()=>Object.FindObjectsByType<Collider2D>().Where(c=>c.enabled&&c.gameObject.activeInHierarchy).OrderBy(c=>PathOf(c.transform)).Select(c=>new{path=PathOf(c.transform),type=c.GetType().Name,pos=c.transform.position.ToString("R"),scale=c.transform.lossyScale.ToString("R"),c.isTrigger,layer=c.gameObject.layer,offset=c.offset.ToString("R"),radius=c is CircleCollider2D circle?circle.radius:0,box=c is BoxCollider2D box?box.size.ToString("R"):null,paths=c is PolygonCollider2D p?Enumerable.Range(0,p.pathCount).Select(i=>p.GetPath(i).Select(v=>v.ToString("R")).ToArray()).ToArray():null}).ToArray();
 static string Nav(){var n=Object.FindAnyObjectByType<ArchitectureRegionData>();return string.Concat(Enumerable.Range(0,n.Width*n.Height).Select(i=>n.CellWalkable(i%n.Width,i/n.Width)?'1':'0'));}
 static object Plants()=>Object.FindObjectsByType<VegetationAnchor>().OrderBy(a=>a.InstanceId).Select(a=>new{a.InstanceId,a.Species,a.Variant,a.FootprintRadius,position=a.transform.position.ToString("R")}).ToArray();
 static object Relief()=>Object.FindObjectsByType<MeshFilter>().Where(f=>f.name.StartsWith("Continuous")).OrderBy(f=>f.name).Select(f=>new{f.name,mesh=AssetDatabase.GetAssetPath(f.sharedMesh),vertices=Hash(f.sharedMesh.vertices.Select(v=>v.ToString("R")).ToArray()),uv=Hash(f.sharedMesh.uv.Select(v=>v.ToString("R")).ToArray()),indices=Hash(f.sharedMesh.triangles)}).ToArray();
 static object Snapshot()=>new{colliders=Hash(JArray.FromObject(Geometry()).Select(v=>v.ToString(Formatting.None)).OrderBy(v=>v,StringComparer.Ordinal).ToArray()),navigation=Hash(Nav()),plants=Hash(Plants()),relief=Hash(Relief()),colliderCount=Object.FindObjectsByType<Collider2D>().Count(c=>c.enabled&&c.gameObject.activeInHierarchy)};
 public static object Baseline(){if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped Editor required");var s=Snapshot();File.WriteAllText(Output+"physics-baseline.json",JsonConvert.SerializeObject(s,Formatting.Indented));return s;}
 public static object Main()
 {
  if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=EnvironmentFinish12Importer.Scene)throw new IOException("Stopped Ground12 required");var baseline=JObject.Parse(File.ReadAllText(Output+"physics-baseline.json"));var lab=Object.FindAnyObjectByType<EnvironmentFinishLab>();var stages=new List<object>();
  foreach(bool refined in new[]{false,true}){lab.Select(refined);var s=JObject.FromObject(Snapshot());var nav=Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int mismatch=0;for(int y=0;y<nav.Height;y++)for(int x=0;x<nav.Width;x++)if((Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f),1<<8)!=null)==nav.CellWalkable(x,y))mismatch++;stages.Add(new{refined,snapshot=s,sameColliders=(string)s["colliders"]==(string)baseline["colliders"],sameNavigation=(string)s["navigation"]==(string)baseline["navigation"],samePlantAnchors=(string)s["plants"]==(string)baseline["plants"],sameReliefMeshUVs=(string)s["relief"]==(string)baseline["relief"],samples=nav.Width*nav.Height,mismatch});}lab.Select(true);
  var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{EnvironmentFinish12Importer.Art.TrimEnd('/')}).Select(AssetDatabase.GUIDToAssetPath).Select(p=>new{path=p,settings=(TextureImporter)AssetImporter.GetAtPath(p)});
  var result=new{stages,onePlayer=Object.FindObjectsByType<PlayerController>().Length==1,oneCamera=Object.FindObjectsByType<Camera>().Length==1,profile=LocalJourneyProfile.ValidationRootOverride,playing=EditorApplication.isPlaying,syntheticDevices=InputSystem.devices.Count(d=>d.name.Contains("Ground12QA")),fixedResolution=SessionState.GetBool("Nature10.FixedView",false),textures=textures.Select(t=>new{t.path,point=t.settings.filterMode==FilterMode.Point,noMips=!t.settings.mipmapEnabled,uncompressed=t.settings.textureCompression==TextureImporterCompression.Uncompressed,ppu=t.settings.spritePixelsPerUnit})};File.WriteAllText(Output+"editor-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));return result;
 }
}
