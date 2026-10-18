using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
using Newtonsoft.Json;
public static class MeasureGround13Final
{
 static Ground13Lab lab;static Camera camera;static ProductionSpriteAnimator actor;static int stage,phase,firstFrame,lastFrame;static double until,began;static bool actorEnabled;
 static List<object> metrics=new List<object>(),captures=new List<object>();static List<double> dt=new List<double>();
 const string Root="Docs/Validation/ValdoriaGround13/";
 static object Performance(){var rr=UnityEngine.Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();var tt=rr.SelectMany(r=>r is SpriteRenderer s&&s.sprite?new[]{s.sprite.texture}:r.sharedMaterials.Where(m=>m&&m.mainTexture is Texture2D).Select(m=>(Texture2D)m.mainTexture)).Distinct().ToArray();return new{drawCalls=UnityStats.drawCalls,renderers=rr.Length,visible=rr.Count(r=>r.isVisible),textures=tt.Length,textureBytes=tt.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t))};}
 public static object Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Isolated Play required");if(Directory.Exists(Root+"Original/OptimizationFinal"))throw new IOException("Refuse capture overwrite");Directory.CreateDirectory(Root+"Original/OptimizationFinal");lab=UnityEngine.Object.FindAnyObjectByType<Ground13Lab>();camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(28.5f,14.25f,-10);var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();body.position=new Vector2(28.673845f,6.245552f);body.transform.position=body.position;actor=body.GetComponent<ProductionSpriteAnimator>();actorEnabled=actor.enabled;actor.enabled=false;stage=0;phase=0;until=0;EditorApplication.update+=Tick;return "Five comparable rendering states queued, live water for timing, fixed phase for screenshots";
 }
 static void Tick()
 {
  try{
   if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(Time.frameCount==lastFrame)return;lastFrame=Time.frameCount;
   if(phase==2)dt.Add(Time.unscaledDeltaTime*1000.0);
   if(Time.realtimeSinceStartupAsDouble<until)return;
   if(stage==5){Finish(null);return;}
   if(phase==0){lab.Select(stage);phase=1;until=Time.realtimeSinceStartupAsDouble+.75;return;}
   if(phase==1){phase=2;began=Time.realtimeSinceStartupAsDouble;firstFrame=Time.frameCount;dt.Clear();until=began+2.5;return;}
   if(phase==2){var frames=new FrameTiming[1];FrameTimingManager.CaptureFrameTimings();uint timings=FrameTimingManager.GetLatestTimings(1,frames);var values=dt.OrderBy(v=>v).ToArray();metrics.Add(new{stage,frames=Time.frameCount-firstFrame,seconds=Time.realtimeSinceStartupAsDouble-began,fps=(Time.frameCount-firstFrame)/(Time.realtimeSinceStartupAsDouble-began),medianFrameMs=values[values.Length/2],p95FrameMs=values[Math.Min(values.Length-1,(int)(values.Length*.95))],frameTimingAvailable=timings>0,cpuFrameMs=timings>0?frames[0].cpuFrameTime:0,gpuFrameMs=timings>0?frames[0].gpuFrameTime:0,performance=Performance()});lab.EvidencePhase(0);phase=3;until=Time.realtimeSinceStartupAsDouble+.3;return;}
   string relative="Original/OptimizationFinal/stage-"+stage+".png";ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+relative));captures.Add(new{original=relative,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,state="stage-"+stage,comparison=stage<2?"packing-ground12":stage==3||stage==4?"packing-ground13":"clay",camera=new{position=new[]{28.5,14.25,-10},ortho=14.0625,ppu=32,actorScale=1.25,width=camera.pixelWidth,height=camera.pixelHeight},integral=true,frame=Time.frameCount,waterPhase=0,actorAnimation="held identical for pixel comparison"});stage++;phase=0;until=Time.realtimeSinceStartupAsDouble+.4;
  }catch(Exception ex){Finish(ex.ToString());}
 }
 static void Finish(string error){EditorApplication.update-=Tick;if(actor)actor.enabled=actorEnabled;if(lab){lab.Select(3);lab.EvidencePhase(-1);}File.WriteAllText(Root+"QA/performance-final.json",JsonConvert.SerializeObject(new{error,conditions=new{resolution="1600x900",camera="28.5,14.25,-10",ortho=14.0625,ppu=32,quality=QualitySettings.names[QualitySettings.GetQualityLevel()],vSync=QualitySettings.vSyncCount,targetFrameRate=Application.targetFrameRate,graphicsAPI=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,timeScale=Time.timeScale,context="Editor Play, unfocused autotick; actor pose held, live water while timing; not standalone benchmark"},metrics},Formatting.Indented));File.WriteAllText(Root+"QA/optimization-final-captures.json",JsonConvert.SerializeObject(captures,Formatting.Indented));}
}
