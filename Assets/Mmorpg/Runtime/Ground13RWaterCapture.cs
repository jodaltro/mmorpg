#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
namespace Mmorpg.Runtime
{
 // Editor-only, temporary Play probe. It never sets an animation phase or enters a saved scene.
 public sealed class Ground13RWaterCapture:MonoBehaviour
 {
  [Serializable] public sealed class Shot{public string original,scene;public int phase,renderedFrame,width,height;public double time,realtime;public int[] animatorFrames;public string[] textures;}
  [Serializable] public sealed class Report{public bool realTemporalReplay=true;public string method="WaitForEndOfFrame + CaptureScreenshotAsTexture; phase observed, never forced",error;public List<Shot> captures=new List<Shot>();public string camera;public float ortho;}
  const string Root="Docs/Validation/ValdoriaGround13R/";
  Report report=new Report();Camera camera;CameraFollow follow;bool followed;Vector3 oldPosition;float oldOrtho;Ground13RLab lab;int oldStage;ProductionSpriteAnimator actor;bool actorEnabled;
  public static object Begin(){if(!Application.isPlaying||!LocalJourneyProfile.Root.Contains("Temp")||Directory.Exists(Root+"Original/WaterLive"))throw new IOException("New isolated Play destination required");Directory.CreateDirectory(Root+"Original/WaterLive");new GameObject("Ground13R temporary live water evidence"){hideFlags=HideFlags.DontSave}.AddComponent<Ground13RWaterCapture>();return "Observing twelve real water phase changes after rendered frames; no forced phases";}
  IEnumerator Start(){camera=Camera.main;follow=camera.GetComponent<CameraFollow>();followed=follow.enabled;oldPosition=camera.transform.position;oldOrtho=camera.orthographicSize;follow.enabled=false;camera.transform.position=new Vector3(10,23,-10);camera.orthographicSize=7.03125f;report.camera=camera.transform.position.ToString("R");report.ortho=camera.orthographicSize;lab=FindAnyObjectByType<Ground13RLab>();oldStage=lab.Stage;lab.Select(2);lab.EvidencePhase(-1);actor=GameObject.Find("Player").GetComponent<ProductionSpriteAnimator>();actorEnabled=actor.enabled;actor.enabled=false;var water=FindObjectsByType<WaterSurfaceAnimator>().OrderBy(w=>w.name).ToArray();int previous=-1;double began=Time.realtimeSinceStartupAsDouble;
   while(report.captures.Count<12&&Time.realtimeSinceStartupAsDouble-began<15){yield return new WaitForEndOfFrame();int phase=water[0].FrameIndex;if(phase<0||phase==previous)continue;var indices=water.Select(w=>w.FrameIndex).ToArray();var paths=water.Select(w=>{var p=new MaterialPropertyBlock();w.GetComponent<MeshRenderer>().GetPropertyBlock(p);return AssetDatabase.GetAssetPath(p.GetTexture("_MainTex"));}).ToArray();string path="Original/WaterLive/frame-"+report.captures.Count.ToString("00")+"-phase-"+phase+".png";var texture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.GetFullPath(Root+path),texture.EncodeToPNG());Destroy(texture);report.captures.Add(new Shot{original=path,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,phase=phase,renderedFrame=Time.frameCount,time=Time.timeAsDouble,realtime=Time.realtimeSinceStartupAsDouble,animatorFrames=indices,textures=paths,width=camera.pixelWidth,height=camera.pixelHeight});previous=phase;}
   if(report.captures.Count!=12)report.error="Temporal capture did not complete twelve observed phase changes";File.WriteAllText(Root+"QA/water-live.json",JsonUtility.ToJson(report,true));Destroy(gameObject);
  }
  void OnDestroy(){if(actor)actor.enabled=actorEnabled;if(camera){camera.transform.position=oldPosition;camera.orthographicSize=oldOrtho;}if(follow)follow.enabled=followed;if(lab){lab.Select(oldStage);lab.EvidencePhase(-1);}}
 }
}
#endif
