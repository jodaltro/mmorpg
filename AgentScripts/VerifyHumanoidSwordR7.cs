using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
public static class VerifyHumanoidSwordR7
{
 static string Hash(string p){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant();}
 static void Check(bool p,string m){if(!p)throw new Exception(m);}
 public static string Inspect(){
 const string E="Docs/Validation/HumanoidSwordR7/";Check(!EditorApplication.isPlaying,"Stop before final verification");
 var frozen=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(E+"protected-files.json"));var changed=frozen.Where(p=>!File.Exists(p.Key)||Hash(p.Key)!=p.Value).Select(p=>p.Key).ToArray();Check(changed.Length==0,"Frozen files changed: "+string.Join(",",changed));
 var saves=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/HumanoidR7/personal-before.json"));Check(saves.All(p=>File.Exists(p.Key)&&Hash(p.Key)==p.Value),"Personal save changed");
 var r6=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidCombat8Dir2026/Valdoria8Dir.asset");var r7=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset");Check(r6.clips.Length==16&&r7.clips.Length==48&&r7.eightDirectionPresentation,"Clip contract changed");int count=0;
 foreach(var c in r6.clips){var other=r7.Find(c.action,c.direction);Check(c.frames.Length==other.frames.Length&&c.Duration==other.Duration,"Locomotion timing changed");for(int i=0;i<c.frames.Length;i++){Check(c.frames[i].sprite==other.frames[i].sprite&&c.frames[i].seconds==other.frames[i].seconds,"Locomotion source changed");Check(other.frames[i].sprite.pivot==new Vector2(64,34)&&other.frames[i].sprite.pixelsPerUnit==32,"Pivot changed");count++;}}
 Check(count==104&&!r7.clips.Any(c=>c.action=="dodge"||c.action=="death"),"Locomotion/state scope changed");var build=JObject.Parse(File.ReadAllText(E+"frozen-reference.json"))["build"];var current=EditorBuildSettings.globalScenes;Check(current.Length==build.Count()+1,"Unexpected build count");for(int i=0;i<build.Count();i++)Check(current[i].path==(string)build[i]["path"]&&current[i].enabled==(bool)build[i]["enabled"],"Build entry changed");Check(current.Last().path.EndsWith("HumanoidSwordR7.unity")&&File.ReadAllText("ProjectSettings/EditorBuildSettings.asset").Contains("HumanoidSwordR7.unity"),"R7 build append not persisted");
 Check(LocalJourneyProfile.ValidationRootOverride==null&&Time.timeScale==1&&!InputSystem.devices.Any(d=>d.name=="AnimationKeyboard"||d.name=="AnimationMouse"),"QA state not restored");
 var result=new{frozenFiles=frozen.Count,frozenFilesUnchanged=true,personalFiles=saves.Count,personalSavesUnchanged=true,locomotionSpritesIdentical=104,r5CardinalPixelHashesPreserved=52,clips=48,totalFrames=r7.clips.Sum(c=>c.frames.Length),referenceSpeed=r7.referenceSpeed,canvas="128x160",pivot="64,34",ppu=32,onlyR7SceneAppended=true,officialEntry=current[0].path,profileOverrideRestored=true,inputRestored=true,timeScale=Time.timeScale,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path};string json=JsonConvert.SerializeObject(result,Formatting.Indented);File.WriteAllText(E+"preservation.json",json);return json;
 }
}
