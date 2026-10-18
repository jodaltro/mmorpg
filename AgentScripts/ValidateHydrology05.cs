using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class ValidateHydrology05
{
 sealed class Step{public float seconds;public Action begin,end;}
 static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static ProductionSpriteAnimator animator;static HydrologyLabController lab;static Step current;static double until,began,nextTrace,nextCapture;static int first,last,captures;static bool motion,dodged;static Vector2 start;
 const string Output="Docs/Validation/ValdoriaWorldStudio05/Final/PlayQA";
 static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 point){held=Array.Empty<Key>();body.position=point;body.transform.position=point;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+name+".png"));}
 static bool WaterOverlap(){var own=body.GetComponent<BoxCollider2D>();var filter=new ContactFilter2D();filter.SetLayerMask(1<<8);var hits=new Collider2D[12];int count=Physics2D.OverlapBox(body.position+own.offset,own.size*.97f,0,filter,hits);return hits.Take(count).Any(c=>c.name.StartsWith("Water blockage"));}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(new Vector2(14.5f,17));start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.15f);}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Hydrology Lab Play");if(Directory.Exists(Output))throw new IOException("Refuse QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  lab=UnityEngine.Object.FindAnyObjectByType<HydrologyLabController>();body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("HydrologyQA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  Add(.2f,()=>{lab.SetWater(true);Camera.main.GetComponent<CameraFollow>().enabled=true;});
  Move("W",new[]{Key.W});Move("A",new[]{Key.A});Move("S",new[]{Key.S});Move("D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
  Add(.4f,()=>{Place(new Vector2(14.5f,17));dodged=false;held=new[]{Key.Space,Key.D};},()=>{held=Array.Empty<Key>();Result("Dodge Input System",dodged,new{observed=dodged});});Add(.6f);
  Add(1.5f,()=>{Place(new Vector2(10.5f,18.5f));held=new[]{Key.W};},()=>{held=Array.Empty<Key>();Result("Deep river collision",body.position.y>19&&body.position.y<20.5f&&!WaterOverlap(),new{position=body.position.ToString(),noPenetration=!WaterOverlap()});Capture("river-contact");});Add(.2f);
  Add(1.45f,()=>{Place(new Vector2(9.5f,18.4f));start=body.position;held=new[]{Key.D};},()=>{held=Array.Empty<Key>();Result("South bank circulation",body.position.x-start.x>4&&!WaterOverlap(),new{from=start.ToString(),to=body.position.ToString(),noPenetration=!WaterOverlap()});Capture("bank-walk");});Add(.2f);
  Add(.55f,()=>{Place(new Vector2(12,18.5f));held=new[]{Key.W};},()=>{Capture("ford-mid-crossing");var group=animator.Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>();var shadow=body.GetComponentsInChildren<Transform>().First(t=>t.name=="GroundShadow");Result("Ford feet and sorting",!WaterOverlap()&&Vector2.Distance(shadow.position,body.transform.position)<.001f&&Mathf.Abs(group.sortingOrder-(100-Mathf.RoundToInt(body.transform.position.y*16)))<=1,new{position=body.position.ToString(),shadowDelta=Vector2.Distance(shadow.position,body.transform.position),physicsToRenderDelta=Vector2.Distance(body.position,body.transform.position),renderGround=body.transform.position.ToString(),expectedSorting=100-Mathf.RoundToInt(body.transform.position.y*16),group.sortingOrder,animation=animator.State});});
  Add(.85f,null,()=>{held=Array.Empty<Key>();Result("Explicit shallow ford crosses river",body.position.y>22.5f&&!WaterOverlap(),new{position=body.position.ToString(),noSwimmingMechanic=true});Capture("ford-crossed");});Add(.2f);
  Add(1.4f,()=>{Place(new Vector2(10.5f,24.5f));held=new[]{Key.A};},()=>{held=Array.Empty<Key>();Result("Lake collision",body.position.x>7&&body.position.x<9.5f&&!WaterOverlap(),new{position=body.position.ToString(),noPenetration=!WaterOverlap()});Capture("lake-contact");});Add(.2f);
  Add(1.6f,()=>{Place(new Vector2(47.5f,10.5f));held=new[]{Key.W};},()=>{held=Array.Empty<Key>();Result("Shared rock collision",body.position.y>11&&body.position.y<13.5f,new{position=body.position.ToString()});Capture("shared-rock-contact");});Add(.2f);
  Add(3.55f,()=>{Place(new Vector2(16.5f,18.5f));motion=true;captures=0;nextCapture=Time.timeAsDouble+.9;held=new[]{Key.D};},()=>{held=Array.Empty<Key>();motion=false;Result("Camera motion and preauthored animation",captures==30,new{captures,final=body.position.ToString(),waterFrame=UnityEngine.Object.FindAnyObjectByType<WaterSurfaceAnimator>().FrameIndex});});Add(.25f);
  Add(.2f,()=>{lab.SetWater(false);Place(new Vector2(10.5f,18.5f));held=new[]{Key.W};});Add(1.2f,null,()=>{held=Array.Empty<Key>();Result("Dry toggle removes water collision and nav restriction",body.position.y>22&& !UnityEngine.Object.FindAnyObjectByType<EnvironmentRegionData>().WaterEnabled,new{position=body.position.ToString()});});
  Add(.1f,()=>{lab.SetWater(true);lab.ResetPose();});EditorApplication.update+=Tick;return "Hydrology QA: real keyboard movement, banks, deep collisions, ford, rock, 30 moving frames";
 }
 static void Tick()
 {
  try{
   if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double time=Time.timeAsDouble;if(body.GetComponent<ActorHealth>().State.IsDodging(time))dodged=true;
   if(time>=nextTrace){nextTrace=time+.08;trace.Add(new{frame=Time.frameCount,time,x=body.position.x,y=body.position.y,animation=animator.State,held=string.Join(",",held),water=lab.WaterEnabled,camera=Camera.main.transform.position.ToString(),waterFrame=UnityEngine.Object.FindAnyObjectByType<WaterSurfaceAnimator>()?.FrameIndex});}
   if(motion&&captures<30&&time>=nextCapture){string file="Motion/"+captures.ToString("00")+".png";Capture(file);trace.Add(new{capture=file,frame=Time.frameCount,time,camera=Camera.main.transform.position.ToString(),width=Camera.main.pixelWidth,height=Camera.main.pixelHeight,waterFrame=UnityEngine.Object.FindAnyObjectByType<WaterSurfaceAnimator>().FrameIndex});captures++;nextCapture=time+.08;}
   if(current!=null&&time<until)return;current?.end?.Invoke();if(steps.Count==0){Finish(null);return;}current=steps.Dequeue();current.begin?.Invoke();until=time+current.seconds;
  }catch(Exception e){Finish(e.ToString());}
 }
 static void Finish(string error)
 {
  EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;
  File.WriteAllText(Output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace},Formatting.Indented));
 }
}
