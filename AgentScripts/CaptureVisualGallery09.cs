using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
using Newtonsoft.Json;
public static class CaptureVisualGallery09
{
 sealed class Step{public Action start,end;public float seconds;}
 static Queue<Step> queue=new Queue<Step>();static Step step;static double until;static int frame;static List<object> captures=new List<object>();const string Root="Docs/Validation/ValdoriaWorldStudio09/GalleryQA/";
 static void Add(float duration,Action start,Action end=null)=>queue.Enqueue(new Step{seconds=duration,start=start,end=end});
 static void Capture(string file){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+file+".png"));captures.Add(new{file,frame=Time.frameCount,camera=Camera.main.transform.position.ToString(),ortho=Camera.main.orthographicSize,actor=GameObject.Find("Player").transform.position.ToString()});}
 public static object Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated gallery Play");if(Directory.Exists(Root))throw new IOException("Refuse gallery overwrite");Directory.CreateDirectory(Root);var camera=Camera.main;var visual=UnityEngine.Object.FindAnyObjectByType<VisualUnificationLab>();
  Add(.7f,()=>{visual.Apply(2);camera.orthographicSize=39;camera.transform.position=new Vector3(67.5f,52,-10);},()=>Capture("01-three-families-same-scale"));Add(.25f,()=>{});
  Add(.7f,()=>visual.Apply(2,true),()=>Capture("02-three-weathered-variants-same-scale"));Add(.25f,()=>{});
  Add(.4f,()=>visual.Apply(2));
  EditorApplication.update+=Tick;return "Real gallery frame sequence started";
 }
 static void Tick(){if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(frame==Time.frameCount)return;frame=Time.frameCount;if(step!=null&&Time.timeAsDouble<until)return;step?.end?.Invoke();if(queue.Count==0){Finish(null);return;}step=queue.Dequeue();step.start();until=Time.timeAsDouble+step.seconds;}
 static void Finish(string error){EditorApplication.update-=Tick;File.WriteAllText(Root+"captures.json",JsonConvert.SerializeObject(new{error,captures,reviewOnly=true,castleWorldLotAccepted=false},Formatting.Indented));}
}
