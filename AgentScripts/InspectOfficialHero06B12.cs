using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;

// Reuses InspectIronKnight06B11 for animation/physical QA, directing its output to B12.
public static class InspectOfficialHero06B12
{
    private const string Evidence="Docs/Validation/Marco06B12/";
    private const string Official="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    private static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    private static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    private static ActorHealth Player=>Journey.Player;
    private static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="AnimationKeyboard");
    private static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    private static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    private static async Task Tap(Key key){Key(key);await Wait(.06f);Key();await Wait(.1f);}
    private static void Check(bool value,string message){if(!value)throw new Exception(message);}
    public static string Prepare()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Official)throw new Exception("Clean official scene outside Play required");
        Check(EditorBuildSettings.scenes[0].path==Official&&EditorBuildSettings.scenes[0].enabled,"Official entry missing");
        SessionState.SetString("b11-evidence",Evidence+"gameplay/");Directory.CreateDirectory(Evidence+"gameplay/");
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/Marco06B12/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);LocalJourneyProfile.ValidationRootOverride=dir;
        return "Isolated validation profile configured before Play; B11 harness cleanup will restore Editor/input/override.";
    }
    private static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>();Player.StartCoroutine(CaptureFrame(name,done));if(await Task.WhenAny(done.Task,Task.Delay(3000))!=done.Task)throw new Exception("EOF capture stalled");await done.Task;
    }
    private static System.Collections.IEnumerator CaptureFrame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try{var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+name+".png",t.EncodeToPNG());UnityEngine.Object.Destroy(t);done.SetResult(true);}catch(Exception e){done.SetException(e);}
    }
    public static async Task<string> BootIndexZero()
    {
        var old=Player.GetEntityId();string profile=LocalJourneyProfile.Root;SceneManager.LoadScene(0);await Wait(.8f);
        Check(SceneManager.GetActiveScene().path==Official&&Player.GetEntityId()!=old,"Build index zero did not load official world");
        Check(Player.State.IsAlive&&World.State.region=="Valdoria"&&LocalJourneyProfile.Root==profile,"Startup/profile changed");
        var animator=Player.GetComponent<ProductionSpriteAnimator>();var set=(ProductionCharacterSet)new SerializedObject(animator).FindProperty("art").objectReferenceValue;
        Check(set.characterId=="IronKnight"&&set.clips.Length==36&&animator.State=="idle","Official hero not active at boot");
        Check(Player.GetComponentsInChildren<SpriteRenderer>().Count(r=>r.name=="BodySprite")==1&&Player.GetComponentsInChildren<SpriteRenderer>().Count(r=>r.name=="EquippedSword")==1,"Duplicate body or weapon");
        int first=Time.frameCount;await Wait(.2f);await Capture("official-startup");Check(Time.frameCount>first,"Frames stalled");
        string json=JsonConvert.SerializeObject(new{scene=Official,index=SceneManager.GetActiveScene().buildIndex,first,last=Time.frameCount,character=set.characterId,clips=set.clips.Length,position=Player.transform.position.ToString(),region=World.State.region,isolatedProfile=true},Formatting.Indented);File.WriteAllText(Evidence+"startup.json",json);return json;
    }
    private static async Task Walk(Vector2 target,float timeout=8)
    {
        double end=Time.realtimeSinceStartupAsDouble+timeout;
        while(Vector2.Distance(Player.GetComponent<Rigidbody2D>().position,target)>.22f)
        {
            if(Time.realtimeSinceStartupAsDouble>end){Key();throw new Exception("Route blocked toward "+target);}
            var delta=target-Player.GetComponent<Rigidbody2D>().position;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.12f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.12f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Wait(.025f);
        }
        Key();await Wait(.12f);
    }
    public static async Task<string> WorldAndPersistence()
    {
        try {
            Time.timeScale=1;Key();Player.GetComponent<Rigidbody2D>().position=new Vector2(-8,-1);await Wait(.2f);
            await Walk(new Vector2(-8.5f,-1.3f));await Tap(UnityEngine.InputSystem.Key.E);
            Check(World.State.inventory.Any(i=>i.id=="gray-herb"&&i.quantity==2),"Resource interaction failed");await Tap(UnityEngine.InputSystem.Key.E);Check(World.State.inventory.Single(i=>i.id=="gray-herb").quantity==2,"Duplicate collection accepted");
            await Walk(new Vector2(-8,.2f));await Tap(UnityEngine.InputSystem.Key.E);Check(World.DialogueOpen,"Mira dialogue failed");Check(!Player.GetComponent<PlayerController>().enabled,"Dialogue did not retain movement policy");await Capture("npc-dialogue");await Tap(UnityEngine.InputSystem.Key.E);Check(!World.DialogueOpen&&Player.GetComponent<PlayerController>().enabled,"Dialogue close failed");
            int facts=Journey.Engine.Snapshot().facts.Count;Check(facts>0,"NPC narrative fact missing");await Tap(UnityEngine.InputSystem.Key.I);await Capture("inventory");await Tap(UnityEngine.InputSystem.Key.I);await Tap(UnityEngine.InputSystem.Key.Tab);await Capture("journal");await Tap(UnityEngine.InputSystem.Key.Tab);
            await Tap(UnityEngine.InputSystem.Key.Escape);Check(Time.timeScale==0,"Pause failed");await Capture("pause-menu");await Tap(UnityEngine.InputSystem.Key.Escape);Check(Time.timeScale==1,"Resume failed");
            World.SaveOrThrow();Journey.SaveOrThrow();Journey.FlushPersistenceOrThrow();string identity=LocalJourneyProfile.IdentityId;var before=Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x).ToArray();
            await Tap(UnityEngine.InputSystem.Key.F5);await Wait(.8f);Check(SceneManager.GetActiveScene().path==Official&&Player.State.IsAlive,"F5 lost official scene/hero");Check(LocalJourneyProfile.IdentityId==identity,"Profile identity changed on reload");Check(World.State.inventory.Single(i=>i.id=="gray-herb").quantity==2&&World.State.collected.Contains("village-herbs"),"Inventory not loaded");Check(before.SequenceEqual(Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x)),"Narrative facts not loaded");await Capture("saved-session-reloaded");
            var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();Check(authority.IsSafePosition(Player.transform.position),"Village safety changed");
            // Actual input crosses the village/forest boundary; other authored regions remain unchanged by structural comparison.
            Player.GetComponent<Rigidbody2D>().position=new Vector2(-1.5f,0);await Wait(.2f);await Walk(new Vector2(1.4f,0));Check(World.State.region=="Floresta Cinzenta"&&!authority.IsSafePosition(Player.transform.position),"Physical forest entry failed");await Capture("forest-entry");
            string json=JsonConvert.SerializeObject(new{resourceCollected=true,duplicateCollectionRejected=true,npcDialogue=true,narrativeFacts=facts,inventoryAndJournal=true,pauseResume=true,f5SameOfficialScene=true,profileIdentityRetained=true,inventoryAndFactsReloaded=true,physicalRegionCrossing=true,profileIsolated=true},Formatting.Indented);File.WriteAllText(Evidence+"world-and-persistence.json",json);return json;
        }finally{Key();Time.timeScale=1;if(World.DialogueOpen)World.CloseDialogue();}
    }
}
