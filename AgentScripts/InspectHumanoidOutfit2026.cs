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

public static class InspectHumanoidOutfit2026
{
    const string Evidence="Docs/Validation/HumanoidOutfit2026/gameplay/";
    static ActorHealth Player=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
    static ProductionSpriteAnimator Animator=>Player.GetComponent<ProductionSpriteAnimator>();
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
    static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    public static string Prepare()
    {
        if(EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity")throw new Exception("Clean R5 scene required");
        Directory.CreateDirectory(Evidence);SessionState.SetString("b11-evidence",Evidence);
        SessionState.SetBool("b11-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("b11-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("b11-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("b11-editor-input",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        return "R5 QA prepared; automatic Editor guard selects isolated outfit profile.";
    }
    public static async Task<string> Inspect()
    {
        Directory.CreateDirectory(Evidence);Check(LocalJourneyProfile.Root.Contains("Temp"),"Preview profile must be isolated");
        int first=Time.frameCount;
        var original=UnityEditor.AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");
        var candidate=UnityEditor.AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidOutfit2026/ValdoriaSwordsman.asset");
        Check(original.clips.Select(c=>c.Duration).SequenceEqual(candidate.clips.Select(c=>c.Duration)),"Clip cadence differs");
        Check(Animator.CurrentFrame.sprite.texture.name=="ValdoriaSwordsman","Wrong player appearance");
        var report=new System.Collections.Generic.List<object>();
        try
        {
            foreach(var c in new[]{new{key=Key.S,d=0},new{key=Key.A,d=1},new{key=Key.W,d=2},new{key=Key.D,d=3}})
            {
                var rb=Player.GetComponent<Rigidbody2D>();rb.position=new Vector2(-5.5f,0);rb.linearVelocity=Vector2.zero;Input();await Wait(.15f);
                Vector2 before=rb.position;Input(c.key);await Wait(.23f);
                Check(Animator.State=="walk"&&Animator.DirectionIndex==c.d,"Wrong movement animation/direction: "+Animator.State+" dir="+Animator.DirectionIndex+" wanted="+c.d+" velocity="+rb.linearVelocity+" intent="+Player.GetComponent<ActorMotor>().MovementDirection);
                int index=int.Parse(Animator.Body.sprite.name.Substring(5));
                int[] starts={1,40,27,14};
                Check(index>=starts[c.d]&&index<starts[c.d]+12,"Incorrect source view for world direction");
                string pose=Animator.Body.sprite.name;await Wait(.12f);Check(Animator.Body.sprite.name!=pose,"Walk frame did not advance");
                float distance=Vector2.Distance(before,rb.position);Check(distance>.4f,"Player did not move");
                await Capture("walk-"+c.d);Input();await Wait(.2f);Check(Animator.State=="idle"&&rb.linearVelocity.sqrMagnitude<.001f,"Stop failed");
                report.Add(new{direction=c.d,distance,animated=true,idleAfterRelease=true,sourceViewCorrect=true});
            }
            var body=Player.GetComponent<Rigidbody2D>();body.position=new Vector2(-5.5f,0);body.linearVelocity=Vector2.zero;Input(Key.W,Key.D);await Wait(.25f);
            Check(Player.GetComponent<ActorMotor>().MovementDirection.x>0&&Player.GetComponent<ActorMotor>().MovementDirection.y>0,"Diagonal intent failed");Input();await Wait(.2f);
            body.position=new Vector2(-5.5f,0);body.linearVelocity=Vector2.zero;await Wait(.3f);await Capture("controllable-player");
            // Real keyboard movement on the road in front of houses, then near the tree line.
            foreach(var location in new[]{new Vector2(-5.5f,0),new Vector2(-7f,-3.5f)})
            {
                body.position=location;body.linearVelocity=Vector2.zero;Input();await Wait(.2f);Input(Key.D);await Wait(.25f);Input();await Wait(.2f);
                Check(Vector2.Distance(body.position,location)>.3f,"Environment route blocked");await Capture(location.y==0?"houses-road":"near-trees");
            }
            var tree=GameObject.Find("TreeWest").GetComponentsInChildren<SpriteRenderer>().Single(s=>s.name=="ProvidedTree");
            body.position=new Vector2(-6,-3.5f);body.linearVelocity=Vector2.zero;await Wait(.25f);Check(Animator.Body.sortingOrder<tree.sortingOrder,"Tree behind occlusion failed");await Capture("tree-behind");
            body.position=new Vector2(-6,-5.5f);body.linearVelocity=Vector2.zero;await Wait(.25f);Check(Animator.Body.sortingOrder>tree.sortingOrder,"Tree front occlusion failed");await Capture("tree-front");
            var render=Player.GetComponent<SpriteRenderer>();var world=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();
            Check(Camera.main!=null&&UnityEngine.Object.FindObjectsByType<Canvas>().Any(c=>c.isActiveAndEnabled),"Camera/HUD missing");
            // Compare physical adapters against approved scene, excluding Unity instance IDs.
            string motor=EditorJsonUtility.ToJson(Player.GetComponent<ActorMotor>()),collider=EditorJsonUtility.ToJson(Player.GetComponent<Collider2D>());
            var cameraSize=Camera.main.orthographicSize;int canvases=UnityEngine.Object.FindObjectsByType<Canvas>().Count(c=>c.isActiveAndEnabled);
            Func<string,string> norm=x=>System.Text.RegularExpressions.Regex.Replace(x,"\"instanceID\":-?[0-9]+","\"instanceID\":0");
            UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/HumanoidScale2026.unity");await Wait(.5f);
            Check(norm(motor)==norm(EditorJsonUtility.ToJson(Player.GetComponent<ActorMotor>()))&&norm(collider)==norm(EditorJsonUtility.ToJson(Player.GetComponent<Collider2D>())),"Physical adapter changed");
            Check(Camera.main.orthographicSize==cameraSize&&UnityEngine.Object.FindObjectsByType<Canvas>().Count(c=>c.isActiveAndEnabled)==canvases,"Camera/HUD changed");
            UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity");await Wait(.5f);
            body=Player.GetComponent<Rigidbody2D>();body.position=new Vector2(-5.5f,2.7f);body.linearVelocity=Vector2.zero;await Wait(.3f);await Capture("beside-npcs");
            // Contact sorting around Mira; placement isolates the check from navigation obstacles.
            var npc=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Interactions.Single(i=>i.Kind==Mmorpg.Runtime.InteractionKind.Mira);var visual=npc.GetComponent<SpriteRenderer>();Vector2 np=npc.transform.position;
            body.position=np+Vector2.down*1.3f;body.linearVelocity=Vector2.zero;await Wait(.15f);Input(Key.W);await Wait(.4f);Input();await Wait(.15f);Check(Animator.Body.sortingOrder>visual.sortingOrder,"Front occlusion reversed");await Capture("npc-front");
            body.position=np+Vector2.up*.95f;body.linearVelocity=Vector2.zero;await Wait(.15f);Input(Key.S);await Wait(.25f);Input();await Wait(.15f);Check(Animator.Body.sortingOrder<visual.sortingOrder,"Back occlusion reversed");await Capture("npc-behind");
            world=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();world.SaveOrThrow();var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();journey.SaveOrThrow();journey.FlushPersistenceOrThrow();string identity=LocalJourneyProfile.IdentityId;
            Input(Key.F5);await Wait(.07f);Input();await Wait(.6f);Check(LocalJourneyProfile.IdentityId==identity&&UnityEngine.SceneManagement.SceneManager.GetActiveScene().path.EndsWith("HumanoidOutfit2026.unity")&&Animator.CurrentFrame.sprite.texture.name=="ValdoriaSwordsman","Reload lost profile/outfit");
            body=Player.GetComponent<Rigidbody2D>();body.position=new Vector2(-5.5f,0);body.linearVelocity=Vector2.zero;await Wait(.3f);await Capture("after-f5");
            Check(!Player.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.activeInHierarchy,"Uncalibrated weapon visible");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,isolatedProfile=true,directions=report,diagonalInput=true,originalMotor=true,movementOnly=true,weaponHidden=true,physicalAdaptersIdentical=true,cameraHudIdentical=true,saveLoad=true,frontBackNpcOcclusion=true,environmentMovement=true,treeFrontBackOcclusion=true},Formatting.Indented);File.WriteAllText(Evidence+"qa.json",json);return json;
        }
        finally{Input();}
    }
    static async Task Capture(string name)
    {
        var done=new TaskCompletionSource<bool>();Player.StartCoroutine(Frame(name,done));Check(await Task.WhenAny(done.Task,Task.Delay(3000))==done.Task,"Capture stalled");await done.Task;
    }
    static System.Collections.IEnumerator Frame(string name,TaskCompletionSource<bool> done)
    {
        yield return new WaitForEndOfFrame();
        try{var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Evidence+name+".png",tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);done.SetResult(true);}catch(Exception e){done.SetException(e);}
    }
}
