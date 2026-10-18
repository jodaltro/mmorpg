using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class ValidateWaterAnimation05
{
 static int last=-1,captures,first;static readonly List<object> records=new List<object>();static WaterSurfaceAnimator animator;static Texture2D[] frames;static MeshRenderer surface;
 const string Output="Docs/Validation/ValdoriaWorldStudio05/Final/StaticWater";
 public static string Main()
 {
  if(!EditorApplication.isPlaying||!LocalJourneyProfile.Root.Contains("Temp"))throw new IOException("Requires isolated Play");if(Directory.Exists(Output))throw new IOException("Refuse existing static animation QA");Directory.CreateDirectory(Output);
  var cam=Camera.main;cam.GetComponent<CameraFollow>().enabled=false;cam.transform.position=new Vector3(20,23,-10);var lab=UnityEngine.Object.FindAnyObjectByType<HydrologyLabController>();lab.SetWater(true);lab.ResetPose();
  animator=UnityEngine.Object.FindObjectsByType<WaterSurfaceAnimator>().First(a=>a.name=="Water chunk 0-2");surface=animator.GetComponent<MeshRenderer>();var f=new SerializedObject(animator).FindProperty("frames");frames=Enumerable.Range(0,4).Select(i=>(Texture2D)f.GetArrayElementAtIndex(i).objectReferenceValue).ToArray();first=Time.frameCount;EditorApplication.update+=Tick;return "Eight native frames, two cycles, fixed camera and shader texture verification";
 }
 static void Tick()
 {
  if(animator.FrameIndex<0||animator.FrameIndex==last)return;last=animator.FrameIndex;var block=new MaterialPropertyBlock();surface.GetPropertyBlock(block);var texture=block.GetTexture("_MainTex");string name=captures.ToString("00")+"-phase"+last+".png";ScreenCapture.CaptureScreenshot(Path.GetFullPath(Output+"/"+name));records.Add(new{capture=name,frame=Time.frameCount,phase=last,shaderTextureMatches=texture==frames[last],camera=Camera.main.transform.position.ToString(),width=Camera.main.pixelWidth,height=Camera.main.pixelHeight});captures++;
  if(captures<8)return;EditorApplication.update-=Tick;File.WriteAllText(Output+"/animation-qa.json",JsonConvert.SerializeObject(new{framesAdvanced=Time.frameCount-first,records},Formatting.Indented));
 }
}
