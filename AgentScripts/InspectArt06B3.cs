using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

// A short visual walkthrough, not the suspended test suites. Uses isolated saves.
public static class InspectArt06B3
{
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="ArtInspectionKeyboard");
    private static Mouse Mouse=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="ArtInspectionMouse");
    public static string Prepare()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/Marco06B3Art.unity")throw new InvalidOperationException("Open B3 art scene");
        SessionState.SetBool("art-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("art-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("art-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("art-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B3/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);SessionState.SetString("art-save",dir);
        ExplorationWorld.ValidationDirectory=dir;JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(dir,"journey.json"));
        return "Isolated saves: "+dir;
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("art-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var d in native)InputSystem.DisableDevice(d);
        InputSystem.AddDevice<Keyboard>("ArtInspectionKeyboard");InputSystem.AddDevice<Mouse>("ArtInspectionMouse");Aim((Vector2)Journey.Player.transform.position+Vector2.down*3);return Inspect();
    }
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    private static void Aim(Vector2 point,int button=0)=>InputSystem.QueueStateEvent(Mouse,new MouseState{position=Camera.main.WorldToScreenPoint(point),buttons=(ushort)button});
    private static async Task Wait(float seconds)
    {double end=Time.timeAsDouble+seconds,deadline=Time.realtimeSinceStartupAsDouble+seconds+10;while(Time.timeAsDouble<end){if(Time.realtimeSinceStartupAsDouble>deadline)throw new TimeoutException("Frozen frames");await Task.Delay(10);}}
    private static async Task Capture(string name)
    {Directory.CreateDirectory("Docs/Validation/Marco06B3");ScreenCapture.CaptureScreenshot("Docs/Validation/Marco06B3/"+name+".png");await Wait(.04f);}
    public static string Inspect()
    {var p=Journey.Player;var a=p.GetComponent<GameplaySpriteAnimator>();return "frame="+Time.frameCount+" position="+p.transform.position+" health="+p.State.Health+" sprite="+p.GetComponent<SpriteRenderer>().sprite.name+" state="+a.PresentationState+" facing="+a.DirectionIndex+" wolfHP="+Journey.Wolf.State.Health;}
    public static async Task<string> Player()
    {
        int first=Time.frameCount;await Wait(.2f);await Capture("player-idle");
        // Two complete native two-pose cycles in each direction, via real input.
        var directions=new[]{UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.S};
        var vectors=new[]{Vector2.right,Vector2.up,Vector2.left,Vector2.down};
        var report=new System.Text.StringBuilder();
        for(int d=0;d<4;d++)
        {
            await Walk(new Vector2(-7,0));
            Aim((Vector2)Journey.Player.transform.position+vectors[d]*3);Key(directions[d]);
            for(int i=0;i<5;i++){await Wait(.13f);await Capture("walk-"+d+"-"+i);}
            report.AppendLine(Inspect());Key();await Wait(.1f);
        }
        for(int d=0;d<4;d++)
        {
            Aim((Vector2)Journey.Player.transform.position+vectors[d]*3,1);await Wait(.05f);Aim((Vector2)Journey.Player.transform.position+vectors[d]*3);
            await Capture("attack-"+d+"-preparation");await Wait(.05f);await Capture("attack-"+d+"-active");await Wait(.25f);
            report.AppendLine(Inspect());
        }
        Key(UnityEngine.InputSystem.Key.Space);await Wait(.06f);Key();await Capture("dodge");await Wait(.35f);
        if(Time.frameCount<=first)throw new Exception("No advancing frames");return report+Inspect();
    }
    private static async Task Tap(Key key){Key(key);await Wait(.05f);Key();await Wait(.08f);}
    public static async Task<string> Village()
    {
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-8,.1f));await Tap(UnityEngine.InputSystem.Key.E);await Capture("mira-dialogue");await Tap(UnityEngine.InputSystem.Key.E);
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-2,.3f));await Walk(new Vector2(-2,2.3f));await Tap(UnityEngine.InputSystem.Key.E);await Capture("orin-dialogue");await Tap(UnityEngine.InputSystem.Key.E);
        await Walk(new Vector2(-2,.3f));await Walk(new Vector2(-7,0));await Walk(new Vector2(-6,0));await Walk(new Vector2(-6,4));await Capture("houses-scale");
        await Walk(new Vector2(-6,0));await Walk(new Vector2(-7,-4.2f));await Walk(new Vector2(-6,-4.2f));await Capture("tree-behind");
        var tree=GameObject.Find("TreeWest").transform.Find("ProvidedTree").GetComponent<SpriteRenderer>();var body=Journey.Player.GetComponent<SpriteRenderer>();
        int behind=body.sortingOrder,obstacle=tree.sortingOrder;
        await Walk(new Vector2(-7,-4.2f));await Walk(new Vector2(-7,-5.6f));await Walk(new Vector2(-6,-5.6f));await Capture("tree-front");int front=body.sortingOrder;
        if(!(behind<obstacle&&front>obstacle))throw new Exception("Foot sorting mismatch "+behind+" "+obstacle+" "+front);
        await Walk(new Vector2(-7,-5.6f));await Walk(new Vector2(-7,0));
        return "Mira/Orin real interaction; houses inspected; tree rear order="+behind+", tree="+obstacle+", front="+front+"; "+Inspect();
    }
    public static async Task<string> AbilityVisuals()
    {
        // Use the project's existing isolated ability inspection mode only in Play.
        // No ability/progression is persisted, and all requests still go through authority.
        var combat=Journey.Player.GetComponent<ActionCombat>();combat.ConfigureIsolatedAbilityTest(true);
        try
        {
            await Walk(new Vector2(-7,0));await Walk(new Vector2(-5.2f,-1));await Tap(UnityEngine.InputSystem.Key.Q);await Wait(.1f);await Capture("weakness-confirmed");
            bool marked=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>()!=null&&Journey.IsWeaknessMarked(UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health);
            await Walk(new Vector2(-7,0));await Walk(new Vector2(.5f,0));await Tap(UnityEngine.InputSystem.Key.C);await Wait(.1f);await Capture("hunter-mark-confirmed");
            return "Weakness on dummy="+marked+"; hunter mark="+(combat.MarkedTarget!=null)+"; "+Inspect();
        }
        finally {combat.ConfigureIsolatedAbilityTest(false);}
    }
    public static async Task<string> HunterOnDummy()
    {
        var combat=Journey.Player.GetComponent<ActionCombat>();combat.ConfigureIsolatedAbilityTest(true);
        try {await Walk(new Vector2(-7,0));await Walk(new Vector2(-5.2f,-1));await Tap(UnityEngine.InputSystem.Key.C);await Wait(.1f);await Capture("hunter-mark-confirmed");return "Confirmed hunter target="+(combat.MarkedTarget!=null?combat.MarkedTarget.name:"none")+"; "+Inspect();}
        finally {combat.ConfigureIsolatedAbilityTest(false);}
    }
    public static async Task<string> DeliveryView()
    {
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-6,0));await Walk(new Vector2(-6,4));Aim((Vector2)Journey.Player.transform.position+Vector2.down*3);await Wait(.12f);await Capture("delivery-village");
        Aim((Vector2)Journey.Player.transform.position+Vector2.right*3,1);await Wait(.05f);Aim((Vector2)Journey.Player.transform.position+Vector2.right*3);await Wait(.05f);await Capture("delivery-slash");await Wait(.3f);
        return Inspect();
    }
    private static async Task Walk(Vector2 goal)
    {
        double end=Time.timeAsDouble+12;
        while(Vector2.Distance(Journey.Player.GetComponent<Rigidbody2D>().position,goal)>.18f)
        {
            if(Time.timeAsDouble>end||!Journey.Player.State.IsAlive){Key();throw new Exception("Walk blocked: "+Inspect());}
            Vector2 delta=goal-Journey.Player.GetComponent<Rigidbody2D>().position;
            var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.1f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.1f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Wait(.04f);
        }
        Key();await Wait(.1f);
    }
    public static async Task<string> Fight()
    {
        await Walk(new Vector2(-7,0));await Walk(new Vector2(1,0));
        var report=new System.Text.StringBuilder();int playerHp=Journey.Player.State.Health,wolfHp=Journey.Wolf.State.Health,number=0;
        bool received=false;double end=Time.timeAsDouble+20;
        while(Journey.Wolf.State.IsAlive&&Journey.Player.State.IsAlive&&Time.timeAsDouble<end)
        {
            var delta=Journey.Wolf.transform.position-Journey.Player.transform.position;
            if(delta.magnitude>1.1f){Key(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);await Wait(.08f);Key();}
            // Let the first real attack connect to inspect received-damage feedback.
            if(received&&Journey.Wolf.GetComponent<WolfBrain>().Mode==WolfMode.Windup)
            {await Wait(.25f);Key(UnityEngine.InputSystem.Key.Space);await Wait(.05f);Key();await Capture("fight-dodge");await Wait(.22f);}
            Aim(Journey.Wolf.transform.position,number%3==2?2:1);await Wait(.05f);Aim(Journey.Wolf.transform.position);
            await Capture("fight-"+number.ToString("D2"));await Wait(.2f);
            if(Journey.Player.State.Health<playerHp){received=true;report.AppendLine("Received confirmed damage "+playerHp+" -> "+Journey.Player.State.Health);playerHp=Journey.Player.State.Health;await Capture("received-damage");}
            if(Journey.Wolf.State.Health<wolfHp){report.AppendLine("Wolf confirmed hit "+wolfHp+" -> "+Journey.Wolf.State.Health);wolfHp=Journey.Wolf.State.Health;}
            await Wait(.15f);number++;
        }
        Key();await Wait(.1f);await Capture("wolf-defeat");await Wait(.5f);await Capture("wolf-fade");
        report.AppendLine(Inspect());report.AppendLine("ReceivedDamage="+received+" wolfDefeated="+!Journey.Wolf.State.IsAlive);
        return report.ToString();
    }
    public static string Cleanup()
    {
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("art-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("art-editor-input",0);
        foreach(var d in InputSystem.devices.Where(d=>d.name.StartsWith("ArtInspection")).ToArray())InputSystem.RemoveDevice(d);
        foreach(string id in SessionState.GetString("art-devices","").Split(','))if(int.TryParse(id,out int value)){var d=InputSystem.GetDeviceById(value);if(d!=null)InputSystem.EnableDevice(d);}
        ExplorationWorld.ValidationDirectory=null;JourneySession.PersistenceFactory=null;EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("art-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("art-options",0);return "Input, Editor settings and persistence restored; user saves untouched.";
    }
}

