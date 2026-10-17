using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Mmorpg.Domain;

// Short, frame-driven Play QA. Setup/teleports are explicit fixtures; traversal uses Input System.
public static class ValidateValdoriaPhase2
{
    sealed class Step { public float seconds; public Action begin,end; }
    static readonly Queue<Step> steps=new Queue<Step>();
    static readonly List<object> results=new List<object>();
    static Keyboard keyboard; static Mouse mouse;
    static Keyboard originalKeyboard; static Mouse originalMouse;
    static InputSettings.BackgroundBehavior background;
    static GameObject player,fixture; static Rigidbody2D body; static ActorHealth health,target;
    static ProductionSpriteAnimator animator; static OfflineAuthority authority; static SwordSwing sword;
    static Step current; static double deadline; static int frame; static Vector2 start;
    static string output="Docs/Validation/ValdoriaReconstructionPhase2/Verified";
    static readonly List<GameObject> pausedActors=new List<GameObject>();
    static Key[] held=Array.Empty<Key>(); static bool heavy;
    static Vector2 aim=Vector2.down;
    static void Add(float duration,Action begin=null,Action end=null)=>steps.Enqueue(new Step{seconds=duration,begin=begin,end=end});
    static void Result(string name,object observed,bool pass)=>results.Add(new{name,pass,observed,frame=Time.frameCount});
    static void Place(Vector2 p){body.position=p;body.linearVelocity=Vector2.zero;player.transform.position=p;Physics2D.SyncTransforms();}
    static void Capture(string name)
    {
        // Render the current live camera after advancing simulation frames. No editor repaint dependency.
        var camera=Camera.main;var previous=camera.targetTexture;var active=RenderTexture.active;
        var rt=RenderTexture.GetTemporary(960,540,24,RenderTextureFormat.ARGB32);
        var image=new Texture2D(960,540,TextureFormat.RGB24,false);
        try {camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,960,540),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());}
        finally {camera.targetTexture=previous;RenderTexture.active=active;RenderTexture.ReleaseTemporary(rt);UnityEngine.Object.DestroyImmediate(image);}
    }
    static void Input()
    {
        if(body==null)
        {
            player=GameObject.Find("Player"); if(player==null)return;
            body=player.GetComponent<Rigidbody2D>();health=player.GetComponent<ActorHealth>();
            animator=player.GetComponent<ProductionSpriteAnimator>();
        }
        InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));
        var screen=Camera.main.WorldToScreenPoint((Vector3)(body.position+aim*4));
        var state=new MouseState{position=screen}; if(heavy)state=state.WithButton(MouseButton.Right);
        InputSystem.QueueStateEvent(mouse,state);
    }
    static void Move(string name,Key[] keys,float seconds)
    {
        Add(seconds,()=>{start=body.position;held=keys;},()=>{held=Array.Empty<Key>();Result(name,new{from=start.ToString(),to=body.position.ToString(),state=animator.State,dir=animator.DirectionIndex},Vector2.Distance(start,body.position)>.3f);});
        Add(.15f);
    }
    static void NewTarget(Vector2 position)
    {
        if(fixture!=null)UnityEngine.Object.DestroyImmediate(fixture);
        fixture=new GameObject("Phase2QA-Target"); fixture.layer=9;fixture.transform.position=position;
        fixture.AddComponent<CircleCollider2D>().radius=.18f;
        fixture.AddComponent<SpriteRenderer>(); // Hit feedback requires the standard actor proxy.
        target=fixture.AddComponent<ActorHealth>();target.Configure(Faction.Training);Physics2D.SyncTransforms();
    }
    static void ContactResult(string id)
    {
        var obstacle=GameObject.Find("ValdoriaPilotArea/"+id).GetComponent<Collider2D>();
        var distance=Physics2D.Distance(player.GetComponent<Collider2D>(),obstacle);
        Result(id+"-physical-contact",new{from=start.ToString(),stop=body.position.ToString(),distance=distance.distance},distance.distance<.08f && Vector2.Distance(start,body.position)>.2f);
    }
    public static string Main()
    {
        if(!EditorApplication.isPlaying || !LocalJourneyProfile.Root.Contains("Temp")) throw new InvalidOperationException("Requires isolated Play");
        UnityEngine.Object.DontDestroyOnLoad(GameObject.Find("Phase2-QA-Isolation"));
        if(Directory.Exists(output))throw new IOException("QA output already exists; refuse overwrite");
        Directory.CreateDirectory(output);
        player=GameObject.Find("Player");body=player.GetComponent<Rigidbody2D>();health=player.GetComponent<ActorHealth>();
        animator=player.GetComponent<ProductionSpriteAnimator>();sword=player.GetComponent<SwordSwing>();
        foreach(var actor in UnityEngine.Object.FindObjectsByType<ActorHealth>(FindObjectsSortMode.None))
            if(actor.Faction!=Faction.Player && actor.Faction!=Faction.Training){pausedActors.Add(actor.gameObject);actor.gameObject.SetActive(false);}
        authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        originalKeyboard=Keyboard.current;originalMouse=Mouse.current;background=InputSystem.settings.backgroundBehavior;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        keyboard=InputSystem.AddDevice<Keyboard>("Phase2QAKeyboard");mouse=InputSystem.AddDevice<Mouse>("Phase2QAMouse");
        frame=Time.frameCount;
        Add(.2f,()=>Place(new Vector2(-8,-3)));
        Move("WASD-W",new[]{Key.W},.4f);Move("WASD-A",new[]{Key.A},.4f);Move("WASD-S",new[]{Key.S},.4f);Move("WASD-D",new[]{Key.D},.4f);
        Move("diagonal",new[]{Key.S,Key.D},.4f);
        Add(.3f,null,()=>Result("idle",animator.State,animator.State=="idle"));
        Add(.05f,()=>held=new[]{Key.Space},()=>Result("dodge-input",new{animator.State,dodging=health.State.IsDodging(Time.timeAsDouble)},health.State.IsDodging(Time.timeAsDouble)));
        Add(1.1f,()=>held=Array.Empty<Key>());
        for(int d=0;d<8;d++)
        {
            int direction=d;var vector=ProductionDirections.Vector(d);
            Add(.1f,()=>{Place(new Vector2(-8,-3));aim=vector;NewTarget(body.position+vector*.9f);});
            Add(.6f,()=>authority.RequestAttack(health,vector),()=>Result("basic-"+direction,new{damage=100-target.State.Health,originDelta=Vector2.Distance(body.position,sword.PhysicalOriginWorld)},target.State.Health==80&&Vector2.Distance(body.position,sword.PhysicalOriginWorld)<.0001f));
        }
        Add(.1f,()=>{NewTarget(body.position+Vector2.right*.9f);aim=Vector2.right;});
        Add(.05f,()=>heavy=true);
        Add(.9f,()=>heavy=false,()=>Result("heavy-mouse",100-target.State.Health,target.State.Health==64));
        Add(.7f);
        Add(.1f,()=>NewTarget(body.position+Vector2.right*2.2f));
        Add(.6f,()=>authority.RequestAttack(health,Vector2.right),()=>Result("out-of-range",100-target.State.Health,target.State.Health==100));
        GameObject wall=null;
        Add(.1f,()=>{NewTarget(body.position+Vector2.right*.9f);wall=new GameObject("Phase2QA-Wall");wall.layer=8;wall.transform.position=body.position+Vector2.right*.45f;wall.AddComponent<BoxCollider2D>().size=new Vector2(.1f,2);Physics2D.SyncTransforms();});
        Add(.6f,()=>authority.RequestAttack(health,Vector2.right),()=>{Result("wall-blocks",100-target.State.Health,target.State.Health==100);UnityEngine.Object.DestroyImmediate(wall);UnityEngine.Object.DestroyImmediate(fixture);});
        // Collected frames show actual continuous movement, never orbit teleports.
        var well=GameObject.Find("ValdoriaPilotArea/village-well").transform.position;
        Add(.2f,()=>Place((Vector2)well+new Vector2(-3.7f,-1.5f)));
        CaptureMove("well",new[]{Key.D},1.9f);
        CaptureMove("well",new[]{Key.W},1.2f);
        CaptureMove("well",new[]{Key.A},1.9f);
        CaptureMove("well",new[]{Key.S},1.2f);
        Add(.2f,null,()=>Capture("well-after"));
        Add(.2f,()=>Place((Vector2)well+new Vector2(4,.5f)));
        Add(1.1f,()=>{held=new[]{Key.A};start=body.position;},()=>{held=Array.Empty<Key>();ContactResult("village-well");});
        var fence=GameObject.Find("ValdoriaPilotArea/village-fence-west").transform.position;
        Add(.2f,()=>Place((Vector2)fence+new Vector2(-3,-3)));
        Move("fence-clear-passage",new[]{Key.D},1.7f);
        var tree=GameObject.Find("ValdoriaPilotArea/oak-full").transform.position;
        Add(.2f,()=>Place((Vector2)tree+new Vector2(4,-2)));
        CaptureMove("tree",new[]{Key.W},1.4f);CaptureMove("tree",new[]{Key.A},2.3f);CaptureMove("tree",new[]{Key.S},1.4f);CaptureMove("tree",new[]{Key.D},2.3f);
        Add(.2f,null,()=>Capture("tree-after"));
        Add(.2f,()=>Place((Vector2)tree+new Vector2(4,3)),()=>{var order=GameObject.Find("ValdoriaPilotArea/oak-full/DepthSilhouette").GetComponent<SpriteRenderer>().sortingOrder;var group=player.GetComponentInChildren<UnityEngine.Rendering.SortingGroup>();Result("tree-behind",new{actor=group.sortingOrder,tree=order},group.sortingOrder<order);Capture("tree-behind");});
        Add(.2f,()=>Place((Vector2)tree+new Vector2(4,-3)),()=>{var order=GameObject.Find("ValdoriaPilotArea/oak-full/DepthSilhouette").GetComponent<SpriteRenderer>().sortingOrder;var group=player.GetComponentInChildren<UnityEngine.Rendering.SortingGroup>();Result("tree-front",new{actor=group.sortingOrder,tree=order},group.sortingOrder>order);Capture("tree-front");});
        var cottage=GameObject.Find("ValdoriaPilotArea/cottage-full").transform.position;
        Add(.2f,()=>Place((Vector2)cottage+new Vector2(0,-2)));
        Add(1.2f,()=>{held=new[]{Key.W};start=body.position;},()=>{held=Array.Empty<Key>();ContactResult("cottage-full");Capture("house-after");});
        Add(.2f,null,()=>Result("camera",new{Camera.main.orthographicSize,rect=Camera.main.rect.ToString()},Mathf.Abs(Camera.main.orthographicSize-7.03125f)<.0001f&&Camera.main.rect==new Rect(0,0,1,1)));
        Add(.2f,()=>{typeof(ActorHealth).GetMethod("ApplyDamage",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(health,new object[]{100,Time.timeAsDouble});});
        Add(.7f,null,()=>{Result("death",new{alive=health.State.IsAlive,animator.State},!health.State.IsAlive);Capture("death");});
        Add(.05f,()=>held=new[]{Key.F5});
        Add(.8f,()=>held=Array.Empty<Key>(),()=>Result("F5-restart",new{alive=health.State.IsAlive,hp=health.State.Health},health.State.IsAlive));
        EditorApplication.update+=Tick;
        return "QA running with frame-driven Input System; results and PNGs under "+output;
    }
    static int captureIndex;
    static void CaptureMove(string subject,Key[] keys,float seconds)
    {
        Add(.01f,()=>held=keys);
        int count=(int)(seconds/.18f);
        for(int i=0;i<count;i++){int n=captureIndex++;Add(.18f,null,()=>Capture(subject+"-"+n.ToString("000")));}
        Add(.01f,()=>held=Array.Empty<Key>());
    }
    static void Tick()
    {
        try
        {
            if(!EditorApplication.isPlaying){Finish("Play stopped");return;}
            Input();
            if(current!=null&&Time.timeAsDouble<deadline)return;
            current?.end?.Invoke();
            if(steps.Count==0){Finish(null);return;}
            current=steps.Dequeue();current.begin?.Invoke();deadline=Time.timeAsDouble+current.seconds;
        }
        catch(Exception e){Finish(e.ToString());}
    }
    static void Finish(string error)
    {
        EditorApplication.update-=Tick;
        InputSystem.settings.backgroundBehavior=background;
        if(keyboard!=null)InputSystem.RemoveDevice(keyboard);if(mouse!=null)InputSystem.RemoveDevice(mouse);
        originalKeyboard?.MakeCurrent();originalMouse?.MakeCurrent();
        if(fixture!=null)UnityEngine.Object.DestroyImmediate(fixture);
        foreach(var actor in pausedActors)if(actor!=null)actor.SetActive(true);
        File.WriteAllText(output+"/qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-frame,results},Formatting.Indented));
    }
    public static string SingleHit()
    {
        if(!EditorApplication.isPlaying || !LocalJourneyProfile.Root.Contains("Temp"))throw new InvalidOperationException("Requires isolated Play");
        var p=GameObject.Find("Player");var rb=p.GetComponent<Rigidbody2D>();var hp=p.GetComponent<ActorHealth>();
        rb.position=new Vector2(-8,-3);p.transform.position=new Vector3(-8,-3,0);rb.linearVelocity=Vector2.zero;
        var server=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        var dummy=new GameObject("Phase2QA-OneHit");dummy.layer=9;dummy.transform.position=new Vector3(-8,-3.9f,0);
        dummy.AddComponent<SpriteRenderer>();var hitbox=dummy.AddComponent<CircleCollider2D>();hitbox.radius=.18f;hitbox.isTrigger=true;
        var victim=dummy.AddComponent<ActorHealth>();victim.Configure(Faction.Training);Physics2D.SyncTransforms();
        var previousKey=Keyboard.current;var previousMouse=Mouse.current;
        var previousBackground=InputSystem.settings.backgroundBehavior;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        var key=InputSystem.AddDevice<Keyboard>();var pointer=InputSystem.AddDevice<Mouse>();
        int hits=0;double began=Time.timeAsDouble;Action<ActorHealth,ActorHealth> hit=(a,b)=>{if(b==victim)hits++;};server.HitConfirmed+=hit;
        EditorApplication.CallbackFunction tick=null;
        tick=()=>{
            double elapsed=Time.timeAsDouble-began;
            InputSystem.QueueStateEvent(key,new KeyboardState(elapsed>=.12&&elapsed<.25?new[]{Key.J}:Array.Empty<Key>()));
            InputSystem.QueueStateEvent(pointer,new MouseState{position=Camera.main.WorldToScreenPoint(dummy.transform.position)});
            if(Time.timeAsDouble-began<.75)return;
            EditorApplication.update-=tick;server.HitConfirmed-=hit;
            int damage=100-victim.State.Health;
            bool dodge=server.RequestDodge(hp);int before=hp.State.Health;
            typeof(ActorHealth).GetMethod("ApplyDamage",BindingFlags.NonPublic|BindingFlags.Instance).Invoke(hp,new object[]{20,Time.timeAsDouble});
            File.WriteAllText(output+"/single-hit-proof.json",JsonConvert.SerializeObject(new{input="Input System J",hits,damage,dodgeInvulnerability=dodge&&hp.State.Health==before,pass=hits==1&&damage==20&&dodge&&hp.State.Health==before},Formatting.Indented));
            InputSystem.settings.backgroundBehavior=previousBackground;
            InputSystem.RemoveDevice(key);InputSystem.RemoveDevice(pointer);previousKey?.MakeCurrent();previousMouse?.MakeCurrent();UnityEngine.Object.DestroyImmediate(dummy);
        };
        EditorApplication.update+=tick;return "Single-hit and dodge probe started";
    }
}
