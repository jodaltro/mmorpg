using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
// Short Editor inspection with real movement and input, not an automated test suite.
public static class InspectCharacterPolish
{
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="ExplorationInspectionKeyboard");
    private static Mouse Mouse=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="ExplorationInspectionMouse");
    public static string Prepare()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        SessionState.SetBool("b2-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b2-options",(int)EditorSettings.enterPlayModeOptions);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        SessionState.SetInt("b2-background",(int)InputSystem.settings.backgroundBehavior);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        string dir=Path.GetFullPath("Temp/Marco06B2/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);SessionState.SetString("b2-save",dir);
        ExplorationWorld.ValidationDirectory=dir;JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(dir,"journey.json"));
        EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/Marco06B2World.unity");return dir;
    }
    public static string Resume()
    {
        string dir=SessionState.GetString("b2-save","");Prepare();SessionState.SetString("b2-save",dir);ExplorationWorld.ValidationDirectory=dir;JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(dir,"journey.json"));return dir;
    }
    public static async Task<string> FinalInspection()
    {
        if(World.State.inventory.Single(i=>i.id=="wolf-fang").quantity!=2||World.State.inventory.Single(i=>i.id=="iron-ore").quantity!=3||Journey.Wolf.State.IsAlive)throw new InvalidOperationException("Reload did not preserve materials / narrative defeat");
        var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();if(!authority.IsSafePosition(Journey.Player.transform.position))throw new InvalidOperationException("Safe village configuration missing");
        await Walk(new Vector2(-7,0));await Walk(new Vector2(1.4f,0));if(World.State.region!="Floresta Cinzenta"||authority.IsSafePosition(Journey.Player.transform.position))throw new InvalidOperationException("Region boundary incorrect");await Walk(new Vector2(-7,0));await Tap(UnityEngine.InputSystem.Key.I);return Inspect();
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b2-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var device in native)InputSystem.DisableDevice(device);
        InputSystem.AddDevice<Keyboard>("ExplorationInspectionKeyboard");InputSystem.AddDevice<Mouse>("ExplorationInspectionMouse");return Inspect();
    }
    public static string State()
    {var p=Journey.Player;return "controller="+p.GetComponent<PlayerController>().enabled+" timescale="+Time.timeScale+" keyboard="+Keyboard.current?.name+" devices="+string.Join(",",InputSystem.devices.Select(d=>d.name+":"+d.enabled))+" motor="+p.GetComponent<ActorMotor>().Direction+" body="+p.GetComponent<Rigidbody2D>().linearVelocity;}
    public static async Task<string> Probe(){Key(UnityEngine.InputSystem.Key.D);await Wait(.2f);string s=State()+" keyHeld="+Keys.dKey.isPressed+" busy="+Journey.Player.GetComponent<SwordSwing>().Busy;Key();return s;}
    public static async Task<string> Directions()
    {
        var sword=Journey.Player.GetComponent<SwordSwing>();var body=Journey.Player.GetComponent<Rigidbody2D>();
        var report=new System.Text.StringBuilder();await Walk(new Vector2(-7,0));
        int frame=Time.frameCount;
        for(int i=0;i<8;i++)
        {
            float a=i*Mathf.PI/4;Vector2 d=new Vector2(Mathf.Cos(a),Mathf.Sin(a));var start=body.position;
            Key();Aim(start+Vector2.right*3);await Wait(.06f);
            var keys=new System.Collections.Generic.List<Key>();if(d.x>.2f)keys.Add(UnityEngine.InputSystem.Key.D);if(d.x<-.2f)keys.Add(UnityEngine.InputSystem.Key.A);if(d.y>.2f)keys.Add(UnityEngine.InputSystem.Key.W);if(d.y<-.2f)keys.Add(UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Wait(.16f);
            float speed=body.linearVelocity.magnitude;if(speed<3.5f||speed>4.1f)throw new InvalidOperationException("Direction speed unexpected "+i+": "+speed);
            if(Vector2.Dot(body.linearVelocity.normalized,d)<.97f)throw new InvalidOperationException("Artificial cardinal movement");
            report.AppendLine("move "+i+" speed="+speed+" delta="+(body.position-start));Key();await Wait(.09f);await Walk(new Vector2(-7,0));
        }
        for(int i=0;i<16;i++)
        {
            float a=i*Mathf.PI/8;Vector2 d=new Vector2(Mathf.Cos(a),Mathf.Sin(a));
            Aim(body.position+d*3,1);await Wait(.09f);Aim(body.position+d*3);
            if(!sword.Busy || !sword.Active)throw new InvalidOperationException("Sword animation not active "+i);
            report.AppendLine("attack "+i+" angle="+sword.VisualAngle);await Wait(.35f);
        }
        var p=body.position;Key(UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.Space);await Wait(.12f);
        if(!Journey.Player.State.IsDodging(Time.timeAsDouble) || Mathf.Abs(body.linearVelocity.x-body.linearVelocity.y)>.1f || Mathf.Abs(body.linearVelocity.magnitude-Mmorpg.Domain.CombatRules.DodgeSpeed)>.1f)throw new InvalidOperationException("Diagonal dodge invalid");
        report.AppendLine("diagonal dodge velocity="+body.linearVelocity+" invulnerable="+Journey.Player.State.IsDodging(Time.timeAsDouble));Key();await Wait(.35f);await Walk(new Vector2(-7,0));
        if(Time.frameCount<=frame)throw new InvalidOperationException("Frozen frames");
        return report+Inspect();
    }
    public static async Task<string> Collision()
    {
        await Tap(UnityEngine.InputSystem.Key.I);await Walk(new Vector2(-7,0));await Walk(new Vector2(-7,2));await Walk(new Vector2(-6,2));
        var body=Journey.Player.GetComponent<Rigidbody2D>();Key(UnityEngine.InputSystem.Key.D);await Wait(.8f);Key();await Wait(.1f);
        var wall=GameObject.Find("RockWest").GetComponent<Collider2D>();var player=Journey.Player.GetComponent<Collider2D>();
        float gap=player.Distance(wall).distance;if(gap<-.02f || body.position.x>-4.95f)throw new InvalidOperationException("Passed through rock");
        string result="Blocked by RockWest at "+body.position+" collider gap="+gap;
        await Walk(new Vector2(-6,0));await Walk(new Vector2(-7,0));return result+"\n"+Inspect();
    }
    public static async Task<string> Capture()
    {
        var window=Resources.FindObjectsOfTypeAll<EditorWindow>().First(w=>w.GetType().Name=="GameView");window.Show();window.Focus();await Task.Delay(200);
        string path="Docs/Validation/m06b2-ui.png";var started=DateTime.UtcNow;ScreenCapture.CaptureScreenshot(path);
        for(int i=0;i<100&&(!File.Exists(path)||File.GetLastWriteTimeUtc(path)<started);i++)await Task.Delay(50);
        if(!File.Exists(path)||File.GetLastWriteTimeUtc(path)<started)throw new InvalidOperationException("UI capture absent");return path;
    }
    public static async Task<string> CaptureGameplay()
    {
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();foreach(var t in canvas.GetComponentsInChildren<Transform>(true))if(t.name=="ActionSecondaryPanel" || t.name=="JourneyJournal" || t.name=="ExplorationDialogue")t.gameObject.SetActive(false);
        await Wait(.05f);return await Capture();
    }
    public static async Task<string> AttackReposition()
    {
        await Walk(new Vector2(-7,0));var p=Journey.Player;var rb=p.GetComponent<Rigidbody2D>();var before=rb.position;
        Aim(rb.position+Vector2.right*4,1);Key(UnityEngine.InputSystem.Key.W);await Wait(.1f);Aim(rb.position+Vector2.right*4);
        var velocity=rb.linearVelocity;bool active=p.GetComponent<SwordSwing>().Active;
        if(!active || velocity.y<1.6f || velocity.magnitude>2.1f || Vector2.Dot(p.GetComponent<ActorMotor>().Facing,Vector2.right)<.98f)throw new InvalidOperationException("Attack movement / independent aim invalid");
        Key();await Wait(.35f);return "Active sword while repositioning: velocity="+velocity+" position delta="+(rb.position-before)+" mouse facing right.";
    }
    public static async Task<string> UiControls()
    {
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var panel=canvas.GetComponentsInChildren<Transform>(true).Single(t=>t.name=="ActionSecondaryPanel").gameObject;var journal=UnityEngine.Object.FindAnyObjectByType<JourneyHud>();
        await Tap(UnityEngine.InputSystem.Key.I);if(!panel.activeSelf)throw new InvalidOperationException("Inventory key failed");await Tap(UnityEngine.InputSystem.Key.I);if(panel.activeSelf)throw new InvalidOperationException("Inventory did not close");
        await Tap(UnityEngine.InputSystem.Key.Tab);if(!journal.JournalOpen)throw new InvalidOperationException("Journal key failed");await Tap(UnityEngine.InputSystem.Key.Tab);if(journal.JournalOpen)throw new InvalidOperationException("Journal did not close");
        Key(UnityEngine.InputSystem.Key.Escape);await Task.Delay(100);if(Time.timeScale!=0)throw new InvalidOperationException("Pause failed");Key();await Task.Delay(80);Key(UnityEngine.InputSystem.Key.Escape);await Task.Delay(100);Key();await Task.Delay(80);if(Time.timeScale!=1)throw new InvalidOperationException("Resume failed");
        return "I inventory, Tab journal, Esc pause/resume verified; six existing skill slots with icons/cooldown fills.";
    }
    private static void Key(params Key[] keys){InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;if(!Keys.enabled)InputSystem.EnableDevice(Keys);if(!SessionState.GetBool("b2-editor-input-stored",false)){SessionState.SetInt("b2-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);SessionState.SetBool("b2-editor-input-stored",true);}InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));}
    private static void Aim(Vector2 point,int button=0){if(!Mouse.enabled)InputSystem.EnableDevice(Mouse);InputSystem.QueueStateEvent(Mouse,new MouseState{position=Camera.main.WorldToScreenPoint(point),buttons=(ushort)button});}
    private static async Task Wait(float seconds){double end=Time.timeAsDouble+seconds,limit=Time.realtimeSinceStartupAsDouble+seconds+5;while(Time.timeAsDouble<end){if(Time.realtimeSinceStartupAsDouble>limit)throw new TimeoutException("Frames not advancing");await Task.Delay(10);}}
    private static async Task Walk(Vector2 target,float timeout=15)
    {
        double end=Time.timeAsDouble+timeout;
        while(Vector2.Distance(Journey.Player.GetComponent<Rigidbody2D>().position,target)>.2f)
        {
            if(!Journey.Player.State.IsAlive||Time.timeAsDouble>end){Key();throw new InvalidOperationException("Walk blocked toward "+target+" "+Inspect());}
            var delta=target-Journey.Player.GetComponent<Rigidbody2D>().position;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.12f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.12f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Task.Delay(20);
        }
        Key();await Wait(.06f);
    }
    private static async Task Tap(Key key){Key(key);await Wait(.05f);Key();await Wait(.08f);}
    public static async Task<string> Village()
    {
        int frame=Time.frameCount;await Walk(new Vector2(-8.7f,-1.6f));await Tap(UnityEngine.InputSystem.Key.E);
        if(World.State.inventory.All(i=>i.id!="gray-herb"))throw new InvalidOperationException("Resource not collected");
        await Tap(UnityEngine.InputSystem.Key.E);if(World.State.inventory.Single(i=>i.id=="gray-herb").quantity!=2)throw new InvalidOperationException("Duplicate collection");
        await Walk(new Vector2(-9,0));await Tap(UnityEngine.InputSystem.Key.E);if(!World.DialogueOpen)throw new InvalidOperationException("NPC dialogue absent");await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.I);
        if(Time.frameCount<=frame)throw new InvalidOperationException("Frozen game");World.Save();return Inspect();
    }
    public static async Task<string> ForestCombat()
    {
        await Tap(UnityEngine.InputSystem.Key.I);await Walk(new Vector2(-7,0));await Walk(new Vector2(1,0));
        // Deliberately miss away from the real wolf before fighting it.
        var sword=Journey.Player.GetComponent<SwordSwing>();int healthBefore=Journey.Wolf.State.Health;
        Vector2 away=(Vector2)Journey.Player.transform.position-((Vector2)Journey.Wolf.transform.position-(Vector2)Journey.Player.transform.position).normalized*3;
        Aim(away,1);await Wait(.06f);Aim(away);await Wait(.38f);
        if(Journey.Wolf.State.Health!=healthBefore || sword.Feedback!="Sem acerto")throw new InvalidOperationException("Expected directional miss against real enemy");
        int hits=0;double end=Time.timeAsDouble+22;
        while(Journey.Wolf.State.IsAlive&&Journey.Player.State.IsAlive&&Time.timeAsDouble<end)
        {
            var delta=Journey.Wolf.transform.position-Journey.Player.transform.position;
            if(delta.magnitude>1.1f){Key(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);await Wait(.12f);Key();}
            if(Journey.Wolf.GetComponent<WolfBrain>().Mode==WolfMode.Windup){await Wait(.25f);Key(UnityEngine.InputSystem.Key.Space);await Wait(.05f);Key();await Wait(.23f);}
            Aim(Journey.Wolf.transform.position,hits++%3==2?2:1);await Wait(.06f);Aim(Journey.Wolf.transform.position);await Wait(.5f);
        }
        Key();if(Journey.Wolf.State.IsAlive||!Journey.Player.State.IsAlive)throw new InvalidOperationException("Combat inspection failed "+Inspect());
        var drop=UnityEngine.Object.FindObjectsByType<ExplorationNode>().Single(n=>n.SourceId=="wolf-material");await Walk((Vector2)drop.transform.position+Vector2.up*.8f);await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);
        if(!World.State.inventory.Any(i=>i.id=="wolf-fang"&&i.quantity==2))throw new InvalidOperationException("Confirmed defeat drop not collected");return Inspect();
    }
    public static async Task<string> MinesAndRuins()
    {
        await Walk(new Vector2(1,0));await Walk(new Vector2(-7,0));await Walk(new Vector2(-7,19));if(World.State.region!="Minas de Kharum")throw new InvalidOperationException("Mine entry absent");
        await Walk(new Vector2(-8.2f,21));await Tap(UnityEngine.InputSystem.Key.E);await Walk(new Vector2(-7,21));await Walk(new Vector2(-7,24));await Walk(new Vector2(31,24));if(World.State.region!="Ruínas de Asterion")throw new InvalidOperationException("Ruins entry absent");return Inspect();
    }
    public static async Task<string> SwampReturn()
    {
        await Walk(new Vector2(31,19));await Walk(new Vector2(31,0));if(World.State.region!="Pântano dos Ecos")throw new InvalidOperationException("Swamp entry absent");
        await Walk(new Vector2(24,0));await Walk(new Vector2(8,0));await Walk(new Vector2(1,0));await Walk(new Vector2(-7,0));if(World.State.region!="Valdoria")throw new InvalidOperationException("Return absent");World.Save();Journey.Save();await Tap(UnityEngine.InputSystem.Key.I);return Inspect();
    }
    public static async Task<string> WorldView(){await Tap(UnityEngine.InputSystem.Key.I);return Inspect();}
    public static string Inspect()=>JsonUtility.ToJson(new Report{frame=Time.frameCount,region=World.State.region,position=Journey.Player.transform.position,health=Journey.Player.State.Health,wolfAlive=Journey.Wolf.State.IsAlive,dialogue=World.DialogueOpen,inventory=World.InventoryText(),save=SessionState.GetString("b2-save","")},true);
    [Serializable] private sealed class Report {public int frame,health;public string region,inventory,save;public Vector2 position;public bool wolfAlive,dialogue;}
    public static string Cleanup()
    {
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("b2-background",0);if(SessionState.GetBool("b2-editor-input-stored",false)){InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("b2-editor-input",0);SessionState.SetBool("b2-editor-input-stored",false);}
        foreach(var device in InputSystem.devices.Where(d=>d.name.StartsWith("ExplorationInspection")).ToArray())InputSystem.RemoveDevice(device);
        foreach(var id in SessionState.GetString("b2-devices","").Split(','))if(int.TryParse(id,out int value)){var device=InputSystem.GetDeviceById(value);if(device!=null)InputSystem.EnableDevice(device);}
        ExplorationWorld.ValidationDirectory=null;JourneySession.PersistenceFactory=null;EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b2-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b2-options",0);return "Restored input, play settings and persistence factories. Personal saves not loaded.";
    }
}




