using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class RoyalGardensViews
{
 public static async Task<object> Main(){const string root="Docs/Validation/ValdoriaRoyalGardens/Preview/";if(!EditorApplication.isPlaying||Directory.Exists(root))throw new Exception("Fresh Play views required");var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();var recorder=new GameObject("TEMP anime initial views").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot(root);
  void Place(Vector2 p){body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.simulated=false;body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;body.simulated=true;Physics2D.SyncTransforms();body.WakeUp();}
  follow.enabled=false;
  try{foreach(var v in new[]{new{id="entry",p=new Vector2(116.6f,98),actor=new Vector2(116.6f,91),ortho=24f},new{id="royal-precinct",p=new Vector2(182,226),actor=new Vector2(182,191),ortho=59f},new{id="fountain",p=new Vector2(182,203),actor=new Vector2(178,195),ortho=14.0625f},new{id="overview",p=new Vector2(141,167.5f),actor=new Vector2(116.6f,26.4f),ortho=167.5f}}){Place(v.actor);camera.transform.position=new Vector3(v.p.x,v.p.y,-10);camera.orthographicSize=v.ortho;await Task.Delay(200);recorder.Capture(v.id,"Initial anime-directed actual Play inspection; fixed review fixture before full QA");while(recorder.Busy)await Task.Delay(20);}}
  finally{Place(new Vector2(116.6f,26.4f));follow.enabled=true;camera.orthographicSize=14.0625f;UnityEngine.Object.Destroy(recorder.gameObject);}return "Four initial Play views captured";
 }
}
