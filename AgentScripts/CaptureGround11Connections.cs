using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureGround11Connections
{
 static SpriteRenderer[] visuals;static bool[] states;static GroundFinishLab lab;static double until;static int phase;static bool ready;
 public static object Main(){if(!EditorApplication.isPlaying)throw new IOException("Play required");foreach(string name in new[]{"before","after"})if(File.Exists("Docs/Validation/ValdoriaGround11/Details/connection-"+name+".png"))throw new IOException("Refuse capture overwrite");visuals=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().Where(a=>a.FootprintRadius>0).SelectMany(a=>a.GetComponentsInChildren<SpriteRenderer>()).ToArray();states=visuals.Select(r=>r.enabled).ToArray();foreach(var r in visuals)r.enabled=false;lab=UnityEngine.Object.FindAnyObjectByType<GroundFinishLab>();Camera.main.GetComponent<CameraFollow>().enabled=false;Camera.main.orthographicSize=7.03125f;Camera.main.transform.position=new Vector3(17.5f,14.5f,-10);EditorApplication.update+=Tick;return "Diagnostic only: tree visuals hidden for ground junction inspection; collisions untouched";}
 static void Tick(){if(!EditorApplication.isPlaying){Restore();return;}if(Time.timeAsDouble<until)return;if(phase>=2){Restore();return;}if(!ready){lab.Select(phase==0?0:3);ready=true;until=Time.timeAsDouble+.6;return;}ScreenCapture.CaptureScreenshot(Path.GetFullPath("Docs/Validation/ValdoriaGround11/Details/connection-"+(phase==0?"before":"after")+".png"));phase++;ready=false;until=Time.timeAsDouble+.3;}
 static void Restore(){EditorApplication.update-=Tick;for(int j=0;j<visuals.Length;j++)if(visuals[j])visuals[j].enabled=states[j];lab.Select(3);}
}
