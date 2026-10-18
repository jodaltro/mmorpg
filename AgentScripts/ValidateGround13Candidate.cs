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
public static class ValidateGround13Candidate
{
 sealed class Step{public float seconds;public Action begin,end;}
 static Queue<Step> queue=new Queue<Step>();static List<object> results=new List<object>(),trace=new List<object>();static List<InputDevice> disabled=new List<InputDevice>();
 static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();
 static Rigidbody2D body;static ProductionSpriteAnimator animator;static Camera camera;static CameraFollow follow;static Ground13Lab lab;static Step current;static double until,began,nextCapture;static int first,last,captures;static bool motion,dodged;static Vector2 start;
 const string Output="Docs/Validation/ValdoriaGround13/Original/GameplayCandidate";
 static List<Vector2> route;static int waypoint;static bool following;
 static void Add(float t,Action begin=null,Action end=null)=>queue.Enqueue(new Step{seconds=t,begin=begin,end=end});
 static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
 static void Place(Vector2 p){held=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Capture(string name)=>ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+name+".png"));
 static void Context(){follow.enabled=false;camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(28.5f,14.25f,-10);}
 static void Move(string name,Key[] keys){Add(.45f,()=>{Place(new Vector2(28,3));start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.65f,new{from=start.ToString(),to=body.position.ToString()});});Add(.15f);}
 static object Performance(){var rr=UnityEngine.Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();var tt=rr.SelectMany(r=>r is SpriteRenderer s&&s.sprite?new[]{s.sprite.texture}:r.sharedMaterials.Where(m=>m&&m.mainTexture is Texture2D).Select(m=>(Texture2D)m.mainTexture)).Distinct().ToArray();return new{drawCalls=UnityStats.drawCalls,renderers=rr.Length,visible=rr.Count(r=>r.isVisible),textureCount=tt.Length,textureBytes=tt.Sum(t=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t))};}
 static object Navigation(){var n=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int mismatch=0;for(int y=0;y<n.Height;y++)for(int x=0;x<n.Width;x++){bool blocked=Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f),1<<8)!=null;if(blocked==n.CellWalkable(x,y))mismatch++;}return new{samples=n.Width*n.Height,mismatch};}
 static int NavMismatch(){var n=UnityEngine.Object.FindAnyObjectByType<ArchitectureRegionData>();Physics2D.SyncTransforms();int m=0;for(int y=0;y<n.Height;y++)for(int x=0;x<n.Width;x++)if((Physics2D.OverlapPoint(new Vector2((x+.5f)*.25f,48-(y+.5f)*.25f),1<<8)!=null)==n.CellWalkable(x,y))m++;return m;}
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated nature Play");if(Directory.Exists(Output))throw new IOException("Refuse QA overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
  body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();lab=UnityEngine.Object.FindAnyObjectByType<Ground13Lab>();previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
  foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Ground13QA");InputSystem.onBeforeUpdate+=Feed;first=Time.frameCount;began=Time.timeAsDouble;
  var house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>();
  var data=JObject.Parse(File.ReadAllText(ArchitectureArt07RImporter.Source+"house.json"));route=data["access"]["points"].Select(p=>new Vector2((float)p[0],48-(float)p[1])).Reverse().ToList();
  for(int i=0;i<2;i++){int selected=i;Add(.15f,()=>{Context();Place(house.Approach);held=new[]{selected==0?Key.Digit1:Key.Digit4};});Add(.6f,()=>held=Array.Empty<Key>(),()=>{Result("Presentation stage "+selected,lab.Stage==(selected==1?3:0),new{stage=lab.Stage,performance=Performance()});Capture(selected==0?"00-before":"01-final");});Add(.3f);}
  Add(.2f,()=>lab.Select(0),()=>Result("Before navigation physics",NavMismatch()==0,Navigation()));Add(.2f,()=>lab.Select(3),()=>Result("After navigation physics",NavMismatch()==0,Navigation()));
  Move("W",new[]{Key.W});Move("A",new[]{Key.A});Move("S",new[]{Key.S});Move("D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
  Add(.4f,()=>{Place(new Vector2(28,3));dodged=false;held=new[]{Key.D,Key.Space};},()=>{held=Array.Empty<Key>();Result("Dodge",dodged,new{observed=dodged});});Add(.5f);
  Add(.4f,()=>{Place(new Vector2(14.5f,4.8f));camera.orthographicSize=7.03125f;camera.transform.position=new Vector3(14,11,-10);start=body.position;});Add(.7f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Tree trunk collision",body.position.y<5.65f&&body.position.y>start.y,new{from=start.ToString(),to=body.position.ToString(),radius=.5});Capture("04-tree-front-collision");});Add(.3f);
  Add(.5f,()=>Place(new Vector2(13.4f,7.5f)),()=>{var tree=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Single(p=>p.InstanceId=="A/oak/26/00026");var t=tree.GetComponentInChildren<SortingGroup>();int order=animator.Body.GetComponentInParent<SortingGroup>().sortingOrder;Result("Tree behind canopy",order<t.sortingOrder,new{actorOrder=order,treeOrder=t.sortingOrder});Capture("05-tree-behind");});Add(.3f);
  Add(.4f,()=>{Place(new Vector2(13.4f,4.7f));start=body.position;});Add(.9f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Pass beside trunk under visual crown",body.position.y>start.y+2.5f,new{from=start.ToString(),to=body.position.ToString()});});Add(.3f);
  Add(.5f,()=>{Place(new Vector2(10.5f,1.8f));camera.transform.position=new Vector3(11,7.03125f,-10);start=body.position;});Add(.7f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Boulder footprint collision",body.position.y<2.8f&&body.position.y>start.y,new{from=start.ToString(),to=body.position.ToString()});Capture("06-rock-front");});Add(.3f);
  Add(.6f,()=>Place(new Vector2(10.5f,5.1f)),()=>{var rock=GameObject.Find("reference-boulder");int order=animator.Body.GetComponentInParent<SortingGroup>().sortingOrder,stone=rock.GetComponentInChildren<SortingGroup>().sortingOrder;Result("Boulder depth",order<stone,new{actorOrder=order,stoneOrder=stone});Capture("07-rock-behind");});Add(.3f);
  Add(.6f,()=>{Place(house.Approach);Context();},()=>Capture("08-house-preserved"));Add(.3f);
  Add(.2f,()=>{Place(route[0]);waypoint=1;following=true;});Add(7,null,()=>{following=false;held=Array.Empty<Key>();Result("Road to preserved house entrance",Vector2.Distance(body.position,route.Last())<.5f,new{point=body.position.ToString(),target=route.Last().ToString()});});Add(.3f);
  Add(.5f,()=>{Place(new Vector2(41.8f,5.35f));},()=>Capture("09-house-side"));Add(.3f);
  Add(.7f,()=>Place(new Vector2(38,13)),()=>{Result("House cutaway preserved",house.GetComponentsInChildren<ReferenceHouseDepth>().Any(d=>d.CutawayActive&&d.RoofAlpha<.25f),new{actor=body.position.ToString()});Capture("10-house-behind");});Add(.3f);
  Add(.6f,()=>{Place(house.Approach);camera.orthographicSize=7.03125f;camera.transform.position=new Vector3(13,12.5f,-10);},()=>Capture("11-canopy-detail"));Add(.3f);
  Add(.6f,()=>camera.transform.position=new Vector3(13,7.03125f,-10),()=>Capture("12-trunks-rocks-transitions"));Add(.3f);
  Add(.6f,()=>camera.transform.position=new Vector3(30,7.03125f,-10),()=>Capture("13-entry-transition"));Add(.3f);
  Add(.2f,()=>{Place(new Vector2(12,18.5f));start=body.position;});Add(1.4f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();Result("Ford retained",body.position.y>start.y+3,new{from=start.ToString(),to=body.position.ToString()});});Add(.3f);
  Add(.2f,()=>{Place(new Vector2(9.5f,18.4f));start=body.position;});Add(1.45f,()=>held=new[]{Key.D},()=>{held=Array.Empty<Key>();Result("Water bank circulation retained",body.position.x>start.x+4,new{from=start.ToString(),to=body.position.ToString()});});Add(.3f);
  var legacyTree=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Single(t=>t.InstanceId=="A/oak/00/00000");var tp=(Vector2)legacyTree.transform.position;
  Add(.3f,()=>{Place(tp+new Vector2(0,-1.5f));start=body.position;camera.transform.position=new Vector3(tp.x,tp.y+3,-10);camera.orthographicSize=7.03125f;});Add(.65f,()=>held=new[]{Key.W},()=>{held=Array.Empty<Key>();float gap=Vector2.Distance(body.position,tp);Result("Refined legacy trunk collision",gap>.3f&&gap<1,new{gap,radius=legacyTree.FootprintRadius});Capture("legacy-trunk-contact");});Add(.2f);
  Add(.6f,()=>Place(tp+new Vector2(.65f,1)),()=>{var sorting=legacyTree.transform.Find("Ground12 authored replacement graphics").GetComponentInChildren<SortingGroup>();int order=animator.Body.GetComponentInParent<SortingGroup>().sortingOrder;Result("Refined legacy tree behind",order<sorting.sortingOrder,new{actor=order,tree=sorting.sortingOrder});Capture("legacy-tree-behind");});Add(.2f);
  Add(.6f,()=>Place(tp+new Vector2(0,-1)),()=>{var sorting=legacyTree.transform.Find("Ground12 authored replacement graphics").GetComponentInChildren<SortingGroup>();int order=animator.Body.GetComponentInParent<SortingGroup>().sortingOrder;Result("Refined legacy tree front",order>sorting.sortingOrder,new{actor=order,tree=sorting.sortingOrder});Capture("legacy-tree-front");});Add(.2f);
  var animWater=UnityEngine.Object.FindObjectsByType<WaterSurfaceAnimator>();int[] waterFrames=null;Add(.1f,()=>waterFrames=animWater.Select(w=>w.FrameIndex).ToArray());Add(.23f,null,()=>Result("Water replay advances",animWater.Where((w,i)=>w.FrameIndex!=waterFrames[i]).Any(),new{frames=animWater.Select(w=>w.FrameIndex).ToArray()}));
  Add(.2f,()=>{Place(new Vector2(26,18.75f));camera.orthographicSize=14.0625f;follow.enabled=true;motion=true;captures=0;nextCapture=Time.timeAsDouble+.1;held=new[]{Key.D};});Add(4.5f,null,()=>{held=Array.Empty<Key>();motion=false;Result("Camera motion",captures==20,new{captures,camera=camera.transform.position.ToString()});});Add(.3f);
  Add(.6f,()=>{Context();Place(house.Approach);},()=>{Capture("14-final-context");Result("Final performance",camera.pixelHeight==900,new{performance=Performance(),width=camera.pixelWidth,height=camera.pixelHeight,pixelRatio=camera.pixelHeight/(2*camera.orthographicSize*32)});});Add(.4f);
  for(int state=0;state<2;state++){bool value=state==1;Add(.7f,()=>{lab.Select(value?3:0);Place(new Vector2(38,25));follow.enabled=false;camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(39,24,-10);},()=>{Capture("15-second-area-"+(!value?"before":"after"));Result("Second area same component "+value,lab.Stage==(value?3:0),new{stage=lab.Stage,actor=body.position.ToString(),camera=camera.transform.position.ToString()});});Add(.3f);}
  Add(.2f,()=>{lab.Select(3);Context();Place(house.Approach);});
  EditorApplication.update+=Tick;return "Ground finishing Play QA queued";
 }
 static void Tick(){try{if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double time=Time.timeAsDouble;if(body.GetComponent<ActorHealth>().State.IsDodging(time))dodged=true;if(following){while(waypoint<route.Count&&Vector2.Distance(body.position,route[waypoint])<.19f)waypoint++;var k=new List<Key>();if(waypoint<route.Count){var d=route[waypoint]-body.position;if(Mathf.Abs(d.x)>.085f)k.Add(d.x>0?Key.D:Key.A);if(Mathf.Abs(d.y)>.085f)k.Add(d.y>0?Key.W:Key.S);}held=k.ToArray();}trace.Add(new{frame=last,time,x=body.position.x,y=body.position.y,held=string.Join(",",held),camera=camera.transform.position.ToString()});if(held.Length==0)animator.SetPreviewFacing(0);if(motion&&captures<20&&time>=nextCapture){Capture("Motion/frame-"+captures.ToString("00"));captures++;nextCapture=time+.10;}if(current!=null&&time<until)return;current?.end?.Invoke();if(queue.Count==0){Finish(null);return;}current=queue.Dequeue();current.begin?.Invoke();until=time+current.seconds;}catch(Exception e){Finish(e.ToString());}}
 static void Finish(string error){EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;File.WriteAllText(Output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace},Formatting.Indented));}
}
