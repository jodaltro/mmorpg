using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
public static class ValidateVisualUnification09
{
 sealed class Step{public float seconds;public Action begin,end;}
 static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static ProductionSpriteAnimator animator;static Step current;static double until,began,nextTrace,nextCapture;static int first,last,captures,waypoint;static bool motion,dodged,following;static Vector2 start;static List<Vector2> path;static string style;static Camera camera;static CameraFollow follow;
 static string Output;static Vector2 freePoint;
 static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 p){held=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name)=>ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+(name.EndsWith(".png")?name:name+".png")));
 static bool Penetration(){var box=body.GetComponent<BoxCollider2D>();var filter=new ContactFilter2D();filter.SetLayerMask(1<<8);var hits=new Collider2D[32];int n=Physics2D.OverlapBox(body.position+box.offset,box.size*.94f,0,filter,hits);return hits.Take(n).Any(c=>c.GetComponentInParent<ArchitectureBuilding>()!=null);}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(freePoint);start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.12f);}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Architecture Lab Play");var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();bool castle=house.Id.Contains("castle"),rural=house.Id.Contains("rural");Output="Docs/Validation/ValdoriaWorldStudio09/"+(castle?"Castle":rural?"House":"Barn")+"QA";freePoint=castle?new Vector2(12,30):new Vector2(28,3);if(Directory.Exists(Output))throw new IOException("Refuse Architecture QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("VisualDirection09QA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  var data=JObject.Parse(File.ReadAllText((rural?ArchitectureArt07RImporter.Source:"ArtSource/Labs/World2026/WorldStudio08/"+(castle?"Castle/ReviewV1/":"Barn/RegionV1/"))+"house.json"));float height=(float)data["sizeUnits"][1];Func<JToken,Vector2> point=p=>new Vector2((float)p[0],height-(float)p[1]);
  Action context=()=>{follow.enabled=false;camera.orthographicSize=castle?24:14.5f;camera.transform.position=castle?new Vector3(34,65,-10):new Vector3(house.transform.position.x,15.5f,-10);};
  var visual=UnityEngine.Object.FindAnyObjectByType<VisualUnificationLab>();
  for(int i=0;i<3;i++)
  {
   int selected=i;var key=i==0?Key.Digit1:i==1?Key.Digit2:Key.Digit3;
   Add(.15f,()=>{context();Place(house.Approach);held=new[]{key};});
   Add(.65f,()=>held=Array.Empty<Key>(),()=>{Result("ABC material references "+selected,visual.Stage==selected,new{stage=visual.Stage,actor=body.position.ToString(),camera=camera.transform.position.ToString(),ortho=camera.orthographicSize,persisted=visual.Stage==selected,performance=Performance()});Capture("00-"+"ABC"[selected]+"-same-pose");});Add(.25f);
  }
  Add(.15f,()=>follow.enabled=true);Move("W",new[]{Key.W});Move("A",new[]{Key.A});Move("S",new[]{Key.S});Move("D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
  Add(.4f,()=>{Place(freePoint);dodged=false;held=new[]{Key.D,Key.Space};},()=>{held=Array.Empty<Key>();Result("Dodge Input System",dodged,new{observed=dodged});});Add(.5f);
  Add(.6f,()=>{context();Place(house.Approach);},()=>Capture("01-context-front"));Add(.25f);
  var route=castle?data["courtyardRoute"].Select(point).ToList():data["access"]["points"].Select(point).Reverse().ToList();float length=0;for(int i=1;i<route.Count;i++)length+=Vector2.Distance(route[i-1],route[i]);
  Add(.3f,()=>{Place(route[0]);follow.enabled=true;camera.orthographicSize=11.25f;});
  Add(length/3.1f+2,()=>{style=castle?"castle":rural?"house":"barn";path=route;waypoint=1;following=true;motion=true;captures=0;nextCapture=Time.timeAsDouble+.2;},()=>{following=false;motion=false;held=Array.Empty<Key>();Result(castle?"Open gate to courtyard and keep approach":"Road to barn door",Vector2.Distance(body.position,route.Last())<.5f&&!Penetration(),new{point=body.position.ToString(),target=route.Last().ToString(),length,captures,noPenetration=!Penetration()});Capture("02-arrival");});Add(.25f);
  if(castle){Add(.7f,()=>{context();Place(point(data["poses"]["courtyard"]));},()=>{var keep=house.GetComponentsInChildren<ReferenceHouseDepth>().Single(d=>d.name.StartsWith("Keep "));var gate=house.GetComponentsInChildren<ReferenceHouseDepth>().Single(d=>d.name.StartsWith("Gate "));var actorOrder=animator.Body.GetComponentInParent<SortingGroup>().sortingOrder;Result("Courtyard between opaque keep and cutaway gate",keep.RoofAlpha>.99f&&gate.RoofAlpha<.25f&&actorOrder>keep.GetComponent<SortingGroup>().sortingOrder&&actorOrder<gate.GetComponent<SortingGroup>().sortingOrder&&!Penetration(),new{actor=body.position.ToString(),keepAlpha=keep.RoofAlpha,gateAlpha=gate.RoofAlpha,actorOrder});Capture("03-courtyard-depth");});Add(.25f);}
  Add(.5f,()=>{Place(castle?point(data["poses"]["keepDoor"]):house.Approach);camera.orthographicSize=11.25f;camera.transform.position=new Vector3(body.position.x,body.position.y+4,-10);start=body.position;});
  Add(.9f,()=>held=castle?new[]{Key.W}:new[]{Key.W,Key.D},()=>{held=Array.Empty<Key>();Result("Closed building wall collision",Vector2.Distance(start,body.position)<2.5f&&!Penetration(),new{from=start.ToString(),to=body.position.ToString(),noPenetration=!Penetration()});Capture("04-door-collision");});Add(.25f);
  Add(.6f,()=>{context();Place(castle?point(data["poses"]["side"]):rural?new Vector2(41.8f,5.35f):new Vector2(48,3.4f));},()=>{Result("Side foot outside physical building",!Penetration(),new{actor=body.position.ToString()});Capture("05-side");});Add(.25f);
  Add(.7f,()=>{context();Place(castle?point(data["poses"]["behind"]):rural?new Vector2(38,13):new Vector2(41.8f,11.6f));},()=>{var depths=house.GetComponentsInChildren<ReferenceHouseDepth>();Result("Behind building volume cutaway",depths.Any(d=>d.CutawayActive&&d.RoofAlpha<.25f)&&!Penetration(),new{actor=body.position.ToString(),volumes=depths.Select(d=>new{name=d.name,alpha=d.RoofAlpha,active=d.CutawayActive}).ToArray(),noPenetration=!Penetration()});Capture("06-behind");});Add(.25f);
  Add(.6f,()=>{Place(house.Approach);camera.orthographicSize=11.25f;camera.transform.position=castle?new Vector3(36,77,-10):rural?new Vector3(34,22.2f,-10):new Vector3(39,21,-10);},()=>Capture("07-roof-native"));Add(.25f);
  Add(.5f,()=>{camera.transform.position=castle?new Vector3(32,53,-10):rural?new Vector3(32.7f,10.1f,-10):new Vector3(40,7,-10);},()=>{Capture("08-walls-native");Result("Rendered native detail and performance",camera.pixelHeight==720,new{ppu=32,ortho=camera.orthographicSize,pixelRatio=camera.pixelHeight/(2*camera.orthographicSize*32),drawCalls=UnityStats.drawCalls,renderers=UnityEngine.Object.FindObjectsByType<Renderer>().Length});});Add(.25f);
  Add(.65f,()=>{visual.Apply(2,true);context();Place(house.Approach);},()=>Capture("09-weathered-variant"));Add(.25f);
  Add(.3f,()=>{visual.Apply(2,false);context();Place(house.Approach);});
  EditorApplication.update+=Tick;return "Real Input System QA started for "+house.Id;
 }
 static object Performance()
 {
  var renderers=UnityEngine.Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();
  var textures=renderers.SelectMany(r=>r is SpriteRenderer s&&s.sprite?new[]{s.sprite.texture}:r.sharedMaterials.Where(m=>m&&m.mainTexture is Texture2D).Select(m=>(Texture2D)m.mainTexture)).Distinct().ToArray();
  var visible=renderers.Count(r=>r.isVisible);return new{drawCalls=UnityStats.drawCalls,renderers=renderers.Length,visible,textureCount=textures.Length,textureBytes=textures.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)),textures=textures.Select(t=>new{name=t.name,t.width,t.height,bytes=UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t)}).ToArray()};
 }
 static void Tick()
 {
  try{
   if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double time=Time.timeAsDouble;if(body.GetComponent<ActorHealth>().State.IsDodging(time))dodged=true;
   if(following){while(waypoint<path.Count&&Vector2.Distance(body.position,path[waypoint])<.19f)waypoint++;if(waypoint>=path.Count)held=Array.Empty<Key>();else{var delta=path[waypoint]-body.position;var keys=new List<Key>();if(Mathf.Abs(delta.x)>.085f)keys.Add(delta.x>0?Key.D:Key.A);if(Mathf.Abs(delta.y)>.085f)keys.Add(delta.y>0?Key.W:Key.S);held=keys.ToArray();}}
   if(held.Length==0&&!following)animator.SetPreviewFacing(0);
   if(time>=nextTrace){nextTrace=time+.08;trace.Add(new{frame=Time.frameCount,time,x=body.position.x,y=body.position.y,animation=animator.State,held=string.Join(",",held),style,camera=camera.transform.position.ToString()});}
   if(motion&&captures<20&&time>=nextCapture){string file="Motion/"+style+"-"+captures.ToString("00")+".png";Capture(file);trace.Add(new{capture=file,frame=Time.frameCount,time,camera=camera.transform.position.ToString(),width=camera.pixelWidth,height=camera.pixelHeight});captures++;nextCapture=time+.10;}
   if(current!=null&&time<until)return;current?.end?.Invoke();if(steps.Count==0){Finish(null);return;}current=steps.Dequeue();current.begin?.Invoke();until=time+current.seconds;
  }catch(Exception e){Finish(e.ToString());}
 }
 static void Finish(string error)
 {
  EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;
  File.WriteAllText(Output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace},Formatting.Indented));
 }
}
