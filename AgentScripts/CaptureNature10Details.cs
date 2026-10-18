using System;
using System.IO;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureNature10Details
{
 static int index;static double until;static bool waiting;static Camera camera;
 static readonly Vector3[] points={new Vector3(13,12.5f,-10),new Vector3(13,7.03125f,-10),new Vector3(30,7.03125f,-10)};
 static readonly string[] names={"canopy","trunks-rocks-contact","entrance"};
 public static string Main(){if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Isolated Play required");if(Directory.Exists("Docs/Validation/ValdoriaNature10/Details"))throw new IOException("Refuse captures overwrite");Directory.CreateDirectory("Docs/Validation/ValdoriaNature10/Details");camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;camera.orthographicSize=7.03125f;var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();body.position=new Vector2(28.673845f,6.245552f);body.transform.position=body.position;UnityEngine.Object.FindAnyObjectByType<NatureReferenceLab>().Select(3);EditorApplication.update+=Tick;return "Three real rendered detail captures queued";}
 static void Tick(){if(!EditorApplication.isPlaying){EditorApplication.update-=Tick;return;}if(Time.timeAsDouble<until)return;if(waiting){ScreenCapture.CaptureScreenshot(Path.GetFullPath("Docs/Validation/ValdoriaNature10/Details/"+names[index]+".png"));index++;waiting=false;until=Time.timeAsDouble+.3;return;}if(index==points.Length){EditorApplication.update-=Tick;return;}camera.transform.position=points[index];waiting=true;until=Time.timeAsDouble+.6;}
}
