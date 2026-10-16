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
public static class InspectHumanoidCombatCandidateR6
{
 const string E="Docs/Validation/HumanoidCombat8Dir2026/combat-candidate/",Raw="Temp/HumanoidR6/CombatFrames/";
 static ActorHealth Player=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
 static ProductionSpriteAnimator Animator=>Player.GetComponent<ProductionSpriteAnimator>();
 static SwordSwing Sword=>Player.GetComponent<SwordSwing>();
 static OfflineAuthority Authority=>UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
 static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
 static Mouse MouseDevice=>InputSystem.devices.OfType<Mouse>().Single(k=>k.name=="AnimationMouse");
 static void Input(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
 static void Aim(Vector2 d,int buttons=0)=>InputSystem.QueueStateEvent(MouseDevice,new MouseState{position=Camera.main.WorldToScreenPoint((Vector2)Player.transform.position+d*3),buttons=(ushort)buttons});
 static void Check(bool p,string s){if(!p)throw new Exception(s);}
 static async Task Wait(float seconds){double end=Time.timeAsDouble+seconds;while(Time.timeAsDouble<end)await Task.Delay(5);}
 static async Task Reset(){Input();Aim(Vector2.down);while(Sword.Busy)await Task.Delay(5);Player.Configure(Faction.Player);var rb=Player.GetComponent<Rigidbody2D>();rb.simulated=true;rb.position=new Vector2(-2.75f,0);rb.linearVelocity=Vector2.zero;await Wait(.15f);}
 static async Task<List<object>> Trace(string name,float seconds)
 {
  var rows=new List<object>();var done=new TaskCompletionSource<bool>();Player.StartCoroutine(Record(name,seconds,rows,done));Check(await Task.WhenAny(done.Task,Task.Delay(20000))==done.Task,"Trace stalled");await done.Task;File.WriteAllText(E+name+".json",JsonConvert.SerializeObject(rows));return rows;
 }
 static System.Collections.IEnumerator Record(string name,float seconds,List<object> rows,TaskCompletionSource<bool> done)
 {
  double end=Time.timeAsDouble+seconds,next=-1;int index=0;
  while(Time.timeAsDouble<end)
  {
   yield return new WaitForEndOfFrame();
   try{
    float error=Vector3.Distance(Sword.GripWorld,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand));
    rows.Add(new{time=Time.timeAsDouble,frame=Time.frameCount,state=Animator.State,phase=Sword.VisualPhase,active=Sword.Active,direction=Animator.DirectionIndex,source=Animator.CurrentFrame.source,handError=error,bladeLength=Sword.BladeLength,visualAngle=Sword.VisualAngle});
    if(Time.timeAsDouble>=next){var tex=ScreenCapture.CaptureScreenshotAsTexture();string path=Raw+name+"-"+(index++).ToString("000")+".png";File.WriteAllBytes(path,tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);var point=Camera.main.WorldToScreenPoint(Player.transform.position);File.AppendAllText(E+"captures.jsonl",JsonConvert.SerializeObject(new{name,path,frame=Time.frameCount,time=Time.timeAsDouble,playerPixel=new[]{point.x,Screen.height-point.y},screen=new[]{Screen.width,Screen.height}})+"\n");next=Time.timeAsDouble+.05;}
   }catch(Exception e){done.SetException(e);yield break;}
  }
  done.SetResult(true);
 }
 public static async Task<string> NearSweepStudy()
 {
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Time.timeScale=.4f;
  var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidCombat8Dir2026/ValdoriaCombatCandidate.asset");Animator.Configure(set,Player,Animator.Body,Sword);Player.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword").gameObject.SetActive(true);
  await Reset();var target=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;Vector3 saved=target.transform.position;target.Configure(Faction.Training);target.transform.position=Player.transform.position+Vector3.right*.85f;Physics2D.SyncTransforms();int hp=target.State.Health,hits=0;var samples=new List<object>();
  Action<ActorHealth,ActorHealth> hit=(a,b)=>{if(a==Player&&b==target)hits++;};Action<Vector2,Vector2> sweep=(h,t)=>samples.Add(new{time=Time.timeAsDouble,frame=Time.frameCount,hand=new[]{h.x,h.y},tip=new[]{t.x,t.y},target=new[]{target.transform.position.x,target.transform.position.y},phase=Sword.VisualPhase});
  Authority.HitConfirmed+=hit;Sword.SweepSampled+=sweep;
  try{Input(Key.F7);await Wait(.03f);Input();Aim(Vector2.right);await Wait(.05f);Aim(Vector2.right,1);await Trace("near-sweep-study",.55f);Aim(Vector2.right);string json=JsonConvert.SerializeObject(new{expectedDamage=20,actualDamage=hp-target.State.Health,expectedHitCount=1,actualHitCount=hits,passed=hits==1&&hp-target.State.Health==20,samples},Formatting.Indented);File.WriteAllText(E+"near-sweep-failure.json",json);return json;}
  finally{Authority.HitConfirmed-=hit;Sword.SweepSampled-=sweep;target.transform.position=saved;Input();Aim(Vector2.down);Time.timeScale=1;}
 }
 public static async Task<string> LegacyR5()
 {
  Input();Time.timeScale=1;UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity");await Wait(.5f);
  var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidOutfit2026/ValdoriaSwordsman.asset");Check(!set.eightDirectionPresentation,"R5 opted into eight directions unexpectedly");var result=new List<object>();
  try{for(int d=0;d<4;d++){var rb=Player.GetComponent<Rigidbody2D>();rb.position=new Vector2(-5.5f,0);rb.linearVelocity=Vector2.zero;Input();await Wait(.15f);Input(new[]{Key.S,Key.A,Key.W,Key.D}[d]);await Wait(.2f);Check(Animator.State=="walk"&&Animator.DirectionIndex==d,"R5 cardinal walk changed");result.Add(new{direction=d,speed=rb.linearVelocity.magnitude});Input();await Wait(.15f);Check(Animator.State=="idle"&&Animator.DirectionIndex==d,"R5 idle changed");}string json=JsonConvert.SerializeObject(result,Formatting.Indented);File.WriteAllText("Docs/Validation/HumanoidCombat8Dir2026/legacy-r5.json",json);return json;}
  finally{Input();}
 }
 public static async Task<string> WalkStudy()
 {
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Time.timeScale=.5f;
  try{for(int d=0;d<8;d++){await Reset();Vector2 v=ProductionDirections.Vector(d);var keys=new List<Key>();if(v.x<0)keys.Add(Key.A);if(v.x>0)keys.Add(Key.D);if(v.y<0)keys.Add(Key.S);if(v.y>0)keys.Add(Key.W);Input(keys.ToArray());await Trace("weapon-walk-"+d,.7f);Input();}return "Captured walking attachment study in all eight directions; not a passed combat gate.";}
  finally{Input();Aim(Vector2.down);Time.timeScale=1;}
 }
 public static async Task<string> Inspect()
 {
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Check(LocalJourneyProfile.Root.Contains("Temp/HumanoidR6")||LocalJourneyProfile.Root.Contains("Temp\\HumanoidR6"),"Isolated profile required");int first=Time.frameCount;Time.timeScale=.4f;var reports=new List<object>();
  try{
   for(int heavy=0;heavy<2;heavy++)for(int d=0;d<8;d++)
   {
    await Reset();await Wait((float)Player.GetComponent<ActionCombat>().HeavyRemaining+.05f);var direction=ProductionDirections.Vector(d);Aim(direction);await Wait(.05f);Aim(direction,heavy==0?1:2);
    await Trace((heavy==0?"basic-":"heavy-")+d,heavy==0?.48f:.8f);Aim(direction);
    reports.Add(new{heavy=heavy==1,direction=d});
   }
   // A moving strike keeps confirmed aim even opposite to the movement intention.
   await Reset();Input(Key.D);Aim(Vector2.left);await Wait(.15f);Aim(Vector2.left,1);await Trace("moving-opposite-aim",.5f);Input();Aim(Vector2.left);
   // Confirmed damage produces one reaction; immunity/friendly refusal produces none.
   await Reset();var states=Player.GetComponent<ProductionCharacterStates>();int before=states.ConfirmedReactions;var attacker=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;
   var method=typeof(OfflineAuthority).GetMethod("ResolveDamage",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
   Check((bool)method.Invoke(Authority,new object[]{attacker,Player,ActionStrike.Wolf,null}),"Confirmed fixture damage refused");Check(!(bool)method.Invoke(Authority,new object[]{attacker,Player,ActionStrike.Wolf,null}),"Immunity damage accepted");Check(!(bool)method.Invoke(Authority,new object[]{Player,Player,ActionStrike.Wolf,null}),"Friendly damage accepted");await Trace("hurt-confirmed",.6f);Check(states.ConfirmedReactions==before+1,"Hurt duplicated or missing");
   string json=JsonConvert.SerializeObject(new{first,last=Time.frameCount,actions=reports,basicDirections=8,heavyDirections=8,heavyReusesBasicDrawings=true,damageImmunity=true,singleHurtNotification=true,rollAndDeathNotIntegrated=true},Formatting.Indented);File.WriteAllText(E+"qa.json",json);return json;
  }finally{Input();Aim(Vector2.down);Time.timeScale=1;}
 }
}
