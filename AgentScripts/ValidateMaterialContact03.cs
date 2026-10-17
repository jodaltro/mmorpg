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
public static class ValidateMaterialContact03
{
 static Keyboard keyboard,previous;static readonly List<InputDevice> disabled=new List<InputDevice>();static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode focus;static Rigidbody2D body;static double start;static int first,last;static bool captured;static readonly List<object> trace=new List<object>();
 const string Output="Docs/Validation/ValdoriaWorldStudio03/Final/Contact";
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.W));}
 public static string Main()
 {
  if(!EditorApplication.isPlaying)throw new Exception("Enter Play first");if(Directory.Exists(Output))throw new IOException("Refuse contact QA overwrite");Directory.CreateDirectory(Output);
  previous=Keyboard.current;foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}background=InputSystem.settings.backgroundBehavior;focus=InputSystem.settings.editorInputBehaviorInPlayMode;InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("MaterialContactQA");
  var lab=UnityEngine.Object.FindAnyObjectByType<TerrainMaterialLabController>();lab.Select(0,2);body=GameObject.Find("Player").GetComponent<Rigidbody2D>();body.position=new Vector2(47.5f,10.5f);body.transform.position=body.position;body.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();start=Time.timeAsDouble;first=Time.frameCount;InputSystem.onBeforeUpdate+=Feed;EditorApplication.update+=Tick;return "Contact QA started: real W into south rock footprint at x47.5";
 }
 static void Tick()
 {
  if(last==Time.frameCount)return;last=Time.frameCount;double elapsed=Time.timeAsDouble-start;
  if(trace.Count==0||elapsed>trace.Count*.1)trace.Add(new{frame=Time.frameCount,time=elapsed,x=body.position.x,y=body.position.y,velocity=body.linearVelocity.ToString()});
  if(elapsed>1.5&&!captured){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/cliff-contact.png"));captured=true;}
  if(elapsed<2.0)return;
  var box=body.GetComponent<BoxCollider2D>();bool overlap=Physics2D.OverlapBox(body.position+box.offset,box.size*.98f,0,1<<8)!=null;
  var result=new{passed=body.position.y>12&&body.position.y<13&&!overlap,x=body.position.x,y=body.position.y,semanticSouthBoundaryY=13,noPenetration=!overlap,frames=Time.frameCount-first,trace};
  EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=focus;File.WriteAllText(Output+"/contact-qa.json",JsonConvert.SerializeObject(result,Formatting.Indented));
 }
}
