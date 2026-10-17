using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Collections.Generic;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class PromoteQuaterniusR10
{
    const string Scene="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    const string SourceSetPath="Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/ValdoriaContactR8.asset";
    const string Production="Assets/Mmorpg/Art/Production/ValdoriaProtagonist/";
    const string ProductionSetPath=Production+"ValdoriaProtagonist.asset";
    const string Environment="Assets/Mmorpg/Art/Production/ValdoriaEnvironment/";
    const string MapPath=Environment+"ValdoriaVillageScene.png";
    const string MapSource="Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm/village-scene-v3.png";

    public static string PrepareAssets()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play before asset promotion");
        EnsureFolder("Assets/Mmorpg/Art/Production/ValdoriaProtagonist");
        EnsureFolder(Production+"Sprites");
        EnsureFolder("Assets/Mmorpg/Art/Production/ValdoriaEnvironment");
        AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
        if(!File.Exists(MapPath)&&!AssetDatabase.CopyAsset(MapSource,MapPath))throw new IOException("Could not copy Aseprite-cleaned map into production: source="+File.Exists(MapSource)+" imported="+(AssetDatabase.LoadAssetAtPath<Texture2D>(MapSource)!=null));
        var mapImporter=(TextureImporter)AssetImporter.GetAtPath(MapPath);mapImporter.spriteImportMode=SpriteImportMode.Single;ConfigureTexture(mapImporter,32,new Vector2(.5208f,.4625f));

        var source=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(SourceSetPath);
        if(source==null)throw new FileNotFoundException("R8 Quaternius sword-contact set missing",SourceSetPath);
        var sourceSprites=source.clips.SelectMany(c=>c.frames).Where(f=>f.sprite!=null).Select(f=>f.sprite).ToList();
        var sourceTexturePaths=sourceSprites.Select(s=>AssetDatabase.GetAssetPath(s.texture)).Distinct().ToList();
        string fingerSource="Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/fingers.png";
        if(!File.Exists(fingerSource))throw new FileNotFoundException("Procedural finger mask atlas missing",fingerSource);
        sourceTexturePaths.Add(fingerSource);
        var pathMap=new Dictionary<string,string>();
        foreach(string src in sourceTexturePaths.Distinct())
        {
            string destination=Production+"Sprites/"+Path.GetFileNameWithoutExtension(src)+"-"+Hash(src).Substring(0,8)+Path.GetExtension(src);
            if(!File.Exists(destination)&&!AssetDatabase.CopyAsset(src,destination))throw new IOException("Atlas copy failed: "+src);
            AssetDatabase.ImportAsset(destination,ImportAssetOptions.ForceSynchronousImport|ImportAssetOptions.ForceUpdate);
            var ti=(TextureImporter)AssetImporter.GetAtPath(destination);ConfigureTexture(ti,32,null);
            pathMap[src]=destination;
        }
        AssetDatabase.SaveAssets();AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
        var spriteMaps=new Dictionary<string,Dictionary<string,Sprite>>();
        foreach(var pair in pathMap)
            spriteMaps[pair.Key]=AssetDatabase.LoadAllAssetsAtPath(pair.Value).OfType<Sprite>().ToDictionary(s=>s.name);
        ProductionCharacterSet productionSet;
        if(AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(ProductionSetPath)==null)
        {
            productionSet=UnityEngine.Object.Instantiate(source);productionSet.characterId="valdoria-protagonist-quaternius-r8";
            foreach(var clip in productionSet.clips)foreach(var frame in clip.frames)
            {
                if(frame.sprite==null)continue;
                string from=AssetDatabase.GetAssetPath(frame.sprite.texture);
                if(!pathMap.ContainsKey(from)||!spriteMaps[from].TryGetValue(frame.sprite.name,out var target))throw new InvalidDataException("Production sprite map missing "+from+" / "+frame.sprite.name);
                frame.sprite=target;
            }
            AssetDatabase.CreateAsset(productionSet,ProductionSetPath);
        }
        else productionSet=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(ProductionSetPath);
        var bodyPath=pathMap["Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/body.png"];
        var fingersPath=pathMap[fingerSource];
        var bodySprites=AssetDatabase.LoadAllAssetsAtPath(bodyPath).OfType<Sprite>().ToDictionary(s=>s.name);
        var fingerSprites=AssetDatabase.LoadAllAssetsAtPath(fingersPath).OfType<Sprite>().ToDictionary(s=>s.name);
        if(bodySprites.Count!=272||fingerSprites.Count!=272)throw new InvalidDataException("Production grip atlases must contain 272 matched body/finger masks");
        AssetDatabase.SaveAssets();AssetDatabase.Refresh();
        return $"Production assets prepared: {productionSet.characterId}, clips={productionSet.clips.Length}, frames={productionSet.clips.Sum(c=>c.frames.Length)}, copied atlases={pathMap.Count}, sword-contact masks={fingerSprites.Count}, scene={MapPath}";
    }

    public static string ApplyToOfficialWorld()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Scene)throw new InvalidOperationException("Clean stopped official MmorpgWorld scene required");
        if(EditorBuildSettings.scenes.Length==0||EditorBuildSettings.scenes[0].path!=Scene||!EditorBuildSettings.scenes[0].enabled)throw new InvalidOperationException("Official world must remain enabled at build index zero");
        var actor=GameObject.Find("Player").GetComponent<ActorHealth>();var animator=actor.GetComponent<ProductionSpriteAnimator>();var body=animator.Body;var sword=actor.GetComponent<SwordSwing>();
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(ProductionSetPath);if(set==null||set.clips.Length!=64||set.clips.Sum(c=>c.frames.Length)!=528)throw new InvalidDataException("Complete Quaternius R8 CharacterSet was not promoted");
        Undo.RecordObject(animator,"Promote Quaternius protagonist");animator.Configure(set,actor,body,sword);animator.enabled=true;
        var state=actor.GetComponent<ProductionCharacterStates>();if(state==null)state=actor.gameObject.AddComponent<ProductionCharacterStates>();state.Configure(actor,animator,sword);state.ConfigureImmediatePresentation(true);
        var sync=actor.GetComponent<ProductionVisualSync>();if(sync!=null)sync.ConfigureAnimatedDeath(true);
        var blade=actor.GetComponentsInChildren<SpriteRenderer>(true).Single(r=>r.name=="EquippedSword");
        var visualRoot=body.transform.parent;var fingerNode=visualRoot.Find("ProceduralGripFingers");
        SpriteRenderer fingers;
        if(fingerNode==null){var fgo=new GameObject("ProceduralGripFingers");fgo.transform.SetParent(visualRoot,false);fingers=fgo.AddComponent<SpriteRenderer>();fingerNode=fgo.transform;}
        else {fingers=fingerNode.GetComponent<SpriteRenderer>();if(fingers==null)fingers=fingerNode.gameObject.AddComponent<SpriteRenderer>();}
        if(fingers==null)throw new MissingComponentException("Could not attach procedural finger renderer");
        fingers.sharedMaterial=body.sharedMaterial;fingers.enabled=false;
        string bodyPath=AssetDatabase.GetAssetPath(set.clips.SelectMany(c=>c.frames).First(f=>f.source!=null&&f.source.StartsWith("R8 weapon-driven")).sprite.texture);
        string fingerPath=Directory.GetFiles(Production+"Sprites","fingers-*.png").Select(p=>p.Replace('\\','/')).First();
        var bodySprites=AssetDatabase.LoadAllAssetsAtPath(bodyPath).OfType<Sprite>().ToDictionary(s=>s.name);
        var fingerSprites=AssetDatabase.LoadAllAssetsAtPath(fingerPath).OfType<Sprite>().ToDictionary(s=>s.name);
        var contacts=bodySprites.OrderBy(p=>p.Key).Select(p=>new ProceduralWeaponGripPresentation.ContactFrame{body=p.Value,fingers=fingerSprites[p.Key]}).ToArray();
        var grip=actor.GetComponent<ProceduralWeaponGripPresentation>();if(grip==null)grip=actor.gameObject.AddComponent<ProceduralWeaponGripPresentation>();grip.Configure(body,blade,fingers,actor,contacts);
        body.sprite=set.Find("idle",0).frames[0].sprite;

        var old=GameObject.Find("GeneratedValdoriaEnvironmentR10");if(old==null)old=new GameObject("GeneratedValdoriaEnvironmentR10");
        old.transform.SetPositionAndRotation(actor.transform.position,Quaternion.identity);old.transform.localScale=Vector3.one;
        var map=AssetDatabase.LoadAssetAtPath<Sprite>(MapPath);if(map==null)throw new FileNotFoundException("Production map sprite is missing",MapPath);
        var renderer=old.GetComponent<SpriteRenderer>();if(renderer==null)renderer=old.AddComponent<SpriteRenderer>();if(renderer==null||renderer.gameObject!=old)throw new MissingComponentException("Could not attach Valdoria scene renderer");renderer.sprite=map;renderer.sortingOrder=-439;renderer.sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");renderer.color=Color.white;old.transform.localScale=Vector3.one*.58f;
        renderer.enabled=true;
        var follow=Camera.main.GetComponent<CameraFollow>();if(follow!=null){var cameraData=new SerializedObject(follow);var bounds=cameraData.FindProperty("worldBounds").rectValue;var mapBounds=renderer.bounds;float xMin=Mathf.Min(bounds.xMin,mapBounds.min.x),yMin=Mathf.Min(bounds.yMin,mapBounds.min.y),xMax=Mathf.Max(bounds.xMax,mapBounds.max.x),yMax=Mathf.Max(bounds.yMax,mapBounds.max.y);cameraData.FindProperty("worldBounds").rectValue=Rect.MinMaxRect(xMin,yMin,xMax,yMax);cameraData.ApplyModifiedPropertiesWithoutUndo();EditorUtility.SetDirty(follow);}

        string[] legacyNames={"ProvidedTree","ProvidedBush","ProvidedRock","ProvidedHouse","ProvidedPillar","Tree","Bush","Rock","House","Barrel","MiraHouse","OrinHouse"};
        int hidden=0;
        foreach(var sr in UnityEngine.Object.FindObjectsByType<SpriteRenderer>(FindObjectsInactive.Include))
        {
            if(sr==renderer||!sr.enabled||sr.gameObject==actor.gameObject||sr.GetComponentInParent<ActorHealth>()!=null)continue;
            bool legacy=sr.transform.GetComponentsInParent<Transform>(true).Any(t=>legacyNames.Contains(t.name,StringComparer.Ordinal));
            if(!legacy)continue;
            sr.enabled=false;hidden++;
        }
        body.sortingOrder=0;EditorUtility.SetDirty(animator);EditorUtility.SetDirty(state);EditorUtility.SetDirty(grip);EditorUtility.SetDirty(old);EditorUtility.SetDirty(body);EditorUtility.SetDirty(renderer);EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        AssetDatabase.SaveAssets();
        if(!EditorSceneManager.SaveScene(SceneManager.GetActiveScene()))throw new IOException("Official world scene save failed");
        return $"Official world updated: Quaternius protagonist active (8 directions, 64 clips/528 frames), procedural sword contact masks {contacts.Length}; Iron Knight no longer bound to Player; environment scene sprite installed, legacy prop renderers hidden={hidden}; actors, colliders, missions, persistence and build order preserved.";
    }

    public static string ReopenOfficialScene()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play before reloading the official scene");
        EditorSceneManager.OpenScene(Scene,OpenSceneMode.Single);return "Reloaded saved official world to discard only the incomplete unsaved authoring attempt.";
    }

    public static string SaveOfficialScene()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().path!=Scene)throw new InvalidOperationException("Official scene outside Play required");
        AssetDatabase.SaveAssets();bool saved=EditorSceneManager.SaveScene(SceneManager.GetActiveScene());return "save="+saved+" dirty="+SceneManager.GetActiveScene().isDirty;
    }

    static void EnsureFolder(string path)
    {
        path=path.TrimEnd('/');if(AssetDatabase.IsValidFolder(path))return;
        string parent=Path.GetDirectoryName(path).Replace('\\','/');string leaf=Path.GetFileName(path);EnsureFolder(parent);AssetDatabase.CreateFolder(parent,leaf);
    }
    static void ConfigureTexture(TextureImporter i,float ppu,Vector2? pivot)
    {
        i.textureType=TextureImporterType.Sprite;i.spriteImportMode=SpriteImportMode.Multiple==i.spriteImportMode?SpriteImportMode.Multiple:SpriteImportMode.Single;
        i.spritePixelsPerUnit=ppu;i.filterMode=FilterMode.Point;i.textureCompression=TextureImporterCompression.Uncompressed;i.mipmapEnabled=false;i.alphaIsTransparency=true;i.wrapMode=TextureWrapMode.Clamp;
        var s=new TextureImporterSettings();i.ReadTextureSettings(s);s.spriteMeshType=SpriteMeshType.FullRect;if(pivot.HasValue){s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=pivot.Value;i.spritePivot=pivot.Value;}i.SetTextureSettings(s);
        var standalone=i.GetPlatformTextureSettings("Standalone");standalone.name="Standalone";standalone.overridden=true;standalone.textureCompression=TextureImporterCompression.Uncompressed;standalone.maxTextureSize=4096;i.SetPlatformTextureSettings(standalone);i.SaveAndReimport();
    }
    static string Hash(string path){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(path))).Replace("-","").ToLowerInvariant();}
}
