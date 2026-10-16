using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;

// Baseline only: no candidate assets are imported and no scene is saved.
public static class InspectNpcs06B13
{
    const string Evidence="Docs/Validation/Marco06B13/";
    static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    static ActorHealth Player=>Journey.Player;
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="AnimationKeyboard");
    static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    static async Task Tap(Key key){Input(key);await Wait(.08f);Input();await Wait(.14f);}
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    public static string Prepare()
    {
        Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty&&SceneManager.GetActiveScene().path=="Assets/Mmorpg/Scenes/MmorpgWorld.unity","Clean official scene required");
        SessionState.SetString("b11-evidence",Evidence+"baseline/");Directory.CreateDirectory(Evidence+"baseline/");
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B13/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);LocalJourneyProfile.ValidationRootOverride=dir;
        return "Isolated baseline ready; use B11 Setup and Cleanup around Play.";
    }
    static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>();Player.StartCoroutine(Frame(name,done));
        if(await Task.WhenAny(done.Task,Task.Delay(3000))!=done.Task)throw new Exception("Capture stalled");await done.Task;
    }
    static System.Collections.IEnumerator Frame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try{var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+"baseline/"+name+".png",t.EncodeToPNG());UnityEngine.Object.Destroy(t);done.SetResult(true);}catch(Exception e){done.SetException(e);}
    }
    public static async Task<string> Baseline()
    {
        Check(LocalJourneyProfile.Root.Contains("Temp")&&LocalJourneyProfile.ValidationRootOverride!=null,"Personal profile forbidden");
        int first=Time.frameCount;var rows=new System.Collections.Generic.List<object>();
        try
        {
            foreach(var kind in new[]{InteractionKind.Mira,InteractionKind.Orin})
            {
                var npc=Journey.Interactions.Single(i=>i.Kind==kind);var p=(Vector2)npc.transform.position;
                var rb=Player.GetComponent<Rigidbody2D>();rb.position=p+Vector2.down*.9f;rb.linearVelocity=Vector2.zero;await Wait(.4f);
                await Capture(kind+"-current");await Tap(Key.E);Check(World.DialogueOpen&&Journey.Message.Contains(kind.ToString()),"Wrong dialogue: "+Journey.Message);
                string message=Journey.Message;await Capture(kind+"-dialogue");await Tap(Key.E);Check(!World.DialogueOpen,"Dialogue stuck");
                rows.Add(new{npc=kind.ToString(),position=npc.transform.position.ToString(),dialogue=message});
            }
            World.SaveOrThrow();Journey.SaveOrThrow();Journey.FlushPersistenceOrThrow();
            string id=LocalJourneyProfile.IdentityId;var facts=Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x).ToArray();
            await Tap(Key.F5);await Wait(.7f);
            Check(SceneManager.GetActiveScene().path=="Assets/Mmorpg/Scenes/MmorpgWorld.unity"&&id==LocalJourneyProfile.IdentityId,"F5 scene/profile changed");
            Check(facts.SequenceEqual(Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x)),"Narrative facts changed on load");
            Check(Player.GetComponent<ProductionSpriteAnimator>().Body.sprite!=null&&Player.State.IsAlive,"Hero missing");
            await Capture("returned-world");Check(Time.frameCount>first,"Frozen frames");
            string json=JsonConvert.SerializeObject(new{baselineOnly=true,candidatesIntegrated=false,first,last=Time.frameCount,rows,isolatedSaveLoad=true,f5=true,narrativeFacts=facts,heroPresent=true},Formatting.Indented);
            File.WriteAllText(Evidence+"baseline/qa.json",json);return json;
        }
        finally{Input();if(World.DialogueOpen)World.CloseDialogue();}
    }
}
