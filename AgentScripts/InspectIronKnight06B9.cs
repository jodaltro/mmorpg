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
public static class InspectIronKnight06B9
{
    private const string Evidence="Docs/Validation/Marco06B9/";
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
        if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/Marco06B9ProfessionalHero.unity")throw new Exception("Clean B9 outside Play required");
        Directory.CreateDirectory(Evidence);
        SessionState.SetBool("b9-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b9-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b9-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b9-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B9/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);LocalJourneyProfile.ValidationRootOverride=dir;
        File.WriteAllText(Evidence+"isolated-profile.txt",dir);return dir;
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b9-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var d in native)InputSystem.DisableDevice(d);
        InputSystem.AddDevice<Keyboard>("AnimationKeyboard");InputSystem.AddDevice<Mouse>("AnimationMouse");Aim(Vector2.down);return Inspect();
    }
    public static string Inspect()=>JsonConvert.SerializeObject(new {frame=Time.frameCount,position=Player.transform.position.ToString(),state=Animator.State,visual=Animator.VisualFacing.ToString(),aim=Sword.AimDirection.ToString(),sprite=Animator.Body.sprite.name,profile=LocalJourneyProfile.Root});
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
        File.AppendAllText(Evidence+"capture-metadata.jsonl",JsonConvert.SerializeObject(new{name,frame=Time.frameCount,time=Time.timeAsDouble,realTime=Time.realtimeSinceStartupAsDouble,timeScale=Time.timeScale,screenWidth=Screen.width,screenHeight=Screen.height,playerScreen=new[]{point.x,point.y},source=Animator.CurrentFrame.source,phase=Sword.VisualPhase,state=Animator.State,visual=Animator.VisualFacing.ToString(),aim=Sword.AimDirection.ToString(),attack=Sword.AttackDirection.ToString(),gripError=Vector3.Distance(pivot.position,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand)),scale=pivot.localScale.ToString(),bladeLength=Sword.BladeLength,sweepLength=Sword.SweepLength})+"\n");
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
        Time.timeScale=.35f;var report=new List<object>();Vector2[] dirs={Vector2.down,Vector2.left,Vector2.up,Vector2.right,new Vector2(1,1).normalized};
        await Tap(UnityEngine.InputSystem.Key.F7);
        for(int d=0;d<dirs.Length;d++)
        {
            Aim(dirs[d],d==4?2:1);await Wait(.025f);Aim(dirs[d]);
            var phases=new HashSet<string>();
            for(int i=0;i<(d==4?24:13);i++){phases.Add(Sword.VisualPhase);if(Sword.Busy&&Vector2.Dot(Sword.AttackDirection,dirs[d])<.99f)throw new Exception("Attack direction drift");await Capture("attack-"+d+"-"+i.ToString("00"));await Wait(.025f);}
            report.Add(new{direction=d,heavy=d==4,phases});await Wait(d==4?3.5f:1.2f);
        }
        Key(UnityEngine.InputSystem.Key.D);Aim(Vector2.left,1);await Wait(.025f);Aim(Vector2.right);if(!Sword.Busy||Vector2.Dot(Sword.AttackDirection,Vector2.left)<.99f)throw new Exception("Moving strike not confirmed/locked");for(int i=0;i<12;i++)await Capture("moving-attack-"+i.ToString("00"));Key();await Wait(.5f);
        await Tap(UnityEngine.InputSystem.Key.Space);await Wait(.8f);Aim(Vector2.down,1);await Wait(.025f);Aim(Vector2.down);if(!Sword.Busy)throw new Exception("Post-dodge strike not accepted");for(int i=0;i<12;i++)await Capture("after-dodge-"+i.ToString("00"));
        Time.timeScale=1;await Tap(UnityEngine.InputSystem.Key.F7);string json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"attacks.json",json);return json;
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
        foreach(string id in SessionState.GetString("b9-devices","").Split(','))if(int.TryParse(id,out int device)){var d=InputSystem.GetDeviceById(device);if(d!=null)InputSystem.EnableDevice(d);}
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b9-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b9-options",0);
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("b9-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("b9-editor-input",0);
        Time.timeScale=1;LocalJourneyProfile.ValidationRootOverride=null;return "Input/Editor restored, personal saves preserved.";
    }
}
