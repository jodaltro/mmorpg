using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;

public static class InspectGarmentLab06B13R3
{
    const string Scene="Assets/Mmorpg/Scenes/Marco06B13R3Wardrobe.unity";
    const string Evidence="Docs/Validation/Marco06B13R3/gameplay/";
    static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    static ActorHealth Player=>Journey.Player;
    static JourneyInteractable Mira=>Journey.Interactions.Single(i=>i.Kind==InteractionKind.Mira);
    static SpriteRenderer Visual=>Mira.GetComponent<SpriteRenderer>();
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
    static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static async Task Wait(float seconds){double until=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<until)await Task.Delay(10);}
    static async Task Tap(Key key){Input(key);await Wait(.07f);Input();await Wait(.15f);}
    static async Task Walk(Vector2 target)
    {
        double until=Time.realtimeSinceStartupAsDouble+4;
        while(Vector2.Distance(Player.GetComponent<Rigidbody2D>().position,target)>.15f)
        {
            Check(Time.realtimeSinceStartupAsDouble<until,"Walking route blocked: "+target);
            var delta=target-Player.GetComponent<Rigidbody2D>().position;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.09f)keys.Add(delta.x>0?Key.D:Key.A);if(Mathf.Abs(delta.y)>.09f)keys.Add(delta.y>0?Key.W:Key.S);Input(keys.ToArray());await Wait(.02f);
        }
        Input();await Wait(.1f);
    }
    public static string Prepare()
    {
        Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty&&SceneManager.GetActiveScene().path==Scene,"Clean experiment required");
        Directory.CreateDirectory(Evidence);SessionState.SetString("b11-evidence",Evidence);
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string root=Path.GetFullPath("Temp/Marco06B13R3/Profile-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(root);LocalJourneyProfile.ValidationRootOverride=root;
        return "Isolated profile configured before Play; use B11 Setup and Cleanup.";
    }
    static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>();Player.StartCoroutine(Frame(name,done));Check(await Task.WhenAny(done.Task,Task.Delay(3000))==done.Task,"GameView capture stalled");await done.Task;
    }
    static System.Collections.IEnumerator Frame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try{var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+name+".png",tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);done.SetResult(true);}catch(Exception e){done.SetException(e);}
    }
    static async Task Place(Vector2 position){Input();var rb=Player.GetComponent<Rigidbody2D>();rb.position=position;rb.linearVelocity=Vector2.zero;await Wait(.3f);var pointer=InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="AnimationMouse");InputSystem.QueueStateEvent(pointer,new MouseState{position=Camera.main.WorldToScreenPoint(Player.transform.position+Vector3.right*3)});await Wait(.1f);}
    public static string CollisionSnapshot()=>JsonConvert.SerializeObject(new{position=Player.transform.position.ToString("R"),colliders=Player.GetComponents<Collider2D>().Select(c=>new{type=c.GetType().Name,trigger=c.isTrigger,distance=Physics2D.Distance(c,Mira.GetComponent<Collider2D>()).distance,enabled=c.enabled}),npc=Mira.transform.position.ToString("R")});
    public static async Task<string> CaptureViews()
    {
        Check(LocalJourneyProfile.ValidationRootOverride!=null,"Isolated profile required");
        SceneManager.LoadScene(0);await Wait(.6f);await Place(new Vector2(-9.2f,.5f));await Capture("mira-before-official");
        SceneManager.LoadScene(Scene);await Wait(.6f);await Place(new Vector2(-9.2f,.5f));
        var cloak=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3/MiraTraveller.png").OfType<Sprite>().ToDictionary(s=>s.name);
        var pack=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3/MiraBackpack.png").OfType<Sprite>().ToDictionary(s=>s.name);
        await Capture("mira-after-procedural");
        foreach(var pair in new[]{new{direction="south",index=6},new{direction="west",index=3},new{direction="north",index=0},new{direction="east",index=9}})
        {
            Visual.sprite=cloak["pose_"+pair.index.ToString("000")];await Wait(.12f);await Capture("outfit-"+pair.direction);
            Visual.sprite=pack["pose_"+pair.index.ToString("000")];await Wait(.12f);await Capture("backpack-"+pair.direction+"-corrected");
        }
        Visual.sprite=cloak["pose_006"];Input();return "Captured real four-direction wardrobe views with the hero standing clear of Mira.";
    }
    public static async Task<string> Inspect()
    {
        Check(LocalJourneyProfile.ValidationRootOverride!=null&&LocalJourneyProfile.Root.Contains("Temp"),"Personal profile forbidden");int first=Time.frameCount;
        try
        {
            SceneManager.LoadScene(0);await Wait(.6f);await Place(new Vector2(-6.8f,.5f));await Capture("mira-before-official");
            await Place(new Vector2(-8,-.3f));Input(Key.W);await Wait(.5f);Input();await Wait(.15f);
            float originalContact=Physics2D.Distance(Player.GetComponent<Collider2D>(),Mira.GetComponent<Collider2D>()).distance;float originalBlockedY=Player.transform.position.y;
            SceneManager.LoadScene(Scene);await Wait(.6f);await Place(new Vector2(-6.8f,.5f));await Capture("mira-after-procedural");
            Check(Visual.sprite.name=="pose_006"&&Visual.sprite.pixelsPerUnit==32&&Visual.sprite.pivot==new Vector2(32,20),"Imported sprite/pivot contract changed");
            var collider=Mira.GetComponent<BoxCollider2D>();Check(collider.size==new Vector2(.5f,.6f)&&collider.offset==Vector2.zero,"NPC collider changed");
            await Tap(Key.E);Check(World.DialogueOpen&&Journey.Message.StartsWith("Mira:"),"Mira dialogue missing");await Capture("mira-dialogue");await Tap(Key.E);Check(!World.DialogueOpen,"Dialogue stuck");
            var sprites=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3/MiraTraveller.png").OfType<Sprite>().ToDictionary(s=>s.name);
            foreach(var pair in new[]{new{direction="south",index=6},new{direction="west",index=3},new{direction="north",index=0},new{direction="east",index=9}})
            {Visual.sprite=sprites["pose_"+pair.index.ToString("000")];await Wait(.12f);await Capture("outfit-"+pair.direction);}
            var backpack=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3/MiraBackpack.png").OfType<Sprite>().ToDictionary(s=>s.name);
            foreach(var pair in new[]{new{direction="west",index=3},new{direction="east",index=9},new{direction="north",index=0},new{direction="south",index=6}})
            {Visual.sprite=backpack["pose_"+pair.index.ToString("000")];await Wait(.12f);await Capture("backpack-"+pair.direction+"-corrected");}
            // Play-only pose inspection. No patrol, runtime animator, or garment secondary animation added.
            for(int n=0;n<8;n++){Visual.sprite=sprites["pose_"+(12+n).ToString("000")];await Wait(.125f);await Capture("back-pose-"+n);}
            Visual.sprite=sprites["pose_006"];
            await Place(new Vector2(-8,-.3f));Input(Key.W);await Wait(.5f);Input();await Wait(.15f);
            var heroBody=Player.GetComponent<ProductionSpriteAnimator>().Body;Check(heroBody.sortingOrder>Visual.sortingOrder,"Front sorting reversed");
            float frontContact=Physics2D.Distance(Player.GetComponent<Collider2D>(),collider).distance;
            Check(frontContact>=originalContact-.001f,"NPC contact exceeds official baseline");float frontY=Player.transform.position.y;Check(frontY<.65f&&Mathf.Abs(frontY-originalBlockedY)<.002f,"NPC blocking differs from official baseline");await Capture("player-in-front");
            await Walk(new Vector2(-9,frontY));await Walk(new Vector2(-9,2));await Walk(new Vector2(-8,2));Input(Key.S);await Wait(.35f);Input();await Wait(.15f);
            Check(heroBody.sortingOrder<Visual.sortingOrder,"Behind sorting reversed");float backContact=Physics2D.Distance(Player.GetComponent<Collider2D>(),collider).distance;Check(backContact>=originalContact-.001f,"Back contact exceeds official baseline");float backY=Player.transform.position.y;Check(backY>1.35f,"NPC back did not block approach");await Capture("player-behind");
            await Place(new Vector2(-1.8f,3));await Tap(Key.E);Check(World.DialogueOpen&&Journey.Message.StartsWith("Orin:"),"Orin identity/interaction changed");await Capture("orin-unchanged-dialogue");await Tap(Key.E);
            World.SaveOrThrow();Journey.SaveOrThrow();Journey.FlushPersistenceOrThrow();var facts=Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x).ToArray();string identity=LocalJourneyProfile.IdentityId;
            await Tap(Key.F5);await Wait(.7f);Check(SceneManager.GetActiveScene().path==Scene&&identity==LocalJourneyProfile.IdentityId,"F5 scene/profile changed");Check(facts.SequenceEqual(Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x)),"Facts changed/duplicated on reload");Check(Visual.sprite.name=="pose_006"&&Player.State.IsAlive,"Return lost outfit/hero");
            await Place(new Vector2(-6.8f,.5f));await Capture("returned-to-experiment");Check(Time.frameCount>first,"Play frames frozen");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,profileIsolated=true,realGameCaptures=true,miradialogue=true,orinDialogue=true,frontCollisionY=frontY,backCollisionY=backY,originalContact,frontContact,backContact,contactComparedToOfficial=true,frontBehindSorting=true,saveLoadF5=true,identityAndFactsRetained=true,garmentDirectionsInspected=4,backpackDirectionsInspected=4,poseInspectionFrames=8,secondaryClothAnimation=false,staticNpcBehaviorRetained=true},Formatting.Indented);File.WriteAllText(Evidence+"qa.json",json);return json;
        }
        finally{Input();if(World.DialogueOpen)World.CloseDialogue();}
    }
}
