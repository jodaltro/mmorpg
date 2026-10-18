using System;
using System.IO;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureGround11Baseline
{
 static int i;static double until;static bool waiting;
 static Vector3[] poses={new Vector3(28.5f,14.25f,-10),new Vector3(15,15,-10),new Vector3(27,19,-10),new Vector3(13,7.03125f,-10)};
 static string[] names={"composition","road-connection","open-ground","contacts"};
 public static string Main(){if(!EditorApplication.isPlaying)throw new Exception("Play required");if(Directory.Exists("Docs/Validation/ValdoriaGround11/Before"))throw new IOException("Refuse baseline captures overwrite");Directory.CreateDirectory("Docs/Validation/ValdoriaGround11/Before");var lab=UnityEngine.Object.FindAnyObjectByType<NatureReferenceLab>();lab.Select(3);Camera.main.GetComponent<CameraFollow>().enabled=false;var p=GameObject.Find("Player").GetComponent<Rigidbody2D>();p.position=new Vector2(28.673845f,6.245552f);p.transform.position=p.position;EditorApplication.update+=Tick;return "Queued current scene diagnosis captures";}
 static void Tick(){if(Time.timeAsDouble<until)return;if(waiting){ScreenCapture.CaptureScreenshot(Path.GetFullPath("Docs/Validation/ValdoriaGround11/Before/"+names[i]+".png"));i++;waiting=false;until=Time.timeAsDouble+.3;return;}if(i==poses.Length){EditorApplication.update-=Tick;return;}Camera.main.orthographicSize=i==0?14.0625f:7.03125f;Camera.main.transform.position=poses[i];waiting=true;until=Time.timeAsDouble+.6;}
}
