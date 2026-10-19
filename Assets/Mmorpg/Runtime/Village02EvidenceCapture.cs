#if UNITY_EDITOR
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;

namespace Mmorpg.Runtime
{
    // Play-only evidence recorder instantiated by the review harness, never in the scene.
    public sealed class Village02EvidenceCapture : MonoBehaviour
    {
        const string Root="Docs/Validation/ValdoriaVillage02/";
        readonly List<object> images=new List<object>();
        public bool Busy { get; private set; }
        public void Capture(string name,string state)
        { if(Busy)throw new InvalidOperationException("Capture pending");Busy=true;StartCoroutine(AfterRender(name,state)); }
        IEnumerator AfterRender(string name,string state)
        {
            yield return new WaitForEndOfFrame();
            var camera=Camera.main;var player=GameObject.Find("Player");string path="Original/"+name+".png";
            if(File.Exists(Root+path))throw new IOException("Refuse original overwrite: "+path);
            Directory.CreateDirectory(Root+"Original");Directory.CreateDirectory(Root+"QA");
            var image=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Root+path,image.EncodeToPNG());Destroy(image);
            images.Add(new{original=path,scene=gameObject.scene.path,state,comparison=name,integral=true,
                camera=new{position=camera.transform.position.ToString("R"),ortho=camera.orthographicSize,resolution=new[]{Screen.width,Screen.height},ppu=32,actorScale=1.25},
                frame=Time.frameCount,time=Time.timeAsDouble,actor=player.transform.position.ToString("R"),playMode=true,afterEndOfFrame=true});
            File.WriteAllText(Root+"QA/capture-index.json",JsonConvert.SerializeObject(new{images},Formatting.Indented));Busy=false;
        }
    }
}
#endif
