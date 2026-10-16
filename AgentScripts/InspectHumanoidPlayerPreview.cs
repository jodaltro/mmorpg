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

public static class InspectHumanoidPlayerPreview
{
    const string Evidence="Docs/Validation/HumanoidScale2026/player-direction-fix/";
    static ActorHealth Player=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
    static ProductionSpriteAnimator Animator=>Player.GetComponent<ProductionSpriteAnimator>();
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
    static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    public static async Task<string> Inspect()
    {
        Directory.CreateDirectory(Evidence);Check(LocalJourneyProfile.Root.Contains("Temp"),"Preview profile must be isolated");
        int first=Time.frameCount;var report=new System.Collections.Generic.List<object>();
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
            Check(!Player.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.activeInHierarchy,"Uncalibrated weapon visible");
            string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,isolatedProfile=true,directions=report,diagonalInput=true,originalMotor=true,movementOnly=true,weaponHidden=true},Formatting.Indented);File.WriteAllText(Evidence+"qa.json",json);return json;
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
