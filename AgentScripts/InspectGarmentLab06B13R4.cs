using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;

public static class InspectGarmentLab06B13R4
{
    const string Scene="Assets/Mmorpg/Scenes/Marco06B13R4NpcWardrobe.unity";
    const string Evidence="Docs/Validation/Marco06B13R4/gameplay/";
    const string Art="Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R4/";
    static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    static ExplorationWorld World=>UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
    static ActorHealth Player=>Journey.Player;
    static JourneyInteractable Npc(InteractionKind kind)=>Journey.Interactions.Single(i=>i.Kind==kind);
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
    static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static async Task Wait(float seconds){double until=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<until)await Task.Delay(10);}
    static async Task Tap(Key key){Input(key);await Wait(.07f);Input();await Wait(.15f);}
    static async Task Place(Vector2 position)
    {
        Input();var rb=Player.GetComponent<Rigidbody2D>();rb.position=position;rb.linearVelocity=Vector2.zero;await Wait(.35f);
        var pointer=InputSystem.devices.OfType<Mouse>().Single(d=>d.name=="AnimationMouse");
        InputSystem.QueueStateEvent(pointer,new MouseState{position=Camera.main.WorldToScreenPoint(Player.transform.position+Vector3.right*3)});await Wait(.1f);
    }
    static async Task Walk(Vector2 target)
    {
        double until=Time.realtimeSinceStartupAsDouble+4;
        while(Vector2.Distance(Player.GetComponent<Rigidbody2D>().position,target)>.15f)
        {
            Check(Time.realtimeSinceStartupAsDouble<until,"Walking route blocked: "+target);
            var delta=target-Player.GetComponent<Rigidbody2D>().position;var keys=new List<Key>();
            if(Mathf.Abs(delta.x)>.09f)keys.Add(delta.x>0?Key.D:Key.A);if(Mathf.Abs(delta.y)>.09f)keys.Add(delta.y>0?Key.W:Key.S);
            Input(keys.ToArray());await Wait(.02f);
        }
        Input();await Wait(.1f);
    }
    public static string Prepare()
    {
        Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty&&SceneManager.GetActiveScene().path==Scene,"Clean R4 scene required");
        Directory.CreateDirectory(Evidence);SessionState.SetString("b11-evidence",Evidence);
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string root=Path.GetFullPath("Temp/Marco06B13R4/Profile-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(root);LocalJourneyProfile.ValidationRootOverride=root;
        return "Isolated R4 profile configured before Play; reuse B11 Setup and Cleanup.";
    }
    static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>();Player.StartCoroutine(Frame(name,done));Check(await Task.WhenAny(done.Task,Task.Delay(3000))==done.Task,"GameView capture stalled");await done.Task;
    }
    static System.Collections.IEnumerator Frame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try
        {
            var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+name+".png",tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);
            File.AppendAllText(Evidence+"captures.jsonl",JsonConvert.SerializeObject(new{name,frame=Time.frameCount,player=Player.transform.position.ToString("R"),camera=Camera.main.transform.position.ToString("R"),width=Screen.width,height=Screen.height})+"\n");done.SetResult(true);
        }catch(Exception e){done.SetException(e);}
    }
    public static async Task<string> Inspect()
    {
        Check(LocalJourneyProfile.ValidationRootOverride!=null&&LocalJourneyProfile.Root.Contains("Temp"),"Isolated profile required");int first=Time.frameCount;
        var baselines=new Dictionary<InteractionKind,float>();var positions=new Dictionary<InteractionKind,float>();var reports=new List<object>();
        var kinds=new[]{InteractionKind.Mira,InteractionKind.Orin};int baselineCanvases=0;float baselineZoom=0;
        try
        {
            SceneManager.LoadScene(0);await Wait(.7f);baselineCanvases=UnityEngine.Object.FindObjectsByType<Canvas>().Count(c=>c.isActiveAndEnabled);baselineZoom=Camera.main.orthographicSize;
            foreach(var kind in kinds)
            {
                Vector2 p=Npc(kind).transform.position;await Place(p+new Vector2(-1.2f,-.5f));await Capture(kind.ToString().ToLowerInvariant()+"-official");
                await Place(p+Vector2.down*1.3f);Input(Key.W);await Wait(.5f);Input();await Wait(.15f);
                baselines[kind]=Physics2D.Distance(Player.GetComponent<Collider2D>(),Npc(kind).GetComponent<Collider2D>()).distance;positions[kind]=Player.transform.position.y;
            }
            SceneManager.LoadScene(Scene);await Wait(.7f);
            foreach(var kind in kinds)
            {
                string name=kind.ToString().ToLowerInvariant();string outfit=kind==InteractionKind.Mira?"MiraHealer":"OrinTracker";
                var npc=Npc(kind);Vector2 p=npc.transform.position;var visual=npc.GetComponent<SpriteRenderer>();var collider=npc.GetComponent<BoxCollider2D>();
                Check(visual.sprite.name=="pose_006"&&visual.sprite.pixelsPerUnit==32&&visual.sprite.pivot==new Vector2(32,20),"Sprite contract changed");
                Check(collider.size==new Vector2(.5f,.6f)&&collider.offset==Vector2.zero&&!collider.autoTiling,"Collider changed");
                await Place(p+new Vector2(-1.2f,-.5f));await Capture(name+"-r4");
                // Approach on the right: Helena's existing interaction is closer on Mira's left.
                await Place(p+new Vector2(1.2f,-.5f));
                await Tap(Key.E);Check(World.DialogueOpen&&Journey.Message.StartsWith(kind+":"),"Wrong NPC dialogue");await Capture(name+"-dialogue");await Tap(Key.E);Check(!World.DialogueOpen,"Dialogue stuck");
                await Place(p+new Vector2(-1.2f,-.5f));
                var sprites=AssetDatabase.LoadAllAssetsAtPath(Art+outfit+".png").OfType<Sprite>().ToDictionary(s=>s.name);
                foreach(var view in new[]{new{direction="south",idle=6,walk=28},new{direction="west",idle=3,walk=20},new{direction="north",idle=0,walk=12},new{direction="east",idle=9,walk=36}})
                {
                    visual.sprite=sprites["pose_"+view.idle.ToString("000")];await Wait(.125f);await Capture(name+"-"+view.direction);
                    for(int cycle=0;cycle<2;cycle++)for(int i=0;i<8;i++){visual.sprite=sprites["pose_"+(view.walk+i).ToString("000")];await Wait(.125f);}
                    await Capture(name+"-walk-"+view.direction);
                }
                visual.sprite=sprites["pose_006"];
                await Place(p+Vector2.down*1.3f);Input(Key.W);await Wait(.5f);Input();await Wait(.15f);
                float front=Physics2D.Distance(Player.GetComponent<Collider2D>(),collider).distance;float frontY=Player.transform.position.y;
                Check(front>=baselines[kind]-.001f&&Mathf.Abs(frontY-positions[kind])<.002f,"Front collision differs from official");
                var hero=Player.GetComponent<ProductionSpriteAnimator>().Body;Check(hero.sortingOrder>visual.sortingOrder,"Front sorting reversed");await Capture(name+"-front");
                // Orin has a rock west and his house starts at y=4. Use the narrow clear gap.
                float side=kind==InteractionKind.Orin?1:-1;
                await Walk(new Vector2(p.x+side,frontY));await Walk(p+new Vector2(side,.8f));await Walk(p+Vector2.up*.8f);Input(Key.S);await Wait(.35f);Input();await Wait(.15f);
                float back=Physics2D.Distance(Player.GetComponent<Collider2D>(),collider).distance;
                Check(hero.sortingOrder<visual.sortingOrder&&Player.transform.position.y>p.y+.35f,"Behind sorting/blocking failed");Check(back>=baselines[kind]-.001f,"Back collision exceeds baseline");await Capture(name+"-behind");
                reports.Add(new{character=kind.ToString(),idleDirections=4,walkDirections=4,walkFramesInspected=32,cyclesEach=2,dialogue=true,originalContact=baselines[kind],frontContact=front,backContact=back,frontBehindSorting=true,colliderPreserved=true});
            }
            await Place(new Vector2(-5.5f,1.4f));await Wait(.5f);await Capture("both-with-iron-knight");
            Check(UnityEngine.Object.FindObjectsByType<Canvas>().Count(c=>c.isActiveAndEnabled)==baselineCanvases&&Camera.main.orthographicSize==baselineZoom,"HUD/camera contract changed");
            World.SaveOrThrow();Journey.SaveOrThrow();Journey.FlushPersistenceOrThrow();string identity=LocalJourneyProfile.IdentityId;
            var facts=Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x).ToArray();
            await Tap(Key.F5);await Wait(.7f);Check(SceneManager.GetActiveScene().path==Scene&&identity==LocalJourneyProfile.IdentityId,"F5 scene/profile failed");
            Check(facts.SequenceEqual(Journey.Engine.Snapshot().facts.Select(f=>f.eventId).OrderBy(x=>x)),"Facts changed or duplicated");
            Check(kinds.All(k=>Npc(k).GetComponent<SpriteRenderer>().sprite.name=="pose_006")&&Player.State.IsAlive,"Reload lost outfits/player");
            await Place(new Vector2(-5.5f,1.4f));await Wait(.5f);await Capture("after-f5");Check(Time.frameCount>first,"Frames frozen");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,isolatedProfile=true,realGameCaptures=true,characters=reports,hudAndCameraPreserved=true,saveLoadF5=true,identityAndFactsRetained=true,staticNpcBehaviorRetained=true,clothSimulation=false,runtimeEquipment=false},Formatting.Indented);
            File.WriteAllText(Evidence+"qa.json",json);return json;
        }
        finally{Input();if(World.DialogueOpen)World.CloseDialogue();}
    }
}
