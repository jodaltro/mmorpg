using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class CaptureWaterGround13
{
 static int index,last;static double until;static Ground13Lab lab;static Camera camera;static List<object> captures=new List<object>();
 const string Root="Docs/Validation/ValdoriaGround13/";
 public static object Main(){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||Directory.Exists(Root+"Original/Water"))throw new IOException("Isolated Play and new destination required");Directory.CreateDirectory(Root+"Original/Water");lab=UnityEngine.Object.FindAnyObjectByType<Ground13Lab>();camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=7.03125f;camera.transform.position=new Vector3(10,23,-10);index=0;last=-1;until=0;EditorApplication.update+=Tick;return "Eight phase-locked comparison captures plus eight live replay frames queued";}
 static void Tick(){try{
  if(!EditorApplication.isPlaying)throw new IOException("Play interrupted");if(last==Time.frameCount)return;last=Time.frameCount;if(Time.realtimeSinceStartupAsDouble<until)return;
  if(index==32){EditorApplication.update-=Tick;lab.Select(3);lab.EvidencePhase(-1);File.WriteAllText(Root+"QA/water-captures.json",JsonConvert.SerializeObject(captures,Formatting.Indented));return;}
  int shot=index/2;bool setup=index%2==0;bool locked=shot<8;int stage=shot<4?0:3,phase=shot%4;
  if(setup){if(locked){lab.Select(stage);lab.EvidencePhase(phase);}else if(shot==8){lab.Select(3);lab.EvidencePhase(-1);}until=Time.realtimeSinceStartupAsDouble+(locked?.32:.18);index++;return;}
  string name=locked?(stage==0?"before-":"candidate-")+phase:"live-"+(shot-8).ToString("00");string path="Original/Water/"+name+".png";ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+path));captures.Add(new{original=path,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,state=locked?(stage==0?"before":"candidate"):"live",comparison=locked?"water-phase-"+phase:"water-live-"+shot,camera=new{position=new[]{10,23,-10},ortho=7.03125,ppu=32,resolution=new[]{1600,900}},integral=true,phase=locked?phase:-1,mode=locked?"phase held after rendered settling frames":"live animator replay, requested at >=180ms intervals",requestedFrame=Time.frameCount,time=Time.timeAsDouble,animatorFrames=UnityEngine.Object.FindObjectsByType<WaterSurfaceAnimator>().Select(w=>new{w.name,w.FrameIndex}).ToArray()});index++;until=Time.realtimeSinceStartupAsDouble+.03;
 }catch(Exception e){EditorApplication.update-=Tick;lab?.EvidencePhase(-1);File.WriteAllText(Root+"QA/water-capture-error.txt",e.ToString());}}
}
