using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
public static class CaptureGround11Court
{
 static JArray cases;static GroundFinishLab lab;static Camera camera;static int index=-1,phase;static double until;static bool waiting;static int first;static System.Collections.Generic.List<object> trace=new System.Collections.Generic.List<object>();
 const string Output="Docs/Validation/ValdoriaGround11/Court";
 public static object Main(){if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=GroundFinish11Importer.Court)throw new IOException("Requires grammar court Play");if(Directory.Exists(Output))throw new IOException("Refuse capture overwrite");Directory.CreateDirectory(Output);cases=(JArray)JObject.Parse(File.ReadAllText(GroundFinish11Importer.Source+"CourtFinalV2/composition.json"))["cases"];lab=UnityEngine.Object.FindAnyObjectByType<GroundFinishLab>();camera=Camera.main;first=Time.frameCount;EditorApplication.update+=Tick;return "Real Game View grammar captures queued";}
 static void Tick()
 {
  if(!EditorApplication.isPlaying){EditorApplication.update-=Tick;return;}if(Time.timeAsDouble<until)return;
  if(waiting){string name=index<0?"00-overview":(index+1).ToString("00")+"-"+(string)cases[index]["id"];name+="-"+(phase==0?"before":"after");ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+name+".png"));trace.Add(new{file=name+".png",frame=Time.frameCount,time=Time.timeAsDouble,camera=camera.transform.position.ToString(),ortho=camera.orthographicSize,width=camera.pixelWidth,height=camera.pixelHeight,stage=lab.Stage,physicsClaim="Visual material fixture only; no canonical world navigation"});waiting=false;phase++;if(phase==2){phase=0;index++;}until=Time.timeAsDouble+.3;return;}
  if(index==cases.Count){EditorApplication.update-=Tick;File.WriteAllText(Output+"/capture-qa.json",JsonConvert.SerializeObject(new{framesAdvanced=Time.frameCount-first,cases=cases.Count,trace,geometryChanged=false,canonicalWorld=false,drawCalls=UnityStats.drawCalls,renderers=UnityEngine.Object.FindObjectsByType<Renderer>().Length},Formatting.Indented));return;}
  lab.Select(phase==0?0:3);camera.orthographicSize=index<0?20:7.03125f;camera.transform.position=index<0?new Vector3(30,18.75f,-10):new Vector3((float)cases[index]["centerUnits"][0],37.5f-(float)cases[index]["centerUnits"][1],-10);waiting=true;until=Time.timeAsDouble+.6;
 }
}
