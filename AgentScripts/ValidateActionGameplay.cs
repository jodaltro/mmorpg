using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

// Real scene walkthrough. Position is observed, never assigned; all gameplay uses input devices.
public static class ValidateActionGameplay
{
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static Keyboard Keyboard=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="ActionGameplayKeyboard");
    private static Mouse Mouse=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="ActionGameplayMouse");
    public static string Prepare()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Outside Play required");
        SessionState.SetBool("m06-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("m06-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetBool("m06-background",Application.runInBackground);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;Application.runInBackground=true;
        string path=System.IO.Path.GetFullPath("Temp/Marco06A/gameplay-"+Guid.NewGuid().ToString("N")+".json");SessionState.SetString("m06-save",path);
        var persistence=new JsonJourneyPersistence(path);JourneySession.PersistenceFactory=()=>persistence;
        EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");return "Prepared isolated JSON and existing action scene; no original save access";
    }
    public static string InputSetup()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();
        SessionState.SetString("m06-devices",string.Join(",",native.Select(d=>d.deviceId)));
        foreach(var d in native)InputSystem.DisableDevice(d);
        InputSystem.AddDevice<Keyboard>("ActionGameplayKeyboard");InputSystem.AddDevice<Mouse>("ActionGameplayMouse");
        return Inspect();
    }
    public static string ResumeSavedPlay()
    {
        string path=SessionState.GetString("m06-save","");if(!File.Exists(path))throw new InvalidOperationException("Completed isolated save required");
        Prepare();SessionState.SetString("m06-save",path);var store=new JsonJourneyPersistence(path);JourneySession.PersistenceFactory=()=>store;return "Resume completed isolated investigation at safe village spawn";
    }
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keyboard,new KeyboardState(keys));
    private static void Aim(Vector2 point,int button=0)=>InputSystem.QueueStateEvent(Mouse,new MouseState{position=Camera.main.WorldToScreenPoint(point),buttons=(ushort)button});
    private static async Task Wait(float seconds)
    {
        double end=Time.timeAsDouble+seconds,deadline=Time.realtimeSinceStartupAsDouble+seconds+10;
        while(Time.timeAsDouble<end) {if(Time.realtimeSinceStartupAsDouble>deadline)throw new TimeoutException("Frames stalled");await Task.Delay(10);}
    }
    private static async Task Walk(Vector2 goal,float timeout=8)
    {
        double deadline=Time.timeAsDouble+timeout;
        while(Vector2.Distance(Journey.Player.GetComponent<Rigidbody2D>().position,goal)>.18f)
        {
            if(!Journey.Player.State.IsAlive || Time.timeAsDouble>deadline) {Key();throw new InvalidOperationException("Walk failed toward "+goal+"; "+Inspect());}
            Vector2 delta=goal-Journey.Player.GetComponent<Rigidbody2D>().position;
            var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.1)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.1)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Task.Delay(20);
        }
        Key();await Wait(.08f);
    }
    private static async Task Tap(Key key) {Key(key);await Wait(.05f);Key();await Wait(.05f);}
    public static async Task<string> Village()
    {
        await Walk(new Vector2(-8,.1f));await Tap(UnityEngine.InputSystem.Key.E);
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-2.5f,0));await Walk(new Vector2(-2.5f,2));await Tap(UnityEngine.InputSystem.Key.E);
        await Walk(new Vector2(-2.5f,0));return Inspect();
    }
    public static async Task<string> WolfFight()
    {
        await Walk(new Vector2(1,0));
        // Intentional miss toward the village, followed by physical pursuit/telegraphed combat.
        Aim(new Vector2(-8,0),1);await Wait(.05f);Aim(new Vector2(-8,0));await Wait(.45f);
        double deadline=Time.timeAsDouble+18;int attacks=0;
        while(Journey.Wolf.State.IsAlive && Journey.Player.State.IsAlive && Time.timeAsDouble<deadline)
        {
            Vector2 delta=Journey.Wolf.transform.position-Journey.Player.transform.position;
            if(delta.magnitude>1.1f) {Key(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);await Wait(.12f);Key();}
            var brain=Journey.Wolf.GetComponent<WolfBrain>();
            if(brain.Mode==WolfMode.Windup) {await Wait(.25f);Key(UnityEngine.InputSystem.Key.Space);await Wait(.05f);Key();await Wait(.23f);}
            Aim(Journey.Wolf.transform.position,attacks++%3==2?2:1);await Wait(.06f);Aim(Journey.Wolf.transform.position);await Wait(.5f);
        }
        Key();if(Journey.Wolf.State.IsAlive || !Journey.Player.State.IsAlive)throw new InvalidOperationException("Combat walkthrough failed; "+Inspect());
        return Inspect();
    }
    public static async Task<string> CollectAndReturn()
    {
        var sample=Journey.Interactions.Single(i=>i.Kind==InteractionKind.Sample);await Walk(sample.transform.position);await Tap(UnityEngine.InputSystem.Key.E);
        if(!Journey.Engine.HasSample)throw new InvalidOperationException("Physical collection not confirmed");
        await Walk(new Vector2(1,0));await Walk(new Vector2(-7,0));await Walk(new Vector2(-8,.1f));await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);
        await Wait(.3f);Journey.Save();if(Journey.Engine.HasSample || !Journey.Engine.HasAbility(ForestContent.Technique))throw new InvalidOperationException("Investigation not confirmed");
        return Inspect();
    }
    public static async Task<string> Reload()
    {
        Journey.Save();int before=Journey.Engine.Snapshot().facts.Count;UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");await Wait(.2f);
        if(Journey.Engine.Snapshot().facts.Count!=before || !Journey.Engine.HasAbility(ForestContent.Technique))throw new InvalidOperationException("Save/reload changed investigation");return Inspect();
    }
    public static async Task<string> WeaknessPractice()
    {
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-4,-1));await Tap(UnityEngine.InputSystem.Key.Q);
        var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();Aim(dummy.transform.position,1);await Wait(.05f);Aim(dummy.transform.position);await Wait(.1f);
        if(dummy.Health.State.Health!=70)throw new InvalidOperationException("Learned Q did not add verified bonus");
        await Walk(new Vector2(-4,0));return "Learned Q + basic hit on physical training dummy: HP=70; "+Inspect();
    }
    public static async Task<string> SpiderFight()
    {
        await Walk(new Vector2(-2,0));await Walk(new Vector2(3,0));await Walk(new Vector2(3,-3));await Walk(new Vector2(5,-3));
        var spider=UnityEngine.Object.FindObjectsByType<SpatialCreatureBrain>().Single(b=>b.Kind==CreatureKind.Spider).GetComponent<ActorHealth>();
        // Isolated test toggle does not alter the journey's saved unlocks.
        await Tap(UnityEngine.InputSystem.Key.F9);await Tap(UnityEngine.InputSystem.Key.C);await Tap(UnityEngine.InputSystem.Key.Q);
        double deadline=Time.timeAsDouble+16;int attacks=0;
        while(spider.State.IsAlive&&Journey.Player.State.IsAlive&&Time.timeAsDouble<deadline)
        {
            Vector2 delta=spider.transform.position-Journey.Player.transform.position;Aim(spider.transform.position);
            if(delta.magnitude>1.1f){var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.2f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.2f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);if(attacks%3==0)keys.Add(UnityEngine.InputSystem.Key.Space);Key(keys.ToArray());await Wait(.12f);Key();}
            Aim(spider.transform.position,1);await Wait(.06f);Aim(spider.transform.position);await Wait(.42f);attacks++;
        }
        Key();if(spider.State.IsAlive||!Journey.Player.State.IsAlive)throw new InvalidOperationException("Spider fight failed; "+Inspect());
        await Walk(new Vector2(5,-1));return "Spider physically defeated using C/Q in isolated test mode; "+Inspect();
    }
    public static async Task<string> GolemFight()
    {
        if(!Journey.Player.GetComponent<ActionCombat>().TestMode)await Tap(UnityEngine.InputSystem.Key.F9);
        await Walk(new Vector2(5,0));await Walk(new Vector2(7,2));
        var brain=UnityEngine.Object.FindObjectsByType<SpatialCreatureBrain>().Single(b=>b.Kind==CreatureKind.Golem);var golem=brain.GetComponent<ActorHealth>();
        double deadline=Time.timeAsDouble+8;
        while(brain.Mode!=CreatureMode.Windup&&Time.timeAsDouble<deadline)await Wait(.02f);
        if(brain.Mode!=CreatureMode.Windup)throw new InvalidOperationException("No spatial golem windup");
        double release=(double)typeof(SpatialCreatureBrain).GetField("until",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(brain);
        int hp=Journey.Player.State.Health;await Wait((float)Math.Max(0,release-Time.timeAsDouble-.14));Aim(golem.transform.position);await Tap(UnityEngine.InputSystem.Key.Space);await Wait(.16f);await Tap(UnityEngine.InputSystem.Key.F);
        bool counterHit=golem.State.Health<60;
        if(!counterHit)throw new InvalidOperationException("No counter hit after real evasion; "+Inspect());
        await Tap(UnityEngine.InputSystem.Key.C);await Tap(UnityEngine.InputSystem.Key.Q);
        Aim(golem.transform.position,2);await Wait(.06f);Aim(golem.transform.position);await Wait(.6f);
        if(golem.State.IsAlive){Aim(golem.transform.position,1);await Wait(.06f);Aim(golem.transform.position);await Wait(.6f);}
        if(golem.State.IsAlive)throw new InvalidOperationException("Golem not defeated");
        Key();return "Real golem impact evaded; counter damaged target; golem defeated; playerHPBefore="+hp+"; "+Inspect();
    }
    public static async Task<string> FreshGolemWalk()
    {
        await Walk(new Vector2(-8,0));await Walk(new Vector2(-7,0));await Walk(new Vector2(3,0));await Walk(new Vector2(5,-1));return await GolemFight();
    }
    public static async Task<string> JournalAndNotice()
    {
        await Walk(new Vector2(5,0));await Walk(new Vector2(-7,0));await Walk(new Vector2(-7,2.5f));await Walk(new Vector2(-6,2.5f));await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.Tab);
        return "notice="+Journey.WorldEvents.World.NoticePublished+"; journal="+UnityEngine.Object.FindAnyObjectByType<JourneyHud>().JournalOpen+"; "+Inspect();
    }
    public static async Task<string> OpenJournalOnly() {await Tap(UnityEngine.InputSystem.Key.Tab);return Inspect();}
    public static string Inspect()=>"position="+Journey.Player.GetComponent<Rigidbody2D>().position+"; hp="+Journey.Player.State.Health+"; wolf="+Journey.Wolf.State.Health+"; sample="+Journey.Engine.HasSample+"; facts="+Journey.Engine.Snapshot().facts.Count+"; ability="+Journey.Engine.HasAbility(ForestContent.Technique)+"; "+UnityEngine.Object.FindAnyObjectByType<ActionMetrics>().Report();
    public static string Cleanup()
    {
        foreach(var d in InputSystem.devices.Where(d=>d.name=="ActionGameplayKeyboard"||d.name=="ActionGameplayMouse").ToArray())InputSystem.RemoveDevice(d);
        var ids=SessionState.GetString("m06-devices","").Split(',');foreach(var d in InputSystem.devices.Where(d=>ids.Contains(d.deviceId.ToString())))InputSystem.EnableDevice(d);
        JourneySession.PersistenceFactory=null;EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("m06-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("m06-options",0);Application.runInBackground=SessionState.GetBool("m06-background",false);return "Inputs and Editor settings restored";
    }
}
