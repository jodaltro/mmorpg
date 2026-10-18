using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Newtonsoft.Json;
public static class ValidateCatalogDirection09
{
 sealed class Step{public Action begin,end;public float duration;}
 static readonly Queue<Step> queue=new Queue<Step>();static readonly List<object> results=new List<object>();static readonly List<InputDevice> disabled=new List<InputDevice>();
 static Step current;static double until;static int frame,first;static Keyboard keyboard,previous;static InputSettings.BackgroundBehavior background;static InputSettings.EditorInputBehaviorInPlayMode editorInput;static Key[] held=Array.Empty<Key>();
 const string Root="Docs/Validation/ValdoriaWorldStudio09/CatalogQA/";
 static void Add(float duration,Action begin,Action end=null)=>queue.Enqueue(new Step{duration=duration,begin=begin,end=end});
 static void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
 public static object Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Play");if(Directory.Exists(Root))throw new IOException("Refuse catalog QA overwrite");Directory.CreateDirectory(Root);
  first=Time.frameCount;previous=Keyboard.current;background=InputSystem.settings.backgroundBehavior;editorInput=InputSystem.settings.editorInputBehaviorInPlayMode;foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("VisualCatalog09QA");InputSystem.onBeforeUpdate+=Feed;
  for(int i=0;i<4;i++)
  {
   int index=i;Key key=new[]{Key.F1,Key.F2,Key.F3,Key.F4}[i];
   Add(.10f,()=>held=new[]{key});Add(.90f,()=>held=Array.Empty<Key>());
   Add(.12f,()=>held=new[]{Key.P});
   Add(.80f,()=>held=Array.Empty<Key>(),()=>{var c=UnityEngine.Object.FindAnyObjectByType<VisualUnificationLab>();var buildings=UnityEngine.Object.FindObjectsByType<ArchitectureBuilding>();bool allWeathered=buildings.SelectMany(b=>b.GetComponentsInChildren<SpriteRenderer>()).Where(r=>r.sprite).All(r=>r.sprite.texture.name.EndsWith("weathered"));bool pass=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path==VisualUnification09Importer.Scenes[index]&&c.Catalog&&c.Recipes.Length==3&&c.Selections.Length==3&&c.Weathered&&allWeathered;results.Add(new{index,pass,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,allWeathered,catalog=c.Catalog?c.Catalog.name:null,frame=Time.frameCount});ScreenCapture.CaptureScreenshot(Path.GetFullPath(Root+index+"-selected-recipe.png"));});Add(.25f,()=>{});
  }
  EditorApplication.update+=Tick;return "Catalog recipes, real P and F1-F4 Input System sequence started";
 }
 static void Tick(){try{if(!EditorApplication.isPlaying){Finish("Play interrupted");return;}if(frame==Time.frameCount)return;frame=Time.frameCount;if(current!=null&&Time.timeAsDouble<until)return;current?.end?.Invoke();if(queue.Count==0){Finish(null);return;}current=queue.Dequeue();current.begin();until=Time.timeAsDouble+current.duration;}catch(Exception e){Finish(e.ToString());}}
 static void Finish(string error){EditorApplication.update-=Tick;InputSystem.onBeforeUpdate-=Feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)if(d.added)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=editorInput;File.WriteAllText(Root+"play-qa.json",JsonConvert.SerializeObject(new{error,framesAdvanced=Time.frameCount-first,results},Formatting.Indented));}
}
