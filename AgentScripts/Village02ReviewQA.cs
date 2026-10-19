using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.Rendering;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Object=UnityEngine.Object;

public static class Village02ReviewQA
{
    const string Root="Docs/Validation/ValdoriaVillage02/";
    const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Blockout.unity";
    sealed class Probe{public string id;public Vector2 start,direction;public bool dodge;public string target;}
    static List<Probe> probes;static List<object> results=new List<object>();static List<object> trace=new List<object>();
    static Rigidbody2D body;static Camera camera;static CameraFollow follow;static Village02EvidenceCapture capture;
    static Keyboard keyboard,previous;static List<InputDevice> disabled=new List<InputDevice>();static Key[] held=Array.Empty<Key>();
    static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;
    static int index,phase,last,first;static double until,began;static bool views;static Vector2 start;static bool stopped;
    static JObject data;static bool[,] walk;static int nx=256,ny=304;static List<Vector2> route;static int routeIndex;static bool exploring;static int destination;static double lastProgress;static Vector2 progressPoint;
    static readonly string[] viewNames={"01-overview","02-entry-gameplay","03-internal-gameplay","04-castle-silhouette","05-castle-gameplay","06-physical-diagnostic"};
    static readonly Vector3[] cameras={new Vector3(64,76,-10),new Vector3(53,47,-10),new Vector3(65,76,-10),new Vector3(90,119,-10),new Vector3(83,110,-10),new Vector3(64,76,-10)};
    static readonly Vector2[] actors={new Vector2(53,12),new Vector2(53,40),new Vector2(65,66),new Vector2(83,108),new Vector2(83,108),new Vector2(53,49)};
    static readonly float[] orthos={76,14.0625f,14.0625f,28,14.0625f,76};
    static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic&&keyboard!=null)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
    static void Place(Vector2 p){held=Array.Empty<Key>();body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
    static Key[] Keys(Vector2 d,bool dodge=false){var k=new List<Key>();if(Mathf.Abs(d.x)>.09f)k.Add(d.x>0?Key.D:Key.A);if(Mathf.Abs(d.y)>.09f)k.Add(d.y>0?Key.W:Key.S);if(dodge)k.Add(Key.Space);return k.ToArray();}
    static bool Free(Vector2 p)=>Physics2D.OverlapCircle(p,.625f,1<<8)==null;
    static Vector2 Point(int id)=>new Vector2((id%nx+.5f)*.5f,(id/nx+.5f)*.5f);
    static List<Vector2> Route(Vector2 a,Vector2 b,bool close=false)
    {
        int Near(Vector2 p){int x=Mathf.Clamp((int)(p.x*2),0,nx-1),y=Mathf.Clamp((int)(p.y*2),0,ny-1);for(int r=0;r<8;r++)for(int dy=-r;dy<=r;dy++)for(int dx=-r;dx<=r;dx++){int xx=x+dx,yy=y+dy;if(xx>=0&&xx<nx&&yy>=0&&yy<ny&&walk[xx,yy])return yy*nx+xx;}throw new IOException("No clearance point");}
        int s=Near(a),e=Near(b);var parent=Enumerable.Repeat(-1,nx*ny).ToArray();var q=new Queue<int>();parent[s]=s;q.Enqueue(s);int[] xs={1,0,-1,0},ys={0,1,0,-1};
        while(q.Count>0&&parent[e]<0){int n=q.Dequeue();for(int i=0;i<4;i++){int x=n%nx+xs[i],y=n/nx+ys[i];if(x<0||x>=nx||y<0||y>=ny||!walk[x,y])continue;int v=y*nx+x;var p=Point(v);if(parent[v]>=0||(close&&p.x>48&&p.x<58&&p.y>28&&p.y<40))continue;parent[v]=n;q.Enqueue(v);}}
        if(parent[e]<0)return null;var raw=new List<Vector2>();for(int n=e;n!=s;n=parent[n])raw.Add(Point(n));raw.Reverse();var answer=new List<Vector2>();for(int i=0;i<raw.Count;i++)if(i==0||i==raw.Count-1||raw[i]-raw[i-1]!=raw[i+1]-raw[i])answer.Add(raw[i]);return answer;
    }
    static void Result(string name,bool pass,object evidence){results.Add(new{name,pass,evidence,frame=Time.frameCount});}
    public static object Main()
    {
        if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=Scene||!LocalJourneyProfile.Root.Contains("Temp")||File.Exists(Root+"QA/play-qa.json"))throw new IOException("New isolated blockout Play required");
        body=GameObject.Find("Player").GetComponent<Rigidbody2D>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();capture=new GameObject("Temporary Village02 review recorder").AddComponent<Village02EvidenceCapture>();
        data=JObject.Parse(File.ReadAllText("ArtSource/World/PlayableVillage02/BlockoutV1/layout.json"));
        previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
        foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        keyboard=InputSystem.AddDevice<Keyboard>("Village02 review keyboard");InputSystem.onBeforeUpdate+=Feed;
        walk=new bool[nx,ny];for(int y=0;y<ny;y++)for(int x=0;x<nx;x++)walk[x,y]=Free(Point(y*nx+x));
        Result("Bridge necessary in live Physics2D",Route(body.position,new Vector2(53,49),true)==null,new{step=.5,clearance=.625});
        int mismatch=0;foreach(var p in data["physical"]){var c=GameObject.Find("Physics:"+(string)p["id"]).GetComponent<PolygonCollider2D>();var desired=p["polygon"].Select(v=>new Vector2((float)v[0],(float)v[1])).ToArray();var actual=c.GetPath(0);if(actual.Length!=desired.Length||actual.Where((v,i)=>Vector2.Distance(c.transform.TransformPoint(v),desired[i])>.0001f).Any())mismatch++;}
        Result("Baked physical polygons match scene",mismatch==0,new{mismatch,polygons=data["physical"].Count()});
        probes=new List<Probe>();
        foreach(var v in data["volumes"].Where(v=>(string)v["kind"]=="building"||new[]{"G-west","G-east","C-gate-west","C-gate-east"}.Contains((string)v["id"])))
        {
            var p=v["footprint"].Select(t=>new Vector2((float)t[0],(float)t[1])).ToArray();Vector2 center=p.Aggregate(Vector2.zero,(a,b)=>a+b)/p.Length;
            for(int i=0;i<p.Length;i++)
            {
                Vector2 mid=(p[i]+p[(i+1)%p.Length])*.5f;Vector2 outward=(mid-center).normalized;
                // Select an exterior fixture without silently testing through a neighbour.
                Vector2 from=mid+outward*2.2f;
                if(!Free(from)){Result((string)v["id"]+"-side-"+i+"-fixture",false,new{reason="adjacent obstruction; review access",from=from.ToString()});continue;}
                probes.Add(new Probe{id=(string)v["id"]+"-side-"+i,start=from,direction=-outward,target=(string)v["id"]});
                if(i==0)probes.Add(new Probe{id=(string)v["id"]+"-front-dodge",start=from,direction=-outward,target=(string)v["id"],dodge=true});
            }
            // Diagonal corner pushes, all four corners. There may be deliberate shared walls.
            for(int i=0;i<p.Length;i++){Vector2 outward=(p[i]-center).normalized;Vector2 from=p[i]+outward*2.4f;if(Free(from))probes.Add(new Probe{id=(string)v["id"]+"-corner-"+i,start=from,direction=-outward,target=(string)v["id"]});}
        }
        exploring=true;first=Time.frameCount;began=Time.timeAsDouble;destination=0;route=Route(body.position,new Vector2(53,49));routeIndex=0;lastProgress=began;progressPoint=body.position;EditorApplication.update+=Tick;
        return new{queued=true,fixtures=probes.Count,noSpritesProduced=true,profile=LocalJourneyProfile.Root};
    }
    static void Tick()
    {
        try{
            if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double now=Time.timeAsDouble;
            if(now-began>300){Finish("Review timeout");return;}if(capture.Busy||now<until)return;
            if(exploring)
            {
                if(route==null)throw new IOException("Route missing");trace.Add(new{frame=last,time=now,x=body.position.x,y=body.position.y,keys=string.Join(",",held),destination});
                while(routeIndex<route.Count&&Vector2.Distance(body.position,route[routeIndex])<.22f)routeIndex++;
                if(routeIndex==route.Count)
                {
                    held=Array.Empty<Key>();Result("Continuous-route-"+destination,true,new{position=body.position.ToString(),noTeleport=true});destination++;
                    Vector2[] goals={new Vector2(53,49),new Vector2(65,66),new Vector2(83,108),new Vector2(58,103.9f),new Vector2(53,12)};
                    if(destination>=goals.Length){exploring=false;index=0;phase=0;follow.enabled=false;until=now+.3;return;}
                    route=Route(body.position,goals[destination]);routeIndex=0;lastProgress=now;progressPoint=body.position;return;
                }
                held=Keys(route[routeIndex]-body.position);if(Vector2.Distance(progressPoint,body.position)>.3f){lastProgress=now;progressPoint=body.position;}if(now-lastProgress>5)throw new IOException("Continuous route stuck at "+body.position);return;
            }
            if(views)
            {
                if(index==viewNames.Length){Finish(null);return;}
                if(phase==0){Place(actors[index]);camera.transform.position=cameras[index];camera.orthographicSize=orthos[index];if(index==5)Diagnostic();phase=1;until=now+.4;return;}
                capture.Capture(viewNames[index],"Neutral blockout in actual Play; fixed review fixture, not continuous exploration; opaque exterior occlusion");index++;phase=0;until=now+.3;return;
            }
            if(index==probes.Count){views=true;index=0;phase=0;return;}
            var p=probes[index];
            if(phase==0)
            {
                Place(p.start);start=body.position;camera.transform.position=new Vector3(start.x,start.y+4,-10);camera.orthographicSize=14.0625f;
                phase=1;until=now+.15;return;
            }
            if(phase==1){capture.Capture("contact-"+p.id+"-before","Explicit collision fixture before real Input System push");phase=2;until=now+.1;return;}
            if(phase==2){held=Keys(p.direction,p.dodge);phase=3;until=now+.7;return;}
            held=Array.Empty<Key>();
            var target=GameObject.Find("Physics:"+p.target).GetComponent<PolygonCollider2D>();
            bool inside=target.OverlapPoint(body.position);float travel=Vector2.Distance(start,body.position);
            Result(p.id,!inside&&travel>.1f&&travel<4,new{from=start.ToString("R"),to=body.position.ToString("R"),travel,inside,fixturePlacement=true,realKeyboard=true,p.dodge});
            capture.Capture("contact-"+p.id+"-after","After real Input System push; collision and visual evidence inspected separately");index++;phase=0;until=now+.1;
        }catch(Exception e){Finish(e.ToString());}
    }
    static void Diagnostic()
    {
        var mat=new Material(Shader.Find("Sprites/Default"));var root=new GameObject("TEMP Diagnostic footprints - presentation only");
        foreach(var c in Object.FindObjectsByType<PolygonCollider2D>())
        {var go=new GameObject(c.name);go.transform.SetParent(root.transform);var line=go.AddComponent<LineRenderer>();line.sharedMaterial=mat;line.startColor=line.endColor=Color.cyan;line.startWidth=line.endWidth=.16f;line.sortingOrder=30000;var points=c.GetPath(0).Select(v=>c.transform.TransformPoint(v)).ToArray();line.positionCount=points.Length;line.SetPositions(points);line.loop=true;}
    }
    static void Finish(string error)
    {
        if(stopped)return;stopped=true;EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;held=Array.Empty<Key>();
        if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)if(d!=null)InputSystem.EnableDevice(d);previous?.MakeCurrent();
        InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;if(body)Place(new Vector2(53,12));if(follow)follow.enabled=true;if(camera)camera.orthographicSize=14.0625f;
        var diagnostic=GameObject.Find("TEMP Diagnostic footprints - presentation only");if(diagnostic)Object.DestroyImmediate(diagnostic);
        File.WriteAllText(Root+"QA/play-qa.json",JsonConvert.SerializeObject(new{error,allPassed=error==null&&results.All(x=>(bool)JObject.FromObject(x)["pass"]),framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace,inputRestored=true,coverage="Each principal building and both gate pairs: four faces, available corners and front dodge. Fixture exclusions reported as failures; no final-art approval."},Formatting.Indented));
    }
    public static object Cancel(){Finish("Cancelled by agent");return "Input restored";}
}
