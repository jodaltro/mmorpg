using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class BuildHumanoidCombat8Dir2026
{
    public const string ScenePath="Assets/Mmorpg/Scenes/HumanoidCombat8Dir2026.unity";
    const string Original="Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity";
    const string Evidence="Docs/Validation/HumanoidCombat8Dir2026/";
    const string Art="Assets/Mmorpg/Art/Experimental/HumanoidCombat8Dir2026/";
    const string Lab="ArtSource/Labs/Humanoid2026/R6/Locomotion/";
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    static Dictionary<string,Sprite> ImportAtlas(string outfit,string sourceLab=null,int expected=104)
    {
        string source=sourceLab??Lab;
        var data=JObject.Parse(File.ReadAllText(source+"aseprite.json"));
        Check(data["frames"].Count()==expected,"Expected 104 native body frames");
        string path=Art+outfit+".png";Check(!File.Exists(path),"Refusing atlas overwrite");
        Directory.CreateDirectory(Art);File.Copy(source+"spritesheet.png",path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);
        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
        importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=4096;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        importer.GetSourceTextureWidthAndHeight(out int width,out int height);
        int w=128,h=160;
        var pivot=new Vector2(.5f,34f/160f);
        var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var rects=data["frames"].Select((f,i)=>new SpriteRect{name="pose_"+i.ToString("000"),rect=new Rect((int)f["frame"]["x"],height-(int)f["frame"]["y"]-h,w,h),alignment=SpriteAlignment.Custom,pivot=pivot,spriteID=GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
        var sprites=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
        Check(sprites.Count==expected&&sprites.Values.All(s=>s.pixelsPerUnit==32&&s.pivot==new Vector2(64,34)),"Wrong sprite import/pivot");return sprites;
    }
    public static string Create()
    {
        Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty,"Clean stopped scene required");
        Check(!File.Exists(ScenePath)&&!File.Exists(Art+"Valdoria8Dir.asset"),"Refusing existing scene/character overwrite");
        var sprites=ImportAtlas("Valdoria8Dir");
        var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");
        var set=UnityEngine.Object.Instantiate(original);set.characterId="quaternius-r6-eight-direction-locomotion-gate";
        set.eightDirectionPresentation=true;
        var manifest=JObject.Parse(File.ReadAllText(Lab+"manifest.json"));var timing=JObject.Parse(File.ReadAllText(Lab+"aseprite.json"));
        set.clips=manifest["clips"].Select(c=>new ProductionClip{action=(string)c["action"],direction=(int)c["direction"],loop=true,status="experimental-eight-directions",frames=Enumerable.Range((int)c["first"]-1,(int)c["last"]-(int)c["first"]+1).Select(i=>new ProductionFrame{sprite=sprites["pose_"+i.ToString("000")],seconds=(float)timing["frames"][i]["duration"]/1000,source="R6 "+(string)c["name"]+" frame"+i}).ToArray()}).ToArray();
        AssetDatabase.CreateAsset(set,Art+"Valdoria8Dir.asset");
        AssetDatabase.SaveAssets();AssetDatabase.ImportAsset(Art+"Valdoria8Dir.asset",ImportAssetOptions.ForceSynchronousImport);
        Check(AssetDatabase.CopyAsset(Original,ScenePath),"Scene copy failed");EditorSceneManager.OpenScene(ScenePath);
        set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"Valdoria8Dir.asset");
        Check(set!=null,"Persistent CharacterSet missing");
        var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();
        var serialized=new SerializedObject(animator);serialized.FindProperty("art").objectReferenceValue=set;serialized.ApplyModifiedPropertiesWithoutUndo();animator.Body.sprite=sprites["pose_000"];
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());Check(EditorSceneManager.SaveScene(SceneManager.GetActiveScene()),"Scene save failed");
        var scenes=EditorBuildSettings.globalScenes.ToList();Check(scenes[0].path=="Assets/Mmorpg/Scenes/MmorpgWorld.unity","Official entry changed");scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();AssetDatabase.SaveAssets();
        return "Created R6 eight-direction scene; cloned approved clips/directions/timings; original motor and world retained.";
    }
    public static string IntegrateCombatCandidate()
    {
        Check(!EditorApplication.isPlaying&&SceneManager.GetActiveScene().path==ScenePath&&!SceneManager.GetActiveScene().isDirty,"Clean stopped R6 scene required");
        const string combatLab="ArtSource/Labs/Humanoid2026/R6/CombatCandidate/";
        Check((bool)JObject.Parse(File.ReadAllText(combatLab+"qa.json"))["eligibleForIntegration"],"Cropped combat frames rejected");
        Check(!File.Exists(Art+"ValdoriaCombatCandidate.asset"),"Refusing combat asset overwrite");
        var sprites=ImportAtlas("CombatCandidate",combatLab,160);
        var locomotion=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"Valdoria8Dir.asset");var set=UnityEngine.Object.Instantiate(locomotion);set.characterId="quaternius-r6-partial-attack-hurt-no-dodge-death";
        var poses=JArray.Parse(File.ReadAllText(Lab+"pose-metadata.json"));int index=0;
        foreach(var clip in set.clips)foreach(var frame in clip.frames)
        {
            var p=poses[index++];JToken hand=p["hand"]??p["rightHand"]["pixel"];JToken tip=p["handTip"]??p["rightHand"]["boneAxisPixel"];
            float x=(float)hand[0]+((float)tip[0]-(float)hand[0])*.45f,y=(float)hand[1]+((float)tip[1]-(float)hand[1])*.45f;
            frame.hand=new Vector2((x-64)/32,(126-y)/32);
            frame.holdAngle=Mathf.Atan2(-((float)tip[1]-(float)hand[1]),(float)tip[0]-(float)hand[0])*Mathf.Rad2Deg;
            if(p["rightHand"]!=null)frame.depth=(string)p["rightHand"]["occlusionHint"]=="behind"?-1:1;
            else{float angle=(float)p["cameraDegrees"]*Mathf.Deg2Rad;var camera=new Vector3(8*Mathf.Sin(angle),-8*Mathf.Cos(angle),5.5f);var forward=(new Vector3(0,0,.9f)-camera).normalized;var b=p["skeleton"]["pelvis"];float z=Vector3.Dot(new Vector3((float)b[0][3],(float)b[1][3],(float)b[2][3])-camera,forward);frame.depth=(float)hand[2]>z+.03f?-1:1;}
        }
        var manifest=JObject.Parse(File.ReadAllText(combatLab+"manifest.json"));var extra=new List<ProductionClip>();
        foreach(var clip in manifest["clips"])
        {
            var frames=new List<ProductionFrame>();int first=(int)clip["first"]-1,last=(int)clip["last"]-1;
            for(int i=first;i<=last;i++)
            {
                var p=manifest["frames"][i];var hand=p["hand"];var tip=p["handTip"];
                frames.Add(new ProductionFrame{sprite=sprites["pose_"+i.ToString("000")],seconds=(float)p["seconds"],hand=new Vector2(((float)hand[0]+((float)tip[0]-(float)hand[0])*.45f-64)/32,(126-((float)hand[1]+((float)tip[1]-(float)hand[1])*.45f))/32),holdAngle=(float)p["handAngle"],depth=(int)p["depth"],source="R6 "+(string)p["sourceAction"]+" sourceFrame "+(string)p["sourceFrame"]});
            }
            extra.Add(new ProductionClip{action=(string)clip["action"],direction=(int)clip["direction"],loop=false,status="candidate-needs-artistic-review",frames=frames.ToArray()});
        }
        set.clips=set.clips.Concat(extra).ToArray();AssetDatabase.CreateAsset(set,Art+"ValdoriaCombatCandidate.asset");AssetDatabase.SaveAssets();AssetDatabase.ImportAsset(Art+"ValdoriaCombatCandidate.asset",ImportAssetOptions.ForceSynchronousImport);
        set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaCombatCandidate.asset");
        var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();var so=new SerializedObject(animator);so.FindProperty("art").objectReferenceValue=set;so.ApplyModifiedPropertiesWithoutUndo();
        animator.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.SetActive(true);
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());return "Partial combat candidate integrated: eight-direction attack phases and Hurt; Roll/Death rejected for canvas clipping. Sword size and Sweep code unchanged.";
    }
    public static string KeepValidatedLocomotion()
    {
        Check(!EditorApplication.isPlaying&&SceneManager.GetActiveScene().path==ScenePath,"Stop in the R6 scene first");
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"Valdoria8Dir.asset");set.characterId="quaternius-r6-eight-direction-locomotion-gate";EditorUtility.SetDirty(set);AssetDatabase.SaveAssets();
        var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();var so=new SerializedObject(animator);so.FindProperty("art").objectReferenceValue=set;so.ApplyModifiedPropertiesWithoutUndo();
        animator.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.SetActive(false);animator.Body.sprite=set.Find("idle",0).frames[0].sprite;
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());return "Main R6 scene restored to passed locomotion gate. Failed combat candidate retained separately as an asset and evidence, with sword hidden in the playable gate.";
    }
    public static string Verify()
    {
        var protectedFiles=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"protected-files.json"));Check(protectedFiles.All(p=>Hash(p.Key)==p.Value),"A frozen reference changed");
        var personal=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/HumanoidR6/personal-before.json"));Check(personal.All(p=>Hash(p.Key)==p.Value),"A personal save changed");
        var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"Valdoria8Dir.asset");
        Check(set.eightDirectionPresentation&&set.clips.Length==16,"Eight direction locomotion contract");
        var r5=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidOutfit2026/ValdoriaSwordsman.asset");
        foreach(var a in r5.clips){var b=set.Find(a.action,a.direction);Check(b!=null&&b.frames.Length==a.frames.Length&&b.Duration==a.Duration,"Cardinal timing changed");for(int j=0;j<a.frames.Length;j++)Check(a.frames[j].sprite.pivot==b.frames[j].sprite.pivot&&a.frames[j].sprite.pixelsPerUnit==b.frames[j].sprite.pixelsPerUnit,"Pivot or PPU changed");}
        var entries=JObject.Parse(File.ReadAllText(Evidence+"frozen-reference.json"))["build"];var current=EditorBuildSettings.globalScenes;Check(current.Length==entries.Count()+1&&current.Last().path==ScenePath,"Build delta unexpected");for(int i=0;i<entries.Count();i++)Check(current[i].path==(string)entries[i]["path"]&&current[i].enabled==(bool)entries[i]["enabled"],"Existing build entry changed");
        var report=new{protectedFiles=protectedFiles.Count,frozenFilesUnchanged=true,personalFiles=personal.Count,personalSavesUnchanged=true,clipsAndTimingsIdentical=true,pivotsAndPpuIdentical=true,onlyNewSceneAppended=true};string json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"preservation.json",json);return json;
    }
}
