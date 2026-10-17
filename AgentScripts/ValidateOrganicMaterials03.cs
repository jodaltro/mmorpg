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

public static class ValidateOrganicMaterials03
{
    sealed class Step {public float seconds;public Action begin,end;}
    static readonly Queue<Step> steps=new Queue<Step>();static readonly List<object> results=new List<object>(),trace=new List<object>();
    static TerrainMaterialLabController lab;static Rigidbody2D body;static ProductionSpriteAnimator animator;
    static readonly List<InputDevice> disabledKeyboards=new List<InputDevice>();
    static Keyboard keyboard,previousKeyboard;static InputSettings.BackgroundBehavior previousBackground;static InputSettings.EditorInputBehaviorInPlayMode previousEditorInput;
    static Key[] held=Array.Empty<Key>();static Step active;static double until,routeDeadline,nextTrace;
    static int firstFrame,lastFrame,targetIndex,style,motionFrames;static double nextMotion;static bool dodged;static bool routing,captured;static Vector2 start,narrowPoint;
    static Vector2[] axis,targets;static float[] widths;static float nearestNarrow,maxFootExcess;static double began;
    const string Output="Docs/Validation/ValdoriaWorldStudio03/Final/PlayQA";
    static void Add(float seconds,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=seconds,begin=begin,end=end});
    static void Result(string name,bool pass,object evidence)=>results.Add(new{name,pass,evidence,frame=Time.frameCount});
    static void Place(Vector2 p){body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();}
    static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
    static Key[] Keys(Vector2 d,float dead=.07f)
    {var k=new List<Key>();if(Mathf.Abs(d.x)>dead)k.Add(d.x>0?Key.D:Key.A);if(Mathf.Abs(d.y)>dead)k.Add(d.y>0?Key.W:Key.S);return k.ToArray();}
    static void Move(string name,Key[] keys,float seconds=.4f)
    {
        Add(seconds,()=>{start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,Vector2.Distance(start,body.position)>.6f,new{from=start.ToString(),to=body.position.ToString(),animation=animator.State});});Add(.1f);
    }
    static void LoadRoad()
    {
        var r=JObject.Parse(File.ReadAllText("ArtSource/Labs/World2026/WorldStudio02/RoadsR3/A/road.json"));var list=new List<Vector2>();var ws=new List<float>();
        foreach(var segment in r["segments"])foreach(var p in segment["samples"])
        {
            var point=new Vector2((float)p[0],48-(float)p[1]);if(list.Count>0&&Vector2.Distance(list.Last(),point)<.00001f)continue;
            list.Add(point);ws.Add((float)p[4]);
        }
        axis=list.ToArray();widths=ws.ToArray();int narrow=Array.IndexOf(widths,widths.Min());narrowPoint=axis[narrow];
        var destination=new List<Vector2>();for(int i=0;i<axis.Length;i+=4)destination.Add(axis[i]);destination.Add(axis.Last());targets=destination.ToArray();
    }
    static float FootExcess(Vector2 point)
    {
        float best=float.MaxValue,half=0;
        for(int i=0;i<axis.Length-1;i++)
        {
            var delta=axis[i+1]-axis[i];float t=Mathf.Clamp01(Vector2.Dot(point-axis[i],delta)/delta.sqrMagnitude);
            float distance=Vector2.Distance(point,axis[i]+t*delta);
            if(distance<best){best=distance;half=Mathf.Lerp(widths[i],widths[i+1],t)*.5f;}
        }
        return best-half;
    }
    static float ColliderExcess()
    {
        var collider=body.GetComponent<BoxCollider2D>();var centre=body.position+collider.offset;var half=collider.size*.5f;float excess=float.NegativeInfinity;
        foreach(var corner in new[]{new Vector2(-half.x,-half.y),new Vector2(half.x,-half.y),new Vector2(half.x,half.y),new Vector2(-half.x,half.y)})excess=Mathf.Max(excess,FootExcess(centre+corner));
        return excess;
    }
    public static string Main()
    {
        if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new Exception("Requires isolated road lab Play");
        if(Directory.Exists(Output))throw new IOException("Refuse QA destination overwrite");Directory.CreateDirectory(Output);Directory.CreateDirectory(Output+"/Motion");
        lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();body=GameObject.Find("Player").GetComponent<Rigidbody2D>();animator=body.GetComponent<ProductionSpriteAnimator>();
        previousKeyboard=Keyboard.current;foreach(var device in InputSystem.devices.OfType<Keyboard>().Where(d=>d.enabled).ToArray()){disabledKeyboards.Add(device);InputSystem.DisableDevice(device);}
        previousBackground=InputSystem.settings.backgroundBehavior;previousEditorInput=InputSystem.settings.editorInputBehaviorInPlayMode;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;keyboard=InputSystem.AddDevice<Keyboard>("OrganicMaterialsQA");InputSystem.onBeforeUpdate+=Feed;
        firstFrame=Time.frameCount;began=Time.timeAsDouble;
        Add(.2f,()=>{lab.Select(0,2);Place(new Vector2(14.5f,14.5f));});
        Move("WASD-W",new[]{Key.W});Move("WASD-A",new[]{Key.A});Move("WASD-S",new[]{Key.S});Move("WASD-D",new[]{Key.D});Move("Diagonal-WD",new[]{Key.W,Key.D});
        Add(.4f,()=>{dodged=false;held=new[]{Key.D,Key.Space};},()=>{held=Array.Empty<Key>();Result("Input System dodge",dodged,new{observedDodge=dodged});});Add(.3f);
        for(int selection=1;selection<=3;selection++)
        {
            int current=selection;
            Add(.2f,()=>{style=current;lab.Select(current-1,2);LoadRoad();});
            Add(.1f,()=>{motionFrames=0;nextMotion=Time.timeAsDouble+7.5;Place(targets[0]);targetIndex=1;routing=true;routeDeadline=Time.timeAsDouble+40;nearestNarrow=float.MaxValue;maxFootExcess=float.NegativeInfinity;captured=false;});
            Add(.25f,null,()=>{
                Result("ABC"[current-1]+" narrow-section",nearestNarrow<.35f,new{nearestNarrow,narrow=narrowPoint.ToString(),minimum=widths.Min()});
                var shadow=body.GetComponentsInChildren<Transform>().First(t=>t.name=="GroundShadow");var group=animator.Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>();
                Result("ABC"[current-1]+" feet/sorting",Vector2.Distance(shadow.position,body.position)<.01f&&group.sortingOrder==100-Mathf.RoundToInt(body.position.y*16),new{shadowDelta=Vector2.Distance(shadow.position,body.position),group.sortingOrder,scale=animator.Body.transform.lossyScale.ToString()});
            });
            for(int side=-1;side<=1;side+=2)
            {
                int sign=side;Vector2 normal=Vector2.zero;float expected=0;
                Add(.2f,()=>{int index=Mathf.Min(125,axis.Length-2);var tangent=(axis[index+1]-axis[index]).normalized;normal=new Vector2(-tangent.y,tangent.x)*sign;Place(axis[index]);expected=widths[index]*.5f;});
                Add(1.05f,()=>{start=body.position;held=Keys(normal,.15f);},()=>{
                    held=Array.Empty<Key>();float crossed=Vector2.Dot(body.position-start,normal);
                    bool obstacle=Physics2D.OverlapBox(body.position+body.GetComponent<BoxCollider2D>().offset,body.GetComponent<BoxCollider2D>().size,0,1<<8)!=null;
                    Result("ABC"[current-1]+(sign<0?" right margin":" left margin"),crossed>expected+.2f&&!obstacle,new{from=start.ToString(),to=body.position.ToString(),projectedDistance=crossed,halfWidth=expected,obstacle});
                });Add(.15f);
            }
        }
        Add(.5f,()=>lab.Select(0,2),()=>{
            var camera=Camera.main;Result("Camera/scale",Mathf.Abs(camera.orthographicSize-11.25f)<.0001f,new{camera.orthographicSize,camera.pixelWidth,camera.pixelHeight});
            var data=UnityEngine.Object.FindAnyObjectByType<TerrainRegionData>();
            Result("Single shared terrain",UnityEngine.Object.FindObjectsByType<TerrainRegionData>().Length==1,new{source=data.WorldRegion.name});
            Result("No road colliders",UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>().GetComponentsInChildren<Collider2D>(true).Length==0,"Overlays use original terrain collision only");
        });
        EditorApplication.update+=Tick;return "Material QA started: complete A/B/C curves, narrow sections and both visual margins";
    }
    static void Tick()
    {
        try
        {
            if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}
            if(lastFrame==Time.frameCount)return;lastFrame=Time.frameCount;
            if(body.GetComponent<ActorHealth>().State.IsDodging(Time.timeAsDouble))dodged=true;
            if(routing)
            {
                if(motionFrames<30&&Time.timeAsDouble>=nextMotion){var cam=Camera.main;string file="ABC"[style-1]+"-"+motionFrames.ToString("00")+".png";ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/Motion/"+file));trace.Add(new{capture=file,frame=Time.frameCount,camera=cam.transform.position.ToString(),pixelWidth=cam.pixelWidth,pixelHeight=cam.pixelHeight,deltaTime=Time.unscaledDeltaTime});motionFrames++;nextMotion=Time.timeAsDouble+.10;}
                nearestNarrow=Mathf.Min(nearestNarrow,Vector2.Distance(body.position,narrowPoint));
                if(Time.timeAsDouble>=nextTrace)
                {
                    float excess=ColliderExcess();maxFootExcess=Mathf.Max(maxFootExcess,excess);nextTrace=Time.timeAsDouble+.08;
                    trace.Add(new{style,frame=Time.frameCount,time=Time.timeAsDouble,x=body.position.x,y=body.position.y,animation=animator.State,footExcess=excess,keyboard=Keyboard.current?.name,held=string.Join(",",held),target=targets[targetIndex].ToString(),velocity=body.linearVelocity.ToString()});
                }
                if(!captured&&targetIndex>targets.Length/2&&animator.State=="walk")
                {
                    ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+"ABC"[style-1]+"-walking.png"));captured=true;
                    results.Add(new{name="ABC"[style-1]+" walking capture request",pass=true,evidence=new{frame=Time.frameCount,position=body.position.ToString(),animation=animator.State,method="ScreenCapture end-of-frame Game View"}});
                }
                if(Vector2.Distance(body.position,targets[targetIndex])<.14f)targetIndex++;
                if(targetIndex>=targets.Length||Time.timeAsDouble>routeDeadline)
                {
                    bool reached=targetIndex>=targets.Length;routing=false;held=Array.Empty<Key>();
                    Result("ABC"[style-1]+" complete curve",reached&&maxFootExcess<.04f,new{reached,maxFootExcess,targetsReached=targetIndex,targets=targets.Length,position=body.position.ToString()});
                }
                else held=Keys(targets[targetIndex]-body.position);
                return;
            }
            if(active!=null&&Time.timeAsDouble<until)return;active?.end?.Invoke();
            if(steps.Count==0){Finish(null);return;}active=steps.Dequeue();active.begin?.Invoke();until=Time.timeAsDouble+active.seconds;
        }
        catch(Exception error){Finish(error.ToString());}
    }
    static void Finish(string error)
    {
        EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;
        if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var device in disabledKeyboards)InputSystem.EnableDevice(device);previousKeyboard?.MakeCurrent();InputSystem.settings.backgroundBehavior=previousBackground;InputSystem.settings.editorInputBehaviorInPlayMode=previousEditorInput;
        File.WriteAllText(Output+"/play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-firstFrame,seconds=Time.timeAsDouble-began,results,trace},Formatting.Indented));
    }
}
