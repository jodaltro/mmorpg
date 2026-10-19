using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

// A second receipt, never a rewrite of FinalV2. Input is quantized before placing
// fixtures so a thin face cannot be missed by changing the approach direction.
public static class Village02ContactCorrections
{
 const string Root="Docs/Validation/ValdoriaVillage02-Integration/ContactCorrections/";
 static Task active; static Keyboard keyboard; static Key[] held=Array.Empty<Key>();
 static Rigidbody2D body; static Collider2D feet; static PolygonCollider2D[] solids;
 static Village02EvidenceCapture capture; static List<object> results=new List<object>();
 static void Write(string name,object value)=>File.WriteAllText(Root+"QA/"+name,JsonConvert.SerializeObject(value,Formatting.Indented));
 static void Feed(){if(keyboard!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
 static Vector2 Quantize(Vector2 v){float a=Mathf.Round(Mathf.Atan2(v.y,v.x)/(Mathf.PI/4))*Mathf.PI/4;return new Vector2(Mathf.Round(Mathf.Cos(a)),Mathf.Round(Mathf.Sin(a))).normalized;}
 static Key[] Keys(Vector2 v,bool dodge){var k=new List<Key>();if(Mathf.Abs(v.x)>.2f)k.Add(v.x>0?Key.D:Key.A);if(Mathf.Abs(v.y)>.2f)k.Add(v.y>0?Key.W:Key.S);if(dodge)k.Add(Key.Space);return k.ToArray();}
 static bool Free(Vector2 p)=>!Physics2D.OverlapBox(p+feet.offset,(Vector2)feet.bounds.size-Vector2.one*.002f,0,1<<8);
 static void Place(Vector2 p){held=Array.Empty<Key>();body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.simulated=false;body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;body.simulated=true;Physics2D.SyncTransforms();body.WakeUp();}
 static async Task Snap(string id){capture.Capture(id,"Aligned eight-direction contact replay; actual Play and opaque art; see correction receipt for measured contact");while(capture.Busy)await Task.Delay(20);}
 public static object Main(){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||File.Exists(Root+"QA/result.json")||active!=null)throw new Exception("Fresh isolated Play correction receipt required");Directory.CreateDirectory(Root+"QA");active=Run();return "Contact corrections queued";}
 static async Task Run()
 {
  var previous=Keyboard.current;var disabled=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();int first=Time.frameCount;string error=null;
  try{
   body=GameObject.Find("Player").GetComponent<Rigidbody2D>();feet=body.GetComponent<Collider2D>();solids=UnityEngine.Object.FindObjectsByType<PolygonCollider2D>().Where(c=>c.gameObject.layer==8).ToArray();capture=new GameObject("TEMP contact correction evidence").AddComponent<Village02EvidenceCapture>();capture.ConfigureRoot(Root);
   if(!SessionState.GetBool("Village02Integration.FPSOverride",false)){SessionState.SetInt("Village02Integration.PreviousFPS",Application.targetFrameRate);SessionState.SetBool("Village02Integration.FPSOverride",true);}Application.targetFrameRate=60;follow.enabled=false;
   foreach(var k in disabled)InputSystem.DisableDevice(k);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Village02-Contact-Corrections");InputSystem.onBeforeUpdate+=Feed;
   var failed=JObject.Parse(File.ReadAllText("Docs/Validation/ValdoriaVillage02-Integration/FinalV2/QA/play-qa.json"))["results"].Where(r=>!(bool)r["pass"]).ToArray();
   foreach(var old in failed){string id=(string)old["id"];var target=solids.Single(c=>c.name==(string)old["evidence"]["target"]);var p=target.GetPath(0).Select(v=>(Vector2)target.transform.TransformPoint(v)).ToArray();bool corner=id.Contains("-corner-"),dodge=id.EndsWith("-dodge");int edge=dodge?0:int.Parse(id.Substring(id.LastIndexOf('-')+1));float area=0;for(int i=0;i<p.Length;i++)area+=p[i].x*p[(i+1)%p.Length].y-p[(i+1)%p.Length].x*p[i].y;
    var v=p[(edge+1)%p.Length]-p[edge];var normal=corner?(p[edge]-p.Aggregate(Vector2.zero,(a,b)=>a+b)/p.Length):(area>0?new Vector2(v.y,-v.x):new Vector2(-v.y,v.x));var outward=Quantize(normal);Vector2? from=null;string blocker=null;float expected=0;
    // Preflight the same physical feet shape, along the same quantized ray that
    // the real keyboard will drive. Prefer a direct hit on the intended piece.
    foreach(float t in new[]{.5f,.25f,.75f,.1f,.9f}){var aim=corner?p[edge]:Vector2.Lerp(p[edge],p[(edge+1)%p.Length],t);foreach(float gap in new[]{1.1f,1.5f,2f}){var pos=aim-feet.offset+outward*gap;if(!Free(pos))continue;var hits=Physics2D.BoxCastAll(pos+feet.offset,(Vector2)feet.bounds.size-Vector2.one*.002f,0,-outward,gap+.5f,1<<8).Where(h=>h.collider).OrderBy(h=>h.distance).ToArray();if(hits.Length==0)continue;if(from==null){from=pos;blocker=hits[0].collider.name;expected=hits[0].distance;}if(hits[0].collider==target){from=pos;blocker=target.name;expected=hits[0].distance;break;}}if(blocker==target.name)break;}
    if(from==null){results.Add(new{id,pass=false,reason="No clear aligned fixture found; coverage unresolved"});continue;}
    Place(from.Value);camera.transform.position=new Vector3(from.Value.x,from.Value.y+5,-10);camera.orthographicSize=14.0625f;await Task.Delay(dodge?1150:150);await Snap(id+"-before");var start=body.position;held=Keys(-outward,dodge);float targetMin=100,unionMin=100;bool inside=false,dodged=false;int frame=-1,samples=0;var contacts=new HashSet<string>();double contactAt=-1,began=Time.timeAsDouble;
    while(Time.timeAsDouble-began<1.1){await Task.Delay(10);if(frame==Time.frameCount)continue;frame=Time.frameCount;samples++;targetMin=Mathf.Min(targetMin,feet.Distance(target).distance);foreach(var solid in solids){float d=feet.Distance(solid).distance;unionMin=Mathf.Min(unionMin,d);inside|=solid.OverlapPoint(body.position);if(d<.035f){contacts.Add(solid.name);if(contactAt<0)contactAt=Time.timeAsDouble;}}dodged|=body.GetComponent<ActorHealth>().State.IsDodging(Time.timeAsDouble);if(contactAt>=0&&Time.timeAsDouble-contactAt>.16)break;}
    held=Array.Empty<Key>();await Task.Delay(80);float travel=Vector2.Distance(start,body.position);bool direct=contacts.Contains(target.name);bool pass=!inside&&unionMin>=-.025f&&contacts.Count>0&&travel>.03f&&(!dodge||dodged);results.Add(new{id,pass,target=target.name,fixture=from.Value.ToString("R"),direction=(-outward).ToString("R"),preflightFirst=blocker,preflightDistance=expected,directTargetContact=direct,coverage=direct?"Intended target contacted":"Adjacent solid stops this approach; target face remains a coverage limitation",contacts=contacts.ToArray(),targetMin,unionMin,inside,travel,samples,dodge,dodged,realInput=true,quantizedBeforePlacement=true});await Snap(id+"-after");Write("checkpoint.json",new{complete=false,results,frame=Time.frameCount});
   }
  }catch(Exception ex){error=ex.ToString();}
  finally{held=Array.Empty<Key>();InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var k in disabled)InputSystem.EnableDevice(k);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;if(body)Place(new Vector2(116.6f,26.4f));follow.enabled=true;camera.orthographicSize=14.0625f;Write("result.json",new{error,allExecutedPassed=error==null&&results.All(r=>(bool)JObject.FromObject(r)["pass"]),framesAdvanced=Time.frameCount-first,results,inputRestored=!InputSystem.devices.Any(d=>d.name.Contains("Contact-Corrections")),timeScale=Time.timeScale,fpsRestorePendingUntilStop=true});}
 }
}

