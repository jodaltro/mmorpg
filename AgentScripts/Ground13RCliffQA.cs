using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class Ground13RCliffQA
{
 static Keyboard keyboard,previous;static List<Keyboard> disabled;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;
 static Rigidbody2D body;static int step,last;static double until;static Key[] keys=Array.Empty<Key>();static Vector2 start;static List<object> results=new List<object>(),trace=new List<object>();
 const string Root="Docs/Validation/ValdoriaGround13R/Original/CliffQA/";
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(keys));}
 static void Place(Vector2 p){keys=Array.Empty<Key>();body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();start=p;}
 public static object Main(){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||Directory.Exists(Root))throw new IOException("New isolated Play destination required");Directory.CreateDirectory(Root);body=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=7.03125f;camera.transform.position=new Vector3(48,18,-10);UnityEngine.Object.FindAnyObjectByType<Ground13RLab>().Select(2);previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;disabled=InputSystem.devices.OfType<Keyboard>().Where(d=>d.enabled).ToList();foreach(var d in disabled)InputSystem.DisableDevice(d);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Cliff13QA");InputSystem.onBeforeUpdate+=Feed;step=0;last=-1;until=0;EditorApplication.update+=Tick;return "Real Input System cliff-foot and lateral passage tests queued";}
 static void Tick(){try{if(!EditorApplication.isPlaying)throw new IOException("Play interrupted");if(last==Time.frameCount)return;last=Time.frameCount;trace.Add(new{frame=last,time=Time.timeAsDouble,position=body.position.ToString("R"),keys=string.Join(",",keys)});if(Time.timeAsDouble<until)return;
  if(step==0){Place(new Vector2(48,11.8f));keys=new[]{Key.W};until=Time.timeAsDouble+1.2;step++;return;}
  if(step==1){keys=Array.Empty<Key>();results.Add(new{name="Cliff foot blocks north approach",pass=body.position.y>start.y+.2f&&body.position.y<13,evidence=new{start=start.ToString("R"),end=body.position.ToString("R"),physicalFootY=13.005642f}});until=Time.timeAsDouble+.3;step++;return;}
  if(step==2){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+"cliff-front.png"));until=Time.timeAsDouble+.3;step++;return;}
  if(step==3){Place(new Vector2(45,11.8f));keys=new[]{Key.D};until=Time.timeAsDouble+1.4;step++;return;}
  if(step==4){keys=Array.Empty<Key>();results.Add(new{name="Lateral passage below cliff",pass=body.position.x>49,evidence=new{start=start.ToString("R"),end=body.position.ToString("R")}});until=Time.timeAsDouble+.3;step++;return;}
  ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+"cliff-passage.png"));Finish(null);
 }catch(Exception e){Finish(e.ToString());}}
 static void Finish(string error){EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;File.WriteAllText(Root+"play-qa.json",JsonConvert.SerializeObject(new{error,results,trace},Formatting.Indented));}
}
