using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;
public static class HydrologyStudioImporter
{
 public const string Source="ArtSource/Labs/World2026/WorldStudio05/BuildR4/";
 public const string Art="Assets/Mmorpg/Art/Experimental/ValdoriaHydrology05/";
 public const string Scene="Assets/Mmorpg/Scenes/ValdoriaHydrologyLab.unity";
 static string Hash(byte[] b){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 public static object Verify()
 {
  var m=JObject.Parse(File.ReadAllText(Source+"manifest.json"));if((string)m["schema"]!="valdoria-hydrology-build/v1")throw new IOException("Hydrology schema");
  foreach(var p in ((JObject)m["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(Source+p.Name))!=(string)p.Value)throw new IOException("Hydrology output hash "+p.Name);
  foreach(var p in ((JObject)m["inputs"]).Properties())if(Hash(File.ReadAllBytes((string)p.Value["path"]))!=(string)p.Value["sha256"])throw new IOException("Hydrology input hash "+p.Name);
  var library=JObject.Parse(File.ReadAllText((string)m["inputs"]["library"]["path"]));string dir=Path.GetDirectoryName((string)m["inputs"]["library"]["path"]);
  foreach(var p in ((JObject)library["files"]).Properties())if(Path.GetFileName(p.Name)!=p.Name||Hash(File.ReadAllBytes(Path.Combine(dir,p.Name)))!=(string)p.Value)throw new IOException("Water source library hash");
  return new{files=((JObject)m["files"]).Count,inputs=((JObject)m["inputs"]).Count};
 }
 static Texture2D ImportTexture(string name)
 {
  string path=Art+name;File.Copy(Source+name,path);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Default;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.alphaIsTransparency=true;i.wrapMode=TextureWrapMode.Clamp;i.maxTextureSize=512;i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
 }
 static void AddCollider(Transform parent,string name,JArray loops,float height)
 {
  var go=new GameObject(name);go.transform.SetParent(parent);go.layer=8;var c=go.AddComponent<PolygonCollider2D>();c.pathCount=loops.Count;
  for(int i=0;i<loops.Count;i++)c.SetPath(i,loops[i].Select(p=>new Vector2((float)p[0],height-(float)p[1])).ToArray());
 }
 struct Vertex{public Vector2 p;public float water,bank;public Vertex(Vector2 p,float w,float b){this.p=p;water=w;bank=b;}}
 static List<Vertex> Clip(List<Vertex> poly,Func<Vertex,float> sign)
 {
  var result=new List<Vertex>();for(int i=0;i<poly.Count;i++){var a=poly[i];var b=poly[(i+1)%poly.Count];float sa=sign(a),sb=sign(b);if(sa>=0)result.Add(a);if((sa>=0)!=(sb>=0)){float t=sa/(sa-sb);result.Add(new Vertex(Vector2.Lerp(a.p,b.p,t),Mathf.Lerp(a.water,b.water,t),Mathf.Lerp(a.bank,b.bank,t)));}}return result;
 }
 static Mesh BuildChunk(JArray surface,JArray bank,float step,int ox,int oy,int width,int height,float regionHeight)
 {
  var vertices=new List<Vector3>();var uvs=new List<Vector2>();var triangles=new List<int>();int x0=Mathf.RoundToInt(ox/32f/step),y0=Mathf.RoundToInt(oy/32f/step),x1=x0+Mathf.RoundToInt(width/32f/step),y1=y0+Mathf.RoundToInt(height/32f/step);
  Action<List<Vertex>> append=poly=>{if(poly.Count<3)return;int n=vertices.Count;foreach(var p in poly){vertices.Add(new Vector3(p.p.x,regionHeight-p.p.y,0));uvs.Add(new Vector2((p.p.x*32-ox)/width,1-(p.p.y*32-oy)/height));}for(int i=1;i<poly.Count-1;i++){triangles.Add(n);triangles.Add(n+i);triangles.Add(n+i+1);}};
  Func<int,int,Vertex> sample=(x,y)=>new Vertex(new Vector2(x*step,y*step),(float)surface[y][x],(float)bank[y][x]);
  for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++)
  {
   var a=sample(x,y);var b=sample(x+1,y);var c=sample(x+1,y+1);var d=sample(x,y+1);
   foreach(var t in new[]{new List<Vertex>{a,b,c},new List<Vertex>{a,c,d}}){append(Clip(t,p=>p.water));append(Clip(Clip(t,p=>p.bank),p=>-p.water));}
  }
  var mesh=new Mesh{name="SharedWaterAndBank_"+ox+"_"+oy};if(vertices.Count>65535)mesh.indexFormat=UnityEngine.Rendering.IndexFormat.UInt32;mesh.SetVertices(vertices);mesh.SetUVs(0,uvs);mesh.SetColors(Enumerable.Repeat(Color.white,vertices.Count).ToList());mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();return mesh;
 }
 [MenuItem("Valdoria/World Studio/09 - Build Hydrology Lab (NEW destination)")]
 public static void BuildMenu()=>Build();
 public static object Build()
 {
  if(EditorApplication.isPlaying)throw new IOException("Stop Play first");var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(original.isDirty||original.path!="Assets/Mmorpg/Scenes/ValdoriaArtisticTerrainLab.unity")throw new IOException("Open clean Marco04 Lab");if(File.Exists(Scene)||Directory.Exists(Art))throw new IOException("Refuse existing Hydrology scene/art destination");Verify();var sourceCollision=Object.FindAnyObjectByType<TerrainRegionData>().transform.Find("Collision - blocked semantic cells");if(sourceCollision==null||sourceCollision.GetComponents<BoxCollider2D>().Length==0||sourceCollision.GetComponents<Component>().Any(c=>!(c is Transform)&&!(c is BoxCollider2D)))throw new IOException("Unexpected coarse collision consumers");int replaced=sourceCollision.GetComponents<BoxCollider2D>().Length;string originalPath=original.path;
  try{
  Directory.CreateDirectory(Art);AssetDatabase.Refresh();EditorSceneManager.SaveScene(original,Scene,true);var scene=EditorSceneManager.OpenScene(Scene);var old=Object.FindAnyObjectByType<TerrainMaterialLabController>();old.Select(0,2);var so=new SerializedObject(old);var before=(GameObject)so.FindProperty("previousVisuals").GetArrayElementAtIndex(0).objectReferenceValue;Object.DestroyImmediate(before);Object.DestroyImmediate(old.gameObject);
  var terrain=Object.FindAnyObjectByType<TerrainRegionData>();var legacy=terrain.transform.Find("Collision - blocked semantic cells");Object.DestroyImmediate(legacy.gameObject);
  var geometry=JObject.Parse(File.ReadAllText(Source+"geometry.json"));var render=JObject.Parse(File.ReadAllText(Source+"water-render.json"));float regionHeight=(float)geometry["sizeUnits"][1],step=(float)geometry["stepUnits"];
  AddCollider(terrain.transform,"Solid - shared subcell relief footprint",(JArray)geometry["rockLoops"],regionHeight);
  var water=new GameObject("Hydrology - shared water banks and collision");water.transform.SetParent(terrain.transform);AddCollider(water.transform,"Water blockage - depth threshold except explicit ford",(JArray)geometry["waterBlockedLoops"],regionHeight);
  foreach(var chunk in render["chunks"])
  {
   string id=(string)chunk["id"];var textures=chunk["frames"].Select(n=>ImportTexture((string)n)).ToArray();var mat=new Material(Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default")){mainTexture=textures[0]};AssetDatabase.CreateAsset(mat,Art+"Water-"+id+".mat");var rect=chunk["rectPixels"];var mesh=BuildChunk((JArray)geometry["waterFields"]["surface"],(JArray)render["bankScalar"],step,(int)rect[0],(int)rect[1],(int)rect[2],(int)rect[3],regionHeight);AssetDatabase.CreateAsset(mesh,Art+"Water-"+id+".asset");
   var go=new GameObject("Water chunk "+id);go.transform.SetParent(water.transform);go.AddComponent<MeshFilter>().sharedMesh=mesh;var mr=go.AddComponent<MeshRenderer>();mr.sharedMaterial=mat;mr.sortingOrder=-1985;go.AddComponent<WaterSurfaceAnimator>().Configure(mr,textures,(float)render["durationMs"]/1000);
  }
  File.Copy(Source+"hydrology.json",Art+"hydrology.json");File.Copy(Source+"geometry.json",Art+"geometry.json");AssetDatabase.ImportAsset(Art+"hydrology.json");AssetDatabase.ImportAsset(Art+"geometry.json");var nav=JObject.Parse(File.ReadAllText(Source+"navigation.json"));int count=((JArray)nav["walkable"]).Count;var flags=new byte[count];
  for(int i=0;i<count;i++)flags[i]=(byte)(((bool)nav["solidBlocked"][i]?1:0)|((bool)nav["waterBlocked"][i]?2:0)|((bool)nav["surfaceWater"][i]?4:0)|((bool)nav["wetland"][i]?8:0));
  var data=terrain.gameObject.AddComponent<EnvironmentRegionData>();data.Configure(AssetDatabase.LoadAssetAtPath<TextAsset>(Art+"hydrology.json"),(int)nav["size"][0],(int)nav["size"][1],step,flags);var controller=new GameObject("Water Lab - 0 dry 1 water R reset").AddComponent<HydrologyLabController>();controller.Configure(water,data,GameObject.Find("Player").transform);controller.ResetPose();Object.FindAnyObjectByType<ValdoriaR9ProfileIsolation>().ConfigureTemporaryProfile("ValdoriaHydrology05/IsolatedProfile");
  EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();return new{scene=Scene,chunks=((JArray)render["chunks"]).Count,framesPerChunk=4,coarseBoxesReplaced=replaced,solidLoops=((JArray)geometry["rockLoops"]).Count,waterLoops=((JArray)geometry["waterBlockedLoops"]).Count};
  }catch{EditorSceneManager.OpenScene(originalPath);AssetDatabase.DeleteAsset(Scene);AssetDatabase.DeleteAsset(Art.TrimEnd('/'));throw;}
 }
}
