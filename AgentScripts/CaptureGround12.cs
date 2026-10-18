using System;
using System.IO;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class CaptureGround12
{
 static int index,frame;static double until;static bool waiting;static string state;static Camera camera;static List<object> captures;
 static readonly Vector3[] points={new Vector3(28.5f,14.25f,-10),new Vector3(48,23,-10),new Vector3(35,36,-10),new Vector3(10,23,-10),new Vector3(18,28,-10),new Vector3(49,9,-10)};
 static readonly string[] names={"composition","plateau","relief-upper","water-bank","second-area","historical-tree"};
 public static string Before()=>Begin("before");
 public static string After()=>Begin("after");
 public static string Final()=>Begin("final");
 static string Begin(string value)
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Isolated Play required");
  state=value;index=0;waiting=false;captures=new List<object>();Directory.CreateDirectory("Docs/Validation/ValdoriaGround12/Original");
  foreach(var name in names)if(File.Exists(PathFor(name)))throw new IOException("Refuse capture overwrite");
  camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;var p=GameObject.Find("Player").GetComponent<Rigidbody2D>();p.position=new Vector2(28.673845f,6.245552f);p.transform.position=p.position;
  EditorApplication.update+=Tick;return "Queued six rendered Play captures, paired cameras";
 }
 static string PathFor(string name)=>"Docs/Validation/ValdoriaGround12/Original/"+name+"-"+state+".png";
 static void Tick()
 {
  if(!EditorApplication.isPlaying){EditorApplication.update-=Tick;return;}if(Time.timeAsDouble<until)return;
  if(waiting){ScreenCapture.CaptureScreenshot(Path.GetFullPath(PathFor(names[index])));captures.Add(new{path=PathFor(names[index]),scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,state,comparison=names[index],camera=new{position=points[index].ToString(),ortho=camera.orthographicSize,ppu=32,actorScale=1.25,width=camera.pixelWidth,height=camera.pixelHeight},integral=true,frame=Time.frameCount,framesAfterCameraChange=Time.frameCount-frame});index++;waiting=false;until=Time.timeAsDouble+.4;return;}
  if(index==points.Length){EditorApplication.update-=Tick;File.WriteAllText("Docs/Validation/ValdoriaGround12/QA/captures-"+state+".json",JsonConvert.SerializeObject(captures,Formatting.Indented));return;}
  camera.transform.position=points[index];camera.orthographicSize=index==0||index==4?14.0625f:7.03125f;frame=Time.frameCount;waiting=true;until=Time.timeAsDouble+.7;
 }
}
