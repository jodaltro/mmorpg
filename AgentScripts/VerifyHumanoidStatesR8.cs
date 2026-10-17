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
public static class VerifyHumanoidStatesR8
{
 const string E="Docs/Validation/HumanoidStatesR8/";
 static string Hash(string path){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
 static void Check(bool b,string message){if(!b)throw new Exception(message);}
 public static string Inspect(){
  Check(!EditorApplication.isPlaying,"Stop before verification");var frozen=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(E+"protected-files.json"));Check(frozen.All(p=>File.Exists(p.Key)&&Hash(p.Key)==p.Value),"Protected R5/R6/R7/source/rules file changed");var saves=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/HumanoidR8/personal-before.json"));Check(saves.All(p=>File.Exists(p.Key)&&Hash(p.Key)==p.Value),"Personal save changed");
  var old=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset");var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/ValdoriaStatesR8.asset");Check(set.clips.Length==64&&set.clips.Sum(c=>c.frames.Length)==528&&set.eightDirectionPresentation,"Wrong clip contract");int reused=0;
  foreach(var c in old.clips){var n=set.Find(c.action,c.direction);Check(n!=null&&n.loop==c.loop&&n.frames.Length==c.frames.Length,"Old clip changed");for(int i=0;i<c.frames.Length;i++){var a=c.frames[i];var b=n.frames[i];Check(a.sprite==b.sprite&&a.seconds==b.seconds&&a.hand==b.hand&&a.holdAngle==b.holdAngle&&a.depth==b.depth&&a.source==b.source&&a.events.SequenceEqual(b.events),"Old frame metadata changed");reused++;}}
  foreach(string action in new[]{"dodge","death"})for(int d=0;d<8;d++){var clip=set.Find(action,d);Check(!clip.loop&&clip.frames.Length==(action=="dodge"?8:25),"Incomplete state");Check(Math.Abs(clip.Duration-(action=="dodge"?.22:2.4+1d/30))<.00001,"State duration changed");foreach(var f in clip.frames){var sp=f.sprite;Vector2 pivot=action=="dodge"?new Vector2(64,34):new Vector2(128,66);Check(sp.pixelsPerUnit==32&&Vector2.Distance(sp.pivot,pivot)<.0001&&sp.rect.size==(action=="dodge"?new Vector2(128,160):new Vector2(256,224)),"Action canvas/pivot wrong");var importer=(TextureImporter)AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(sp));Check(importer.filterMode==FilterMode.Point&&!importer.mipmapEnabled&&importer.textureCompression==TextureImporterCompression.Uncompressed,"Importer contract wrong");}}
  var preview=UnityEngine.Object.FindAnyObjectByType<WeaponValidationPreview>();var frames=new SerializedObject(preview).FindProperty("bowFrames");var bow=AssetDatabase.LoadAllAssetsAtPath("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/BowAnatomyStudy/BowDraw.png").OfType<Sprite>().OrderBy(s=>s.name).ToArray();Check(frames.arraySize==74&&Enumerable.Range(0,74).All(i=>frames.GetArrayElementAtIndex(i).objectReferenceValue==bow[i]),"Approved bow references changed");
  var baseline=JArray.Parse(File.ReadAllText(E+"build-before.json"));var current=EditorBuildSettings.globalScenes;Check(current.Length==baseline.Count+1,"Unexpected build count");for(int i=0;i<baseline.Count;i++)Check(current[i].path==(string)baseline[i]["path"]&&current[i].enabled==(bool)baseline[i]["enabled"],"Existing build entry changed");Check(current.Last().path.EndsWith("HumanoidStatesR8.unity")&&File.ReadAllText("ProjectSettings/EditorBuildSettings.asset").Contains("HumanoidStatesR8.unity"),"R8 build append not persisted");Check(LocalJourneyProfile.ValidationRootOverride==null&&Time.timeScale==1&&!InputSystem.devices.Any(d=>d.name=="AnimationKeyboard"||d.name=="AnimationMouse"),"QA state not restored");
  string json=JsonConvert.SerializeObject(new{passed=true,protectedFiles=frozen.Count,personalFiles=saves.Count,reusedFrames=reused,walkFramesIdentical=104,newDodgeFrames=64,newDeathFrames=200,clips=64,frames=528,approvedBowFramesIdentical=74,officialEntry=current[0].path,onlyR8Appended=true,inputAndProfileRestored=true,scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path},Formatting.Indented);File.WriteAllText(E+"preservation.json",json);return json;
 }
}
