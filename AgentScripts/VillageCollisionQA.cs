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
public static class VillageCollisionQA
{
    sealed class Probe {public string id;public Vector2 point;public Key[] keys;public Func<Vector2,bool> check;}
    static List<Probe> probes;static int i,last;static double until;static bool pushing;static Rigidbody2D body;static Vector2 start;
    static Keyboard keyboard,previous;static List<InputDevice> devices=new List<InputDevice>();static Key[] held=Array.Empty<Key>();
    static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;
    static List<object> results=new List<object>();static VillageEvidenceCapture capture;
    const string Root="Docs/Validation/ValdoriaPlayableVillage01/";
    static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
    public static object Main()
    {
        if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||File.Exists(Root+"QA/collision-qa.json"))throw new IOException("New isolated Play probe required");
        body=GameObject.Find("Player").GetComponent<Rigidbody2D>();capture=Object.FindAnyObjectByType<VillageEvidenceCapture>();if(!capture)capture=new GameObject("Temporary village captures").AddComponent<VillageEvidenceCapture>();
        previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;
        foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){devices.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        keyboard=InputSystem.AddDevice<Keyboard>("Village collision fixtures");InputSystem.onBeforeUpdate+=Feed;
        probes=new List<Probe>{
            new Probe{id="bridge-right-rail",point=new Vector2(56,24),keys=new[]{Key.D},check=p=>p.x<58.1f&&p.x>56.2f},
            new Probe{id="south-wall",point=new Vector2(46,37),keys=new[]{Key.S},check=p=>p.y>35&&p.y<36.6f},
            new Probe{id="river-outside-bridge",point=new Vector2(70,31),keys=new[]{Key.S},check=p=>p.y>26&&p.y<30},
            new Probe{id="tree-trunk",point=new Vector2(19,8),keys=new[]{Key.W},check=p=>p.y<9.7f&&p.y>8.2f},
            new Probe{id="house-wall",point=new Vector2(36,44.5f),keys=new[]{Key.W},check=p=>p.y<47.1f&&p.y>44.8f},
            new Probe{id="rock-footprint",point=new Vector2(38,8.3f),keys=new[]{Key.W},check=p=>p.y<11&&p.y>8.5f},
            new Probe{id="west-world-edge",point=new Vector2(2,8),keys=new[]{Key.A},check=p=>p.x>.05f&&p.x<1.5f},
            new Probe{id="diagonal-input",point=new Vector2(56,10),keys=new[]{Key.W,Key.D},check=p=>p.x>57&&p.y>11},
            new Probe{id="dodge-input",point=new Vector2(56,8),keys=new[]{Key.D,Key.Space},check=p=>p.x>57.5f},
            new Probe{id="house-front-opaque",point=new Vector2(30,45.5f),keys=Array.Empty<Key>(),check=p=>!Object.FindObjectsByType<ReferenceHouseDepth>().Where(h=>h.name=="home-west").Any(h=>h.CutawayActive)},
            new Probe{id="house-behind-cutaway",point=new Vector2(30,58),keys=Array.Empty<Key>(),check=p=>Object.FindObjectsByType<ReferenceHouseDepth>().Where(h=>h.name=="home-west").Any(h=>h.CutawayActive)},
            new Probe{id="tree-front-sorting",point=new Vector2(19,8),keys=Array.Empty<Key>(),check=p=>body.GetComponent<ProductionSpriteAnimator>().Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>().sortingOrder>GameObject.Find("oak-0").GetComponentInChildren<UnityEngine.Rendering.SortingGroup>().sortingOrder},
            new Probe{id="tree-behind-sorting",point=new Vector2(19,11.8f),keys=Array.Empty<Key>(),check=p=>body.GetComponent<ProductionSpriteAnimator>().Body.GetComponentInParent<UnityEngine.Rendering.SortingGroup>().sortingOrder<GameObject.Find("oak-0").GetComponentInChildren<UnityEngine.Rendering.SortingGroup>().sortingOrder}
        };i=0;until=0;EditorApplication.update+=Tick;return "Directed collision fixtures queued; separate from zero-teleport exploration proof";
    }
    static void Tick()
    {
        if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(last==Time.frameCount)return;last=Time.frameCount;double now=Time.timeAsDouble;if(now<until)return;
        try{
            if(i==probes.Count){Finish(null);return;}var p=probes[i];
            if(!pushing){held=Array.Empty<Key>();body.position=p.point;body.transform.position=p.point;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();start=body.position;held=p.keys;pushing=true;until=now+.75;return;}
            held=Array.Empty<Key>();results.Add(new{name=p.id,pass=p.check(body.position),from=start.ToString("R"),to=body.position.ToString("R"),frame=last,fixturePlacement=true,realKeyboard=true});capture.Capture("collision-"+p.id,"directed collision fixture, not exploration sequence");i++;pushing=false;until=now+.5;
        }catch(Exception e){Finish(e.ToString());}
    }
    static void Finish(string error)
    {
        EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in devices)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;
        body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);File.WriteAllText(Root+"QA/collision-qa.json",JsonConvert.SerializeObject(new{error,results,placement="Explicit fixture setups, not part of mandatory continuous exploration",inputRestored=true},Formatting.Indented));
    }
}
