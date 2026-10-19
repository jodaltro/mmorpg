using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class Village02IntegrationViews
{
 public static async Task<object> Main()
 {
  if(!EditorApplication.isPlaying||UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!="Assets/Mmorpg/Scenes/ValdoriaVillage02Integrated.unity")throw new Exception("Integrated Play required");
  var actor=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();var recorder=new GameObject("TEMP initial integration views").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot("Docs/Validation/ValdoriaVillage02-Integration/InitialViews/");follow.enabled=false;
  foreach(var v in new[]{new{id="overview",p=new Vector2(141,167.5f),ortho=167.5f,actor=new Vector2(116.6f,26.4f)},new{id="entry",p=new Vector2(116.6f,98),ortho=24f,actor=new Vector2(116.6f,91)},new{id="house",p=new Vector2(105.6f,182),ortho=20f,actor=new Vector2(105.6f,172)},new{id="castle",p=new Vector2(190,240),ortho=35f,actor=new Vector2(188,237)}})
  {actor.position=v.actor;actor.transform.position=v.actor;actor.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();camera.transform.position=new Vector3(v.p.x,v.p.y,-10);camera.orthographicSize=v.ortho;await Task.Delay(250);recorder.Capture(v.id,"Initial integration Play inspection; fixed fixture before collision QA");while(recorder.Busy)await Task.Delay(20);}
  actor.position=new Vector2(116.6f,26.4f);actor.transform.position=actor.position;actor.linearVelocity=Vector2.zero;follow.enabled=true;camera.orthographicSize=14.0625f;UnityEngine.Object.Destroy(recorder.gameObject);return new{captured=4,restoredSpawn=true};
 }
}
