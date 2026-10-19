#if DEVELOPMENT_BUILD && !UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Newtonsoft.Json;
namespace Mmorpg.Runtime
{
    // Development-build smoke only, opt-in command line, absent from release.
    public sealed class VillageStandaloneSmoke:MonoBehaviour
    {
        const string Root="Docs/Validation/ValdoriaPlayableVillage01/Standalone/";
        Keyboard keyboard;Key[] held=Array.Empty<Key>();Rigidbody2D body;
        readonly List<object> images=new List<object>(),trace=new List<object>();
        readonly List<InputDevice> disabled=new List<InputDevice>();
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot(){if(Environment.GetCommandLineArgs().Contains("-village-smoke"))new GameObject("Development standalone smoke").AddComponent<VillageStandaloneSmoke>();}
        void Feed(){if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(keyboard,new KeyboardState(held));}
        void Update(){if(body)trace.Add(new{frame=Time.frameCount,time=Time.timeAsDouble,x=body.position.x,y=body.position.y,keys=string.Join(",",held)});}
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();var image=ScreenCapture.CaptureScreenshotAsTexture();
            if(!image){Debug.LogWarning("Standalone smoke: screen capture unavailable in hidden window; gameplay test continues, Editor Play PNGs remain the visual evidence.");yield break;}
            File.WriteAllBytes(Root+"Original/"+name+".png",image.EncodeToPNG());Destroy(image);
            images.Add(new{original="Original/"+name+".png",scene=gameObject.scene.path,state="standalone actual rendered Player",comparison=name,integral=true,camera=new{position=Camera.main.transform.position.ToString("R"),ortho=Camera.main.orthographicSize,ppu=32,resolution=new[]{Screen.width,Screen.height}},frame=Time.frameCount,time=Time.timeAsDouble,actor=body.position.ToString("R"),afterEndOfFrame=true});
        }
        IEnumerator Start()
        {
            Application.runInBackground=true;
            if(Directory.Exists(Root)){Debug.LogError("Refuse standalone evidence overwrite");Application.Quit(18);yield break;}
            Directory.CreateDirectory(Root+"Original");Directory.CreateDirectory(Root+"QA");
            yield return new WaitForSeconds(2);
            body=GameObject.Find("Player").GetComponent<Rigidbody2D>();Vector2 start=body.position;
            foreach(var d in InputSystem.devices.OfType<Keyboard>().Where(d=>d.enabled).ToArray()){disabled.Add(d);InputSystem.DisableDevice(d);}
            InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;keyboard=InputSystem.AddDevice<Keyboard>("Standalone smoke keyboard");InputSystem.onBeforeUpdate+=Feed;
            yield return Capture("standalone-spawn");held=new[]{Key.W};yield return new WaitForSeconds(1.1f);held=Array.Empty<Key>();yield return new WaitForSeconds(.15f);Vector2 north=body.position;yield return Capture("standalone-wasd-north");
            held=new[]{Key.S};yield return new WaitForSeconds(1.1f);held=Array.Empty<Key>();yield return new WaitForSeconds(.15f);Vector2 end=body.position;yield return Capture("standalone-return");
            bool pass=north.y>start.y+2&&Vector2.Distance(start,end)<.8f&&LocalJourneyProfile.Root.Contains("Temp")&&Time.frameCount>60;
            InputSystem.onBeforeUpdate-=Feed;InputSystem.RemoveDevice(keyboard);foreach(var d in disabled)InputSystem.EnableDevice(d);
            File.WriteAllText(Root+"QA/capture-index.json",JsonConvert.SerializeObject(new{images},Formatting.Indented));
            File.WriteAllText(Root+"QA/standalone.json",JsonConvert.SerializeObject(new{passed=pass,scene=gameObject.scene.path,spawn=start.ToString("R"),north=north.ToString("R"),returned=end.ToString("R"),frames=Time.frameCount,profile=LocalJourneyProfile.Root,inputRestored=true,trace},Formatting.Indented));
            Debug.Log(pass?"VILLAGE_STANDALONE_SMOKE_PASS":"VILLAGE_STANDALONE_SMOKE_FAIL");Application.Quit(pass?0:17);
        }
    }
}
#endif
