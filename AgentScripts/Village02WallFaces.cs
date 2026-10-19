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

public static class Village02WallFaces
{
 const string Root="Docs/Validation/ValdoriaVillage02-Integration/WallFaces/";
 static Task active;static Rigidbody2D body;static Collider2D feet;static Keyboard keyboard;static Key[] held=Array.Empty<Key>();static List<object> results=new List<object>();
 static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
 static void Write(string name,object v)=>File.WriteAllText(Root+"QA/"+name,JsonConvert.SerializeObject(v,Formatting.Indented));
 static void Feed(){if(keyboard!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static Key[] Keys(Vector2 d){var r=new List<Key>();if(Mathf.Abs(d.x)>.2)r.Add(d.x>0?Key.D:Key.A);if(Mathf.Abs(d.y)>.2)r.Add(d.y>0?Key.W:Key.S);return r.ToArray();}
 static void Place(Vector2 p){held=Array.Empty<Key>();body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.simulated=false;body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;body.simulated=true;Physics2D.SyncTransforms();body.WakeUp();}
 public static object Main(){if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/ValdoriaVillage02Integrated.unity"||!LocalJourneyProfile.Root.Contains("Temp")||active!=null||Directory.Exists(Root))throw new Exception("Fresh isolated wall-face QA required");Directory.CreateDirectory(Root+"QA");active=Run();return "All 79 wall front/back faces queued";}
 static async Task Run(){var previous=Keyboard.current;var disabled=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();int first=Time.frameCount;string error=null;var recorder=new GameObject("TEMP wall face evidence").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot(Root);
  try{
   body=GameObject.Find("Player").GetComponent<Rigidbody2D>();feet=body.GetComponent<Collider2D>();var all=UnityEngine.Object.FindObjectsByType<PolygonCollider2D>().Where(c=>c.gameObject.layer==8).ToArray();follow.enabled=false;SessionState.SetInt("Village02Integration.PreviousFPS",Application.targetFrameRate);SessionState.SetBool("Village02Integration.FPSOverride",true);Application.targetFrameRate=60;
   foreach(var k in disabled)InputSystem.DisableDevice(k);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Village02-Wall-Faces");InputSystem.onBeforeUpdate+=Feed;
   var data=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/IntegrationV2/layout.json"));int ordinal=0;
   foreach(var wall in data["physical"].Where(p=>(string)p["kind"]=="wall")){
    string id=(string)wall["id"];var target=all.Single(c=>c.name=="Physics:"+id);var p=wall["polygon"].Select(V).ToArray();float area=0;for(int i=0;i<p.Length;i++)area+=p[i].x*p[(i+1)%p.Length].y-p[(i+1)%p.Length].x*p[i].y;
    // strip() is [a+n,a-n,b-n,b+n]: edges 1/3 are the long faces.
    foreach(int edge in new[]{1,3}){var v=p[(edge+1)%4]-p[edge];var n=area>0?new Vector2(v.y,-v.x):new Vector2(-v.y,v.x);float angle=Mathf.Round(Mathf.Atan2(n.y,n.x)/(Mathf.PI/4))*Mathf.PI/4;var outward=new Vector2(Mathf.Round(Mathf.Cos(angle)),Mathf.Round(Mathf.Sin(angle))).normalized;Vector2? fixture=null;string firstHit=null;
     foreach(float t in new[]{.5f,.25f,.75f,.1f,.9f}){var aim=Vector2.Lerp(p[edge],p[(edge+1)%4],t);var pos=aim-feet.offset+outward*1.3f;if(Physics2D.OverlapBox(pos+feet.offset,(Vector2)feet.bounds.size-Vector2.one*.002f,0,1<<8))continue;var hit=Physics2D.BoxCast(pos+feet.offset,(Vector2)feet.bounds.size-Vector2.one*.002f,0,-outward,1.8f,1<<8);if(!hit.collider)continue;if(fixture==null){fixture=pos;firstHit=hit.collider.name;}if(hit.collider==target){fixture=pos;firstHit=target.name;break;}}
     if(fixture==null){results.Add(new{id,edge,pass=false,reason="No aligned exterior fixture"});continue;}
     Place(fixture.Value);camera.transform.position=new Vector3(fixture.Value.x,fixture.Value.y+5,-10);camera.orthographicSize=14.0625f;await Task.Delay(100);bool take=ordinal%10==0;string image=id+"-face-"+edge;if(take){recorder.Capture(image+"-before","Long face of outer wall: aligned actual Input System contact");while(recorder.Busy)await Task.Delay(20);}
     held=Keys(-outward);float min=100,unionMin=100;bool inside=false;var contacts=new HashSet<string>();int last=-1,samples=0;double start=Time.timeAsDouble,contact=-1;
     while(Time.timeAsDouble-start<1.2){await Task.Delay(10);if(last==Time.frameCount)continue;last=Time.frameCount;samples++;min=Mathf.Min(min,feet.Distance(target).distance);foreach(var solid in all){float d=feet.Distance(solid).distance;unionMin=Mathf.Min(unionMin,d);inside|=solid.OverlapPoint(body.position);if(d<.035f){contacts.Add(solid.name);if(contact<0)contact=Time.timeAsDouble;}}if(contact>=0&&Time.timeAsDouble-contact>.12)break;}
     held=Array.Empty<Key>();await Task.Delay(60);bool direct=contacts.Contains(target.name);bool pass=!inside&&unionMin>=-.025&&direct;results.Add(new{id,edge,pass,firstHit,direct,minimumSeparation=min,unionMin,inside,samples,contacts=contacts.ToArray(),fixture=fixture.Value.ToString("R"),position=body.position.ToString("R"),direction=(-outward).ToString("R"),realInput=true});if(take){recorder.Capture(image+"-after","After real Input System push against outer wall long face; see measured receipt");while(recorder.Busy)await Task.Delay(20);}Write("checkpoint.json",new{complete=false,results,frame=Time.frameCount});
    }ordinal++;
   }
  }catch(Exception ex){error=ex.ToString();}
  finally{held=Array.Empty<Key>();InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var k in disabled)InputSystem.EnableDevice(k);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;if(body)Place(new Vector2(116.6f,26.4f));follow.enabled=true;camera.orthographicSize=14.0625f;Write("result.json",new{error,allExecutedPassed=error==null&&results.All(r=>(bool)JObject.FromObject(r)["pass"]),framesAdvanced=Time.frameCount-first,results,inputRestored=!InputSystem.devices.Any(d=>d.name.Contains("Wall-Faces")),timeScale=Time.timeScale,fpsRestorePendingUntilStop=true});}
 }
}
