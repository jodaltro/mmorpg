using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Mmorpg.Domain;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class BuildGarmentLab06B13R3
{
    public const string ScenePath="Assets/Mmorpg/Scenes/Marco06B13R3Wardrobe.unity";
    public const string Official="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    public const string Evidence="Docs/Validation/Marco06B13R3/";
    public const string Art="Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3/";
    public const string Source="ArtSource/Labs/NpcResearch/Marco06B13R3/MiraTravellerCorrected/";
    static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static void Outside()=>Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty,"Clean scene outside Play required");
    static JourneyInteractable Mira()=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Interactions.Single(i=>i.Kind==InteractionKind.Mira);
    public static string Preflight()
    {
        Outside();Check(LocalJourneyProfile.ValidationRootOverride==null,"Validation profile override already active");
        Check(SceneManager.GetActiveScene().path==Official,"Open clean official scene first");
        Check(!File.Exists(ScenePath),"Refusing to overwrite existing scene");Directory.CreateDirectory(Evidence);Directory.CreateDirectory("Temp/Marco06B13R3");
        Check(!File.Exists(Evidence+"official-before.json"),"Refusing to replace initial preservation snapshot");
        var hashes=new Dictionary<string,string>();
        foreach(var path in Directory.GetFiles("Assets/Mmorpg/Art/Production/IronKnight","*",SearchOption.AllDirectories))hashes[path.Replace('\\','/')]=Hash(path);
        foreach(var path in new[]{Official,Official+".meta","ArtSource/Characters/IronKnight/manifest.json"})hashes[path]=Hash(path);
        File.WriteAllText(Evidence+"official-before.json",JsonConvert.SerializeObject(hashes,Formatting.Indented));
        var personal=new Dictionary<string,string>();foreach(var name in new[]{"profile.json","journey.json","journey.json.bak","journey.json.tmp","marco06b1-exploration.json","marco06b1-exploration.json.bak","marco06b1-exploration.json.tmp","decision-cache.json"}){string path=Path.Combine(LocalJourneyProfile.Root,name);if(File.Exists(path))personal[path]=Hash(path);}
        File.WriteAllText("Temp/Marco06B13R3/personal-before.json",JsonConvert.SerializeObject(personal));
        File.WriteAllText(Evidence+"build-before.json",JsonConvert.SerializeObject(EditorBuildSettings.globalScenes.Select(s=>new{s.path,s.enabled}),Formatting.Indented));
        var mira=Mira();File.WriteAllText(Evidence+"mira-before.json",JsonConvert.SerializeObject(new{name=mira.name,position=mira.transform.position.ToString("R"),scale=mira.transform.localScale.ToString("R"),collider=EditorJsonUtility.ToJson(mira.GetComponent<Collider2D>()),interaction=EditorJsonUtility.ToJson(mira)},Formatting.Indented));
        return "Preflight saved official hashes, narrative/collider bindings and private personal hashes; no assets changed.";
    }
    public static string ImportAndCreate()
    {
        Outside();Check(SceneManager.GetActiveScene().path==Official,"Official source scene required");Check(File.Exists(Evidence+"official-before.json"),"Preflight required");Check(!File.Exists(ScenePath),"Refusing scene overwrite");
        var data=JObject.Parse(File.ReadAllText(Source+"manifest.json"));Check((string)data["schema"]=="npc-procedural-garment-v1","Wrong source contract");
        var frames=data["frames"].ToArray();Check(frames.Length==44,"Unexpected source frame count");
        Directory.CreateDirectory(Art);File.Copy(Source+"spritesheet.png",Art+"MiraTraveller.png",false);AssetDatabase.Refresh();string path=Art+"MiraTraveller.png";
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
        importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=1024;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        importer.GetSourceTextureWidthAndHeight(out int width,out int height);Check(width==512&&height==384,"Atlas layout changed");
        var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var rects=frames.Select((f,i)=>new SpriteRect{name="pose_"+i.ToString("000"),rect=new Rect((int)f["rect"]["x"],height-(int)f["rect"]["y"]-64,64,64),alignment=SpriteAlignment.Custom,pivot=new Vector2(.5f,1-44f/64),spriteID=GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
        var sprites=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);Check(sprites.Count==44,"Sprite import lost frames");
        Check(AssetDatabase.CopyAsset(Official,ScenePath),"Scene copy failed");EditorSceneManager.OpenScene(ScenePath);var mira=Mira();
        int idle=(int)data["clips"].First(c=>(string)c["name"]=="idle_south")["first"]-1;mira.GetComponent<SpriteRenderer>().sprite=sprites["pose_"+idle.ToString("000")];
        EditorUtility.SetDirty(mira.GetComponent<SpriteRenderer>());EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());Check(EditorSceneManager.SaveScene(SceneManager.GetActiveScene()),"Scene save failed");
        // Append for F5/scene-path reload while preserving every existing entry and index zero.
        var scenes=EditorBuildSettings.globalScenes.ToList();Check(scenes[0].path==Official,"Official entry changed");scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();AssetDatabase.SaveAssets();
        return "Experimental scene created with one visual replacement (Mira). Static presentation retained; 44 generated poses available for inspection. Official entry preserved.";
    }
    public static string Verify()
    {
        Outside();var before=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"official-before.json"));Check(before.All(p=>Hash(p.Key)==p.Value),"Official scene/hero changed");
        var personal=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/Marco06B13R3/personal-before.json"));Check(personal.All(p=>Hash(p.Key)==p.Value),"Personal file changed");
        var entries=JArray.Parse(File.ReadAllText(Evidence+"build-before.json"));var current=EditorBuildSettings.globalScenes;Check(current.Length==entries.Count+1&&current.Last().path==ScenePath&&current[0].path==Official,"Unexpected build delta");for(int i=0;i<entries.Count;i++)Check(current[i].path==(string)entries[i]["path"]&&current[i].enabled==(bool)entries[i]["enabled"],"Existing build entry changed");
        Check(SceneManager.GetActiveScene().path==ScenePath,"Experimental scene required");var saved=JObject.Parse(File.ReadAllText(Evidence+"mira-before.json"));var mira=Mira();
        Check(mira.name==(string)saved["name"]&&mira.transform.position.ToString("R")== (string)saved["position"]&&mira.transform.localScale.ToString("R")== (string)saved["scale"],"NPC transform/name changed");
        // Instance IDs change on reload; authored fields are compared after normalizing them.
        Func<string,string> normalize=s=>System.Text.RegularExpressions.Regex.Replace(s,"\"instanceID\":-?[0-9]+","\"instanceID\":0");
        var oldCollider=JObject.Parse(normalize((string)saved["collider"]));var newCollider=JObject.Parse(normalize(EditorJsonUtility.ToJson(mira.GetComponent<Collider2D>())));
        // Unity refreshes its sprite-tiling cache when replacing an 80px visual with a 64px visual.
        // Auto-tiling is disabled; keep every physics/authority field in the comparison.
        var box=mira.GetComponent<BoxCollider2D>();Check(!box.autoTiling&&box.size==new Vector2(.5f,.6f)&&box.offset==Vector2.zero,"Physical collider changed");
        var cachedBefore=oldCollider["BoxCollider2D"]["m_SpriteTilingProperty"].DeepClone();var cachedAfter=newCollider["BoxCollider2D"]["m_SpriteTilingProperty"].DeepClone();
        ((JObject)oldCollider["BoxCollider2D"]).Remove("m_SpriteTilingProperty");((JObject)newCollider["BoxCollider2D"]).Remove("m_SpriteTilingProperty");
        Check(JToken.DeepEquals(oldCollider,newCollider),"Collider physics fields changed");Check(normalize(EditorJsonUtility.ToJson(mira))==normalize((string)saved["interaction"]),"Interaction changed");
        File.WriteAllText(Evidence+"sprite-collider-cache.json",JsonConvert.SerializeObject(new{autoTiling=false,physicsFieldsUnchanged=true,cachedBefore,cachedAfter},Formatting.Indented));
        string json=JsonConvert.SerializeObject(new{officialFilesCompared=before.Count,officialFilesUnchanged=true,personalFilesCompared=personal.Count,personalFilesUnchanged=true,existingBuildEntriesPreserved=true,experimentalSceneAppended=true,npcColliderInteractionTransformUnchanged=true,gameplayCodeChanged=false},Formatting.Indented);File.WriteAllText(Evidence+"preservation.json",json);return json;
    }
    public static string UpdateCorrected()
    {
        Outside();Check(SceneManager.GetActiveScene().path==ScenePath,"Experimental scene required");
        string path=Art+"MiraTraveller.png";string original="ArtSource/Labs/NpcResearch/Marco06B13R3/MiraTravellerFinal/spritesheet.png";
        Check(Hash(path)==Hash(Source+"spritesheet.png")||(File.Exists(original)&&Hash(path)==Hash(original)),"Unexpected edits to generated atlas; preserved");
        File.Copy(Source+"spritesheet.png",path,true);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        string packSource="ArtSource/Labs/NpcResearch/Marco06B13R3/MiraBackpackFinal/";string packPath=Art+"MiraBackpack.png";string previous="ArtSource/Labs/NpcResearch/Marco06B13R3/MiraBackpackCorrected/spritesheet.png";
        Check(!File.Exists(packPath)||Hash(packPath)==Hash(packSource+"spritesheet.png")||(File.Exists(previous)&&Hash(packPath)==Hash(previous)),"Unexpected backpack atlas edits; preserved");
        File.Copy(packSource+"spritesheet.png",packPath,true);AssetDatabase.ImportAsset(packPath,ImportAssetOptions.ForceSynchronousImport);var importer=(TextureImporter)AssetImporter.GetAtPath(packPath);
        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.maxTextureSize=1024;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        var data=JObject.Parse(File.ReadAllText(packSource+"manifest.json"));var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var oldRects=provider.GetSpriteRects();
        var rects=data["frames"].Select((f,i)=>new SpriteRect{name="pose_"+i.ToString("000"),rect=new Rect((int)f["rect"]["x"],384-(int)f["rect"]["y"]-64,64,64),alignment=SpriteAlignment.Custom,pivot=new Vector2(.5f,1-44f/64),spriteID=oldRects.FirstOrDefault(r=>r.name=="pose_"+i.ToString("000"))?.spriteID??GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
        AssetDatabase.SaveAssets();return "Corrected side-view occlusion imported; existing cape sprite IDs preserved; backpack atlas ready for Play inspection.";
    }
}
