using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;
public static class FreezeHumanoidOutfit2026
{
 public static string Record(){
  string root="Docs/Validation/HumanoidOutfit2026/";Directory.CreateDirectory(root);Directory.CreateDirectory("Temp/HumanoidR5");
  if(File.Exists(root+"frozen-reference.json"))throw new Exception("Refusing snapshot overwrite");
  var a=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();var cam=Camera.main;
  var protectedFiles=new Dictionary<string,string>();
  foreach(string dir in new[]{"ArtSource/Labs/Humanoid2026/Sources","ArtSource/Labs/Humanoid2026/Preview","Assets/Mmorpg/Art/Experimental/HumanoidScale2026","Assets/Mmorpg/Art/Production/IronKnight","Assets/Mmorpg/Runtime","Assets/Mmorpg/Domain","ArtSource/Labs/NpcResearch"})foreach(string p in Directory.GetFiles(dir,"*",SearchOption.AllDirectories))protectedFiles[p.Replace('\\','/')]=Hash(p);
  foreach(string p in new[]{"Assets/Mmorpg/Scenes/MmorpgWorld.unity","Assets/Mmorpg/Scenes/HumanoidScale2026.unity"})protectedFiles[p]=Hash(p);
  File.WriteAllText(root+"protected-files.json",JsonConvert.SerializeObject(protectedFiles,Formatting.Indented));
  var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");
  File.WriteAllText(root+"frozen-reference.json",JsonConvert.SerializeObject(new{playing=EditorApplication.isPlaying,position=a.transform.position.ToString("R"),bodyScale=a.Body.transform.lossyScale.ToString("R"),camera=cam.transform.position.ToString("R"),zoom=cam.orthographicSize,clips=set.clips.Select(c=>new{c.action,c.direction,c.loop,duration=c.Duration,frames=c.frames.Select(f=>new{sprite=f.sprite.name,f.seconds,pivot=f.sprite.pivot.ToString("R"),f.source})}),build=EditorBuildSettings.globalScenes.Select(s=>new{s.path,s.enabled}),sourceRender="Tools/ArtPipeline/inspect_humanoid_study.py; same camera/light/sampling must be reused"},Formatting.Indented));
  string personal=Path.Combine(Application.persistentDataPath,"DevelopmentJourneys","marco06b4");var saves=new Dictionary<string,string>();foreach(string n in new[]{"profile.json","journey.json","journey.json.bak","marco06b1-exploration.json","marco06b1-exploration.json.bak","decision-cache.json"}){string p=Path.Combine(personal,n);if(File.Exists(p))saves[p]=Hash(p);}File.WriteAllText("Temp/HumanoidR5/personal-before.json",JsonConvert.SerializeObject(saves));return "Frozen "+protectedFiles.Count+" files and "+saves.Count+" personal save hashes.";
 }
 static string Hash(string p){using(var s=SHA256.Create())return BitConverter.ToString(s.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
}
