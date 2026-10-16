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

public static class BuildHumanoidOutfit2026
{
    public const string ScenePath="Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity";
    const string Original="Assets/Mmorpg/Scenes/HumanoidScale2026.unity";
    const string Evidence="Docs/Validation/HumanoidOutfit2026/";
    const string Art="Assets/Mmorpg/Art/Experimental/HumanoidOutfit2026/";
    const string Lab="ArtSource/Labs/Humanoid2026/R5/Results/";
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    static Dictionary<string,Sprite> ImportAtlas(string outfit)
    {
        var data=JObject.Parse(File.ReadAllText(Lab+"aseprite.json"));
        Check(data["frames"].Count()==52,"Expected 52 native body frames");
        string path=Art+outfit+".png";Check(!File.Exists(path),"Refusing atlas overwrite");
        Directory.CreateDirectory(Art);File.Copy(Lab+"spritesheet.png",path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);
        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
        importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=2048;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        importer.GetSourceTextureWidthAndHeight(out int width,out int height);
        int w=128,h=160;
        var pivot=new Vector2(.5f,34f/160f);
        var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var rects=data["frames"].Select((f,i)=>new SpriteRect{name="pose_"+i.ToString("000"),rect=new Rect((int)f["frame"]["x"],height-(int)f["frame"]["y"]-h,w,h),alignment=SpriteAlignment.Custom,pivot=pivot,spriteID=GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
        var sprites=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
        Check(sprites.Count==52&&sprites.Values.All(s=>s.pixelsPerUnit==32&&s.pivot==new Vector2(64,34)),"Wrong sprite import/pivot");return sprites;
    }
    public static string Create()
    {
        Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty,"Clean stopped scene required");
        Check(!File.Exists(ScenePath)&&!File.Exists(Art+"ValdoriaSwordsman.asset"),"Refusing existing scene/character overwrite");
        var sprites=ImportAtlas("ValdoriaSwordsman");
        var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");
        var set=UnityEngine.Object.Instantiate(original);set.characterId="valdoria-swordsman-outfit-r5";
        foreach(var clip in set.clips)foreach(var frame in clip.frames)frame.sprite=sprites[frame.sprite.name];
        AssetDatabase.CreateAsset(set,Art+"ValdoriaSwordsman.asset");
        AssetDatabase.SaveAssets();AssetDatabase.ImportAsset(Art+"ValdoriaSwordsman.asset",ImportAssetOptions.ForceSynchronousImport);
        Check(AssetDatabase.CopyAsset(Original,ScenePath),"Scene copy failed");EditorSceneManager.OpenScene(ScenePath);
        set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaSwordsman.asset");
        Check(set!=null,"Persistent CharacterSet missing");
        var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();
        var serialized=new SerializedObject(animator);serialized.FindProperty("art").objectReferenceValue=set;serialized.ApplyModifiedPropertiesWithoutUndo();animator.Body.sprite=sprites["pose_000"];
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());Check(EditorSceneManager.SaveScene(SceneManager.GetActiveScene()),"Scene save failed");
        var scenes=EditorBuildSettings.globalScenes.ToList();Check(scenes[0].path=="Assets/Mmorpg/Scenes/MmorpgWorld.unity","Official entry changed");scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();AssetDatabase.SaveAssets();
        return "Created R5 outfit scene; cloned approved clips/directions/timings; original motor and world retained.";
    }
    public static string Verify()
    {
        var protectedFiles=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"protected-files.json"));Check(protectedFiles.All(p=>Hash(p.Key)==p.Value),"A frozen reference changed");
        var personal=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/HumanoidR5/personal-before.json"));Check(personal.All(p=>Hash(p.Key)==p.Value),"A personal save changed");
        var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidScale2026/MalePlayer.asset");var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"ValdoriaSwordsman.asset");
        Check(set.referenceSpeed==original.referenceSpeed&&set.pixelsPerUnit==original.pixelsPerUnit&&set.clips.Length==original.clips.Length,"Character contract changed");
        for(int i=0;i<set.clips.Length;i++){var a=original.clips[i];var b=set.clips[i];Check(a.action==b.action&&a.direction==b.direction&&a.loop==b.loop&&a.frames.Length==b.frames.Length,"Clip contract changed");for(int j=0;j<a.frames.Length;j++)Check(a.frames[j].seconds==b.frames[j].seconds&&a.frames[j].sprite.name==b.frames[j].sprite.name&&a.frames[j].sprite.pivot==b.frames[j].sprite.pivot&&a.frames[j].sprite.pixelsPerUnit==b.frames[j].sprite.pixelsPerUnit,"Frame contract changed");}
        var entries=JObject.Parse(File.ReadAllText(Evidence+"frozen-reference.json"))["build"];var current=EditorBuildSettings.globalScenes;Check(current.Length==entries.Count()+1&&current.Last().path==ScenePath,"Build delta unexpected");for(int i=0;i<entries.Count();i++)Check(current[i].path==(string)entries[i]["path"]&&current[i].enabled==(bool)entries[i]["enabled"],"Existing build entry changed");
        var report=new{protectedFiles=protectedFiles.Count,frozenFilesUnchanged=true,personalFiles=personal.Count,personalSavesUnchanged=true,clipsAndTimingsIdentical=true,pivotsAndPpuIdentical=true,onlyNewSceneAppended=true};string json=JsonConvert.SerializeObject(report,Formatting.Indented);File.WriteAllText(Evidence+"preservation.json",json);return json;
    }
}
