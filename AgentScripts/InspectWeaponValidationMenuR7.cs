using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
public static class InspectWeaponValidationMenuR7
{
 const string E="Docs/Validation/HumanoidSwordR7/";
 static ActorHealth Player=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
 static WeaponValidationPreview Preview=>Player.GetComponent<WeaponValidationPreview>();
 static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(k=>k.name=="AnimationKeyboard");
 static Mouse Pointer=>InputSystem.devices.OfType<Mouse>().Single(k=>k.name=="AnimationMouse");
 static void Check(bool value,string message){if(!value)throw new Exception(message);}
 static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(5);}
 static async Task Tap(Key key){InputSystem.QueueStateEvent(Keys,new KeyboardState(key));await Wait(.04f);InputSystem.QueueStateEvent(Keys,new KeyboardState());await Wait(.07f);}
 static UnityEngine.UI.Button Button(string name)=>UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>().Single(b=>b.name==name&&b.gameObject.activeInHierarchy);
 static async Task Click(string name)
 {
  var rect=(RectTransform)Button(name).transform;var corners=new Vector3[4];rect.GetWorldCorners(corners);Vector2 point=(corners[0]+corners[2])*.5f;
  var hits=new List<UnityEngine.EventSystems.RaycastResult>();var events=UnityEngine.EventSystems.EventSystem.current;events.RaycastAll(new UnityEngine.EventSystems.PointerEventData(events){position=point},hits);Check(hits.Any(h=>h.gameObject.transform==rect||h.gameObject.transform.IsChildOf(rect)),"UI raycast blocked: "+name);
  InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(.04f);InputSystem.QueueStateEvent(Pointer,new MouseState{position=point,buttons=1});await Wait(.04f);InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(.08f);
 }
 static async Task Capture(string name)
 {
  var done=new TaskCompletionSource<bool>();Player.StartCoroutine(CaptureFrame(name,done));await done.Task;
 }
 static System.Collections.IEnumerator CaptureFrame(string name,TaskCompletionSource<bool> done){yield return new WaitForEndOfFrame();try{var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(E+"previews/"+name+".png",tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);done.SetResult(true);}catch(Exception ex){done.SetException(ex);}}
 public static async Task<string> Inspect()
 {
  Check(LocalJourneyProfile.Root.Contains("Temp"),"Isolated profile required");var identity=LocalJourneyProfile.IdentityId;int first=Time.frameCount;var results=new List<string>();var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();int hits=0;Action<ActorHealth,ActorHealth> hit=(a,b)=>{if(a==Player)hits++;};authority.HitConfirmed+=hit;
  var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>();bool recovery=dummy.enabled;dummy.enabled=false;
  try{
   await Tap(Key.Escape);Check(Time.timeScale==0,"Esc did not pause");await Click("ValidateWeapons");await Capture("weapon-menu");results.Add("Esc + real mouse opened the weapon page while paused");
   await Click("WeaponBowSouth");Check(Preview.BowSelected&&Preview.ViewIndex==0&&Time.timeScale==0,"South selection failed");Check(!Player.GetComponent<PlayerController>().enabled&&!Player.GetComponent<SwordSwing>().enabled,"Sword input not suspended");await Click("WeaponTest");Check(Time.timeScale==1&&!Preview.Playing,"Resume leaked UI click into bow draw");
   Vector2 before=Player.GetComponent<Rigidbody2D>().position;InputSystem.QueueStateEvent(Keys,new KeyboardState(Key.D));await Wait(.18f);InputSystem.QueueStateEvent(Keys,new KeyboardState());Check(Vector2.Distance(before,Player.GetComponent<Rigidbody2D>().position)<.02f,"Stationary bow study moved");
   await Tap(Key.J);Check(Preview.Playing,"J did not start bow draw");await Wait(.65f);await Capture("weapon-bow-south-live");await Wait(1);Check(!Preview.Playing&&Preview.PoseIndex==0&&hits==0,"Bow completion/damage isolation failed");results.Add("South draw played from J and returned to idle; stationary, zero confirmed attacks");
   await Tap(Key.V);Check(Preview.ViewIndex==1,"V did not switch view");await Tap(Key.J);await Wait(.95f);await Capture("weapon-bow-east-live");
   await Tap(Key.Escape);int frozen=Preview.PoseIndex;await Wait(.2f);Check(Time.timeScale==0&&Preview.PoseIndex==frozen,"Paused draw advanced");await Click("ValidateWeapons");await Click("WeaponBowEast");Check(Preview.BowSelected&&Preview.ViewIndex==1&&!Preview.Playing,"Lateral menu selection failed");await Capture("weapon-menu-bow-selected");await Click("WeaponSword");Check(!Preview.BowSelected&&Player.GetComponent<PlayerController>().enabled&&Player.GetComponent<SwordSwing>().enabled,"Sword restoration failed");await Click("WeaponTest");results.Add("V and both menu views work; Esc freezes playback; sword restores original components");
   InputSystem.QueueStateEvent(Keys,new KeyboardState(Key.D));before=Player.GetComponent<Rigidbody2D>().position;await Wait(.2f);InputSystem.QueueStateEvent(Keys,new KeyboardState());Check(Player.GetComponent<Rigidbody2D>().position.x>before.x+.2f,"Sword movement did not resume");
   Player.GetComponent<Rigidbody2D>().position=new Vector2(-2.75f,0);Player.GetComponent<Rigidbody2D>().linearVelocity=Vector2.zero;await Wait(.12f);var target=dummy.GetComponent<ActorHealth>();target.Configure(Faction.Training);target.GetComponent<Rigidbody2D>().position=new Vector2(-1.9f,0);int initialHealth=target.State.Health;Vector2 aim=Camera.main.WorldToScreenPoint((Vector2)Player.transform.position+Vector2.right*3);InputSystem.QueueStateEvent(Pointer,new MouseState{position=aim});await Wait(.05f);await Tap(Key.J);
   await Tap(Key.Escape);await Click("ValidateWeapons");await Click("WeaponBowSouth");Check(!Preview.BowSelected,"Weapon switched during active strike");await Click("WeaponTest");await Wait(.5f);Check(initialHealth-target.State.Health==20&&hits==1,"Sword near gate changed after weapon switch");results.Add("Sword walking and near hit preserved: 20 damage, one confirmed hit; active-strike switch refused");
   await Tap(Key.Escape);await Click("ValidateWeapons");await Click("WeaponBowSouth");await Click("WeaponTest");Check(Preview.BowSelected,"Bow re-selection failed");await Tap(Key.F5);await Wait(.5f);Check(!Preview.BowSelected&&LocalJourneyProfile.IdentityId==identity&&Time.timeScale==1,"Restart changed identity or retained transient preview");Check(UnityEngine.Object.FindObjectsByType<WeaponValidationPreview>().Length==1,"Duplicate preview after restart");results.Add("F5 restored default sword with the same isolated identity and one selector");
   await Tap(Key.Escape);await Click("ValidateWeapons");await Click("WeaponBack");await Click("Continuar");Check(Time.timeScale==1,"Back/Continue failed");results.Add("Back and existing Continue buttons work after restart");
  }finally{if(authority!=null)authority.HitConfirmed-=hit;if(dummy!=null)dummy.enabled=recovery;InputSystem.QueueStateEvent(Keys,new KeyboardState());InputSystem.QueueStateEvent(Pointer,new MouseState{position=new Vector2(800,200)});}
  Check(Time.frameCount>first,"Play frames did not advance");string json=JsonConvert.SerializeObject(new{firstFrame=first,lastFrame=Time.frameCount,identityPreserved=true,results},Formatting.Indented);File.WriteAllText(E+"weapon-menu-qa.json",json);return json;
 }
 public static async Task<string> SmokeLegacy(){Check(LocalJourneyProfile.Root.Contains("Temp"),"Isolated profile required");Check(UnityEngine.Object.FindAnyObjectByType<WeaponValidationPreview>()==null,"Legacy unexpectedly received weapon preview");await Tap(Key.Escape);Check(Time.timeScale==0,"Legacy pause failed");await Click("Continuar");Check(Time.timeScale==1,"Legacy Continue failed");string json=JsonConvert.SerializeObject(new{scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,legacyPausePassed=true,optionalWeaponPageAbsent=true,isolated=true});File.WriteAllText(E+"weapon-menu-legacy-smoke.json",json);return json;}
 public static async Task<string> PointerDraw(){Check(LocalJourneyProfile.Root.Contains("Temp"),"Isolated profile required");await Tap(Key.Escape);await Click("ValidateWeapons");await Click("WeaponBowEast");await Click("WeaponTest");Vector2 point=new Vector2(Screen.width*.8f,Screen.height*.6f);InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(.05f);InputSystem.QueueStateEvent(Pointer,new MouseState{position=point,buttons=1});await Wait(.05f);Check(Preview.Playing,"World mouse click did not start bow draw");InputSystem.QueueStateEvent(Pointer,new MouseState{position=point});await Wait(1.6f);Check(!Preview.Playing,"Mouse draw did not finish");string json="{\"worldMouseDrawPassed\":true,\"returnedToIdle\":true}";File.WriteAllText(E+"weapon-menu-pointer.json",json);await Tap(Key.Escape);await Click("ValidateWeapons");await Click("WeaponSword");await Click("WeaponTest");return json;}
}
