using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using System.Linq;
using Newtonsoft.Json;
using UnityEngine.Rendering;
using Mmorpg.Runtime;
public static class Village02AnimeFinalViews
{
 public static async Task<object> Main(){const string root="Docs/Validation/ValdoriaVillage02-Anime/FinalDepthV2/";if(!EditorApplication.isPlaying||Directory.Exists(root))throw new Exception("Fresh Play views required");var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();var recorder=new GameObject("TEMP anime final views").AddComponent<Village02EvidenceCapture>();recorder.ConfigureRoot(root);
  void Place(Vector2 p){body.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);body.simulated=false;body.position=p;body.transform.position=p;body.linearVelocity=Vector2.zero;body.simulated=true;Physics2D.SyncTransforms();body.WakeUp();}
  follow.enabled=false;
  try{foreach(var v in new[]{new{id="entry",p=new Vector2(116.6f,98),actor=new Vector2(116.6f,91),ortho=24f},new{id="castle",p=new Vector2(190,240),actor=new Vector2(188,233),ortho=35f},new{id="garden",p=new Vector2(191,237),actor=new Vector2(188,233),ortho=24f},new{id="overview",p=new Vector2(141,167.5f),actor=new Vector2(116.6f,26.4f),ortho=167.5f}}){Place(v.actor);camera.transform.position=new Vector3(v.p.x,v.p.y,-10);camera.orthographicSize=v.ortho;await Task.Delay(200);if(v.id=="garden"){var depths=UnityEngine.Object.FindObjectsByType<OpaqueStructureDepth>(FindObjectsSortMode.None).Where(x=>x.name.StartsWith("Volume:castle-compound-gate-")).Select(x=>new{x.name,x.OccludesActor,x.DepthLine,order=x.GetComponent<SortingGroup>().sortingOrder,actorOrder=body.GetComponent<ProductionSpriteAnimator>().Body.sortingOrder,opaque=x.GetComponentsInChildren<SpriteRenderer>().All(r=>r.color.a==1)}).ToArray();Directory.CreateDirectory(root+"QA");File.WriteAllText(root+"QA/tower-depth.json",JsonConvert.SerializeObject(depths,Formatting.Indented));}recorder.Capture(v.id,"Final opaque revision in actual Play; camera/actor fixtures equal initial views");while(recorder.Busy)await Task.Delay(20);}}
  finally{Place(new Vector2(116.6f,26.4f));follow.enabled=true;camera.orthographicSize=14.0625f;UnityEngine.Object.Destroy(recorder.gameObject);}return "Four final Play views captured";
 }
}
