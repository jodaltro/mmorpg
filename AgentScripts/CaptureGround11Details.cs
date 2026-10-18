using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureGround11Details
{
 static int i;static double until;static bool waiting;static SpriteRenderer[] crowns;static bool[] visibility;static GroundFinishLab lab;
 const string Output="Docs/Validation/ValdoriaGround11/Details";
 static string[] names={"tree-stone-contact","foundation-entry","main-road","junction-before-isolated","junction-after-isolated"};
 static Vector3[] poses={new Vector3(13,7.03125f,-10),new Vector3(30,7.03125f,-10),new Vector3(44,26,-10),new Vector3(17.5f,14.5f,-10),new Vector3(17.5f,14.5f,-10)};
 public static object Main(){if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=GroundFinish11Importer.Scene)throw new IOException("Ground11 Play required");if(Directory.Exists(Output))throw new IOException("Refuse captures overwrite");Directory.CreateDirectory(Output);lab=UnityEngine.Object.FindAnyObjectByType<GroundFinishLab>();crowns=UnityEngine.Object.FindObjectsByType<VegetationAnchor>().SelectMany(a=>a.GetComponentsInChildren<SpriteRenderer>()).Where(r=>r.name=="crown").ToArray();visibility=crowns.Select(r=>r.enabled).ToArray();Camera.main.GetComponent<CameraFollow>().enabled=false;var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();body.position=new Vector2(28.673845f,6.245552f);body.transform.position=body.position;EditorApplication.update+=Tick;return "Ground and contact captures queued; isolated junction explicitly labelled";}
 static void Tick(){if(!EditorApplication.isPlaying){Restore();return;}if(Time.timeAsDouble<until)return;if(waiting){ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+names[i]+".png"));i++;waiting=false;until=Time.timeAsDouble+.3;return;}if(i==names.Length){Restore();return;}lab.Select(i==3?0:3);if(i==3)foreach(var r in crowns)r.enabled=false;Camera.main.orthographicSize=7.03125f;Camera.main.transform.position=poses[i];waiting=true;until=Time.timeAsDouble+.6;}
 static void Restore(){EditorApplication.update-=Tick;for(int j=0;j<crowns.Length;j++)if(crowns[j])crowns[j].enabled=visibility[j];lab.Select(3);}
}
