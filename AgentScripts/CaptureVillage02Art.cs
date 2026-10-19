using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Object=UnityEngine.Object;

public static class CaptureVillage02Art
{
    const string Root="Docs/Validation/ValdoriaVillage02-ArtProduction/";
    public static async Task<object> Main()
    {
        if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/ValdoriaVillage02ArtGallery.unity"||File.Exists(Root+"QA/play-review.json"))throw new IOException("New isolated art gallery Play required");
        var recorder=new GameObject("TEMP art evidence").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot(Root);
        var actor=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();follow.enabled=false;int first=Time.frameCount;double began=Time.timeAsDouble;
        var rows=new System.Collections.Generic.List<object>();var previous=Keyboard.current;Keyboard keyboard=null;var disabled=InputSystem.devices.OfType<Keyboard>().Where(k=>k.enabled).ToArray();var bg=InputSystem.settings.backgroundBehavior;var ei=InputSystem.settings.editorInputBehaviorInPlayMode;Key[] held=Array.Empty<Key>();
        Action feed=()=>{if(keyboard!=null&&InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));};
        try{
            foreach(var d in disabled)InputSystem.DisableDevice(d);InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;keyboard=InputSystem.AddDevice<Keyboard>("Village02-Art-QA");InputSystem.onBeforeUpdate+=feed;
            actor.position=new Vector2(0,10);actor.transform.position=actor.position;var start=actor.position;held=new[]{Key.W};await Task.Delay(500);held=Array.Empty<Key>();await Task.Delay(150);bool inputMoved=actor.position.y>start.y+.5f;
            var assets=Object.FindObjectsByType<SpriteRenderer>().Where(r=>r.name.StartsWith("Art E: ")).OrderBy(r=>r.transform.position.y).ToArray();
            foreach(var asset in assets)
            {
                string id=asset.name.Substring(7);actor.position=(Vector2)asset.transform.position+new Vector2(4,-1);actor.transform.position=actor.position;actor.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();
                var bounds=asset.bounds;camera.transform.position=new Vector3(bounds.center.x,bounds.center.y,-10);camera.orthographicSize=Mathf.Max(14.0625f,(bounds.size.y+5)*.5f,(bounds.size.x+6)/(2*camera.aspect));await Task.Delay(300);
                recorder.Capture(id+"-whole","Phase E art gallery, whole asset with protagonist; fixed art-review fixture; no world collision integration");while(recorder.Busy)await Task.Delay(35);
                rows.Add(new{id,wholeOrtho=camera.orthographicSize,canvasWorld=bounds.size.ToString("R"),actor=actor.position.ToString("R"),scale=asset.transform.lossyScale.ToString("R")});
                if(id.StartsWith("H")||id=="B1"||id=="castle-compound"||id=="gate"||id=="bridge")
                {
                    camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(asset.transform.position.x,asset.transform.position.y+5,-10);await Task.Delay(250);recorder.Capture(id+"-native","Phase E native 32 screen pixels/u at 1600x900; close-up may crop the entire building; not a footprint or collision proof");while(recorder.Busy)await Task.Delay(35);
                }
            }
            var receipt=new{completed=true,inputMoved,assets=assets.Length,framesAdvanced=Time.frameCount-first,seconds=Time.timeAsDouble-began,profile=LocalJourneyProfile.Root,rows,worldPhysicsTested=false,artisticApproval=false};File.WriteAllText(Root+"QA/play-review.json",JsonConvert.SerializeObject(receipt,Formatting.Indented));return receipt;
        }finally{
            held=Array.Empty<Key>();InputSystem.onBeforeUpdate-=feed;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);previous?.MakeCurrent();InputSystem.settings.backgroundBehavior=bg;InputSystem.settings.editorInputBehaviorInPlayMode=ei;actor.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);actor.linearVelocity=Vector2.zero;camera.orthographicSize=14.0625f;follow.enabled=true;
            File.WriteAllText(Root+"QA/input-restored.json",JsonConvert.SerializeObject(new{syntheticAbsent=!InputSystem.devices.Any(d=>d.name.Contains("Village02-Art")),keyboards=InputSystem.devices.OfType<Keyboard>().Select(k=>new{k.name,k.enabled}),backgroundRestored=InputSystem.settings.backgroundBehavior==bg,editorInputRestored=InputSystem.settings.editorInputBehaviorInPlayMode==ei,timeScale=Time.timeScale},Formatting.Indented));
        }
    }
}
