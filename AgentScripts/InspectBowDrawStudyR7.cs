using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
public static class InspectBowDrawStudyR7
{
 static Task EndFrame(MonoBehaviour host){var done=new TaskCompletionSource<bool>();host.StartCoroutine(AfterFrame(done));return done.Task;}
 static System.Collections.IEnumerator AfterFrame(TaskCompletionSource<bool> done){yield return new WaitForEndOfFrame();done.SetResult(true);}
 public static async Task<string> Inspect(){
  if(!EditorApplication.isPlaying)throw new Exception("Play required");
  var player=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var animator=player.GetComponent<ProductionSpriteAnimator>();var sword=player.GetComponent<SwordSwing>();var body=animator.Body;var old=body.sprite;bool ae=animator.enabled,se=sword.enabled;var blade=player.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword");bool be=blade.gameObject.activeSelf;
  var sprites=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/BowDrawStudy/BowDraw.png").OfType<Sprite>().OrderBy(s=>s.name).ToArray();if(sprites.Length!=74)throw new Exception("74 frames required");
  var rb=player.GetComponent<Rigidbody2D>();var oldPosition=rb.position;var oldVelocity=rb.linearVelocity;var testPosition=new Vector2(-2.75f,-2.5f);var rows=new List<object>();Directory.CreateDirectory("Temp/HumanoidR7/BowUnity");int first=Time.frameCount;
  try{rb.position=testPosition;rb.linearVelocity=Vector2.zero;await Task.Delay(100);animator.enabled=false;sword.enabled=false;blade.gameObject.SetActive(false);
   for(int view=0;view<2;view++){

    for(int frame=0;frame<37;frame++){double deadline=Time.timeAsDouble+1/24d;body.sprite=sprites[view*37+frame];await EndFrame(player);
     rows.Add(new{view,sourceFrame=frame+1,gameFrame=Time.frameCount,time=Time.timeAsDouble,sprite=body.sprite.name});
     if(new[]{0,8,16,23,29,36}.Contains(frame)){var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes("Temp/HumanoidR7/BowUnity/"+view+"-"+frame.ToString("000")+".png",tex.EncodeToPNG());UnityEngine.Object.Destroy(tex);}
     while(Time.timeAsDouble<deadline)await Task.Delay(5);
    }
   }
  }finally{rb.position=oldPosition;rb.linearVelocity=oldVelocity;body.sprite=old;animator.enabled=ae;sword.enabled=se;blade.gameObject.SetActive(be);}
  if(Time.frameCount<=first||rows.Count!=74)throw new Exception("Frames stalled/skipped");var point=Camera.main.WorldToScreenPoint(testPosition);string json=JsonConvert.SerializeObject(new{firstFrame=first,lastFrame=Time.frameCount,playerPixel=new[]{point.x,Screen.height-point.y},rows,restored=true,scope="24fps diagnostic composite on actual player, two views; no ranged gameplay"},Formatting.Indented);File.WriteAllText("Docs/Validation/HumanoidSwordR7/bow-draw-unity.json",json);return json;
 }
}
