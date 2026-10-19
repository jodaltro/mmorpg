using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Newtonsoft.Json;

public static class RoyalGardensStartup
{
 const string Scene="Assets/Mmorpg/Scenes/ValdoriaVillage02Anime.unity",QA="Docs/Validation/ValdoriaRoyalGardens/QA/";
 public static object OpenFirst()
 {
  if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Clean stopped editor required");
  string first=EditorBuildSettings.scenes.First(s=>s.enabled).path;if(first!=Scene)throw new IOException("Wrong initial scene");EditorSceneManager.OpenScene(first);return first;
 }
 public static async Task<object> Observe()
 {
  if(!EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().path!=Scene||!LocalJourneyProfile.Root.Contains("Temp")||File.Exists(QA+"startup-play.json"))throw new IOException("New isolated initial-scene Play required");
  int frame=Time.frameCount;var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();var before=body.position;var previous=Keyboard.current;var disabled=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;Keyboard synthetic=null;bool holding=true;string error=null;
  void Feed(){if(synthetic!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(synthetic,holding?new KeyboardState(Key.W):new KeyboardState());}
  try{foreach(var d in disabled)InputSystem.DisableDevice(d);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;synthetic=InputSystem.AddDevice<Keyboard>("RoyalGardens-Startup-QA");InputSystem.onBeforeUpdate+=Feed;await Task.Delay(1000);holding=false;await Task.Delay(120);}
  catch(Exception e){error=e.ToString();}
  finally{InputSystem.onBeforeUpdate-=Feed;if(synthetic!=null)InputSystem.RemoveDevice(synthetic);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;}
  var r=new{error,scene=EditorSceneManager.GetActiveScene().path,firstEnabled=EditorBuildSettings.scenes.First(s=>s.enabled).path,framesAdvanced=Time.frameCount-frame,travel=Vector2.Distance(before,body.position),physical=UnityEngine.Object.FindObjectsByType<PolygonCollider2D>().Count(c=>c.gameObject.name.StartsWith("Physics:")),playerCount=UnityEngine.Object.FindObjectsByType<ActorMotor>().Count(),syntheticAbsent=!InputSystem.devices.Any(d=>d.name=="RoyalGardens-Startup-QA"),physicalKeyboards=InputSystem.devices.OfType<Keyboard>().Select(k=>new{k.name,k.enabled}),profile=LocalJourneyProfile.Root};File.WriteAllText(QA+"startup-play.json",JsonConvert.SerializeObject(r,Formatting.Indented));if(error!=null||r.framesAdvanced<3||r.travel<1||r.physical!=172||r.playerCount!=1)throw new IOException("Initial scene smoke failed");return r;
 }
}
