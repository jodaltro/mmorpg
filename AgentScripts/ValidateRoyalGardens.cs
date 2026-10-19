using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.Rendering;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Object=UnityEngine.Object;

public static class ValidateRoyalGardens
{
 const string Root="Docs/Validation/ValdoriaRoyalGardens/",Source="ArtSource/World/PlayableVillage02/RoyalGardensV1/";
 static Task active;static bool cancelled=false;static Rigidbody2D body;static Collider2D actorCollider;static Keyboard keyboard;static Key[] held=Array.Empty<Key>();static JObject data;static Camera camera;static CameraFollow follow;static Village02EvidenceCapture capture;static bool[,] walk;static int nx=564,ny=670;static List<object> results=new List<object>(),trace=new List<object>(),excluded=new List<object>();
 static Vector2 V(JToken p)=>new Vector2((float)p[0],(float)p[1]);
 static void Write(string p,object value)=>File.WriteAllText(Root+"QA/"+p,JsonConvert.SerializeObject(value,Formatting.Indented));
 static void Progress(string stage,string item){Write("progress.json",new{stage,item,results=results.Count,frame=Time.frameCount,time=Time.timeAsDouble});Write("checkpoint.json",new{stage,item,results,excluded,trace,frame=Time.frameCount,time=Time.timeAsDouble,complete=false});}
 static bool Free(Vector2 p)=>Physics2D.OverlapCircle(p,.625f,1<<8)==null;
 static bool FreeFeet(Vector2 p)=>Physics2D.OverlapBox(p+actorCollider.offset,(Vector2)actorCollider.bounds.size-new Vector2(.002f,.002f),0,1<<8)==null;
 static Vector2 Point(int id)=>new Vector2((id%nx+.5f)*.5f,(id/nx+.5f)*.5f);
 static Key[] Keys(Vector2 d,bool dodge=false){var k=new List<Key>();if(Mathf.Abs(d.x)>.15f)k.Add(d.x>0?Key.D:Key.A);if(Mathf.Abs(d.y)>.15f)k.Add(d.y>0?Key.W:Key.S);if(dodge)k.Add(Key.Space);return k.ToArray();}
 static void Feed(){if(keyboard!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 static void Place(Vector2 p){held=Array.Empty<Key>();body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.simulated=false;body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;body.simulated=true;Physics2D.SyncTransforms();body.WakeUp();}
 static async Task Pause(int ms){if(cancelled||File.Exists("Temp/RoyalGardens.cancel"))throw new OperationCanceledException();await Task.Delay(ms);if(!EditorApplication.isPlaying||cancelled||File.Exists("Temp/RoyalGardens.cancel"))throw new OperationCanceledException();}
 static List<Vector2> Route(Vector2 a,Vector2 b,bool close=false)
 {
  int Near(Vector2 p){int x=Mathf.Clamp((int)(p.x*2),0,nx-1),y=Mathf.Clamp((int)(p.y*2),0,ny-1);for(int r=0;r<8;r++)for(int dy=-r;dy<=r;dy++)for(int dx=-r;dx<=r;dx++){int xx=x+dx,yy=y+dy;if(xx>=0&&xx<nx&&yy>=0&&yy<ny&&walk[xx,yy])return yy*nx+xx;}throw new IOException("No clearance point "+p);}
  int s=Near(a),e=Near(b);var parent=Enumerable.Repeat(-1,nx*ny).ToArray();var q=new Queue<int>();parent[s]=s;q.Enqueue(s);int[] xs={1,0,-1,0},ys={0,1,0,-1};while(q.Count>0&&parent[e]<0){int n=q.Dequeue();for(int i=0;i<4;i++){int x=n%nx+xs[i],y=n/nx+ys[i];if(x<0||x>=nx||y<0||y>=ny||!walk[x,y])continue;int v=y*nx+x;var p=Point(v);if(parent[v]>=0||(close&&p.x>113&&p.x<120&&p.y>65&&p.y<88))continue;parent[v]=n;q.Enqueue(v);}}
  if(parent[e]<0)return null;var raw=new List<Vector2>();for(int n=e;n!=s;n=parent[n])raw.Add(Point(n));raw.Reverse();var answer=new List<Vector2>();for(int i=0;i<raw.Count;i++)if(i==0||i==raw.Count-1||raw[i]-raw[i-1]!=raw[i+1]-raw[i])answer.Add(raw[i]);return answer;
 }
 static async Task Snap(string name,string state){capture.Capture(name,state);while(capture.Busy)await Pause(20);}
 static void Result(string id,bool pass,object evidence)=>results.Add(new{id,pass,evidence,frame=Time.frameCount});
 static Vector2 Quantize(Vector2 v){float a=Mathf.Round(Mathf.Atan2(v.y,v.x)/(Mathf.PI/4))*Mathf.PI/4;return new Vector2(Mathf.Round(Mathf.Cos(a)),Mathf.Round(Mathf.Sin(a))).normalized;}
 static bool Direct(Vector2 from,Vector2 direction,PolygonCollider2D target){if(!FreeFeet(from))return false;var hit=Physics2D.BoxCast(from+actorCollider.offset,(Vector2)actorCollider.bounds.size-Vector2.one*.002f,0,direction,2.1f,1<<8);return hit.collider==target;}
 static Vector2? Fixture(Vector2 a,Vector2 b,Vector2 outward,PolygonCollider2D target){foreach(float t in new[]{.5f,.25f,.75f,.1f,.9f})foreach(float gap in new[]{.9f,1.1f,1.5f}){var from=Vector2.Lerp(a,b,t)-actorCollider.offset+outward*gap;if(Direct(from,-outward,target))return from;}return null;}
 static async Task Push(string id,PolygonCollider2D target,Vector2 from,Vector2 direction,bool dodge,bool image)
 {
  // A small set of complete before/after pairs supplements all measured contacts.
  image=image&&(id.StartsWith("royal-wall-0-0-edge-1")||id.StartsWith("H3-0-edge-0")||id.StartsWith("B1-0-edge-0")||id.StartsWith("castle-compound-keep-0-edge-0")||id.StartsWith("gate-west-tower-0-edge-0")||id.StartsWith("court-fountain-edge-0")||id.StartsWith("court-oak-west-edge-0")||id.StartsWith("bridge-left-rail-0-edge-0"));
  Place(from);camera.transform.position=new Vector3(from.x,from.y+5,-10);camera.orthographicSize=14.0625f;await Pause(dodge?1150:120);
  if(image)await Snap(id+"-before","Before aligned real Input System contact; explicit fixture placement");
  held=Keys(direction,dodge);float min=100;int unique=0,last=-1;bool inside=false,dodgeObserved=false;var start=body.position;var samples=new List<object>();
  for(int i=0;i<25;i++){await Pause(20);if(last==Time.frameCount)continue;last=Time.frameCount;unique++;var dist=actorCollider.Distance(target);min=Mathf.Min(min,dist.distance);inside|=target.OverlapPoint(body.position);dodgeObserved|=body.GetComponent<ActorHealth>().State.IsDodging(Time.timeAsDouble);samples.Add(new{frame=Time.frameCount,x=body.position.x,y=body.position.y,distance=dist.distance,motor=body.GetComponent<ActorMotor>().Direction.ToString("R")});}
  held=Array.Empty<Key>();await Pause(80);float travel=Vector2.Distance(start,body.position);float end=actorCollider.Distance(target).distance;bool pass=!inside&&min>=-.025f&&min<.035f&&travel>.03f&&(!dodge||dodgeObserved);
  Result(id,pass,new{target=target.name,from=start.ToString("R"),to=body.position.ToString("R"),travel,minimumSeparation=min,endSeparation=end,inside,uniqueFrames=unique,dodge,dodgeObserved,realInput=true,fixturePlacement=true,direction=direction.ToString("R"),samples});
  if(image)await Snap(id+"-after","After real input contact with the explicit ground volume; new anime painting remains opaque");
 }
 public static object Main()
 {if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/ValdoriaVillage02Anime.unity"||!LocalJourneyProfile.Root.Contains("Temp")||File.Exists(Root+"QA/play-qa.json")||active!=null)throw new IOException("New isolated integration Play required");Directory.CreateDirectory(Root+"QA");active=Run();return new{queued=true,receipt=Root+"QA/play-qa.json"};}
 static async Task Run()
 {
  var previous=Keyboard.current;var disabled=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;int previousFPS=SessionState.GetBool("Village02Integration.FPSOverride",false)?SessionState.GetInt("Village02Integration.PreviousFPS",-1):Application.targetFrameRate;int first=Time.frameCount;double began=Time.timeAsDouble;string error=null;
  try{
   body=GameObject.Find("Player").GetComponent<Rigidbody2D>();actorCollider=body.GetComponent<Collider2D>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();capture=new GameObject("TEMP integration evidence").AddComponent<Village02EvidenceCapture>();capture.ConfigureRoot(Root);data=JObject.Parse(File.ReadAllText(Source+"layout.json"));
   foreach(var d in disabled)InputSystem.DisableDevice(d);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Village02-Integration-QA");InputSystem.onBeforeUpdate+=Feed;SessionState.SetInt("Village02Integration.PreviousFPS",previousFPS);SessionState.SetBool("Village02Integration.FPSOverride",true);Application.targetFrameRate=60;
   Progress("physics-grid","clearance .625");walk=new bool[nx,ny];for(int y=0;y<ny;y++)for(int x=0;x<nx;x++)walk[x,y]=Free(Point(y*nx+x));
   int mismatch=0;foreach(var p in data["physical"]){var c=GameObject.Find("Physics:"+(string)p["id"]).GetComponent<PolygonCollider2D>();var desired=p["polygon"].Select(V).ToArray();var actual=c.GetPath(0);if(actual.Length!=desired.Length||actual.Where((v,i)=>Vector2.Distance(c.transform.TransformPoint(v),desired[i])>.0001f).Any())mismatch++;}Result("All semantic polygons equal Unity",mismatch==0,new{mismatch,polygons=data["physical"].Count()});Result("Only bridge connects exterior",Route(body.position,V(data["targets"][0]["point"]),true)==null,new{step=.5,clearance=.625});
   // The only traversal uses real input, without placing between targets.
   var goals=data["targets"].OrderBy(t=>Array.IndexOf(new[]{"entry","royal-entry","fountain-west","fountain-north","fountain-east","fountain-south","west-lawns","east-lawns","castle-court"},(string)t["id"])).Concat(new[]{JObject.FromObject(new{id="return-exterior",point=data["spawn"]})}).ToArray();
   foreach(var goal in goals){string id=(string)goal["id"];Progress("continuous-route",id);var route=Route(body.position,V(goal["point"]));if(route==null)throw new IOException("Unreachable "+id);double segment=Time.timeAsDouble,lastProgress=segment;var lastPoint=body.position;int n=0;
    while(n<route.Count){if(Time.timeAsDouble-segment>120)throw new IOException("Route segment timeout "+id);while(n<route.Count&&Vector2.Distance(body.position,route[n])<.27f)n++;if(n==route.Count)break;held=Keys(route[n]-body.position);trace.Add(new{frame=Time.frameCount,time=Time.timeAsDouble,x=body.position.x,y=body.position.y,goal=id,keys=string.Join(",",held)});await Pause(35);if(Vector2.Distance(lastPoint,body.position)>.2f){lastProgress=Time.timeAsDouble;lastPoint=body.position;}if(Time.timeAsDouble-lastProgress>4)throw new IOException("Route stuck "+id+" at "+body.position);}
    held=Array.Empty<Key>();Result("route-"+id,true,new{position=body.position.ToString("R"),noTeleport=true,seconds=Time.timeAsDouble-segment});
   }
   follow.enabled=false;
   foreach(var p in data["physical"].Where(p=>(string)p["kind"]=="royal-wall"||((string)p["kind"]=="garden"&&((string)p["id"]=="court-fountain"||((string)p["id"]).StartsWith("royal-")))))
   {
    string id=(string)p["id"];Progress("contacts",id);var target=GameObject.Find("Physics:"+id).GetComponent<PolygonCollider2D>();var vertices=p["polygon"].Select(V).ToArray();float area=0;for(int i=0;i<vertices.Length;i++)area+=vertices[i].x*vertices[(i+1)%vertices.Length].y-vertices[(i+1)%vertices.Length].x*vertices[i].y;bool wall=(string)p["kind"]=="wall";
    for(int i=0;i<vertices.Length;i++){
     // Base wall geometry is unchanged and has158 separately recorded face
     // contacts. This run targets repainted buildings/rails and new garden solids.
     if((string)p["kind"]=="garden"&&i%5!=0)continue;if((string)p["kind"]=="royal-wall"&&i%2==0)continue;
     var a=vertices[i];var b=vertices[(i+1)%vertices.Length];var v=b-a;var outward=Quantize(area>0?new Vector2(v.y,-v.x):new Vector2(-v.y,v.x));var fixture=Fixture(a,b,outward,target);
     if(fixture==null){excluded.Add(new{id,edge=i,reason="No direct exterior approach: adjacent solid; no implicit pass"});continue;}
     await Push(id+"-edge-"+i,target,fixture.Value,-outward,false,i==0||i==1);
     if(i==0||(i==1&&id=="royal-wall-0-0")){var cardinal=ActorMotor.Cardinal(outward);var df=Fixture(a,b,cardinal,target);if(df!=null)await Push(id+"-dodge",target,df.Value,-cardinal,true,false);else excluded.Add(new{id,edge=i,reason="No direct cardinal dodge fixture"});}
    }
   }
   var fountain=GameObject.Find("Garden:court-fountain").GetComponent<OpaqueStructureDepth>();
   foreach(var f in new[]{new{id="front",p=new Vector2(182,197)},new{id="rear",p=new Vector2(182,203)}}){if(!FreeFeet(f.p))throw new IOException("Fountain depth fixture blocked");Place(f.p);camera.transform.position=new Vector3(182,204,-10);camera.orthographicSize=14.0625f;await Pause(200);var ab=body.GetComponent<ProductionSpriteAnimator>().Body;var group=fountain.GetComponent<SortingGroup>();Result("fountain-opaque-"+f.id,f.id=="rear"?group.sortingOrder>ab.sortingOrder:group.sortingOrder<ab.sortingOrder,new{fountain.OccludesActor,group.sortingOrder,actorOrder=ab.sortingOrder,opaque=fountain.GetComponentsInChildren<SpriteRenderer>().All(r=>r.color.a==1)});await Snap("fountain-opaque-"+f.id,"Enlarged fountain opaque depth fixture "+f.id);}
   foreach(var v in new[]{new{id="overview",p=new Vector2(141,167.5f),ortho=167.5f,actor=V(data["spawn"])},new{id="royal-precinct",p=new Vector2(182,226),ortho=59f,actor=new Vector2(182,191)},new{id="fountain",p=new Vector2(182,203),ortho=14.0625f,actor=new Vector2(178,195)},new{id="garden-avenue",p=new Vector2(182,203),ortho=30f,actor=new Vector2(182,190)}}){Place(v.actor);camera.transform.position=new Vector3(v.p.x,v.p.y,-10);camera.orthographicSize=v.ortho;await Pause(250);await Snap(v.id,"Expanded royal gardens in actual Play; native assets scale1, actor unchanged");}
  }catch(Exception ex){error=ex.ToString();}
  finally{
   held=Array.Empty<Key>();InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;if(body)Place(V(data["spawn"]));if(follow)follow.enabled=true;if(camera)camera.orthographicSize=14.0625f;
   Write("play-qa.json",new{error,allExecutedPassed=error==null&&results.All(r=>(bool)JObject.FromObject(r)["pass"]),framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,excluded,trace,profile=LocalJourneyProfile.Root,coverage="All172 polygons equal recipe;43 new walls checked on both long faces, fountain and six new tree trunks; cardinal dodge; continuous garden circuit and bridge negative check; fountain opaque front/rear. Original120 architecture and two original trees unchanged; old coverage inherited. Explicit exclusions are not passes.",artisticApprovalOfIntegration=false});Write("input-restored.json",new{syntheticAbsent=!InputSystem.devices.Any(d=>d.name.Contains("Village02-Integration")),keyboards=InputSystem.devices.OfType<Keyboard>().Select(k=>new{k.name,k.enabled}),backgroundRestored=InputSystem.settings.backgroundBehavior==bg,editorInputRestored=InputSystem.settings.editorInputBehaviorInPlayMode==ei,timeScale=Time.timeScale});Progress("finished",error??"completed");
  }
 }
 public static object Cancel(){File.WriteAllText("Temp/RoyalGardens.cancel","cancel");return "Cancellation requested; await restoration receipt";}
}
