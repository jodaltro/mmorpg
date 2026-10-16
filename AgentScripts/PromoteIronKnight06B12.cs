using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class PromoteIronKnight06B12
{
    public const string Evidence="Docs/Validation/Marco06B12/";
    public const string Approved="Assets/Mmorpg/Scenes/Marco06B11CharacterStates.unity";
    public const string Official="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    public const string Art="Assets/Mmorpg/Art/Production/IronKnight/";
    private static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    private static string PathOf(Transform t)=>t.parent==null?t.name:PathOf(t.parent)+"/"+t.name;
    public static string Diagnose()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty)throw new Exception("Clean saved scene outside Play required");
        if(File.Exists(Official))throw new Exception("Initial diagnosis cannot be overwritten after production promotion");
        Directory.CreateDirectory(Evidence);var original=SceneManager.GetActiveScene().path;
        var scenes=new List<object>();
        foreach(string path in new[]{"Assets/Mmorpg/Scenes/Marco06B2World.unity",Approved})
        {
            var scene=EditorSceneManager.OpenScene(path);var roots=scene.GetRootGameObjects();var all=roots.SelectMany(r=>r.GetComponentsInChildren<Transform>(true)).ToArray();
            var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var actor=journey.Player;
            var animator=actor.GetComponent<ProductionSpriteAnimator>();
            var serialized=new SerializedObject(journey);var art=animator==null?null:new SerializedObject(animator).FindProperty("art").objectReferenceValue;
            var world=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();var sw=new SerializedObject(world);
            scenes.Add(Newtonsoft.Json.Linq.JObject.FromObject(new{path,objects=all.Length,roots=roots.Select(r=>r.name),components=all.SelectMany(t=>t.GetComponents<Component>()).Where(c=>c!=null).GroupBy(c=>c.GetType().FullName).OrderBy(g=>g.Key).ToDictionary(g=>g.Key,g=>g.Count()),
                regions=all.Select(t=>t.GetComponent<ExplorationRegion>()).Where(r=>r!=null).Select(r=>new{r.Title,entry=r.SafeEntry.ToString(),serialized=EditorJsonUtility.ToJson(r)}),
                nodes=all.Select(t=>t.GetComponent<ExplorationNode>()).Where(n=>n!=null).Select(n=>new{name=n.name,n.SourceId,position=n.transform.position.ToString()}),
                interactions=journey.Interactions.Select(i=>new{name=i.name,kind=i.Kind.ToString(),position=i.transform.position.ToString()}),
                actorPath=PathOf(actor.transform),actorComponents=actor.GetComponents<Component>().Select(c=>c.GetType().Name),actorPrefab=PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(actor.gameObject),
                characterSet=AssetDatabase.GetAssetPath(art),visualPrefabs=all.Where(t=>t.GetComponent<ProductionVisualDefinition>()!=null).Select(t=>new{path=PathOf(t),asset=AssetDatabase.GetAssetPath(t.GetComponent<ProductionVisualDefinition>().Character)}),
                body=EditorJsonUtility.ToJson(actor.GetComponent<Rigidbody2D>()),collider=EditorJsonUtility.ToJson(actor.GetComponent<Collider2D>()),
                sessionCommands=UnityEngine.Object.FindAnyObjectByType<LocalSessionCommands>()!=null,gameSessionEnabled=UnityEngine.Object.FindAnyObjectByType<GameSession>().enabled,
                isolatedSave=serialized.FindProperty("isolatedSaveName").stringValue,externalSessionCommands=sw.FindProperty("externalSessionCommands").boolValue,
                camera=Camera.main.GetComponents<Component>().Select(c=>c.GetType().Name),prefabDependencies=AssetDatabase.GetDependencies(path,true).Where(p=>p.EndsWith(".prefab"))}));
        }
        EditorSceneManager.OpenScene(original);
        var files=new Dictionary<string,string>();
        foreach(string dir in new[]{"ArtSource/Labs/IronKnight2026/B10","ArtSource/Labs/IronKnight2026/B11","Assets/Mmorpg/Art/Experimental/IronKnightB10","Assets/Mmorpg/Art/Experimental/IronKnightB11"})foreach(string p in Directory.GetFiles(dir,"*",SearchOption.AllDirectories))files[p.Replace('\\','/')]=Hash(p);
        foreach(string path in new[]{Approved,"Assets/Mmorpg/Scenes/Marco06B2World.unity"})files[path]=Hash(path);
        File.WriteAllText(Evidence+"approved-before.json",JsonConvert.SerializeObject(files,Formatting.Indented));
        var personal=new Dictionary<string,string>();
        foreach(string folder in new[]{Application.persistentDataPath,LocalJourneyProfile.Root})foreach(string name in new[]{"journey-v1.json","marco06b1-exploration.json","marco06b1-journey.json","journey.json","profile.json","journey.json.bak","marco06b1-journey.json.bak","marco06b1-exploration.json.bak"})
        {string p=Path.Combine(folder,name);if(File.Exists(p))personal[p]=Hash(p);}
        File.WriteAllText("Temp/Marco06B12-personal-before.json",JsonConvert.SerializeObject(personal,Formatting.Indented));
        var result=new{build=EditorBuildSettings.scenes.Select(s=>new{s.path,s.enabled}),editorOriginal=original,playModeStart=AssetDatabase.GetAssetPath(EditorSceneManager.playModeStartScene),personalFilesHashed=personal.Count,scenes};
        string json=JsonConvert.SerializeObject(result,Formatting.Indented,new JsonSerializerSettings{ReferenceLoopHandling=ReferenceLoopHandling.Ignore});File.WriteAllText(Evidence+"entry-diagnosis.json",json);return "Entry diagnosis written before any Build Settings changes; "+personal.Count+" personal files hashed without publishing their contents.";
    }
    private static void Outside(){if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty)throw new Exception("Clean scene outside Play required");}
    public static string CreateOfficial()
    {
        Outside();if(!File.Exists(Evidence+"entry-diagnosis.json")||!File.Exists("Docs/Validation/Marco06B12.md"))throw new Exception("Record entry diagnosis first");
        if(File.Exists(Official)||File.Exists(Art+"PlayerVisual.prefab"))throw new IOException("Refusing to overwrite production scene or prefab");
        if(AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"IronKnight.asset")==null)
        {string error=AssetDatabase.MoveAsset(Art+"Sprites/IronKnight.asset",Art+"IronKnight.asset");if(!string.IsNullOrEmpty(error))throw new Exception(error);}
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"IronKnight.asset");if(set==null||set.clips.Length!=36)throw new Exception("Official 36-clip set required");
        var scene=EditorSceneManager.OpenScene(Approved);if(!EditorSceneManager.SaveScene(scene,Official,true))throw new IOException("Scene copy failed");EditorSceneManager.OpenScene(Official);
        var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();
        var visual=actor.transform.Find("VisualRoot");var body=visual.Find("BodySprite").GetComponent<SpriteRenderer>();
        animator.Configure(set,actor,body,actor.GetComponent<SwordSwing>());body.sprite=set.Find("idle",0).frames[0].sprite;
        var definition=visual.gameObject.AddComponent<ProductionVisualDefinition>();definition.Configure(set,body,visual.Find("WeaponPivot"));
        PrefabUtility.SaveAsPrefabAssetAndConnect(visual.gameObject,Art+"PlayerVisual.prefab",InteractionMode.AutomatedAction);
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());AssetDatabase.SaveAssets();
        return "Official scene and connected visual prefab created. World, player authority, camera, HUD, profile and calibration copied unchanged from approved B11.";
    }
    public static string PromoteEntry()
    {
        Outside();if(!File.Exists(Evidence+"production-verification.json"))throw new Exception("Verify production before entry promotion");
        var scenes=EditorBuildSettings.scenes.Where(s=>s.path!=Official).ToList();scenes.Insert(0,new EditorBuildSettingsScene(Official,true));
        EditorBuildSettings.globalScenes=scenes.ToArray();EditorBuildSettings.scenes=scenes.ToArray();AssetDatabase.SaveAssets();
        EditorSceneManager.OpenScene(Official);return "MmorpgWorld is enabled build index 0; every prior build entry retained in order. No forced Play-start override.";
    }
    public static string VerifyProduction()
    {
        Outside();var original=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/IronKnightB11/IronKnightB11.asset");var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"IronKnight.asset");
        if(set==null||set.clips.Length!=36||set.referenceSpeed!=original.referenceSpeed||set.pixelsPerUnit!=32)throw new Exception("Official set contract");
        int frameEntries=0;var unique=new HashSet<Sprite>();
        foreach(var a in original.clips)
        {
            var b=set.Find(a.action,a.direction);if(b==null||b.status!=a.status||b.loop!=a.loop||b.frames.Length!=a.frames.Length)throw new Exception("Clip metadata changed "+a.action);
            for(int i=0;i<a.frames.Length;i++)
            {
                var x=a.frames[i];var y=b.frames[i];unique.Add(y.sprite);frameEntries++;
                if(x.hand!=y.hand||x.seconds!=y.seconds||x.holdAngle!=y.holdAngle||x.depth!=y.depth||x.source!=y.source||!x.events.SequenceEqual(y.events)||x.sprite.rect!=y.sprite.rect||x.sprite.pivot!=y.sprite.pivot)throw new Exception("Approved frame metadata changed "+a.action+"/"+i);
                string p=AssetDatabase.GetAssetPath(x.sprite),q=AssetDatabase.GetAssetPath(y.sprite);if(!q.StartsWith(Art)||Hash(p)!=Hash(q))throw new Exception("Pixel content changed or experimental sprite reference");
            }
        }
        foreach(string path in AssetDatabase.FindAssets("t:Texture2D",new[]{Art}).Select(AssetDatabase.GUIDToAssetPath))
        {var i=(TextureImporter)AssetImporter.GetAtPath(path);if(i.spritePixelsPerUnit!=32||i.filterMode!=FilterMode.Point||i.mipmapEnabled||i.textureCompression!=TextureImporterCompression.Uncompressed)throw new Exception("Import settings changed");}
        var dependencies=AssetDatabase.GetDependencies(Official,true);if(dependencies.Any(p=>p.Contains("/Experimental/")))throw new Exception("Production scene depends on experimental assets");
        EditorSceneManager.OpenScene(Official);var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();var sword=actor.GetComponent<SwordSwing>();
        var sw=new SerializedObject(sword);var proxy=actor.GetComponent<SpriteRenderer>();var body=actor.transform.Find("VisualRoot/BodySprite").GetComponent<SpriteRenderer>();
        if(animator.Body!=body||sw.FindProperty("body").objectReferenceValue!=proxy||sw.FindProperty("production").objectReferenceValue!=animator||sw.FindProperty("hand").objectReferenceValue!=actor.transform.Find("VisualRoot/WeaponPivot"))throw new Exception("Prefab conversion changed player bindings");
        if(actor.GetComponent<ProductionCharacterStates>()==null||!new SerializedObject(actor.GetComponent<ProductionVisualSync>()).FindProperty("holdAnimatedDeath").boolValue)throw new Exception("Approved state observer/death policy missing");
        var files=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"approved-before.json"));if(files.Any(pair=>Hash(pair.Key)!=pair.Value))throw new Exception("Approved archive changed");
        var result=new{clips=set.clips.Length,uniqueSprites=unique.Count,frameEntries,metadataEquivalent=true,sheetBytesIdentical=true,experimentalDependencies=0,approvedFilesUnchanged=files.Count,connectedVisualPrefab=PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(body.gameObject),actorBindingsIntact=true,dependencies};
        string json=JsonConvert.SerializeObject(result,Formatting.Indented);File.WriteAllText(Evidence+"production-verification.json",json);return "Verified 36 equivalent clips, "+unique.Count+" original pixel-identical sprites, correct player bindings, no experimental dependency.";
    }
    private static string SnapshotPath(Transform t)=>(t.parent==null?"":SnapshotPath(t.parent)+"/")+t.name+"["+t.GetSiblingIndex()+"]";
    private static Dictionary<string,string> WorldSnapshot(string path)
    {
        EditorSceneManager.OpenScene(path);var map=new Dictionary<string,string>();
        foreach(var t in SceneManager.GetActiveScene().GetRootGameObjects().SelectMany(r=>r.GetComponentsInChildren<Transform>(true)))
        {
            string key=SnapshotPath(t);map[key+"/transform"]=t.localPosition.ToString("R")+t.localRotation.ToString("R")+t.localScale.ToString("R")+" active="+t.gameObject.activeSelf+" layer="+t.gameObject.layer;
            foreach(var c in t.GetComponents<Component>().Where(c=>c!=null&&(c.GetType().Namespace=="Mmorpg.Runtime"||c is Rigidbody2D||c is Collider2D||c is Camera)))
            {
                if(c is ProductionSpriteAnimator||c is ProductionVisualDefinition)continue;
                string values=System.Text.RegularExpressions.Regex.Replace(EditorJsonUtility.ToJson(c),"\"instanceID\":-?[0-9]+","\"instanceID\":0");
                var so=new SerializedObject(c);var p=so.GetIterator();var refs=new Dictionary<string,string>();
                while(p.Next(true))if(p.propertyType==SerializedPropertyType.ObjectReference)
                {
                    if(p.propertyPath=="m_CorrespondingSourceObject"||p.propertyPath=="m_PrefabInstance"||p.propertyPath=="m_PrefabAsset")continue;
                    var o=p.objectReferenceValue;
                    refs[p.propertyPath]=o==null?"null":o is Component component?SnapshotPath(component.transform)+"/"+component.GetType().FullName:o is GameObject go?SnapshotPath(go.transform):AssetDatabase.GetAssetPath(o);
                }
                map[key+"/"+c.GetType().FullName]=values+JsonConvert.SerializeObject(refs);
            }
        }
        return map;
    }
    public static string VerifyWorldAndSaves()
    {
        Outside();if(EditorBuildSettings.globalScenes[0].path!=Official||EditorBuildSettings.scenes[0].path!=Official)throw new Exception("Official global/active entry mismatch");
        File.WriteAllText(Evidence+"entry-final.json",JsonConvert.SerializeObject(new{global=EditorBuildSettings.globalScenes.Select(s=>new{s.path,s.enabled}),active=EditorBuildSettings.scenes.Select(s=>new{s.path,s.enabled}),playStartOverride=AssetDatabase.GetAssetPath(EditorSceneManager.playModeStartScene)},Formatting.Indented));
        var before=WorldSnapshot(Approved);var after=WorldSnapshot(Official);var differences=before.Keys.Union(after.Keys).Where(k=>!before.ContainsKey(k)||!after.ContainsKey(k)||before[k]!=after[k]).ToArray();
        File.WriteAllText(Evidence+"world-structural-differences.json",JsonConvert.SerializeObject(differences,Formatting.Indented));
        if(differences.Length!=0)File.WriteAllText("Temp/Marco06B12-world-differences.json",JsonConvert.SerializeObject(differences.Select(k=>new{key=k,before=before.ContainsKey(k)?before[k]:null,after=after.ContainsKey(k)?after[k]:null}),Formatting.Indented));
        if(differences.Length!=0)throw new Exception("World/reference differences: "+string.Join(",",differences.Take(8)));
        var personal=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText("Temp/Marco06B12-personal-before.json"));if(personal.Any(p=>!File.Exists(p.Key)||Hash(p.Key)!=p.Value))throw new Exception("Personal save changed");
        string json=JsonConvert.SerializeObject(new{unchangedWorldAndGameplayEntries=before.Count,allWorldAndActorReferencesEquivalent=true,personalFilesUnchanged=personal.Count,personalContentsPublished=false,profilePathUnchanged=true},Formatting.Indented);File.WriteAllText(Evidence+"world-and-save-preservation.json",json);return json;
    }
    private static Dictionary<string,string> ProductionIds()=>AssetDatabase.FindAssets("",new[]{Art}).Select(AssetDatabase.GUIDToAssetPath).Where(p=>!AssetDatabase.IsValidFolder(p)).SelectMany(p=>AssetDatabase.LoadAllAssetsAtPath(p)).Where(o=>o is Sprite||o is ProductionCharacterSet||o is GameObject).ToDictionary(o=>AssetDatabase.GetAssetPath(o)+"/"+o.name,o=>{AssetDatabase.TryGetGUIDAndLocalFileIdentifier(o,out string guid,out long id);return guid+":"+id;});
    public static string RecordReimportIds(){Outside();AssetDatabase.Refresh();var ids=ProductionIds();File.WriteAllText(Evidence+"production-ids-before.json",JsonConvert.SerializeObject(ids,Formatting.Indented));return "Recorded "+ids.Count+" production asset/sprite identities.";}
    public static string VerifyReimportIds()
    {
        Outside();var before=JsonConvert.DeserializeObject<Dictionary<string,string>>(File.ReadAllText(Evidence+"production-ids-before.json"));var after=ProductionIds();if(before.Count!=after.Count||before.Any(p=>!after.ContainsKey(p.Key)||after[p.Key]!=p.Value))throw new Exception("Reimport changed production GUID/local ID");
        string json=JsonConvert.SerializeObject(new{stableIdentities=after.Count,characterSetAndPrefabPreserved=true},Formatting.Indented);File.WriteAllText(Evidence+"reimport.json",json);return json;
    }
}
