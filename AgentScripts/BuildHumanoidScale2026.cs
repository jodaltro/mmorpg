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

// Larger body authoring only: serialized presentation changes in a new scene, no runtime equipment.
public static class BuildHumanoidScale2026
{
    public const string ScenePath="Assets/Mmorpg/Scenes/HumanoidScale2026.unity";
    const string Official="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    const string Evidence="Docs/Validation/HumanoidScale2026/";
    const string Art="Assets/Mmorpg/Art/Experimental/HumanoidScale2026/";
    const string Lab="ArtSource/Labs/Humanoid2026/Preview/";
    static void Check(bool pass,string message){if(!pass)throw new Exception(message);}
    static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    static void Outside()=>Check(!EditorApplication.isPlaying&&!SceneManager.GetActiveScene().isDirty,"Clean scene outside Play required");
    static JourneyInteractable Npc(InteractionKind kind)=>UnityEngine.Object.FindAnyObjectByType<JourneySession>().Interactions.Single(i=>i.Kind==kind);
    static object Audit(JourneyInteractable npc)=>new {kind=npc.Kind.ToString(),name=npc.name,position=npc.transform.position.ToString("R"),scale=npc.transform.localScale.ToString("R"),collider=EditorJsonUtility.ToJson(npc.GetComponent<Collider2D>()),interaction=EditorJsonUtility.ToJson(npc)};
    public static string Preflight()
    {
        Outside();Check(SceneManager.GetActiveScene().path==Official,"Open clean official world first");
        Check(LocalJourneyProfile.ValidationRootOverride==null,"A profile override is already active");
        Check(!File.Exists(ScenePath)&&!File.Exists(Evidence+"official-before.json"),"Refusing scene/snapshot overwrite");
        Directory.CreateDirectory(Evidence);Directory.CreateDirectory("Temp/HumanoidScale2026");
        var hashes=new Dictionary<string,string>();
        foreach(string folder in new[]{"Assets/Mmorpg/Art/Production/IronKnight","Assets/Mmorpg/Art/Experimental/NpcWardrobeB13R3","Assets/Mmorpg/Runtime","Assets/Mmorpg/Domain"})
            foreach(string path in Directory.GetFiles(folder,"*",SearchOption.AllDirectories))hashes[path.Replace('\\','/')]=Hash(path);
        foreach(string path in new[]{Official,Official+".meta","ArtSource/Characters/IronKnight/manifest.json","Assets/Mmorpg/Scenes/Marco06B13R3Wardrobe.unity","Assets/Mmorpg/Scenes/Marco06B13R3Wardrobe.unity.meta"})hashes[path]=Hash(path);
        File.WriteAllText(Evidence+"official-before.json",JsonConvert.SerializeObject(hashes,Formatting.Indented));
        var personal=new Dictionary<string,string>();
        foreach(string name in new[]{"profile.json","journey.json","journey.json.bak","journey.json.tmp","marco06b1-exploration.json","marco06b1-exploration.json.bak","marco06b1-exploration.json.tmp","decision-cache.json"})
        {string path=Path.Combine(LocalJourneyProfile.Root,name);if(File.Exists(path))personal[path]=Hash(path);}
        File.WriteAllText("Temp/HumanoidScale2026/personal-before.json",JsonConvert.SerializeObject(personal));
        File.WriteAllText(Evidence+"build-before.json",JsonConvert.SerializeObject(EditorBuildSettings.globalScenes.Select(s=>new{s.path,s.enabled}),Formatting.Indented));
        File.WriteAllText(Evidence+"npcs-before.json",JsonConvert.SerializeObject(new[]{Audit(Npc(InteractionKind.Mira)),Audit(Npc(InteractionKind.Orin))},Formatting.Indented));
        return "Official world, hero, runtime/domain, historical lab, personal hashes and both NPC bindings recorded.";
    }
    static Dictionary<string,Sprite> ImportAtlas(string outfit)
    {
        var data=JObject.Parse(File.ReadAllText(Lab+outfit+"/aseprite.json"));
        Check(data["frames"].Count()==52,"Expected 52 native body frames");
        string path=Art+outfit+".png";Check(!File.Exists(path),"Refusing atlas overwrite");
        Directory.CreateDirectory(Art);File.Copy(Lab+outfit+"/spritesheet.png",path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
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
    public static string ImportAndCreate()
    {
        Outside();Check(SceneManager.GetActiveScene().path==Official&&File.Exists(Evidence+"official-before.json"),"Official source and preflight required");
        Check(!File.Exists(ScenePath),"Refusing existing scene overwrite");
        var mira=ImportAtlas("Female");var orin=ImportAtlas("Male");
        Check(AssetDatabase.CopyAsset(Official,ScenePath),"Scene copy failed");EditorSceneManager.OpenScene(ScenePath);
        Npc(InteractionKind.Mira).GetComponent<SpriteRenderer>().sprite=mira["pose_000"];
        Npc(InteractionKind.Orin).GetComponent<SpriteRenderer>().sprite=orin["pose_000"];
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());Check(EditorSceneManager.SaveScene(SceneManager.GetActiveScene()),"Scene save failed");
        var scenes=EditorBuildSettings.globalScenes.ToList();Check(scenes[0].path==Official,"Official entry changed");scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();AssetDatabase.SaveAssets();
        return "Created scale study from clean official world: Mira and Orin presentation only, 104 sprites, original gameplay and index zero.";
    }
    public static string Verify()
    {
        Outside();Check(SceneManager.GetActiveScene().path==ScenePath,"Open clean scale study scene");
        var hashes=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"official-before.json"));Check(hashes.All(p=>Hash(p.Key)==p.Value),"Official/historical/runtime file changed");
        
