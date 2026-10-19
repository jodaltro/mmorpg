#if UNITY_EDITOR
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
namespace Mmorpg.Runtime
{
    // Temporary Play-only probe, never serialized into the production scene.
    public sealed class VillageEvidenceCapture:MonoBehaviour
    {
        public readonly List<object> Captures=new List<object>();
        void Awake(){string index="Docs/Validation/ValdoriaPlayableVillage01/QA/capture-index.json";if(File.Exists(index))foreach(var row in JObject.Parse(File.ReadAllText(index))["images"])Captures.Add(row);}
        public void Capture(string name,string state)=>StartCoroutine(AfterRender(name,state));
        IEnumerator AfterRender(string name,string state)
        {
            yield return new WaitForEndOfFrame();
            string root="Docs/Validation/ValdoriaPlayableVillage01/";
            string path="Original/"+name+".png";
            if(File.Exists(root+path))throw new IOException("Refuse evidence overwrite");
            var image=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(root+path,image.EncodeToPNG());Destroy(image);
            var camera=Camera.main;var actor=GameObject.Find("Player");
            Captures.Add(new{original=path,scene=gameObject.scene.path,state,comparison=name,integral=true,
                camera=new{position=camera.transform.position.ToString("R"),ortho=camera.orthographicSize,resolution=new[]{Screen.width,Screen.height},ppu=32,actorScale=1.25},
                frame=Time.frameCount,time=Time.timeAsDouble,actor=actor.transform.position.ToString("R"),waterPhase=UnityEngine.Object.FindAnyObjectByType<WaterSurfaceAnimator>()?.FrameIndex,playMode=true,afterEndOfFrame=true});
            File.WriteAllText(root+"QA/capture-index.json",JsonConvert.SerializeObject(new{images=Captures},Formatting.Indented));
        }
    }
}
#endif
