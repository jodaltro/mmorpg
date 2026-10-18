using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
using Newtonsoft.Json;
public static class BenchmarkGround13R
{
 static Ground13RLab lab;static ProductionSpriteAnimator actor;static bool animated;static int stage,phase,last,first;static double until,began;static List<double> dt=new List<double>();static List<object> rows=new List<object>();
 public static object Main(){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Isolated Play required");var camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(28.5f,14.25f,-10);var p=GameObject.Find("Player").GetComponent<Rigidbody2D>();p.position=new Vector2(28.673845f,6.245552f);p.transform.position=p.position;actor=p.GetComponent<ProductionSpriteAnimator>();animated=actor.enabled;actor.enabled=false;lab=UnityEngine.Object.FindAnyObjectByType<Ground13RLab>();stage=0;phase=0;until=0;EditorApplication.update+=Tick;return "Two comparable live states, no PNG encoding or offline reconstruction during samples";}
 static void Tick(){if(last==Time.frameCount)return;last=Time.frameCount;if(phase==2)dt.Add(Time.unscaledDeltaTime*1000);if(Time.realtimeSinceStartupAsDouble<until)return;if(stage==2){EditorApplication.update-=Tick;actor.enabled=animated;lab.Select(2);File.WriteAllText("Docs/Validation/ValdoriaGround13R/QA/benchmark.json",JsonConvert.SerializeObject(new{conditions="Editor Play; 1600x900; 28.5,14.25,-10; ortho14.0625; Ultra; VSync1; targetFPS -1; D3D12 RX5700XT; autotick16ms; no capture/rebuild/compression during timed samples; actor held and water live",rows},Formatting.Indented));return;}
 if(phase==0){lab.Select(stage==0?1:2);lab.EvidencePhase(-1);phase=1;until=Time.realtimeSinceStartupAsDouble+1;return;}if(phase==1){dt.Clear();first=last;began=Time.realtimeSinceStartupAsDouble;phase=2;until=began+3;return;}var sorted=dt.OrderBy(x=>x).ToArray();rows.Add(new{state=stage==0?"B-Ground13":"C-Ground13R",seconds=Time.realtimeSinceStartupAsDouble-began,frames=last-first,fps=(last-first)/(Time.realtimeSinceStartupAsDouble-began),medianMs=sorted[sorted.Length/2],p95Ms=sorted[(int)(sorted.Length*.95)],drawCalls=UnityStats.drawCalls});stage++;phase=0;until=Time.realtimeSinceStartupAsDouble+.1;}
}
