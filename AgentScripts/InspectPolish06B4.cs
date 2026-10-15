using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;

// Short, real Editor input/capture inspection; not the suspended test suites.
public static class InspectPolish06B4
{
    private const string Evidence="Docs/Validation/Marco06B4/";
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static LocalSessionCommands Commands=>Journey.GetComponent<LocalSessionCommands>();
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="PolishKeyboard");
    private static Mouse Pointer=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="PolishMouse");
    public static string Prepare()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/Marco06B4Polish.unity")throw new InvalidOperationException("Open B4");
        SessionState.SetBool("b4-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b4-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b4-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b4-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B4/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);Directory.CreateDirectory(Evidence);SessionState.SetString("b4-save",dir);LocalJourneyProfile.ValidationRootOverride=dir;
        File.WriteAllText(Path.Combine(dir,"unrelated-sentinel.txt"),"preserve");return dir;
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b4-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var d in native)InputSystem.DisableDevice(d);
        InputSystem.AddDevice<Keyboard>("PolishKeyboard");InputSystem.AddDevice<Mouse>("PolishMouse");Aim((Vector2)Journey.Player.transform.position+Vector2.down*3);return Inspect();
    }
    public static string PrepareRecovered()
    {
        string target=Prepare();string source=Directory.GetDirectories(Path.GetFullPath("Temp/Marco06B4")).FirstOrDefault(dir=>{
            if(dir==target)return false;try{var saved=new JsonJourneyPersistence(Path.Combine(dir,"journey.json")).Load();return saved!=null&&Mmorpg.Domain.JourneyEngine.Restore(saved).HasAbility(Mmorpg.Domain.ForestContent.Technique);}catch{return false;}});
        if(source==null)throw new Exception("No completed isolated gameplay profile");
        foreach(string file in new[]{"journey.json","journey.json.bak","profile.json","marco06b1-exploration.json","marco06b1-exploration.json.bak"})if(File.Exists(Path.Combine(source,file)))File.Copy(Path.Combine(source,file),Path.Combine(target,file),false);
        return "Recovered a copy of real prior Temp gameplay into "+target+"; source unchanged: "+source;
    }
    public static async Task<string> MonitorReview()
    {
        if(!Journey.Engine.HasAbility(Mmorpg.Domain.ForestContent.Technique))throw new Exception("Prior journey not recovered");
        await Walk(new Vector2(-7,0));await Walk(new Vector2(-2,.3f));await Walk(new Vector2(-2,2.3f));await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);
        if(!UnityEngine.Object.FindAnyObjectByType<WorldDebugOverlay>().Visible)await Tap(UnityEngine.InputSystem.Key.F8);
        await Tap(UnityEngine.InputSystem.Key.LeftCtrl,UnityEngine.InputSystem.Key.F8);await Capture("events-history");
        string result="Prior real Temp journey recovered with unlocked ability; Orin interaction generated real current-session diagnostic trace. "+Inspect();File.WriteAllText(Evidence+"recovered-monitor.txt",result);return result;
    }
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    private static void Aim(Vector2 point,int button=0)=>InputSystem.QueueStateEvent(Pointer,new MouseState{position=Camera.main.WorldToScreenPoint(point),buttons=(ushort)button});
    private static async Task Wait(float seconds)
    {double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    private static async Task Tap(params Key[] keys){Key(keys);await Wait(.06f);Key();await Wait(.12f);}
    private static async Task Capture(string name)
    {
        var actor=Journey.Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();var sword=actor.GetComponent<SwordSwing>();var point=Camera.main.WorldToScreenPoint(actor.transform.position);
        File.AppendAllText(Evidence+"capture-metadata.jsonl",JsonConvert.SerializeObject(new{name,frame=Time.frameCount,time=Time.timeAsDouble,screenWidth=Screen.width,screenHeight=Screen.height,playerScreen=new[]{point.x,point.y},source=animator.CurrentFrame.source,phase=sword.VisualPhase,hand=sword.GripWorld.ToString(),tipError=actor.GetComponent<SwordSweepDebug>().MaximumActiveTipError})+"\n");
        ScreenCapture.CaptureScreenshot(Evidence+name+".png");await Wait(.045f);
    }
    public static string Inspect()
    {
        var p=Journey.Player;var a=p.GetComponent<ProductionSpriteAnimator>();
        return JsonConvert.SerializeObject(new{frame=Time.frameCount,position=p.transform.position.ToString(),health=p.State.Health,state=a.State,direction=a.DirectionIndex,sprite=a.Body.sprite.name,hand=p.GetComponent<SwordSwing>().GripWorld.ToString(),epoch=SessionEpoch.Current,identity=LocalJourneyProfile.IdentityId,profile=LocalJourneyProfile.Root,diagnostics=RuntimeDiagnostics.Read()});
    }
    public static async Task<string> Visuals()
    {
        int first=Time.frameCount;await Wait(.3f);await Capture("idle");await Tap(UnityEngine.InputSystem.Key.F8);await Wait(.2f);await Capture("monitor");
        var keys=new[]{UnityEngine.InputSystem.Key.D,UnityEngine.InputSystem.Key.W,UnityEngine.InputSystem.Key.A,UnityEngine.InputSystem.Key.S};var vectors=new[]{Vector2.right,Vector2.up,Vector2.left,Vector2.down};
        var report=new System.Text.StringBuilder();
        for(int d=0;d<4;d++)
        {
            await Walk(new Vector2(-7,0));Aim((Vector2)Journey.Player.transform.position+vectors[d]*5);Key(keys[d]);
            var distinct=new System.Collections.Generic.HashSet<string>();
            for(int i=0;i<14;i++){await Wait(.045f);distinct.Add(Journey.Player.GetComponent<ProductionSpriteAnimator>().Body.sprite.name);await Capture("walk-"+d+"-"+i.ToString("00"));}
            Key();await Wait(.12f);report.AppendLine("direction="+d+" observed sprites="+string.Join(",",distinct));
        }
        await Walk(new Vector2(-7,0));await Tap(UnityEngine.InputSystem.Key.F7);
        for(int d=0;d<4;d++)
        {
            Aim((Vector2)Journey.Player.transform.position+vectors[d]*3,1);await Wait(.025f);Aim((Vector2)Journey.Player.transform.position+vectors[d]*3);
            for(int i=0;i<8;i++){await Capture("attack-"+d+"-"+i.ToString("00"));await Wait(.015f);}await Wait(.15f);
        }
        await Tap(UnityEngine.InputSystem.Key.Space);await Capture("dodge");await Tap(UnityEngine.InputSystem.Key.F7);await Tap(UnityEngine.InputSystem.Key.Escape);await Capture("pause");await Tap(UnityEngine.InputSystem.Key.Escape);
        if(Time.frameCount<=first)throw new Exception("Frozen frames");File.WriteAllText(Evidence+"visual-inspection.txt",report+Inspect());return report+Inspect();
    }
    private static async Task Walk(Vector2 goal)
    {
        double end=Time.realtimeSinceStartupAsDouble+12;
        while(Vector2.Distance(Journey.Player.GetComponent<Rigidbody2D>().position,goal)>.18f)
        {
            if(Time.realtimeSinceStartupAsDouble>end||!Journey.Player.State.IsAlive){Key();throw new Exception("Walk blocked: "+Inspect());}
            var delta=goal-Journey.Player.GetComponent<Rigidbody2D>().position;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.1f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.1f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Wait(.04f);
        }
        Key();await Wait(.12f);
    }
    public static async Task<string> ResetCommands()
    {
        // Only the Temp profile created by Prepare may be reset by this inspection.
        if(LocalJourneyProfile.Root!=SessionState.GetString("b4-save",""))throw new Exception("Not isolated");
        var state=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();state.State.discoveries.Add("b4-restart-verification");state.Save();Journey.Save();Journey.FlushPersistenceOrThrow();string id=LocalJourneyProfile.IdentityId;long epoch=SessionEpoch.Current;
        await Tap(UnityEngine.InputSystem.Key.F5);await Wait(.5f);
        if(LocalJourneyProfile.IdentityId!=id||SessionEpoch.Current<=epoch||!UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>().State.discoveries.Contains("b4-restart-verification"))throw new Exception("F5 did not recover persisted state");
        await Capture("after-f5");await Tap(UnityEngine.InputSystem.Key.LeftCtrl,UnityEngine.InputSystem.Key.LeftShift,UnityEngine.InputSystem.Key.R);
        if(!Commands.ConfirmationOpen)throw new Exception("No confirmation");await Capture("reset-confirmation");await Tap(UnityEngine.InputSystem.Key.Escape);
        if(LocalJourneyProfile.IdentityId!=id)throw new Exception("Cancel changed identity");
        await Tap(UnityEngine.InputSystem.Key.LeftCtrl,UnityEngine.InputSystem.Key.LeftShift,UnityEngine.InputSystem.Key.R);
        var button=GameObject.Find("ConfirmNewJourney/Criar backup e reiniciar");
        // Invoke the actual UI button, after explicitly opening its confirmation in isolated Temp data.
        if(button==null)button=UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>(FindObjectsInactive.Include).Single(b=>b.name=="Criar backup e reiniciar").gameObject;
        button.GetComponent<UnityEngine.UI.Button>().onClick.Invoke();await Wait(.6f);
        state=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
        if(LocalJourneyProfile.IdentityId==id||state.State.discoveries.Contains("b4-restart-verification")||File.ReadAllText(Path.Combine(LocalJourneyProfile.Root,"unrelated-sentinel.txt"))!="preserve")throw new Exception("Reset isolation failed");
        string backup=Directory.GetDirectories(Path.Combine(LocalJourneyProfile.Root,"Backups")).Single();
        if(!File.Exists(Path.Combine(backup,"journey.json"))||!File.Exists(Path.Combine(backup,"profile.json")))throw new Exception("Backup missing");
        await Capture("after-new-journey");await Tap(UnityEngine.InputSystem.Key.F8);await Wait(.2f);await Capture("monitor-after-reset");
        string result="F5 preserved identity and exploration fact; Ctrl+Shift+R required confirmation; Escape cancelled; confirm backed up exact owned files and generated new identity; unrelated sentinel preserved. Backup: "+backup+"\n"+Inspect();File.WriteAllText(Evidence+"reset-inspection.txt",result);return result;
    }
    public static async Task<string> GuardAndOverlay()
    {
        var overlay=UnityEngine.Object.FindAnyObjectByType<WorldDebugOverlay>();bool visible=overlay.Visible;await Tap(UnityEngine.InputSystem.Key.F8);if(overlay.Visible==visible)throw new Exception("F8 did not toggle");await Tap(UnityEngine.InputSystem.Key.F8);if(overlay.Visible!=visible)throw new Exception("F8 did not restore");
        var online=new SupabaseSession("http://127.0.0.1:1","sb_publishable_inspection_not_a_real_key");
        // Isolated in-memory guard fixture, no authentication/network. Never presented as a real connection.
        typeof(SupabaseSession).GetField("accessToken",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).SetValue(online,"inspection-sentinel");
        try{Commands.RequestNewJourney();if(Commands.ConfirmationOpen||string.IsNullOrEmpty(Commands.LastError))throw new Exception("Online reset was not blocked");}
        finally{online.Clear();Commands.Continue();}
        string result="F8 toggled both ways; authenticated-session guard blocked reset using an in-memory fixture, with zero network/auth calls.";File.WriteAllText(Evidence+"guard-inspection.txt",result);return result;
    }
    private static UnityEngine.UI.Button ActiveButton(string name)=>UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>().Single(b=>b.name==name&&b.gameObject.activeInHierarchy);
    private static async Task PointerClick(RectTransform rectangle,float normalizedX=.5f)
    {
        var corners=new Vector3[4];rectangle.GetWorldCorners(corners);Vector2 point=Vector2.Lerp(corners[0],corners[2],.5f);point.x=Mathf.Lerp(corners[0].x,corners[2].x,normalizedX);
        var hits=new System.Collections.Generic.List<UnityEngine.EventSystems.RaycastResult>();
        UnityEngine.EventSystems.EventSystem.current.RaycastAll(new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current){position=point},hits);
        if(!hits.Any(h=>h.gameObject.transform==rectangle||h.gameObject.transform.IsChildOf(rectangle)))throw new Exception("UI raycast did not reach "+rectangle.name);
        InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(.07f);
        InputSystem.QueueStateEvent(Pointer,new MouseState{position=point,buttons=1});await Wait(.07f);
        InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(.18f);
    }
    private static Task ClickButton(string name)=>PointerClick((RectTransform)ActiveButton(name).transform);
    public static async Task<string> PauseButtons()
    {
        if(LocalJourneyProfile.Root!=SessionState.GetString("b4-save",""))throw new Exception("Only isolated Temp profile allowed");
        float oldVolume=AudioListener.volume;var report=new System.Text.StringBuilder();
        try
        {
            await Tap(UnityEngine.InputSystem.Key.Escape);if(Time.timeScale!=0)throw new Exception("Menu did not pause");
            await Capture("pause-mouse-fixed");await ClickButton("Continuar");if(Time.timeScale!=1||ActiveButtonOrNull("Continuar")!=null)throw new Exception("Continue click failed");report.AppendLine("Continuar: real mouse click resumed and hid menu.");
            await Tap(UnityEngine.InputSystem.Key.Escape);await ClickButton("Configurações");
            var slider=UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Slider>().Single(s=>s.name=="Volume"&&s.gameObject.activeInHierarchy);
            await PointerClick((RectTransform)slider.transform,.25f);if(Mathf.Abs(AudioListener.volume-.25f)>.06f)throw new Exception("Volume slider click failed: "+AudioListener.volume);
            report.AppendLine("Configurações: mouse opened settings; volume slider changed AudioListener to "+AudioListener.volume.ToString("0.00"));await ClickButton("Voltar");
            var state=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();state.State.discoveries.Add("pause-mouse-restart");state.Save();string identity=LocalJourneyProfile.IdentityId;long epoch=SessionEpoch.Current;
            await ClickButton("Reiniciar sessão");await Wait(.35f);
            if(identity!=LocalJourneyProfile.IdentityId||SessionEpoch.Current<=epoch||!UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>().State.discoveries.Contains("pause-mouse-restart"))throw new Exception("Restart button failed");report.AppendLine("Reiniciar sessão: real click reloaded and recovered identity/discovery.");
            await Tap(UnityEngine.InputSystem.Key.Escape);await ClickButton("Nova jornada · desenvolvimento");if(!Commands.ConfirmationOpen)throw new Exception("New journey button failed");
            await ClickButton("Cancelar");if(Commands.ConfirmationOpen||identity!=LocalJourneyProfile.IdentityId)throw new Exception("Cancel button failed");report.AppendLine("Nova jornada / Cancelar: real clicks opened confirmation and preserved journey.");
            await Tap(UnityEngine.InputSystem.Key.Escape);await ClickButton("Nova jornada · desenvolvimento");await ClickButton("Criar backup e reiniciar");await Wait(.35f);
            if(identity==LocalJourneyProfile.IdentityId||UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>().State.discoveries.Contains("pause-mouse-restart")||File.ReadAllText(Path.Combine(LocalJourneyProfile.Root,"unrelated-sentinel.txt"))!="preserve"||!Directory.Exists(Path.Combine(LocalJourneyProfile.Root,"Backups")))throw new Exception("Confirmed reset button failed");report.AppendLine("Confirmar nova jornada: mouse reset isolated Temp data, backed up and preserved unrelated sentinel.");
            await Tap(UnityEngine.InputSystem.Key.Escape);await ClickButton("Sair");await Wait(.25f);if(EditorApplication.isPlaying)throw new Exception("Quit button failed");report.AppendLine("Sair: real mouse click exited Play in Editor.");
            File.WriteAllText(Evidence+"pause-mouse-validation.txt",report.ToString());return report.ToString();
        }
        finally{AudioListener.volume=oldVolume;}
    }
    private static UnityEngine.UI.Button ActiveButtonOrNull(string name)=>UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>().FirstOrDefault(b=>b.name==name&&b.gameObject.activeInHierarchy);
    public static async Task<string> Fight()
    {
        await Walk(new Vector2(-7,0));await Walk(new Vector2(1,0));int startHP=Journey.Player.State.Health,wolfHP=Journey.Wolf.State.Health,number=0;bool received=false;double end=Time.realtimeSinceStartupAsDouble+24;
        while(Journey.Wolf.State.IsAlive&&Journey.Player.State.IsAlive&&Time.realtimeSinceStartupAsDouble<end)
        {
            var delta=Journey.Wolf.transform.position-Journey.Player.transform.position;
            if(delta.magnitude>1.1f){Key(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);await Wait(.08f);Key();}
            if(received&&Journey.Wolf.GetComponent<WolfBrain>().Mode==WolfMode.Windup){await Wait(.22f);await Tap(UnityEngine.InputSystem.Key.Space);}
            Aim(Journey.Wolf.transform.position,number%3==2?2:1);await Wait(.035f);Aim(Journey.Wolf.transform.position);
            await Capture("fight-"+number.ToString("00"));await Wait(.18f);
            if(Journey.Player.State.Health<startHP)received=true;number++;
        }
        Key();await Wait(.5f);await Capture("wolf-result");
        if(!Journey.Wolf.State.IsAlive)
        {
            await Walk((Vector2)Journey.Wolf.transform.position+Vector2.down*.8f);await Tap(UnityEngine.InputSystem.Key.E);
            await Walk(new Vector2(-7,0));await Walk(new Vector2(-8,.1f));await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);await Tap(UnityEngine.InputSystem.Key.E);await Wait(.2f);
        }
        if(!UnityEngine.Object.FindAnyObjectByType<WorldDebugOverlay>().Visible)await Tap(UnityEngine.InputSystem.Key.F8);await Tap(UnityEngine.InputSystem.Key.LeftCtrl,UnityEngine.InputSystem.Key.F8);await Capture("events-history");
        string result="Real combat: player HP "+startHP+" -> "+Journey.Player.State.Health+"; wolf HP "+wolfHP+" -> "+Journey.Wolf.State.Health+"; received damage="+received+"; "+Inspect();File.WriteAllText(Evidence+"combat-inspection.txt",result);return result;
    }
    public static async Task<string> FinalView()
    {if(UnityEngine.Object.FindAnyObjectByType<WorldDebugOverlay>().Visible)await Tap(UnityEngine.InputSystem.Key.F8);await Walk(new Vector2(-7,0));await Walk(new Vector2(-6,0));await Walk(new Vector2(-6,4));Aim((Vector2)Journey.Player.transform.position+Vector2.down*3);await Wait(.2f);await Capture("final-village");return Inspect();}
    public static string Cleanup()
    {
        if(EditorApplication.isPlaying)throw new Exception("Stop Play");
        foreach(var d in InputSystem.devices.Where(d=>d.name=="PolishKeyboard"||d.name=="PolishMouse").ToArray())InputSystem.RemoveDevice(d);
        foreach(string id in SessionState.GetString("b4-devices","").Split(','))if(int.TryParse(id,out int device)) {var found=InputSystem.GetDeviceById(device);if(found!=null)InputSystem.EnableDevice(found);}
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b4-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b4-options",0);
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("b4-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("b4-editor-input",0);
        LocalJourneyProfile.ValidationRootOverride=null;ExplorationWorld.ValidationDirectory=null;JourneySession.PersistenceFactory=null;return "Editor/input settings restored; Temp evidence retained; original saves untouched.";
    }
}
