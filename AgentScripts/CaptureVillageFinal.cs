using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Object=UnityEngine.Object;
public static class CaptureVillageFinal
{
    static readonly string[] names={"final-overview","final-bridge-gate-front","final-settlement","final-castle","final-west-wall","final-river","final-nature"};
    static readonly Vector3[] cameras={new Vector3(56,72,-10),new Vector3(56,36,-10),new Vector3(56,60,-10),new Vector3(56,105,-10),new Vector3(16,68,-10),new Vector3(56,24,-10),new Vector3(24,14,-10)};
    static readonly Vector2[] positions={new Vector2(56,8),new Vector2(56,31),new Vector2(56,57),new Vector2(48,82),new Vector2(16,68),new Vector2(56,24),new Vector2(24,10)};
    static readonly float[] scales={72,14.0625f,24,24,14.0625f,14.0625f,14.0625f};
    static VillageEvidenceCapture recorder;static Rigidbody2D actor;static Camera camera;static CameraFollow follow;
    static int index,last,phase;static double until;static List<double> timings=new List<double>();static List<object> metrics=new List<object>();
    public static object Main(){if(!EditorApplication.isPlaying||File.Exists("Docs/Validation/ValdoriaPlayableVillage01/QA/final-performance.json"))throw new IOException("New Play evidence required");recorder=Object.FindAnyObjectByType<VillageEvidenceCapture>();if(!recorder)recorder=new GameObject("Final village evidence").AddComponent<VillageEvidenceCapture>();actor=GameObject.Find("Player").GetComponent<Rigidbody2D>();camera=Camera.main;follow=camera.GetComponent<CameraFollow>();follow.enabled=false;index=0;phase=0;until=0;EditorApplication.update+=Tick;return "Final source/occlusion inspection plus warm and clean performance windows queued";}
    static void Tick()
    {
        try{
            if(!EditorApplication.isPlaying){EditorApplication.update-=Tick;return;}if(last==Time.frameCount)return;last=Time.frameCount;double now=Time.timeAsDouble;
            if(index==names.Length){EditorApplication.update-=Tick;follow.enabled=true;camera.orthographicSize=14.0625f;actor.position=new Vector2(56,8);actor.transform.position=actor.position;File.WriteAllText("Docs/Validation/ValdoriaPlayableVillage01/QA/final-performance.json",JsonConvert.SerializeObject(new{conditions="1600x900 Ultra D3D12 Editor; 0.6s settle + 2s samples before screenshot encoding; same content, explicit camera per image, not a Ground13R lab comparison",rows=metrics},Formatting.Indented));return;}
            if(phase==2)timings.Add(Time.unscaledDeltaTime*1000);if(now<until)return;
            if(phase==0){actor.position=positions[index];actor.transform.position=actor.position;actor.linearVelocity=Vector2.zero;camera.transform.position=cameras[index];camera.orthographicSize=scales[index];phase=1;until=now+.6;return;}
            if(phase==1){timings.Clear();phase=2;until=now+2;return;}
            if(phase==2){var rr=Object.FindObjectsByType<Renderer>().Where(r=>r.enabled&&r.gameObject.activeInHierarchy).ToArray();var tt=rr.SelectMany(r=>r is SpriteRenderer s&&s.sprite?new[]{s.sprite.texture}:r.sharedMaterials.Where(m=>m&&m.mainTexture is Texture2D).Select(m=>(Texture2D)m.mainTexture)).Distinct().ToArray();var mesh=Object.FindObjectsByType<MeshFilter>().Where(f=>f.gameObject.activeInHierarchy).Select(f=>f.sharedMesh).Where(m=>m).Distinct().ToArray();var t=timings.OrderBy(v=>v).ToArray();metrics.Add(new{name=names[index],drawCalls=UnityStats.drawCalls,renderers=rr.Length,visible=rr.Count(r=>r.isVisible),textureBytes=tt.Sum(x=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(x)),textures=tt.Length,meshBytes=mesh.Sum(x=>UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(x)),medianMs=t[t.Length/2],p95Ms=t[(int)(t.Length*.95)],samples=t.Length,camera=cameras[index].ToString(),ortho=scales[index],fixturePlacement=true});recorder.Capture(names[index],"final source inspection in actual Play; explicit fixed camera and actor fixture; gameplay route recorded separately");phase=3;until=now+.3;return;}
            index++;phase=0;
        }catch(Exception e){EditorApplication.update-=Tick;File.WriteAllText("Temp/PlayableVillage01-final-capture-error.txt",e.ToString());follow.enabled=true;}
    }
}
