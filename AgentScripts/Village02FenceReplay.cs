using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
public static class Village02FenceReplay
{
 static Task active;static Key[] held=Array.Empty<Key>();static Keyboard keyboard;
 const string Root="Docs/Validation/ValdoriaVillage02-Integration/FenceReplay2/";
 static void Mark(string value)=>File.WriteAllText(Root+"progress.txt",value+" "+Time.frameCount+" "+Time.timeAsDouble);
 static void Feed(){if(keyboard!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 public static object Main(){if(!EditorApplication.isPlaying)throw new Exception("Play required");Directory.CreateDirectory(Root);active=Run();return "Fence replay queued";}
 static async Task Run(){var previous=Keyboard.current;var keyboards=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;var a=GameObject.Find("Player").GetComponent<Rigidbody2D>();var cam=Camera.main;var follow=cam.GetComponent<CameraFollow>();var recorder=new GameObject("TEMP fence replay").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot(Root);int fps=Application.targetFrameRate;string error=null;
  try{
   foreach(var k in keyboards)InputSystem.DisableDevice(k);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Village02-Fence-Replay");InputSystem.onBeforeUpdate+=Feed;SessionState.SetInt("Village02Integration.PreviousFPS",fps);SessionState.SetBool("Village02Integration.FPSOverride",true);Application.targetFrameRate=60;follow.enabled=false;
   var c=GameObject.Find("Physics:fence-0").GetComponent<PolygonCollider2D>();var p=c.GetPath(0);float area=0;for(int i=0;i<p.Length;i++)area+=p[i].x*p[(i+1)%p.Length].y-p[(i+1)%p.Length].x*p[i].y;
   foreach(int edge in new[]{2,3,0,1}){var mid=(p[edge]+p[(edge+1)%p.Length])*.5f;var v=p[(edge+1)%p.Length]-p[edge];var outward=(area>0?new Vector2(v.y,-v.x):new Vector2(-v.y,v.x)).normalized;var from=mid+outward*.72f;held=Array.Empty<Key>();Mark("before-place-"+edge);a.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);a.simulated=false;a.position=from;a.transform.position=from;a.linearVelocity=Vector2.zero;a.simulated=true;Physics2D.SyncTransforms();a.WakeUp();Mark("after-place-"+edge);cam.transform.position=new Vector3(from.x,from.y+5,-10);cam.orthographicSize=14.0625f;await Task.Delay(150);Mark("before-capture-"+edge);recorder.Capture("fence-"+edge+"-before","Replaying interrupted fence contact fixture");while(recorder.Busy)await Task.Delay(20);Mark("after-capture-"+edge);var direction=-outward;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(direction.x)>.15f)keys.Add(direction.x>0?Key.D:Key.A);if(Mathf.Abs(direction.y)>.15f)keys.Add(direction.y>0?Key.W:Key.S);held=keys.ToArray();for(int n=0;n<20;n++){Mark("push-"+edge+"-"+n);await Task.Delay(20);var dist=a.GetComponent<Collider2D>().Distance(c);if(dist.distance<-.025f)throw new Exception("Penetration "+dist.distance);}held=Array.Empty<Key>();Mark("after-push-"+edge);await Task.Delay(80);recorder.Capture("fence-"+edge+"-after","Replayed live fence push complete");while(recorder.Busy)await Task.Delay(20);Mark("after-png-"+edge);}
  }catch(Exception ex){error=ex.ToString();}finally{held=Array.Empty<Key>();InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var k in keyboards)InputSystem.EnableDevice(k);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;a.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);a.simulated=false;a.position=new Vector2(116.6f,26.4f);a.transform.position=a.position;a.linearVelocity=Vector2.zero;a.simulated=true;Physics2D.SyncTransforms();a.WakeUp();follow.enabled=true;Mark("finished");File.WriteAllText(Root+"result.json",Newtonsoft.Json.JsonConvert.SerializeObject(new{error,passed=error==null,inputRestored=!InputSystem.devices.Any(d=>d.name.Contains("Fence-Replay")),targetFrameRateRestorePendingUntilStop=true,frames=Time.frameCount}));}
 }
}

