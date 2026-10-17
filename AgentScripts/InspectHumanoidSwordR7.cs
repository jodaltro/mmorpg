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
public static class InspectHumanoidSwordR7
{
 static string E="Docs/Validation/HumanoidSwordR7/";
 const string Raw="Temp/HumanoidR7/CombatFrames/";
 static bool debugCapture;
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
    rows.Add(new{time=Time.timeAsDouble,frame=Time.frameCount,state=Animator.State,phase=Sword.VisualPhase,active=Sword.Active,direction=Animator.DirectionIndex,source=Animator.CurrentFrame.source,handError=error,bladeLength=Sword.BladeLength,visualAngle=Sword.VisualAngle,root=Player.GetComponent<Rigidbody2D>().position.ToString("R"),velocity=Player.GetComponent<Rigidbody2D>().linearVelocity.ToString("R"),confirmedAim=Sword.AttackDirection.ToString("R"),physicalOrigin=Sword.PhysicalOriginWorld.ToString("R"),physicalRange=Sword.AuthorizedRange,depth=Animator.CurrentFrame.depth,bodySorting=Animator.Body.sortingOrder,bladeSorting=Player.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword").sortingOrder,tipSeparation=Player.GetComponent<SwordSweepDebug>().MaximumActiveTipError});
    if(Time.timeAsDouble>=next){var tex=ScreenCapture.CaptureScreenshotAsTexture();string path=Raw+name+"-"+(index++).ToString("000")+".png";File.WriteAllBytes(path,tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);var point=Camera.main.WorldToScreenPoint(Player.transform.position);File.AppendAllText(E+"captures.jsonl",JsonConvert.SerializeObject(new{name,path,frame=Time.frameCount,time=Time.timeAsDouble,playerPixel=new[]{point.x,Screen.height-point.y},screen=new[]{Screen.width,Screen.height}})+"\n");next=Time.timeAsDouble+.05;}
   }catch(Exception e){done.SetException(e);yield break;}
  }
  done.SetResult(true);
 }
 // Single physical origin now: the planar/legacy toggle no longer exists.
 public static async Task<string> NearSweepStudy()
 {
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Time.timeScale=.4f;
  var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidCombat8Dir2026/ValdoriaCombatCandidate.asset");Animator.Configure(set,Player,Animator.Body,Sword);Player.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword").gameObject.SetActive(true);
   await Reset();var target=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;Vector3 saved=target.transform.position;target.Configure(Faction.Training);target.transform.position=Player.transform.position+Vector3.right*.85f;Physics2D.SyncTransforms();int hp=target.State.Health,hits=0;var samples=new List<object>();
  Action<ActorHealth,ActorHealth> hit=(a,b)=>{if(a==Player&&b==target)hits++;};Action<Vector2,Vector2> sweep=(h,t)=>samples.Add(new{time=Time.timeAsDouble,frame=Time.frameCount,hand=new[]{h.x,h.y},tip=new[]{t.x,t.y},target=new[]{target.transform.position.x,target.transform.position.y},phase=Sword.VisualPhase,root=Player.GetComponent<Rigidbody2D>().position.ToString("R"),visualHand=Sword.GripWorld.ToString("R"),targetBounds=target.GetComponent<Collider2D>().bounds.ToString(),rootLos=Authority.HasLineOfSight(Player.transform.position,target.transform.position),gripLos=Authority.HasLineOfSight(h,target.transform.position),overlaps=Physics2D.OverlapCapsuleAll((h+t)*.5f,new Vector2(Vector2.Distance(h,t)+.16f,.16f),CapsuleDirection2D.Horizontal,Mathf.Atan2(t.y-h.y,t.x-h.x)*Mathf.Rad2Deg,1<<9).Any(c=>c.GetComponentInParent<ActorHealth>()==target)});
  Authority.HitConfirmed+=hit;Sword.SweepSampled+=sweep;
  try{Input(Key.F7);await Wait(.03f);Input();Aim(Vector2.right);await Wait(.05f);Aim(Vector2.right,1);await Trace("near-sweep-study",.55f);Aim(Vector2.right);string json=JsonConvert.SerializeObject(new{expectedDamage=20,actualDamage=hp-target.State.Health,expectedHitCount=1,actualHitCount=hits,passed=hits==1&&hp-target.State.Health==20,samples},Formatting.Indented);File.WriteAllText(E+"near-gate.json",json);return "damage="+(hp-target.State.Health)+", hits="+hits+", origin=actorRoot";}
  finally{Authority.HitConfirmed-=hit;Sword.SweepSampled-=sweep;target.transform.position=saved;Input();Aim(Vector2.down);Time.timeScale=1;}
 }
 public static async Task<string> LegacyR5()
 {
  Input();Time.timeScale=1;UnityEngine.SceneManagement.SceneManager.LoadScene("Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity");await Wait(.5f);
  var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidOutfit2026/ValdoriaSwordsman.asset");Check(!set.eightDirectionPresentation,"R5 opted into eight directions unexpectedly");var result=new List<object>();
  try{for(int d=0;d<4;d++){var rb=Player.GetComponent<Rigidbody2D>();rb.position=new Vector2(-5.5f,0);rb.linearVelocity=Vector2.zero;Input();await Wait(.15f);Input(new[]{Key.S,Key.A,Key.W,Key.D}[d]);await Wait(.2f);Check(Animator.State=="walk"&&Animator.DirectionIndex==d,"R5 cardinal walk changed");result.Add(new{direction=d,speed=rb.linearVelocity.magnitude});Input();await Wait(.15f);Check(Animator.State=="idle"&&Animator.DirectionIndex==d,"R5 idle changed");}string json=JsonConvert.SerializeObject(result,Formatting.Indented);File.WriteAllText("Docs/Validation/HumanoidSwordR7/legacy-r5.json",json);return json;}
  finally{Input();}
 }
 public static async Task<string> WalkStudy()
 {
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Time.timeScale=.5f;
  try{for(int d=0;d<8;d++){await Reset();Vector2 v=ProductionDirections.Vector(d);var keys=new List<Key>();if(v.x<0)keys.Add(Key.A);if(v.x>0)keys.Add(Key.D);if(v.y<0)keys.Add(Key.S);if(v.y>0)keys.Add(Key.W);Input(keys.ToArray());await Trace("weapon-walk-"+d,.7f);Input();}return "Eight-direction walking attachment captures recorded; physical results are in matrix files.";}
  finally{Input();Aim(Vector2.down);Time.timeScale=1;}
 }
 public static async Task<string> Matrix(string scenario="basic",string evidenceFolder=null)
 {
  if(evidenceFolder!=null)E=evidenceFolder;
  Directory.CreateDirectory(E);Directory.CreateDirectory(Raw);Time.timeScale=.65f;
  var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();bool dummyEnabled=dummy.enabled;dummy.enabled=false;var target=dummy.Health;Vector3 saved=target.transform.position;var rows=new List<object>();GameObject wall=null;
  try{for(int d=0;d<8;d++){
   await Reset();await Wait((float)Player.GetComponent<ActionCombat>().HeavyRemaining+.02f);Vector2 direction=ProductionDirections.Vector(d),root=Player.GetComponent<Rigidbody2D>().position;
   if(scenario=="continuous")direction=(Vector2)(Quaternion.Euler(0,0,13)*(Vector3)direction);
   target.Configure(scenario=="friendly"?Faction.Player:Faction.Training);target.transform.position=root+direction*(scenario=="outside"?1.9f:scenario=="heavy-outside"?2.2f:scenario=="wall"||scenario=="wall-control"?1.3f:scenario=="heavy-reach"?1.6f:.85f);
   if(scenario=="dead-target")target.State.TryDamage(target.State.Health,Time.timeAsDouble,0);
   if(scenario=="wall"){wall=new GameObject("R7 LOS fixture");wall.layer=8;wall.transform.position=root+direction*.65f;wall.transform.rotation=Quaternion.Euler(0,0,Mathf.Atan2(direction.y,direction.x)*Mathf.Rad2Deg);wall.AddComponent<BoxCollider2D>().size=new Vector2(.08f,3);}
   Physics2D.SyncTransforms();int hp=target.State.Health,hits=0,attacks=0,samples=0;double firstHit=-1,begin=-1;var sampleRows=new List<object>();var phases=new HashSet<string>();float gripError=0;bool cancelled=false,rejectedCooldown=false,rejectedDodge=false;
   Action<ActorHealth,ActorHealth> onHit=(a,b)=>{if(a==Player&&b==target){hits++;if(firstHit<0)firstHit=Time.timeAsDouble;}};
   Action<ActorHealth,Vector2> onAttack=(a,v)=>{if(a==Player){attacks++;begin=Time.timeAsDouble;}};
   Action<Vector2,Vector2> onSweep=(h,t)=>{samples++;sampleRows.Add(new{time=Time.timeAsDouble,root=Player.GetComponent<Rigidbody2D>().position.ToString("R"),origin=h.ToString("R"),tip=t.ToString("R"),direction=Sword.AttackDirection.ToString("R")});};
   Authority.HitConfirmed+=onHit;Authority.AttackPerformed+=onAttack;Sword.SweepSampled+=onSweep;
   try{
    Aim(direction);await Wait(.05f);
    if(scenario=="moving-opposite"){var v=-direction;var keys=new List<Key>();if(v.x<0)keys.Add(Key.A);if(v.x>0)keys.Add(Key.D);if(v.y<0)keys.Add(Key.S);if(v.y>0)keys.Add(Key.W);Input(keys.ToArray());await Wait(.01f);Aim(direction);}
    if(scenario=="dodging"){Check(Authority.RequestDodge(Player),"Dodge fixture rejected");rejectedDodge=!Authority.RequestAttack(Player,direction);}
    else Aim(direction,scenario.StartsWith("heavy")?2:1);
    double until=Time.timeAsDouble+(scenario.StartsWith("heavy")?.82:.5);bool deathSet=false,cooldownChecked=false;
    var recording=Trace((debugCapture?"f7-":"")+scenario+"-"+d,scenario.StartsWith("heavy")?.8f:.48f);
    while(Time.timeAsDouble<until){
     if(Sword.Busy){phases.Add(Sword.VisualPhase);gripError=Mathf.Max(gripError,Vector3.Distance(Sword.GripWorld,Animator.Body.transform.TransformPoint(Animator.CurrentFrame.hand)));}
     if(begin>=0&&scenario=="death-cancel"&&!deathSet&&Time.timeAsDouble-begin>.025){Player.State.TryDamage(Player.State.Health,Time.timeAsDouble,0);deathSet=true;}
     if(begin>=0&&scenario=="cooldown"&&!cooldownChecked&&Time.timeAsDouble-begin>.37){rejectedCooldown=!Authority.RequestAttack(Player,direction);cooldownChecked=true;}
     await Task.Delay(3);
    }
    await recording;cancelled=scenario=="death-cancel"&&!Sword.Busy&&!Player.State.IsAlive;
   }finally{Authority.HitConfirmed-=onHit;Authority.AttackPerformed-=onAttack;Sword.SweepSampled-=onSweep;Input();Aim(direction);}
   int damage=hp-target.State.Health;bool expected=scenario=="basic"||scenario=="continuous"||scenario=="wall-control"||(scenario.StartsWith("heavy")&&scenario!="heavy-outside")||scenario=="cooldown"||scenario=="moving-opposite";int wanted=expected?(scenario.StartsWith("heavy")?36:20):0;float prep=scenario.StartsWith("heavy")?.38f:.06f;
   bool passed=damage==wanted&&hits==(expected?1:0)&&(firstHit<0||firstHit-begin>=prep-.001)&&(scenario!="cooldown"||rejectedCooldown)&&(scenario!="dodging"||rejectedDodge)&&(scenario!="death-cancel"||cancelled);
   rows.Add(new{scenario,direction=d,initialRoot=root.ToString("R"),target=target.transform.position.ToString("R"),targetBounds=target.GetComponent<Collider2D>().bounds.ToString(),expectedDamage=wanted,damage,hits,attacks,begin,firstHit,preparation=prep,active=.14,recovery=.16,samples,phases=phases.ToArray(),preLateUpdateGripSeparation=gripError,policy=Sword.OriginPolicy.ToString(),rejectedCooldown,rejectedDodge,cancelled,passed,sweep=sampleRows});
   File.WriteAllText(E+(debugCapture?"f7-matrix-":"matrix-")+scenario+".json",JsonConvert.SerializeObject(rows,Formatting.Indented));
   if(wall!=null){UnityEngine.Object.Destroy(wall);wall=null;await Wait(.03f);}Check(passed,"Failed "+scenario+" direction "+d+" damage="+damage+" hits="+hits);
  }return scenario+": 8/8 passed";}
  finally{if(wall!=null)UnityEngine.Object.Destroy(wall);target.Configure(Faction.Training);target.transform.position=saved;dummy.enabled=dummyEnabled;Input();Aim(Vector2.down);Time.timeScale=1;}
 }
 public static async Task<string> HurtEight()
 {
  var rows=new List<object>();Time.timeScale=.6f;
  try{for(int d=0;d<8;d++){
   await Reset();var v=ProductionDirections.Vector(d);var keys=new List<Key>();if(v.x<0)keys.Add(Key.A);if(v.x>0)keys.Add(Key.D);if(v.y<0)keys.Add(Key.S);if(v.y>0)keys.Add(Key.W);Input(keys.ToArray());await Wait(.08f);Input();await Wait(.15f);Check(Animator.DirectionIndex==d,"Hurt orientation setup failed");
   var states=Player.GetComponent<ProductionCharacterStates>();int before=states.ConfirmedReactions;var attacker=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>().Health;var method=typeof(OfflineAuthority).GetMethod("ResolveDamage",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
   bool accepted=(bool)method.Invoke(Authority,new object[]{attacker,Player,ActionStrike.Wolf,null}),immune=!(bool)method.Invoke(Authority,new object[]{attacker,Player,ActionStrike.Wolf,null}),friendly=!(bool)method.Invoke(Authority,new object[]{Player,Player,ActionStrike.Wolf,null});await Wait(.02f);Check(Animator.State=="hurt"&&Animator.DirectionIndex==d,"Hurt view failed");await Trace("hurt-"+d,.4f);bool passed=accepted&&immune&&friendly&&states.ConfirmedReactions==before+1;rows.Add(new{direction=d,accepted,immune,friendly,singleReaction=states.ConfirmedReactions==before+1,passed});Check(passed,"Hurt gate failed");
  }File.WriteAllText(E+"hurt-eight.json",JsonConvert.SerializeObject(rows,Formatting.Indented));return "Hurt confirmed in 8 orientations; rejected damage did not react";}finally{Input();Time.timeScale=1;}
 }

 public static async Task<string> DebugStudy()
 {
  var debug=Player.GetComponent<SwordSweepDebug>();bool shown=(bool)typeof(SwordSweepDebug).GetField("shown",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).GetValue(debug);
  if(!shown){Input(Key.F7);await Wait(.02f);Input();}
  debugCapture=true;string result;try{result=await Matrix("basic");}finally{debugCapture=false;}
  Input(Key.F7);await Wait(.02f);Input();return result+"; actual F7 samples captured in all eight views";
 }

 public static async Task<string> GripStudy()
 {
  var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset");var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();var target=dummy.Health;Vector3 saved=target.transform.position;bool enabled=dummy.enabled;dummy.enabled=false;Time.timeScale=.5f;var report=new List<object>();
  try{foreach(string profile in new[]{"sword-neutral","sword-adjusted-grip"})foreach(int d in new[]{0,3}){
   var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/GripStudy/"+profile+".asset");Animator.Configure(set,Player,Animator.Body,Sword);await Reset();target.Configure(Faction.Training);Vector2 direction=ProductionDirections.Vector(d);target.transform.position=Player.transform.position+(Vector3)direction*.85f;Physics2D.SyncTransforms();int hp=target.State.Health,hits=0;
   Action<ActorHealth,ActorHealth> hit=(a,b)=>{if(a==Player&&b==target)hits++;};Authority.HitConfirmed+=hit;
   try{Aim(direction);await Wait(.04f);Aim(direction,1);var frames=await Trace("grip-"+profile+"-"+d,.5f);Aim(direction);var data=Newtonsoft.Json.Linq.JArray.FromObject(frames);bool poses=data.Any(r=>((string)r["source"]).StartsWith("ProceduralGripR7"));bool aligned=data.All(r=>(float)r["handError"]<.0001f);Check(hits==1&&hp-target.State.Health==20&&poses&&aligned,"Procedural grip Unity fixture failed");report.Add(new{profile,direction=d,damage=hp-target.State.Health,hits,proceduralBodyObserved=poses,handAnchorAligned=aligned,fullAnimation=false});}finally{Authority.HitConfirmed-=hit;}
  }File.WriteAllText(E+"procedural-grip-unity.json",JsonConvert.SerializeObject(report,Formatting.Indented));return "4/4 procedural grip presentation studies tested in Unity with 20 damage, one hit and aligned grip; no full animation claim";}
  finally{Input();Aim(Vector2.down);Time.timeScale=1;target.Configure(Faction.Training);target.transform.position=saved;dummy.enabled=enabled;Animator.Configure(original,Player,Animator.Body,Sword);}
 }

}
