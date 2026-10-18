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
public static class ValidateEnvironmentDirection09
{
 sealed class Step{public float seconds;public Action begin,end;}
 static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static ProductionSpriteAnimator animator;static VisualUnificationLab lab;static VegetationAnchor tree;static Step current;static double until,began,nextTrace,nextCapture;static int first,last,captures,style;static bool motion,dodged;static Vector2 start;static SpriteRenderer canopy;
 const string Output="Docs/Validation/ValdoriaWorldStudio09/EnvironmentQA";
 static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 p){held=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+(name.EndsWith(".png")?name:name+".png")));}
 static bool TreePenetration(){var box=body.GetComponent<BoxCollider2D>();var filter=new ContactFilter2D();filter.SetLayerMask(1<<8);var hits=new Collider2D[16];int n=Physics2D.OverlapBox(body.position+box.offset,box.size*.96f,0,filter,hits);return hits.Take(n).Any(c=>c.GetComponent<VegetationAnchor>()!=null);}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(new Vector2(14.5f,17));start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.12f);}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Vegetation Lab Play");if(Directory.Exists(Output))throw new IOException("Refuse vegetation QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  lab=UnityEngine.Object.FindAnyObjectByType<VisualUnificationLab>();body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("VisualEnvironment09QA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  Add(.2f,()=>{lab.Apply(2);Camera.main.orthographicSize=11.25f;Camera.main.GetComponent<CameraFollow>().enabled=true;tree=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Where(t=>t.FootprintRadius>0&&t.transform.position.x<18&&t.transform.position.y>20).OrderBy(t=>t.InstanceId).First();canopy=tree.GetComponentsInChildren<SpriteRenderer>().Single(r=>r.name=="crown");Place((Vector2)tree.transform.position+new Vector2(0,-1.2f));});
  Add(.9f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Trunk collision",body.position.y<tree.transform.position.y-.2f&&body.position.y>tree.transform.position.y-.9f&&!TreePenetration(),new{position=body.position.ToString(),tree=tree.transform.position.ToString(),radius=tree.FootprintRadius,noPenetration=!TreePenetration()});Capture("B-trunk-contact");});Add(.2f);
  Add(.15f,()=>{Place((Vector2)tree.transform.position+new Vector2(-.75f,-1.5f));body.GetComponent<ActorMotor>().Aim(Vector2.down);},()=>{var group=tree.GetComponentInChildren<UnityEngine.Rendering.SortingGroup>();var player=animator.Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>();Result("Actor in front of trunk and crown",player.sortingOrder>group.sortingOrder,new{playerOrder=player.sortingOrder,treeOrder=group.sortingOrder,point=body.position.ToString()});Capture("B-front-tree");});
  Add(1.0f,()=>{start=body.position;held=new[]{Key.W};},()=>{held=Array.Empty<Key>();Result("Walk beside narrow trunk under canopy",body.position.y-start.y>3&&!TreePenetration(),new{from=start.ToString(),to=body.position.ToString(),noCanopyCollider=tree.GetComponentsInChildren<Collider2D>().Length==1});body.GetComponent<ActorMotor>().Aim(Vector2.down);});Add(.16f,null,()=>{var group=tree.GetComponentInChildren<UnityEngine.Rendering.SortingGroup>();var player=animator.Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>();Result("Actor behind crown",player.sortingOrder<group.sortingOrder,new{playerOrder=player.sortingOrder,treeOrder=group.sortingOrder,point=body.position.ToString()});Capture("B-behind-tree");});
  Add(.18f);Add(.12f,()=>canopy.enabled=false,()=>Capture("B-behind-canopy-hidden-reference"));Add(.18f);Add(.12f,()=>canopy.enabled=true);
  for(int i=2;i<3;i++)
  {
   int selection=i;
   Add(.15f,()=>{style=selection;lab.Apply(style);Place(new Vector2(12,18.5f));});
   Add(1.4f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("ABC"[selection]+" ford retained",body.position.y>22.5f&&!TreePenetration(),new{position=body.position.ToString(),noPenetration=!TreePenetration()});Capture("ABC"[selection]+"-ford");});Add(.15f);
   Add(1.45f,()=>{Place(new Vector2(9.5f,18.4f));start=body.position;held=new[]{Key.D};},()=>{held=Array.Empty<Key>();Result("ABC"[selection]+" bank circulation",body.position.x-start.x>4&&!TreePenetration(),new{from=start.ToString(),to=body.position.ToString()});});Add(.15f);
   Add(3.55f,()=>{Place(new Vector2(16.5f,18.5f));motion=true;captures=0;nextCapture=Time.timeAsDouble+.9;held=new[]{Key.D};},()=>{held=Array.Empty<Key>();motion=false;Result("ABC"[selection]+" camera walk",captures==12&&body.position.x>22&&!TreePenetration(),new{captures,position=body.position.ToString()});});Add(.15f);
  }
  Add(.15f,()=>{lab.Apply(2);Place(new Vector2(12,23));});EditorApplication.update+=Tick;return "Direction09 ecology QA: trunk, front/back sorting, canopy passage, ford, banks and 12 motion frames";
 }
 static void Tick()
 {
  try{
   if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double time=Time.timeAsDouble;if(body.GetComponent<ActorHealth>().State.IsDodging(time))dodged=true;
   if(time>=nextTrace){nextTrace=time+.08;trace.Add(new{frame=Time.frameCount,time,x=body.position.x,y=body.position.y,animation=animator.State,held=string.Join(",",held),style=lab.Stage,before=lab.Stage==0,camera=Camera.main.transform.position.ToString()});}
   if(motion&&captures<12&&time>=nextCapture){string file="Motion/"+"ABC"[style]+"-"+captures.ToString("00")+".png";Capture(file);trace.Add(new{capture=file,frame=Time.frameCount,time,camera=Camera.main.transform.position.ToString(),width=Camera.main.pixelWidth,height=Camera.main.pixelHeight});captures++;nextCapture=time+.10;}
   if(current!=null&&time<until)return;current?.end?.Invoke();if(steps.Count==0){Finish(null);return;}current=steps.Dequeue();current.begin?.Invoke();until=time+current.seconds;
  }catch(Exception e){Finish(e.ToString());}
 }
 static void Finish(string error)
 {
  EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(canopy!=null)canopy.enabled=true;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;
  File.WriteAllText(Output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace},Formatting.Indented));
 }
}
