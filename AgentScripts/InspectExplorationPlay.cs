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
public static class InspectExplorationPlay
{
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="ExplorationInspectionKeyboard");
    private static Mouse Mouse=>InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="ExplorationInspectionMouse");
    public static string Prepare()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play");
        SessionState.SetBool("b1-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b1-options",(int)EditorSettings.enterPlayModeOptions);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        string dir=Path.GetFullPath("Temp/Marco06B1/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);SessionState.SetString("b1-save",dir);
        ExplorationWorld.ValidationDirectory=dir;JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(dir,"journey.json"));
        EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/Marco06B1World.unity");return dir;
    }
    public static string Resume()
    {
        string dir=SessionState.GetString("b1-save","");Prepare();SessionState.SetString("b1-save",dir);ExplorationWorld.ValidationDirectory=dir;JourneySession.PersistenceFactory=()=>new JsonJourneyPersistence(Path.Combine(dir,"journey.json"));return dir;
    }
    public static async Task<string> FinalInspection()
    {
        if(World.State.inventory.Single(i=>i.id=="wolf-fang").quantity!=2||World.State.inventory.Single(i=>i.id=="iron-ore").quantity!=3||Journey.Wolf.State.IsAlive)throw new InvalidOperationException("Reload did not preserve materials / narrative defeat");
        var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();if(!authority.IsSafePosition(Journey.Player.transform.position))throw new InvalidOperationException("Safe village configuration missing");
        await Walk(new Vector2(-7,0));await Walk(new Vector2(1.4f,0));if(World.State.region!="Floresta Cinzenta"||authority.IsSafePosition(Journey.Player.transform.position))throw new InvalidOperationException("Region boundary incorrect");await Walk(new Vector2(-7,0));await Tap(UnityEngine.InputSystem.Key.I);return Inspect();
    }
    public static string Setup()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("b1-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var device in native)InputSystem.DisableDevice(device);
        InputSystem.AddDevice<Keyboard>("ExplorationInspectionKeyboard");InputSystem.AddDevice<Mouse>("ExplorationInspectionMouse");return Inspect();
    }
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    private static void Aim(Vector2 point,int button=0)=>InputSystem.QueueStateEvent(Mouse,new MouseState{position=Camera.main.WorldToScreenPoint(point),buttons=(ushort)button});
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
    public static string Inspect()=>JsonUtility.ToJson(new Report{frame=Time.frameCount,region=World.State.region,position=Journey.Player.transform.position,health=Journey.Player.State.Health,wolfAlive=Journey.Wolf.State.IsAlive,dialogue=World.DialogueOpen,inventory=World.InventoryText(),save=SessionState.GetString("b1-save","")},true);
    [Serializable] private sealed class Report {public int frame,health;public string region,inventory,save;public Vector2 position;public bool wolfAlive,dialogue;}
    public static string Cleanup()
    {
        foreach(var device in InputSystem.devices.Where(d=>d.name.StartsWith("ExplorationInspection")).ToArray())InputSystem.RemoveDevice(device);
        foreach(var id in SessionState.GetString("b1-devices","").Split(','))if(int.TryParse(id,out int value)){var device=InputSystem.GetDeviceById(value);if(device!=null)InputSystem.EnableDevice(device);}
        ExplorationWorld.ValidationDirectory=null;JourneySession.PersistenceFactory=null;EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("b1-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("b1-options",0);return "Restored input, play settings and persistence factories. Personal saves not loaded.";
    }
}
