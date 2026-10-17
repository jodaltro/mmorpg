using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;

public static class ValidateTerrainStudio01
{
    sealed class Step {public float duration;public Action begin,end;}
    static readonly Queue<Step> steps=new Queue<Step>();
    static readonly List<object> results=new List<object>(),trace=new List<object>();
    static Keyboard keyboard,original;static InputSettings.BackgroundBehavior background;
    static TerrainLabController controller;static Rigidbody2D body;static ProductionSpriteAnimator animator;
    static Key[] held=Array.Empty<Key>();static Step active;static double until;
    static Vector2 start;static int firstFrame,lastFrame;static Vector2[] route;static int waypoint;
    static bool routing;static string routeName;static double routeDeadline;
    static string output="Docs/Validation/ValdoriaWorldStudio01/Verified";
    static void Add(float t,Action begin=null,Action end=null)=>steps.Enqueue(new Step{duration=t,begin=begin,end=end});
    static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
    static void Place(Vector2 p){body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
    static void Feed()=>InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));
    static void Move(string name,Key[] keys)
    {
        Add(.4f,()=>{start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.5f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.15f);
    }
    public static string Main()
    {
        if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new Exception("Requires isolated Play");
        if(File.Exists(output+"/play-qa.json"))throw new IOException("Refuse QA overwrite");Directory.CreateDirectory(output);
        controller=UnityEngine.Object.FindAnyObjectByType<TerrainLabController>();body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();
        original=Keyboard.current;background=InputSystem.settings.backgroundBehavior;InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        keyboard=InputSystem.AddDevice<Keyboard>("TerrainStudioQA");InputSystem.onBeforeUpdate+=Feed;firstFrame=Time.frameCount;
        Add(.2f,()=>{controller.Select(0);Place(new Vector2(12.5f,13.5f));});
        Move("WASD W",new[]{Key.W});Move("WASD A",new[]{Key.A});Move("WASD S",new[]{Key.S});Move("WASD D",new[]{Key.D});Move("Diagonal WD",new[]{Key.W,Key.D});
        for(int i=0;i<3;i++)
        {
            int selection=i;
            Add(.25f,()=>controller.Select(selection));
            Add(.1f,()=>{
                var r=JObject.Parse(controller.Region.text);int h=(int)r["size"][1];
                route=((JArray)r["routePoints"]).Select(p=>new Vector2((float)p[0]+.5f,h-1-(float)p[1]+.5f)).ToArray();
                Place(route[0]);waypoint=1;routing=true;routeName="ABC"[selection]+" route full traversal";routeDeadline=Time.timeAsDouble+40;
            });
            Add(.2f,null,()=>{
                var shadow=body.GetComponentsInChildren<Transform>().First(t=>t.name=="GroundShadow");
                var group=animator.Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>();
                Result("ABC"[selection]+" feet and sorting",Vector2.Distance(shadow.position,body.position)<.01f&&group.sortingOrder==100-Mathf.RoundToInt(body.position.y*16),
                    new{shadowDelta=Vector2.Distance(shadow.position,body.position),bodyOffset=animator.Body.transform.localPosition.ToString(),scale=animator.Body.transform.lossyScale.ToString(),group.sortingOrder});
            });
            if(i>0)
            {
                Collider2D obstacle=null;float edge=0;Vector2 contactStart=Vector2.zero;
                Add(.2f,()=>{
                    var r=JObject.Parse(controller.Region.text);int w=(int)r["size"][0],h=(int)r["size"][1];var b=r["layers"]["blocked"];
                    int found=-1;
                    for(int y=3;y<h-4&&found<0;y++)for(int x=3;x<w-3&&found<0;x++)
                    {
                        if(!(bool)b[y*w+x])continue;bool clear=true;
                        for(int dy=1;dy<=3;dy++)for(int dx=-1;dx<=1;dx++)if((bool)b[(y+dy)*w+x+dx])clear=false;
                        if(clear)found=y*w+x;
                    }
                    if(found<0)throw new Exception("No clear southern cliff fixture");
                    edge=h-1-found/w;contactStart=new Vector2(found%w+.5f,edge-1.5f);Place(contactStart);
                    obstacle=Physics2D.OverlapPoint(new Vector2(found%w+.5f,edge+.5f),1<<8);
                    if(obstacle==null)throw new Exception("Blocked cell missing physical obstacle");
                });
                Add(1f,()=>{start=body.position;held=new[]{Key.W};},()=>{
                    held=Array.Empty<Key>();var distance=Physics2D.Distance(body.GetComponent<Collider2D>(),obstacle);
                    Result("ABC"[selection]+" cliff collision",distance.distance>=-Physics2D.defaultContactOffset*2&&distance.distance<.12f&&body.position.y<edge+.2f,
                        new{from=start.ToString(),stop=body.position.ToString(),edge,distance=distance.distance,overlap=distance.isOverlapped,collider=obstacle.name});
                });Add(.2f);
            }
        }
        Add(.2f,()=>{controller.Select(0);Place(new Vector2(62,10));start=body.position;held=new[]{Key.D};});
        Add(1f,null,()=>{held=Array.Empty<Key>();Result("Region border",body.position.x<64,new{from=start.ToString(),stop=body.position.ToString()});});
        Add(.3f,()=>controller.Select(0),()=>Result("Camera bounds",Camera.main.transform.position.x>0&&Camera.main.transform.position.y>0,Camera.main.transform.position.ToString()));
        EditorApplication.update+=Tick;return "Directed Play QA started; WASD, three complete routes and real collider contacts";
    }
    static void Tick()
    {
        try
        {
            if(!EditorApplication.isPlaying){Finish("Play stopped during QA");return;}
            if(Time.frameCount==lastFrame)return;lastFrame=Time.frameCount;
            if(trace.Count==0||Time.frameCount%12==0)trace.Add(new{frame=Time.frameCount,time=Time.timeAsDouble,region=controller.Selected,x=body.position.x,y=body.position.y,animation=animator.State});
            if(routing)
            {
                if(Time.timeAsDouble>routeDeadline){routing=false;held=Array.Empty<Key>();Result(routeName,false,new{waypoint,position=body.position.ToString()});}
                else
                {
                    var delta=route[waypoint]-body.position;
                    if(delta.magnitude<.34f)
                    {
                        waypoint++;
                        if(waypoint>=route.Length){routing=false;held=Array.Empty<Key>();Result(routeName,true,new{waypoints=waypoint,position=body.position.ToString()});}
                    }
                    if(routing){delta=route[waypoint]-body.position;var keys=new List<Key>();if(Mathf.Abs(delta.x)>.16f)keys.Add(delta.x>0?Key.D:Key.A);if(Mathf.Abs(delta.y)>.16f)keys.Add(delta.y>0?Key.W:Key.S);held=keys.ToArray();}
                }
                return;
            }
            if(active!=null&&Time.timeAsDouble<until)return;
            active?.end?.Invoke();if(steps.Count==0){Finish(null);return;}
            active=steps.Dequeue();active.begin?.Invoke();until=Time.timeAsDouble+active.duration;
        }
        catch(Exception error){Finish(error.ToString());}
    }
    static void Finish(string error)
    {
        EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;
        InputSystem.QueueStateEvent(keyboard,new KeyboardState());InputSystem.RemoveDevice(keyboard);original?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;
        File.WriteAllText(output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-firstFrame,results,trace},Formatting.Indented));
    }
}
