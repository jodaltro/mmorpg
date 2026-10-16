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
public static class InspectIronKnight06B11
{
    private static string Evidence=>SessionState.GetString("b11-evidence","Docs/Validation/Marco06B11/baseline/");
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
        if(scene!="Assets/Mmorpg/Scenes/Marco06B11CharacterStates.unity"&&scene!="Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity")throw new Exception("B9 or B10 required");
        SessionState.SetString("b11-evidence","Docs/Validation/Marco06B11/"+(scene.Contains("06B11")?"candidate":"baseline")+"/");
        Directory.CreateDirectory(Evidence);
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B11/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);LocalJourneyProfile.ValidationRootOverride=dir;
        return dir;
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b11-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var d in native)InputSystem.DisableDevice(d);
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
        if(Player.State.IsAlive)Verify();var point=Camera.main.WorldToScreenPoint(Player.transform.position);var pivot=Player.transform.Find("VisualRoot/WeaponPivot");
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
    private static ProductionCharacterStates States=>Player.GetComponent<ProductionCharacterStates>();
    private static OfflineAuthority Authority=>UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
    private static SpriteRenderer Blade=>Player.transform.Find("VisualRoot/WeaponPivot").GetComponentInChildren<SpriteRenderer>();
    private static Rigidbody2D Rb=>Player.GetComponent<Rigidbody2D>();
    private static void Check(bool condition,string message){if(!condition)throw new Exception(message+" "+Inspect());}
    private static void ResetActor()
    {
        Key();Player.Configure(Faction.Player);Rb.simulated=true;Rb.position=new Vector2(-2.75f,0);Rb.linearVelocity=Vector2.zero;
    }
    // Controlled incoming strikes: invoke the existing authority's post-spatial-validation path.
    // Training faction bypasses sanctuary only in this temporary fixture; damage comes from ActionCombatRules.
    private static bool Hit(Mmorpg.Domain.ActionStrike strike=Mmorpg.Domain.ActionStrike.Wolf,bool friendly=false)
    {
        var attacker=friendly?Player:UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;
        return (bool)typeof(OfflineAuthority).GetMethod("ResolveDamage",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(Authority,new object[]{attacker,Player,strike,null});
    }
    public sealed class StateSample
    {
        public string name,state,sprite,source;public int frame,hp,reactions,direction;
        public double time,dodgeUntil;public float speed,alpha,gripError,screenX,screenY,x,y;public bool dodging,blade,deathComplete,simulated,attack,dust;
    }
    private static async Task<List<StateSample>> Trace(string name,float duration)
    {
        var rows=new List<StateSample>();var done=new TaskCompletionSource<bool>();Player.StartCoroutine(TraceFrames(name,duration,rows,done));
        if(await Task.WhenAny(done.Task,Task.Delay(20000))!=done.Task)throw new Exception("Trace stalled "+name);
        await done.Task;File.WriteAllText(Evidence+name+".json",JsonConvert.SerializeObject(rows,Formatting.Indented));return rows;
    }
    private static System.Collections.IEnumerator TraceFrames(string name,float duration,List<StateSample> rows,TaskCompletionSource<bool> done)
    {
        double end=Time.timeAsDouble+duration,lastCapture=-1;string previous="";int n=0;
        while(Time.timeAsDouble<end)
        {
            yield return new WaitForEndOfFrame();
            try {
                var screen=Camera.main.WorldToScreenPoint(Player.transform.position);var effects=UnityEngine.Object.FindAnyObjectByType<SwordPresentationEffects>();var dust=(SpriteRenderer)Read(effects,"dust");
                var row=new StateSample{name=name,frame=Time.frameCount,time=Time.timeAsDouble,hp=Player.State.Health,reactions=States?.ConfirmedReactions??0,direction=Animator.DirectionIndex,state=Animator.State,sprite=Animator.Body.sprite.name,source=Animator.CurrentFrame.source,dodging=Player.State.IsDodging(Time.timeAsDouble),dodgeUntil=Player.State.DodgeUntil,speed=Rb.linearVelocity.magnitude,alpha=Animator.Body.color.a,blade=Blade.enabled,deathComplete=States?.DeathComplete??false,simulated=Rb.simulated,attack=Sword.Busy,dust=dust.enabled,gripError=Vector3.Distance(Sword.GripWorld,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand)),screenX=screen.x,screenY=screen.y,x=Player.transform.position.x,y=Player.transform.position.y};rows.Add(row);
                if(row.sprite!=previous||Time.timeAsDouble-lastCapture>.1)
                {
                    string file=name+"-"+(n++).ToString("000");var texture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+file+".png",texture.EncodeToPNG());UnityEngine.Object.Destroy(texture);
                    File.AppendAllText(Evidence+"state-captures.jsonl",JsonConvert.SerializeObject(new{file,row})+"\n");previous=row.sprite;lastCapture=Time.timeAsDouble;
                }
            }catch(Exception e){done.SetException(e);yield break;}
        }
        done.SetResult(true);
    }
    public static async Task<string> DodgeStates(int group=0)
    {
        Time.timeScale=.3f;var results=new List<object>();
        Key[][] moves={new Key[0],new[]{UnityEngine.InputSystem.Key.A},new[]{UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.D},new[]{UnityEngine.InputSystem.Key.S},new[]{UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.W},new[]{UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.S}};
        Vector2[] dirs={Vector2.down,Vector2.left,Vector2.up,Vector2.right,Vector2.down,new Vector2(-1,1).normalized,new Vector2(1,-1).normalized};
        try {
            for(int d=group==0?0:4;d<(group==0?4:7);d++)
            {
                ResetActor();await Wait(.1f);Aim(d==0?dirs[d]:-dirs[d]);Key(moves[d]);await Wait(.25f);Key(moves[d].Concat(new[]{UnityEngine.InputSystem.Key.Space}).ToArray());
                var rows=await Trace("dodge-"+d,.38f);Key();Check(rows.Any(r=>r.dodging&&r.state=="dodge"),"Dodge not accepted");
                var active=rows.Where(r=>r.dodging).ToArray();int direction=active[0].direction;
                Check(active.All(r=>r.state=="dodge"&&r.direction==direction),"Dodge clip/direction drift");Check(active[0].source.EndsWith("frame0"),"Dodge skipped first cel");
                Check(active.Max(r=>r.speed)>8.9f&&active.Max(r=>r.speed)<9.01f,"Dodge speed changed");
                Check(Math.Abs(active[0].dodgeUntil-Mmorpg.Domain.CombatRules.DodgeDuration-(active[0].time))<.035,"Dodge start clock");
                Check(active.Any(r=>r.dust),"Accepted dodge dust missing");
                Check(active.Select(r=>r.source).Distinct().Count()>=8,"Dodge lost source cels");
                double until=Player.State.DodgeUntil;Key(UnityEngine.InputSystem.Key.Space);var rejected=await Trace("cooldown-"+d,.08f);Key();
                Check(Player.State.DodgeUntil==until&&rejected.All(r=>r.state!="dodge"&&!r.dust),"Rejected dodge reacted");
                results.Add(new{d,direction,frames=active.Select(r=>r.source).Distinct().Count(),first=active[0].source,last=active.Last().source,speed=active.Max(r=>r.speed),duration=Mmorpg.Domain.CombatRules.DodgeDuration,cooldownRejected=true});
            }
            // A second accepted action on the same state must restart, with real cooldown elapsed.
            await Wait(2);Aim(Vector2.down);Key(UnityEngine.InputSystem.Key.Space);var restart=await Trace("dodge-restart-"+group,.32f);Key();Check(restart.First(r=>r.dodging).source.EndsWith("frame0"),"Dodge clock reused");
            await Wait(.5f);Aim(Vector2.down,1);await Wait(.08f);Aim(Vector2.down);var post=await Trace("dodge-to-attack-"+group,.5f);Check(post.Any(r=>r.state.StartsWith("attack")),"Post-dodge attack failed");
            var json=JsonConvert.SerializeObject(results,Formatting.Indented);File.WriteAllText(Evidence+"dodge-results-"+group+".json",json);return json;
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;}
    }
    public static async Task<string> HurtStates()
    {
        var report=new List<object>();Time.timeScale=.5f;
        try{
            for(int d=0;d<4;d++)
            {
                ResetActor();Key(new[]{UnityEngine.InputSystem.Key.S,UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.D}[d]);await Wait(.3f);
                int reactions=States.ConfirmedReactions,hp=Player.State.Health;Check(Hit(),"Confirmed damage refused");Check(!Hit(),"Immunity allowed second hit");Check(!Hit(friendly:true),"Friendly damage allowed");
                var rows=await Trace("hurt-"+d,.65f);Key();Check(States.ConfirmedReactions==reactions+1,"Duplicate or absent Hurt notification");Check(Player.State.Health<hp,"Damage not applied");Check(rows.Any(r=>r.state=="hurt")&&(rows.Last().state=="walk"||(rows.Last().state=="idle"&&rows.Last().speed<.1f)),"Hurt/walk transition");Check(rows.Where(r=>r.state=="hurt").Select(r=>r.source).Distinct().Count()==7,"Incomplete Hurt");
                await Trace("hurt-to-idle-"+d,.24f);Check(Animator.State=="idle","Hurt did not settle");report.Add(new{d,acceptedDamage=hp-Player.State.Health,reactions=1,immunityRejected=true,friendlyRejected=true});
            }
            ResetActor();await Wait(.2f);Aim(Vector2.down,1);await Wait(.05f);Aim(Vector2.down);Check(Sword.Busy,"Attack not accepted");Check(Hit(),"Attack damage fixture refused");
            var attack=await Trace("attack-hurt",1);Check(attack.Any(r=>r.state.StartsWith("attack"))&&attack.Any(r=>r.state=="hurt"),"Deferred Hurt absent");Check(attack.Where(r=>r.attack).All(r=>r.state.StartsWith("attack")),"Hurt interrupted approved Slash");
            ResetActor();await Wait(.1f);Key(UnityEngine.InputSystem.Key.Space);await Wait(.05f);int before=States.ConfirmedReactions;Check(Player.State.IsDodging(Time.timeAsDouble)&&!Hit(),"Dodge accepted damage");await Trace("dodge-refuses-hurt",.4f);Check(States.ConfirmedReactions==before,"Refused damage reacted");
            var json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"hurt-results.json",json);return json;
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;}
    }
    public static async Task<string> DeathStates(int direction=0)
    {
        Time.timeScale=.7f;
        try {
            ResetActor();Key(new[]{UnityEngine.InputSystem.Key.S,UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.D}[direction]);await Wait(.22f);Key();await Wait(.3f);
            while(Player.State.Health>28){Check(Hit(Mmorpg.Domain.ActionStrike.Golem),"Prelethal damage failed");if(Player.State.Health<=28)await Trace("hurt-before-death-"+direction,.36f);else await Wait(.53f);}
            if(direction==1)await Trace("idle-before-death",.3f);
            if(direction==2){await Wait(.3f);Key(UnityEngine.InputSystem.Key.W);await Trace("walk-before-death",.09f);Key();}
            // Last nonlethal Hurt is still valid when final damage immunity expires.
            Check(Hit(Mmorpg.Domain.ActionStrike.Golem),"Lethal damage refused");Check(!Player.State.IsAlive,"Lethal fixture failed");
            Key(UnityEngine.InputSystem.Key.D);Aim(Vector2.right,1);var rows=await Trace("death-"+direction,1.85f);Key();Aim(Vector2.down);
            Check(rows.Skip(1).All(r=>r.state=="death")&&rows.All(r=>!r.blade&&!r.simulated&&!r.attack&&r.alpha>.99f),"Death presentation/authority mismatch");
            Check(rows.Where(r=>r.state=="death").Select(r=>r.source).Distinct().Count()==23,"Death missed cels");Check(rows.Last().deathComplete,"Death incomplete");Check(rows.All(r=>Math.Abs(r.x-rows[0].x)<.0001&&Math.Abs(r.y-rows[0].y)<.0001),"Dead actor moved");
            string terminal=rows.Last().source;var held=await Trace("death-held-"+direction,.35f);Check(held.All(r=>r.source==terminal),"Death restarted");Check(!Authority.RequestAttack(Player,Vector2.right)&&!Authority.RequestDodge(Player)&&!Hit(),"Dead action accepted");
            ResetActor();await Trace("restored-"+direction,.25f);Check(Animator.State=="idle"&&Blade.enabled&&!States.DeathComplete,"Restored state stuck");
            string json=JsonConvert.SerializeObject(new{direction,frames=23,duration=23f/15,terminal,complete=true,held=true,noDeadActions=true,restored=true});File.WriteAllText(Evidence+"death-results-"+direction+".json",json);return json;
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;}
    }
    public static async Task<string> RestartSession()
    {
        var old=Player.GetEntityId();UnityEngine.Object.FindAnyObjectByType<LocalSessionCommands>().Restart();await Wait(1);
        Check(Player.GetEntityId()!=old&&Player.State.IsAlive&&Animator.State=="idle"&&Blade.enabled,"Session reload stuck");
        await Trace("session-restarted",.2f);return "Existing Restart saved and reloaded isolated profile; fresh alive player, idle body and visible sword.";
    }
    public static async Task<string> Regression()
    {
        Time.timeScale=.5f;var report=new List<object>();
        try {
            Key[] moves={UnityEngine.InputSystem.Key.S,UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.D};
            Vector2[] dirs={Vector2.down,Vector2.left,Vector2.up,Vector2.right};
            for(int d=0;d<4;d++)
            {
                ResetActor();await Wait(.12f);Aim(-dirs[d]);Key(moves[d]);var rows=await Trace("regression-walk-"+d,.68f);Key();await Wait(.45f);
                Check(rows.Any(r=>r.state=="walk"&&r.direction==d)&&rows.Max(r=>r.speed)>3.49f&&rows.Max(r=>r.speed)<3.51f,"Walk regression");
                Check(Vector2.Dot(Sword.AimDirection,-dirs[d])>.9f,"Independent aim regression");Check(rows.All(r=>r.gripError<.0001f),"Hand anchor regression");
                report.Add(new{direction=d,walkSpeed=rows.Max(r=>r.speed),maxGripError=rows.Max(r=>r.gripError)});
                ResetActor();await Wait(.15f);Aim(dirs[d],1);await Wait(.025f);Aim(dirs[d]);var attack=await Trace("regression-basic-"+d,.55f);Check(attack.Any(r=>r.state.StartsWith("attack")),"Basic missing");Check(attack.All(r=>r.gripError<.0001f),"Basic hand regression");
            }
            ResetActor();await Wait(.1f);Aim(Vector2.down,2);await Wait(.025f);Aim(Vector2.down);var heavy=await Trace("regression-heavy",1);Check(heavy.Any(r=>r.state=="attack-preparation")&&heavy.Any(r=>r.state=="attack-cut")&&heavy.Any(r=>r.state=="attack-recovery"),"Heavy phases missing");Check(heavy.All(r=>r.gripError<.0001f),"Heavy hand regression");
            var json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"regression.json",json);return json;
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;}
    }
    public static async Task<string> LegacyFade()
    {
        Check(States==null,"B10 observer must be absent");ResetActor();await Wait(.1f);
        while(Player.State.IsAlive){Check(Hit(Mmorpg.Domain.ActionStrike.Golem),"Legacy lethal fixture");if(Player.State.IsAlive)await Wait(.36f);}
        var rows=await Trace("legacy-death-fade",.7f);Check(rows.Last().alpha<.01f&&!Blade.enabled,"B10 fade changed");
        string json=JsonConvert.SerializeObject(new{legacyFadePreserved=true,alpha=rows.Last().alpha,observerAbsent=true});File.WriteAllText(Evidence+"legacy-fade.json",json);ResetActor();return json;
    }
    public static async Task<string> TransitionDodge()
    {
        try {
            ResetActor();Time.timeScale=.3f;await Wait(.15f);Aim(Vector2.left);Key(UnityEngine.InputSystem.Key.D);
            var recording=Trace("walk-dodge-walk",.95f);await Wait(.84f);Key(UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.Space);await Wait(.1f);Key(UnityEngine.InputSystem.Key.D);var rows=await recording;
            Check(rows.TakeWhile(r=>r.state!="dodge").Any(r=>r.state=="walk")&&rows.Any(r=>r.state=="dodge")&&rows.Last().state=="walk","Continuous transition missing");return "Continuous Walk -> accepted Dodge -> Walk captured";
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;}
    }
    public static async Task<string> IncomingAndReload()
    {
        ResetActor();await Wait(.15f);var attacker=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;var original=attacker.transform.position;GameObject wall=null;
        try {
            attacker.transform.position=Player.transform.position+Vector3.right*.75f;wall=new GameObject("B11 temporary incoming LOS fixture");wall.layer=8;wall.transform.position=Player.transform.position+Vector3.right*.38f;wall.AddComponent<BoxCollider2D>().size=new Vector2(.08f,2);Physics2D.SyncTransforms();
            int hp=Player.State.Health,count=States.ConfirmedReactions;Check(Authority.RequestAttack(attacker,Vector2.left),"Blocked strike intention refused");await Trace("blocked-incoming",.2f);Check(Player.State.Health==hp&&States.ConfirmedReactions==count,"Wall triggered damage/Hurt");
            UnityEngine.Object.Destroy(wall);wall=null;await Wait(1.1f);Physics2D.SyncTransforms();Check(Authority.RequestAttack(attacker,Vector2.left),"Clear incoming intent refused");await Trace("confirmed-incoming",.7f);Check(Player.State.Health<hp&&States.ConfirmedReactions==count+1,"Authority spatial hit did not react");
            // Repeated enable cycles must keep exactly one health subscription.
            States.enabled=false;States.enabled=true;States.enabled=false;States.enabled=true;Check(Hit(),"Subscription fixture damage refused");await Trace("subscription-once",.55f);Check(States.ConfirmedReactions==count+2,"Duplicate health callbacks");
            while(Player.State.IsAlive){await Wait(.36f);Check(Hit(Mmorpg.Domain.ActionStrike.Golem),"Reload lethal fixture refused");}
            await Trace("dead-before-restart",.25f);string restart=await RestartSession();
            string json=JsonConvert.SerializeObject(new{wallBlockedHurt=true,realSpatialIncomingHit=true,singleSubscription=true,restartFromDeath=restart,profile=LocalJourneyProfile.Root});File.WriteAllText(Evidence+"lifecycle.json",json);return json;
        }finally{Key();Aim(Vector2.down);Time.timeScale=1;if(wall!=null)UnityEngine.Object.Destroy(wall);if(attacker!=null)attacker.transform.position=original;}
    }
    public static string Cleanup()
    {
        if(EditorApplication.isPlaying)throw new Exception("Stop Play first");
        foreach(var d in InputSystem.devices.Where(d=>d.name=="AnimationKeyboard"||d.name=="AnimationMouse").ToArray())InputSystem.RemoveDevice(d);
        foreach(string id in SessionState.GetString("b11-devices","").Split(','))if(int.TryParse(id,out int device)){var d=InputSystem.GetDeviceById(device);if(d!=null)InputSystem.EnableDevice(d);}
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b11-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b11-options",0);
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("b11-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("b11-editor-input",0);
        Time.timeScale=1;LocalJourneyProfile.ValidationRootOverride=null;return "Input/Editor restored, personal saves preserved.";
    }
}
