using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
public static class InspectIronKnight06B10
{
    private static string Evidence=>SessionState.GetString("b10-evidence","Docs/Validation/Marco06B10/baseline/");
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static ActorHealth Player=>Journey.Player;
    private static ProductionSpriteAnimator Animator=>Player.GetComponent<ProductionSpriteAnimator>();
    private static SwordSwing Sword=>Player.GetComponent<SwordSwing>();
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="AnimationKeyboard");
    private static Mouse Pointer=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="AnimationMouse");
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    private static void Aim(Vector2 direction,int button=0)=>InputSystem.QueueStateEvent(Pointer,new MouseState{position=Camera.main.WorldToScreenPoint((Vector2)Player.transform.position+direction*3),buttons=(ushort)button});
    private static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(5);}
    private static async Task Tap(params Key[] keys){Key(keys);await Wait(.04f);Key();await Wait(.04f);}
    public static string Prepare()
    {
        if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new Exception("Clean scene outside Play required");
        string scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path;
        if(scene!="Assets/Mmorpg/Scenes/Marco06B9ProfessionalHero.unity"&&scene!="Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity")throw new Exception("B9 or B10 required");
        SessionState.SetString("b10-evidence","Docs/Validation/Marco06B10/"+(scene.Contains("06B10")?"candidate":"baseline")+"/");
        Directory.CreateDirectory(Evidence);
        SessionState.SetBool("b10-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b10-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b10-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b10-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B10/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);LocalJourneyProfile.ValidationRootOverride=dir;
        return dir;
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b10-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var d in native)InputSystem.DisableDevice(d);
        InputSystem.AddDevice<Keyboard>("AnimationKeyboard");InputSystem.AddDevice<Mouse>("AnimationMouse");Aim(Vector2.down);return Inspect();
    }
    public static string Inspect()=>JsonConvert.SerializeObject(new {frame=Time.frameCount,position=Player.transform.position.ToString(),state=Animator.State,visual=Animator.VisualFacing.ToString(),aim=Sword.AimDirection.ToString(),sprite=Animator.Body.sprite.name,profile=LocalJourneyProfile.Root});
    private static object Read(object obj,string field)=>obj.GetType().GetField(field,System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(obj);
    private static float[] XY(Vector3 p)=>new[]{p.x,p.y};
    private static void Verify()
    {
        var pivot=Player.transform.Find("VisualRoot/WeaponPivot");
        float error=Vector3.Distance(pivot.position,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand));
        if(error>.0001f||Vector3.Distance(pivot.localScale,Vector3.one)>.0001f)throw new Exception("Grip/scale mismatch: "+error);
    }
    private static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>(); Player.StartCoroutine(CaptureAtEndOfFrame(name,done));
        if(await Task.WhenAny(done.Task,Task.Delay(3000))!=done.Task)throw new Exception("GameView end-of-frame stalled");
        await done.Task;
    }
    private static System.Collections.IEnumerator CaptureAtEndOfFrame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try {
        Verify();var point=Camera.main.WorldToScreenPoint(Player.transform.position);var pivot=Player.transform.Find("VisualRoot/WeaponPivot");
        File.AppendAllText(Evidence+"capture-metadata.jsonl",JsonConvert.SerializeObject(new{name,frame=Time.frameCount,time=Time.timeAsDouble,realTime=Time.realtimeSinceStartupAsDouble,timeScale=Time.timeScale,screenWidth=Screen.width,screenHeight=Screen.height,playerScreen=new[]{point.x,point.y},position=XY(Player.transform.position),velocity=XY(Player.GetComponent<Rigidbody2D>().linearVelocity),clipTime=(float)Read(Animator,"walkTime"),grip=XY(Sword.GripWorld),anchor=XY(Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand)),bladeAngle=Sword.VisualAngle,tip=XY(Sword.VisualTipWorld),attackProgress=Sword.AttackProgress,phaseProgress=Sword.PhaseProgress,sweep=((IEnumerable<Vector3>)Read(Player.GetComponent<SwordSweepDebug>(),"physical")).Select(XY).ToArray(),sprite=Animator.Body.sprite.name,source=Animator.CurrentFrame.source,phase=Sword.VisualPhase,state=Animator.State,visual=Animator.VisualFacing.ToString(),aim=Sword.AimDirection.ToString(),attack=Sword.AttackDirection.ToString(),gripError=Vector3.Distance(pivot.position,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand)),scale=pivot.localScale.ToString(),bladeLength=Sword.BladeLength,sweepLength=Sword.SweepLength})+"\n");
        var texture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+name+".png",texture.EncodeToPNG());UnityEngine.Object.Destroy(texture);done.SetResult(true);
        } catch(Exception error) {done.SetException(error);}
    }
    public static async Task<string> Movement()
    {
        try {return await MovementCore();} finally {Key();}
    }
    private static async Task<string> MovementCore()
    {
        Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);
        int first=Time.frameCount;var report=new List<object>();
        await Wait(.2f);await Capture("idle");
        Key[][] keys={new[]{UnityEngine.InputSystem.Key.D},new[]{UnityEngine.InputSystem.Key.A},new[]{UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.S},new[]{UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.S},new[]{UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.S}};
        Vector2[] directions={Vector2.right,Vector2.left,Vector2.up,Vector2.down,new Vector2(1,1).normalized,new Vector2(-1,-1).normalized,new Vector2(-1,1).normalized,new Vector2(1,-1).normalized};
        for(int d=0;d<keys.Length;d++)
        {
            Key();Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);await Wait(.1f);var from=(Vector2)Player.transform.position;Aim(-directions[d]);Key(keys[d]);await Wait(.12f);
            var sprites=new HashSet<string>();float maxSpeed=0;
            for(int i=0;i<8;i++){Aim(-directions[d]);await Wait(.035f);await Capture("walk-"+d+"-"+i.ToString("00"));sprites.Add(Animator.Body.sprite.name);maxSpeed=Mathf.Max(maxSpeed,Player.GetComponent<Rigidbody2D>().linearVelocity.magnitude);}
            if(!sprites.Any(s=>s.Contains("walk"))||maxSpeed<3||Vector2.Dot(Animator.VisualFacing,directions[d])<.5f||Vector2.Dot(Sword.AimDirection,-directions[d])<.95f)throw new Exception("Movement/aim policy failed "+d+" "+Inspect());
            report.Add(new{direction=d,from=from.ToString(),to=Player.transform.position.ToString(),maxSpeed,sprites});Key();await Wait(.22f);
            int resting=Animator.DirectionIndex;Aim(directions[d]);await Wait(.06f);Aim(-directions[d]);await Wait(.06f);
            if(Animator.DirectionIndex!=resting)throw new Exception("Idle followed mouse");
            await Capture("stop-"+d);Key(keys[d]);await Wait(.07f);await Capture("resume-"+d);Key();await Wait(.22f);
        }
        await Tap(UnityEngine.InputSystem.Key.Space);await Capture("dodge");await Wait(.3f);
        if(Time.frameCount<=first)throw new Exception("Frozen frames");
        string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,report},Formatting.Indented);File.WriteAllText(Evidence+"movement.json",json);return json;
    }
    public static async Task<string> Attacks()
    {
        try {return await AttacksCore();} finally {Time.timeScale=1;Key();}
    }
    private static async Task<string> AttacksCore()
    {
        Time.timeScale=.35f;var report=new List<object>();Vector2[] dirs={Vector2.down,Vector2.left,Vector2.up,Vector2.right,Vector2.down,Vector2.left,Vector2.up,Vector2.right,new Vector2(1,1).normalized};
        await Tap(UnityEngine.InputSystem.Key.F7);
        for(int d=0;d<dirs.Length;d++)
        {
            Aim(dirs[d],d>=4?2:1);await Wait(.025f);Aim(dirs[d]);
            var phases=new HashSet<string>();
            for(int i=0;i<(d>=4?24:13);i++){phases.Add(Sword.VisualPhase);if(Sword.Busy&&Vector2.Dot(Sword.AttackDirection,dirs[d])<.99f)throw new Exception("Attack direction drift");await Capture("attack-"+d+"-"+i.ToString("00"));await Wait(.025f);}
            if(!new[]{"preparation","cut","recovery"}.All(phases.Contains))throw new Exception("Missing attack phase "+d);
            report.Add(new{direction=d,heavy=d>=4,phases});await Wait(d>=4?3.5f:1.2f);
        }
        Key(UnityEngine.InputSystem.Key.D);Aim(Vector2.left,1);await Wait(.025f);Aim(Vector2.right);if(!Sword.Busy||Vector2.Dot(Sword.AttackDirection,Vector2.left)<.99f)throw new Exception("Moving strike not confirmed/locked");for(int i=0;i<12;i++)await Capture("moving-attack-"+i.ToString("00"));Key();await Wait(.5f);
        await Tap(UnityEngine.InputSystem.Key.Space);await Wait(.8f);Aim(Vector2.down,1);await Wait(.025f);Aim(Vector2.down);if(!Sword.Busy)throw new Exception("Post-dodge strike not accepted");for(int i=0;i<12;i++)await Capture("after-dodge-"+i.ToString("00"));
        Time.timeScale=1;await Wait(.4f);await Capture("attack-to-idle");Key(UnityEngine.InputSystem.Key.D);await Wait(.1f);await Capture("attack-to-walk");Key();await Tap(UnityEngine.InputSystem.Key.F7);string json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"attacks.json",json);return json;
    }

    public static async Task<string> Combat()
    {
        // Controlled Play-only fixture: existing dummy and player repositioned; no saved scene mutation.
        Key();Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);await Wait(.6f);var target=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;
        var rb=Player.GetComponent<Rigidbody2D>();Vector2 origin=rb.position;var targetOriginal=target.transform.position;
        var report=new List<object>();GameObject wall=null;
        var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();int hits=0;Action<ActorHealth,ActorHealth> onHit=(attacker,defender)=>{if(attacker==Player&&defender==target)hits++;};authority.HitConfirmed+=onHit;
        try
        {
            foreach(string scenario in new[]{"near","outside-range","wall","heavy"})
            {
                await Wait(2.2f);rb.position=origin;rb.linearVelocity=Vector2.zero;
                target.transform.position=origin+Vector2.right*(scenario=="outside-range"?3:.85f);Physics2D.SyncTransforms();
                if(scenario=="wall"){wall=new GameObject("B10 temporary LOS fixture");wall.layer=8;wall.transform.position=origin+Vector2.right*.4f;wall.AddComponent<BoxCollider2D>().size=new Vector2(.1f,3);Physics2D.SyncTransforms();}
                hits=0;int before=target.State.Health;Aim(Vector2.right,scenario=="heavy"?2:1);await Wait(.035f);Aim(Vector2.right);await Wait(scenario=="heavy"?.43f:.12f);if(scenario=="near"||scenario=="heavy")await Capture("impact-"+scenario);await Wait(.4f);int damage=before-target.State.Health;
                int expected=scenario=="near"?20:scenario=="heavy"?36:0;
                report.Add(new{scenario,before,after=target.State.Health,damage,expected,hitConfirmedCount=hits});await Capture("combat-"+scenario);
                if(hits!=(expected>0?1:0))throw new Exception("Hit count mismatch "+scenario+": "+hits);
                if(damage!=expected)throw new Exception("Damage mismatch "+scenario+": "+damage+" expected "+expected);
                if(wall!=null){UnityEngine.Object.Destroy(wall);wall=null;}
            }
        }
        finally {authority.HitConfirmed-=onHit;if(wall!=null)UnityEngine.Object.Destroy(wall);target.transform.position=targetOriginal;Key();}
        string json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"combat.json",json);return json;
    }
    public static async Task<string> Obstacles()
    {
        var rb=Player.GetComponent<Rigidbody2D>();var original=rb.position;float max=0;int first=Time.frameCount;
        try
        {
            Key();rb.position=new Vector2(-6,2);await Wait(.25f);Key(UnityEngine.InputSystem.Key.D);
            for(int i=0;i<8;i++){await Wait(.06f);max=Mathf.Max(max,rb.linearVelocity.magnitude);await Capture("obstacle-"+i);}
            float stopped=rb.linearVelocity.magnitude;if(max<3||stopped>.1f)throw new Exception("Existing rock collision inspection failed");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,maxSpeed=max,blockedSpeed=stopped,position=XY(rb.position)});File.WriteAllText(Evidence+"obstacles.json",json);return json;
        } finally {Key();rb.position=original;}
    }
    public static async Task<string> Footfalls()
    {
        var rows=new List<object>();int first=Time.frameCount;
        try
        {
            Key[][] keys={new[]{UnityEngine.InputSystem.Key.S},new[]{UnityEngine.InputSystem.Key.A},new[]{UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.D}};
            for(int d=0;d<4;d++)
            {
                Key();Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);await Wait(.22f);Key(keys[d]);
                var done=new TaskCompletionSource<bool>();Player.StartCoroutine(FootTrace(d,rows,done));await done.Task;Key();await Wait(.22f);
            }
            if(Time.frameCount<=first)throw new Exception("Frozen frame trace");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,rows},Formatting.Indented);File.WriteAllText(Evidence+"foot-trace.json",json);return "Captured "+rows.Count+" rendered foot samples";
        } finally {Key();}
    }
    private static System.Collections.IEnumerator FootTrace(int direction,List<object> rows,TaskCompletionSource<bool> done)
    {
        double end=Time.timeAsDouble+.85;
        while(Time.timeAsDouble<end)
        {
            yield return new WaitForEndOfFrame();
            rows.Add(new{direction,frame=Time.frameCount,time=Time.timeAsDouble,clipTime=(float)Read(Animator,"walkTime"),position=XY(Player.transform.position),velocity=XY(Player.GetComponent<Rigidbody2D>().linearVelocity),source=Animator.CurrentFrame.source,state=Animator.State});
        }
        done.SetResult(true);
    }
    public static async Task<string> FinalView()
    {
        Time.timeScale=1;Key();Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);await Wait(.2f);
        Key(UnityEngine.InputSystem.Key.S);await Wait(.1f);Key();await Wait(.25f);Aim(Vector2.up);await Capture("idle");return Inspect();
    }
    public static string Cleanup()
    {
        if(EditorApplication.isPlaying)throw new Exception("Stop Play first");
        foreach(var d in InputSystem.devices.Where(d=>d.name=="AnimationKeyboard"||d.name=="AnimationMouse").ToArray())InputSystem.RemoveDevice(d);
        foreach(string id in SessionState.GetString("b10-devices","").Split(','))if(int.TryParse(id,out int device)){var d=InputSystem.GetDeviceById(device);if(d!=null)InputSystem.EnableDevice(d);}
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b10-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b10-options",0);
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("b10-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("b10-editor-input",0);
        Time.timeScale=1;LocalJourneyProfile.ValidationRootOverride=null;return "Input/Editor restored, personal saves preserved.";
    }
}
