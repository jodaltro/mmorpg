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
using Object=UnityEngine.Object;
public static class ValidatePlayableVillage01
{
    const string Root="Docs/Validation/ValdoriaPlayableVillage01/";
    static Keyboard keyboard,previous;static List<InputDevice> disabled=new List<InputDevice>();
    static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;
    static Key[] held=Array.Empty<Key>();static Rigidbody2D body;static VillageEvidenceCapture capture;
    static Camera camera;static CameraFollow follow;static int last,first,index;static double began,until,lastProgress;static Vector2 lastPosition;
    static bool[,] walk;static int nx=224,ny=288;static List<Vector2> route;static List<object> trace=new List<object>(),results=new List<object>(),performance=new List<object>();
    static List<Tuple<string,Vector2>> destinations;static int destination;
    static List<double> timings=new List<double>();static int perfPhase;static bool overview;
    static int ID(int x,int y)=>y*nx+x;
    static Vector2 Point(int id)=>new Vector2((id%nx+.5f)*.5f,(id/nx+.5f)*.5f);
    static int Nearest(Vector2 point)
    {
        int cx=Mathf.Clamp((int)(point.x*2),0,nx-1),cy=Mathf.Clamp((int)(point.y*2),0,ny-1);
        for(int radius=0;radius<8;radius++)for(int dy=-radius;dy<=radius;dy++)for(int dx=-radius;dx<=radius;dx++)
        {int x=cx+dx,y=cy+dy;if(x>=0&&y>=0&&x<nx&&y<ny&&walk[x,y])return ID(x,y);}throw new IOException("No clearance point near "+point);
    }
    static List<Vector2> Route(Vector2 a,Vector2 b,bool closeBridge=false)
    {
        int start=Nearest(a),end=Nearest(b);var parent=Enumerable.Repeat(-1,nx*ny).ToArray();var q=new Queue<int>();q.Enqueue(start);parent[start]=start;
        int[] dx={1,0,-1,0},dy={0,1,0,-1};
        while(q.Count>0&&parent[end]<0){int n=q.Dequeue(),x=n%nx,y=n/nx;for(int i=0;i<4;i++){int xx=x+dx[i],yy=y+dy[i];if(xx<0||yy<0||xx>=nx||yy>=ny||!walk[xx,yy])continue;int next=ID(xx,yy);var p=Point(next);if(parent[next]>=0||(closeBridge&&p.x>52&&p.x<60&&p.y>18&&p.y<30))continue;parent[next]=n;q.Enqueue(next);}}
        if(parent[end]<0)return null;var reverse=new List<Vector2>();for(int n=end;n!=start;n=parent[n])reverse.Add(Point(n));reverse.Reverse();
        var compressed=new List<Vector2>();for(int i=0;i<reverse.Count;i++)if(i==0||i==reverse.Count-1||(reverse[i]-reverse[i-1])!=(reverse[i+1]-reverse[i]))compressed.Add(reverse[i]);return compressed;
    }
    static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
    static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
    static void Save()=>File.WriteAllText(Root+"QA/progress.json",JsonConvert.SerializeObject(new{destination,index,position=body.position.ToString(),elapsed=Time.timeAsDouble-began},Formatting.Indented));
    public static object Main()
    {
        if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=PlayableVillage01Builder.Scene)throw new IOException("Isolated actual village Play required");
        if(File.Exists(Root+"QA/play-qa.json"))throw new IOException("Refuse QA receipt overwrite");Directory.CreateDirectory(Root+"Original");
        body=GameObject.Find("Player").GetComponent<Rigidbody2D>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();
        capture=new GameObject("Temporary after-frame village evidence").AddComponent<VillageEvidenceCapture>();
        walk=new bool[nx,ny];for(int y=0;y<ny;y++)for(int x=0;x<nx;x++)walk[x,y]=Physics2D.OverlapCircle(Point(ID(x,y)),.625f,1<<8)==null;
        Result("Spawn clearance",Physics2D.OverlapCircle(body.position,.625f,1<<8)==null,new{position=body.position.ToString()});
        Result("Bridge is necessary for entry",Route(body.position,new Vector2(56,44),true)==null,new{samples=nx*ny,clearance=.625f,bridgeVirtuallyClosed=true});
        Result("Walls prevent all other interior entries",Route(new Vector2(5,60),new Vector2(56,44),true)==null,new{boundary="closed stone perimeter plus full-width river"});
        previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
        foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        keyboard=InputSystem.AddDevice<Keyboard>("Village01-QA-Keyboard");InputSystem.onBeforeUpdate+=Feed;
        destinations=new List<Tuple<string,Vector2>>();void Add(string name,Vector2 target)=>destinations.Add(Tuple.Create(name,target));
        Add("01-exterior-river",new Vector2(56,16));Add("02-bridge",new Vector2(56,25));Add("03-gate",new Vector2(56,38));
        Add("04-main-street",new Vector2(56,48));Add("05-plaza",new Vector2(56,60));
        foreach(var h in Object.FindObjectsByType<ArchitectureBuilding>().Where(h=>h.Archetype!="castle").OrderBy(h=>h.Id))Add("door-"+h.Id,h.Approach);
        Add("06-castle-approach",new Vector2(48,82));
        // Authored castle courtyard path, transformed from the accepted source.
        Add("07-castle-gate",new Vector2(48.25f,87.75f));Add("08-castle-courtyard",new Vector2(50.25f,97.25f));
        Add("09-return-plaza",new Vector2(56,60));Add("10-return-gate",new Vector2(56,38));Add("11-return-bridge",new Vector2(56,25));Add("12-return-spawn",new Vector2(56,8));
        first=Time.frameCount;began=Time.timeAsDouble;lastProgress=began;lastPosition=body.position;destination=0;index=0;route=Route(body.position,destinations[0].Item2);if(route==null)throw new IOException("Exterior route missing");
        EditorApplication.update+=Tick;return new{queued=true,routeDestinations=destinations.Count,noTeleport=true,physicsSamples=nx*ny};
    }
    static object ResourcesNow()
    {
        var rr=Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();
        var tt=rr.SelectMany(r=>r is SpriteRenderer s&&s.sprite?new[]{s.sprite.texture}:r.sharedMaterials.Where(m=>m&&m.mainTexture is Texture2D).Select(m=>(Texture2D)m.mainTexture)).Distinct().ToArray();
        var t=timings.OrderBy(v=>v).ToArray();return new{drawCalls=UnityStats.drawCalls,renderersActive=rr.Length,renderersVisible=rr.Count(r=>r.isVisible),textures=tt.Length,textureBytes=tt.Sum(x=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(x)),samples=t.Length,medianMs=t.Length>0?t[t.Length/2]:0,p95Ms=t.Length>0?t[(int)(t.Length*.95)]:0,resolution=new[]{Screen.width,Screen.height},quality=QualitySettings.names[QualitySettings.GetQualityLevel()],actor=body.position.ToString(),camera=camera.transform.position.ToString()};
    }
    static void Tick()
    {
        try{
            if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double now=Time.timeAsDouble;
            if(now-began>260){Finish("Exploration timeout");return;}
            trace.Add(new{frame=last,time=now,x=body.position.x,y=body.position.y,keys=string.Join(",",held),camera=camera.transform.position.ToString("R"),destination});
            if(overview){if(now<until){if(perfPhase==1)timings.Add(Time.unscaledDeltaTime*1000);return;}if(perfPhase==0){timings.Clear();perfPhase=1;until=now+2;return;}if(perfPhase==1){performance.Add(new{name="overview",metrics=ResourcesNow()});capture.Capture("00-overview","whole playable village, overview camera");perfPhase=2;until=now+.3;return;}Finish(null);return;}
            if(now<until){if(perfPhase==1)timings.Add(Time.unscaledDeltaTime*1000);return;}
            if(perfPhase==1)
            {
                performance.Add(new{name=destinations[destination].Item1,metrics=ResourcesNow()});perfPhase=0;
                capture.Capture(destinations[destination].Item1,"continuous real-input exploration");destination++;
                if(destination==destinations.Count){Result("Continuous exterior-bridge-gate-village-castle-return",Vector2.Distance(body.position,new Vector2(56,8))<1,new{teleports=0,seconds=now-began});overview=true;follow.enabled=false;camera.transform.position=new Vector3(56,72,-10);camera.orthographicSize=72;until=now+.5;return;}
                route=Route(body.position,destinations[destination].Item2);index=0;if(route==null)throw new IOException("No physical route to "+destinations[destination].Item1);lastProgress=now;lastPosition=body.position;
            }
            while(index<route.Count&&Vector2.Distance(body.position,route[index])<.22f)index++;
            if(index==route.Count){held=Array.Empty<Key>();Result(destinations[destination].Item1,true,new{target=destinations[destination].Item2.ToString(),actual=body.position.ToString()});perfPhase=1;timings.Clear();until=now+2;Save();return;}
            var delta=route[index]-body.position;var keys=new List<Key>();if(Mathf.Abs(delta.x)>.09f)keys.Add(delta.x>0?Key.D:Key.A);if(Mathf.Abs(delta.y)>.09f)keys.Add(delta.y>0?Key.W:Key.S);held=keys.ToArray();
            if(Vector2.Distance(lastPosition,body.position)>.35f){lastProgress=now;lastPosition=body.position;}
            if(now-lastProgress>4)throw new IOException("Input movement stuck near "+body.position+" toward "+route[index]);
            if(last%120==0)Save();
        }catch(Exception e){Finish(e.ToString());}
    }
    static void Finish(string error)
    {
        EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;held=Array.Empty<Key>();body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);
        if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();
        InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;follow.enabled=true;camera.orthographicSize=14.0625f;
        File.WriteAllText(Root+"QA/play-qa.json",JsonConvert.SerializeObject(new{passed=error==null&&results.All(r=>(bool)Newtonsoft.Json.Linq.JObject.FromObject(r)["pass"]),error,noTeleport=true,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,results,trace,performance,inputRestored=true},Formatting.Indented));
    }
}
