using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using Newtonsoft.Json;
using Mmorpg.Runtime;
public static class ReviewArchitecture07R
{
 const string Output="Docs/Validation/ValdoriaWorldStudio07R/NativeReview";
 static Camera camera; static GameObject house,access;static double until;static int phase;static object baseline,visible;
 static object Cost()=>new{frame=Time.frameCount,drawCalls=UnityStats.drawCalls,sceneRenderers=UnityEngine.Object.FindObjectsByType<Renderer>().Count(r=>r.enabled),cameraPixels=new[]{camera.pixelWidth,camera.pixelHeight},orthographicSize=camera.orthographicSize};
 public static string Main(){if(!EditorApplication.isPlaying||Directory.Exists(Output))throw new IOException("Requires Play and absent review destination");Directory.CreateDirectory(Output);camera=Camera.main;camera.GetComponent<CameraFollow>().enabled=false;house=UnityEngine.Object.FindAnyObjectByType<ArchitectureBuilding>().gameObject;access=GameObject.Find("Reference pedestrian access");house.SetActive(false);access.SetActive(false);camera.orthographicSize=14.5f;camera.transform.position=new Vector3(32,16,-10);until=Time.timeAsDouble+.5;EditorApplication.update+=Tick;return "One-pixel-per-screen-pixel roof/wall captures and controlled renderer cost";}
 static void Capture(string name)=>ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+name+".png"));
 static void Tick(){if(Time.timeAsDouble<until)return;until=Time.timeAsDouble+.5;switch(phase++){
 case 0:baseline=Cost();house.SetActive(true);access.SetActive(true);break;
 case 1:visible=Cost();camera.orthographicSize=11.25f;camera.transform.position=new Vector3(34,22,-10);break;
 case 2:Capture("roof-1to1");break;
 case 3:camera.transform.position=new Vector3(32,10.1f,-10);break;
 case 4:Capture("walls-1to1");break;
 default:EditorApplication.update-=Tick;File.WriteAllText(Output+"/review.json",JsonConvert.SerializeObject(new{baseline,withReference=visible,nativeRatio=720f/(2*11.25f*32),frame=Time.frameCount},Formatting.Indented));break;
 }}
}
