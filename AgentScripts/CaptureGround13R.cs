using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class CaptureGround13R
{
 static int index,last;static bool prepared;static double until;static Camera camera;static Ground13RLab lab;static ProductionSpriteAnimator actor;static bool animation;static string set;static List<object> rows;
 static readonly Vector3[] positions={new Vector3(48,23,-10),new Vector3(35,36,-10),new Vector3(28.5f,14.25f,-10),new Vector3(18,28,-10),new Vector3(48,26,-10)};
 static readonly string[] names={"plateau","upper-area","composition","second-area","upland"};static readonly int[] modes={0,1,2,4,3};
 const string Root="Docs/Validation/ValdoriaGround13R/";
 public static object Shape()=>Begin("ShapeStudy");public static object ShapeFine()=>Begin("ShapeFine");public static object Final()=>Begin("Final");public static object Refined()=>Begin("Refined");public static object Candidate()=>Begin("Candidate");public static object Delivery()=>Begin("Delivery");
 static object Begin(string value){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||Directory.Exists(Root+"Original/"+value))throw new IOException("New isolated Play capture destination required");Directory.CreateDirectory(Root+"Original/"+value);set=value;index=0;prepared=false;rows=new List<object>();until=0;camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;lab=UnityEngine.Object.FindAnyObjectByType<Ground13RLab>();var p=GameObject.Find("Player").GetComponent<Rigidbody2D>();p.position=new Vector2(28.673845f,6.245552f);p.transform.position=p.position;p.linearVelocity=Vector2.zero;actor=p.GetComponent<ProductionSpriteAnimator>();actor.SetPreviewFacing(0);animation=actor.enabled;actor.enabled=false;EditorApplication.update+=Tick;return "Paired rendered captures queued: same actor, camera, light, water phase";}
 static void Tick(){try{if(!EditorApplication.isPlaying)throw new IOException("Play interrupted");if(last==Time.frameCount)return;last=Time.frameCount;if(Time.realtimeSinceStartupAsDouble<until)return;int modeCount=set.StartsWith("Shape")?2:5;int count=positions.Length*modeCount;if(index==count){EditorApplication.update-=Tick;lab.Select(2);lab.EvidencePhase(-1);actor.enabled=animation;File.WriteAllText(Root+"QA/captures-"+set+".json",JsonConvert.SerializeObject(rows,Formatting.Indented));return;}int pose=index/modeCount,mode=set.StartsWith("Shape")?(index%2==0?4:3):modes[index%5];string state=mode==0?"A-Ground12":mode==1?"B-Ground13":mode==2?"C-Ground13R":mode==3?"D-Ground13R-neutral":"E-Ground13-neutral";
 if(!prepared){lab.Select(mode);lab.EvidencePhase(0);camera.transform.position=positions[pose];camera.orthographicSize=pose==2||pose==3?14.0625f:7.03125f;prepared=true;until=Time.realtimeSinceStartupAsDouble+.55;return;}
 string path="Original/"+set+"/"+names[pose]+"-"+state+".png";ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+path));rows.Add(new{original=path,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,state,comparison=set+"-"+names[pose]+(mode>=3?"-neutral":"-painted"),camera=new{position=positions[pose].ToString("R"),ortho=camera.orthographicSize,ppu=32,resolution=new[]{1600,900},actor="28.673845,6.245552",actorScale=1.25},integral=true,requestedFrame=Time.frameCount,waterPhase=0,actorPose="fixed"});index++;prepared=false;until=Time.realtimeSinceStartupAsDouble+.2;
 }catch(Exception e){EditorApplication.update-=Tick;if(actor)actor.enabled=animation;lab?.EvidencePhase(-1);File.WriteAllText(Root+"QA/capture-error-"+set+".txt",e.ToString());}}
}
