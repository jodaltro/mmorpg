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
public static class ValidateArchitecture07
{
 sealed class Step{public float seconds;public Action begin,end;}
 static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static ProductionSpriteAnimator animator;static Step current;static double until,began,nextTrace,nextCapture;static int first,last,captures,waypoint;static bool motion,dodged,following;static Vector2 start;static List<Vector2> path;static string style;static Camera camera;static CameraFollow follow;
 const string Output="Docs/Validation/ValdoriaWorldStudio07/Final/PlayQA";
 static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 p){held=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name)=>ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+(name.EndsWith(".png")?name:name+".png")));
 static bool Penetration(){var box=body.GetComponent<BoxCollider2D>();var filter=new ContactFilter2D();filter.SetLayerMask(1<<8);var hits=new Collider2D[32];int n=Physics2D.OverlapBox(body.position+box.offset,box.size*.94f,0,filter,hits);return hits.Take(n).Any(c=>c.GetComponentInParent<ArchitectureBuilding>()!=null);}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(new Vector2(28,17));start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.12f);}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Architecture Lab Play");if(Directory.Exists(Output))throw new IOException("Refuse Architecture QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("ArchitectureQA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  Add(.15f,()=>follow.enabled=true);Move("W",new[]{Key.W});Move("A",new[]{Key.A});Move("S",new[]{Key.S});Move("D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
  Add(.4f,()=>{Place(new Vector2(28,17));dodged=false;held=new[]{Key.D,Key.Space};},()=>{held=Array.Empty<Key>();Result("Dodge Input System",dodged,new{observed=dodged});});Add(.5f);
  var build=JObject.Parse(File.ReadAllText(ArchitectureStudioImporter.Source+"architecture.json"));
  foreach(var b in build["buildings"])
  {
   string id=(string)b["id"],kind=(string)b["archetype"];var house=UnityEngine.Object.FindObjectsByType<ArchitectureBuilding>().Single(h=>h.Id==id);var root=house.transform.position;var occlusion=house.GetComponent<ArchitectureOcclusion>();float depth=(float)b["dimensions"]["depth"];float maxX=b["footprint"].Min(p=>(float)p[0]);var localPath=b["access"]["points"].Select(p=>new Vector2((float)p[0],48-(float)p[1])).Reverse().ToList();float length=0;for(int i=1;i<localPath.Count;i++)length+=Vector2.Distance(localPath[i-1],localPath[i]);
   Add(.2f,()=>{style=kind;follow.enabled=true;camera.orthographicSize=11.25f;Place(localPath[0]);});
   Add(length/3.2f+2,()=>{path=localPath;waypoint=1;following=true;captures=0;motion=true;nextCapture=Time.timeAsDouble+.25;},()=>{following=false;motion=false;held=Array.Empty<Key>();Result(kind+" road to door access",Vector2.Distance(body.position,localPath.Last())<.5f&&!Penetration(),new{point=body.position.ToString(),target=localPath.Last().ToString(),length,captures,noPenetration=!Penetration()});});Add(.2f);
   Add(.4f,()=>{follow.enabled=false;camera.transform.position=new Vector3(root.x,root.y+3.4f,-10);Place(house.Approach+Vector2.down*.7f);body.GetComponent<ActorMotor>().Aim(Vector2.down);},()=>{var player=animator.Body.GetComponentInParent<SortingGroup>();var group=house.GetComponentInChildren<SortingGroup>();Result(kind+" front sorting and opaque roof",player.sortingOrder>group.sortingOrder&&occlusion.RoofAlpha>.99f,new{actor=body.position.ToString(),roofAlpha=occlusion.RoofAlpha,playerOrder=player.sortingOrder,houseOrder=group.sortingOrder,camera=camera.transform.position.ToString(),drawCalls=UnityEditor.UnityStats.drawCalls,renderers=UnityEngine.Object.FindObjectsByType<Renderer>().Length,activePlants=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Length,bodyBounds=animator.Body.bounds.size.ToString(),sprite=animator.Body.sprite.name,visualScale=animator.Body.transform.lossyScale.ToString()});Capture(kind+"-front");});Add(.2f);
   Add(.9f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result(kind+" closed wall collision",body.position.y<house.Entrance.y+.08f&&body.position.y>house.Entrance.y-.8f&&!Penetration(),new{actor=body.position.ToString(),door=house.Entrance.ToString(),noPenetration=!Penetration()});Capture(kind+"-door-contact");});Add(.2f);
   Add(.4f,()=>{Place(new Vector2(maxX-.85f,root.y-.1f));body.GetComponent<ActorMotor>().Aim(Vector2.down);},()=>Capture(kind+"-side"));Add(.2f);
   Add(1.4f,()=>{Place(new Vector2(maxX-.85f,root.y-2.6f));start=body.position;follow.enabled=true;held=new[]{Key.W};},()=>{held=Array.Empty<Key>();Result(kind+" walk beside walls",body.position.y-start.y>4&&!Penetration(),new{from=start.ToString(),to=body.position.ToString()});});Add(.2f);
   Add(.5f,()=>{follow.enabled=false;camera.transform.position=new Vector3(root.x,root.y+3.4f,-10);Place(new Vector2(root.x+.6f,root.y+depth/4+.85f));body.GetComponent<ActorMotor>().Aim(Vector2.down);},()=>{var player=animator.Body.GetComponentInParent<SortingGroup>();var group=house.GetComponentInChildren<SortingGroup>();Result(kind+" behind roof cutaway",player.sortingOrder<group.sortingOrder&&occlusion.Occluding&&occlusion.RoofAlpha<.25f&&!Penetration(),new{actor=body.position.ToString(),playerOrder=player.sortingOrder,houseOrder=group.sortingOrder,roofAlpha=occlusion.RoofAlpha,occluding=occlusion.Occluding});Capture(kind+"-behind");});Add(.2f);
  }
  Add(.2f,()=>{follow.enabled=true;Place(new Vector2(12,18.5f));});Add(1.4f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Ford retained after architecture exclusions",body.position.y>22.5f&&!Penetration(),new{point=body.position.ToString()});Capture("ford-retained");});Add(.2f);
  Add(1.45f,()=>{Place(new Vector2(9.5f,18.4f));start=body.position;held=new[]{Key.D};},()=>{held=Array.Empty<Key>();Result("Bank circulation after ecotone merge",body.position.x-start.x>4&&!Penetration(),new{from=start.ToString(),to=body.position.ToString()});});Add(.2f);
  Add(.2f,()=>{follow.enabled=true;Place(new Vector2(28,17));});EditorApplication.update+=Tick;return "Architecture real Input System: road approaches, closed walls, front/side/behind, roof cutaway and motion sequences";
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