        var personal=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/HumanoidScale2026/personal-before.json"));Check(personal.All(p=>Hash(p.Key)==p.Value),"Personal save changed");
        var entries=JArray.Parse(File.ReadAllText(Evidence+"build-before.json"));var current=EditorBuildSettings.globalScenes;
        Check(current.Length==entries.Count+1&&current.Last().path==ScenePath,"Unexpected build delta");
        for(int i=0;i<entries.Count;i++)Check(current[i].path==(string)entries[i]["path"]&&current[i].enabled==(bool)entries[i]["enabled"],"Existing build entry changed");
        Func<string,string> normalize=s=>System.Text.RegularExpressions.Regex.Replace(s,"\"instanceID\":-?[0-9]+","\"instanceID\":0");
        var audits=JArray.Parse(File.ReadAllText(Evidence+"npcs-before.json"));
        foreach(var old in audits)
        {
            var npc=Npc((InteractionKind)Enum.Parse(typeof(InteractionKind),(string)old["kind"]));
            Check(npc.name==(string)old["name"]&&npc.transform.position.ToString("R")== (string)old["position"]&&npc.transform.localScale.ToString("R")== (string)old["scale"],"NPC transform changed");
            var before=JObject.Parse(normalize((string)old["collider"]));var after=JObject.Parse(normalize(EditorJsonUtility.ToJson(npc.GetComponent<Collider2D>())));
            ((JObject)before["BoxCollider2D"]).Remove("m_SpriteTilingProperty");((JObject)after["BoxCollider2D"]).Remove("m_SpriteTilingProperty");
            Check(JToken.DeepEquals(before,after),"NPC collider physics changed");
            Check(normalize((string)old["interaction"])==normalize(EditorJsonUtility.ToJson(npc)),"NPC narrative interaction changed");
        }
        string json=JsonConvert.SerializeObject(new{protectedFiles=hashes.Count,protectedFilesUnchanged=true,personalFiles=personal.Count,personalFilesUnchanged=true,bothNpcBindingsAndCollidersUnchanged=true,onlyBuildSceneAppended=true,noRuntimeOrDomainChanges=true},Formatting.Indented);
        File.WriteAllText(Evidence+"preservation.json",json);return json;
    }
}
