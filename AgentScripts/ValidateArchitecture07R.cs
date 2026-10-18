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
public static class ValidateArchitecture07R
{
 sealed class Step{public float seconds;public Action begin,end;}
 static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static ProductionSpriteAnimator animator;static Step current;static double until,began,nextTrace,nextCapture;static int first,last,captures,waypoint;static bool motion,dodged,following;static Vector2 start;static List<Vector2> path;static string style;static Camera camera;static CameraFollow follow;
 const string Output="Docs/Validation/ValdoriaWorldStudio07R/PlayQA";
 static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 p){held=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name)=>ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+(name.EndsWith(".png")?name:name+".png")));
 static bool Penetration(){var box=body.GetComponent<BoxCollider2D>();var filter=new ContactFilter2D();filter.SetLayerMask(1<<8);var hits=new Collider2D[32];int n=Physics2D.OverlapBox(body.position+box.offset,box.size*.94f,0,filter,hits);return hits.Take(n).Any(c=>c.GetComponentInParent<ArchitectureBuilding>()!=null);}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(new Vector2(28,3));start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.12f);}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Architecture Lab Play");if(Directory.Exists(Output))throw new IOException("Refuse Architecture QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Architecture07RQA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();var depth=house.GetComponent<ReferenceHouseDepth>();var root=house.transform.position;
  Action context=()=>{follow.enabled=false;camera.orthographicSize=14.5f;camera.transform.position=new Vector3(32,16,-10);};
  Add(.15f,()=>follow.enabled=true);Move("W",new[]{Key.W});Move("A",new[]{Key.A});Move("S",new[]{Key.S});Move("D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
  Add(.4f,()=>{Place(new Vector2(28,3));dodged=false;held=new[]{Key.D,Key.Space};},()=>{held=Array.Empty<Key>();Result("Dodge Input System",dodged,new{observed=dodged});});Add(.5f);
  var data=JObject.Parse(File.ReadAllText(ArchitectureArt07RImporter.Source+"house.json"));var route=data["access"]["points"].Select(p=>new Vector2((float)p[0],48-(float)p[1])).Reverse().ToList();float length=0;for(int i=1;i<route.Count;i++)length+=Vector2.Distance(route[i-1],route[i]);
  Add(.25f,()=>{Place(route[0]);follow.enabled=true;camera.orthographicSize=14.5f;});
  Add(length/3.2f+2,()=>{style="reference";path=route;waypoint=1;following=true;motion=true;captures=0;nextCapture=Time.timeAsDouble+.2;},()=>{following=false;motion=false;held=Array.Empty<Key>();Result("Road to new door",Vector2.Distance(body.position,route.Last())<.5f&&!Penetration(),new{point=body.position.ToString(),target=route.Last().ToString(),length,captures});});Add(.2f);
  Add(.6f,()=>{context();Place(house.Approach);},()=>{var player=animator.Body.GetComponentInParent<SortingGroup>();var group=house.GetComponentInChildren<SortingGroup>();Result("Front sorting opaque",player.sortingOrder>group.sortingOrder&&depth.RoofAlpha>.99f,new{playerOrder=player.sortingOrder,houseOrder=group.sortingOrder,depthLine=depth.DepthLineY,roofAlpha=depth.RoofAlpha,bodyBounds=animator.Body.bounds.size.ToString(),sprite=animator.Body.sprite.name,visualScale=animator.Body.transform.lossyScale.ToString(),drawCalls=UnityStats.drawCalls,renderers=UnityEngine.Object.FindObjectsByType<Renderer>().Length});Capture("01-context-door");});Add(.25f);
  Add(.9f,()=>held=new[]{Key.W,Key.D},()=>{held=Array.Empty<Key>();Result("Closed front wall collision",Vector2.Distance(body.position,house.Entrance)<.9f&&!Penetration()&&body.position.y<depth.FrontAt(body.position.x),new{actor=body.position.ToString(),door=house.Entrance.ToString(),noPenetration=!Penetration()});Capture("02-door-contact");});Add(.25f);
  Add(.6f,()=>{Place(new Vector2(41.8f,5.35f));context();},()=>{Result("Side standing outside footprint",!Penetration(),new{actor=body.position.ToString(),depthLine=depth.DepthLineY});Capture("03-side");});Add(.25f);
  Add(.9f,()=>{Place(new Vector2(41.7f,4.8f));start=body.position;held=new[]{Key.D,Key.W};},()=>{held=Array.Empty<Key>();Result("Walk beside projected side wall",Vector2.Distance(start,body.position)>1.4f&&!Penetration(),new{from=start.ToString(),to=body.position.ToString()});});Add(.25f);
  Add(.8f,()=>{context();Place(new Vector2(38,13));},()=>{var player=animator.Body.GetComponentInParent<SortingGroup>();var group=house.GetComponentInChildren<SortingGroup>();Result("Behind volume cutaway",player.sortingOrder<group.sortingOrder&&depth.CutawayActive&&depth.RoofAlpha<.25f&&!Penetration(),new{actor=body.position.ToString(),depthLine=depth.DepthLineY,playerOrder=player.sortingOrder,houseOrder=group.sortingOrder,roofAlpha=depth.RoofAlpha,cutaway=depth.CutawayActive,noPenetration=!Penetration()});Capture("04-behind-cutaway");});Add(.25f);
  Add(.6f,()=>{Place(house.Approach);camera.orthographicSize=7.5f;camera.transform.position=new Vector3(34,22.2f,-10);},()=>Capture("05-roof-closeup"));Add(.25f);
  Add(.5f,()=>{camera.orthographicSize=7.5f;camera.transform.position=new Vector3(32.7f,10.1f,-10);},()=>Capture("06-walls-closeup"));Add(.25f);
  var old=UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects().Single(g=>g.name.StartsWith("REJECTED OLD A"));
  Add(.6f,()=>{old.SetActive(true);context();camera.transform.position=new Vector3(26.5f,16,-10);Place(house.Approach);},()=>Capture("07-old-new-same-scale"));Add(.25f);
  Add(.6f,()=>Place(new Vector2(9,6)),()=>Capture("08-old-door-character-same-camera"));Add(.25f);
  Add(.3f,()=>{old.SetActive(false);context();Place(house.Approach);});
  var hidden=new List<Renderer>();var clear=camera.clearFlags;var color=camera.backgroundColor;
  Add(.6f,()=>{foreach(var r in UnityEngine.Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&!r.transform.IsChildOf(house.transform))){hidden.Add(r);r.enabled=false;}camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.19f,.20f,.19f);},()=>Capture("09-isolated-unity"));Add(.25f);
  Add(.4f,()=>{foreach(var r in hidden)if(r)r.enabled=true;camera.clearFlags=clear;camera.backgroundColor=color;context();Place(house.Approach);});
  EditorApplication.update+=Tick;return "07R real Input System and rendered comparison sequence started";
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
