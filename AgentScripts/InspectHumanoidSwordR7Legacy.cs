using System;
using System.IO;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
public static class InspectHumanoidSwordR7Legacy
{
 public static async Task<string> Load(string mode="official"){
 string scene=mode=="official"?"MmorpgWorld":mode=="r6"?"HumanoidCombat8Dir2026":mode=="r5"?"HumanoidOutfit2026":"HumanoidSwordR7";
 Time.timeScale=1;SceneManager.LoadScene("Assets/Mmorpg/Scenes/"+scene+".unity");double until=Time.realtimeSinceStartupAsDouble+.7;while(Time.realtimeSinceStartupAsDouble<until)await Task.Delay(5);
 var player=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var sword=player.GetComponent<SwordSwing>();if(mode=="official"&&sword.OriginPolicy!=SwordSwing.SweepOriginPolicy.LegacyGrip)throw new Exception("Official policy changed");
 string folder="Docs/Validation/HumanoidSwordR7/legacy-"+mode+"/";Directory.CreateDirectory(folder);SessionState.SetString("b11-evidence",folder);
 if(mode=="official")sword.SweepSampled+=(h,t)=>File.AppendAllText(folder+"actual-sweep.jsonl",JsonConvert.SerializeObject(new{time=Time.timeAsDouble,root=player.GetComponent<Rigidbody2D>().position.ToString("R"),origin=h.ToString("R"),tip=t.ToString("R"),range=sword.AuthorizedRange,direction=sword.AttackDirection.ToString("R"),policy=sword.OriginPolicy.ToString()})+"\n");
 return "Loaded "+scene+"; policy="+sword.OriginPolicy+"; isolated="+LocalJourneyProfile.Root.Contains("Temp");
 }
}
