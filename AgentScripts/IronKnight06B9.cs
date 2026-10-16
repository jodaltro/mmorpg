using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.U2D.Sprites;
using UnityEngine;
public static class IronKnight06B9
{
    const string Source="ArtSource/Labs/IronKnight2026/";
    const string Output="Assets/Mmorpg/Art/Experimental/IronKnightB9/";
    const string Scene="Assets/Mmorpg/Scenes/Marco06B9ProfessionalHero.unity";
    static readonly string[] Directions={"south","west","north","east"};
    public static string ImportAndCreate()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(current.path!="Assets/Mmorpg/Scenes/Marco06B5Animation.unity"||current.isDirty)throw new InvalidOperationException("Clean B5 required");
        if(File.Exists(Scene))throw new IOException("Refusing to overwrite "+Scene);
        Import();
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB9.asset");
        if(!EditorSceneManager.SaveScene(current,Scene,true))throw new IOException("Copy failed");EditorSceneManager.OpenScene(Scene);
        var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();var renderer=actor.transform.Find("VisualRoot/BodySprite").GetComponent<SpriteRenderer>();
        animator.Configure(set,actor,renderer,actor.GetComponent<SwordSwing>());renderer.sprite=set.Find("idle",0).frames[0].sprite;
        EditorUtility.SetDirty(animator);EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        return "B9 scene created; 12 clips, 108 original frames, native 256 canvas / 32 PPU. Existing animator, physics, weapon and effects retained.";
    }
    public static string Import()=>ImportSet(Source,Output,"IronKnightB9");
    // Shared native-canvas importer; variants choose a separate source, asset and scene.
    public static string ImportSet(string source,string output,string characterId)
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var data=JObject.Parse(File.ReadAllText(source+"manifest.json"));
        if(!new[]{"iron-knight-b9-v1","iron-knight-b10-v1","iron-knight-b11-v1"}.Contains((string)data["schema"])||(float)data["ppu"]!=32)throw new InvalidDataException("Explicit Iron Knight 256px / 32 PPU variant contract required");
        Directory.CreateDirectory(output);AssetDatabase.Refresh();var clips=data["baseCharacterSet"]==null?new List<ProductionClip>():AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>((string)data["baseCharacterSet"]).clips.ToList();
        foreach(var c in data["clips"])
        {
            string action=(string)c["animation"],direction=(string)c["direction"],name=action+"_"+direction;
            var frames=c["frames"].ToArray();if(frames.Length!=(int)c["frameCount"]||frames.Length==0)throw new InvalidDataException(name);
            string path=output+name+".png";File.Copy((string)c["sheet"]??source+"frames/"+action+"/"+direction+"/sheet.png",path,true);
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.GetSourceTextureWidthAndHeight(out int sourceWidth,out int sourceHeight);
            importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
            importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;
            importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=Mathf.Max(4096,Mathf.NextPowerOfTwo(Mathf.Max(sourceWidth,sourceHeight)));
            var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
            importer.GetSourceTextureWidthAndHeight(out int width,out int height);
            if(width!=frames.Length*256||height!=256)throw new InvalidDataException("Unexpected horizontal source sheet "+path);
            var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
            var old=provider.GetSpriteRects();var rects=frames.Select((f,i)=>new SpriteRect{name=name+"_"+i.ToString("000"),rect=new Rect(i*256,0,256,256),alignment=SpriteAlignment.Custom,pivot=new Vector2((float)f["pivot"][0]/256,1-(float)f["pivot"][1]/256),spriteID=old.FirstOrDefault(r=>r.name==name+"_"+i.ToString("000"))?.spriteID??GUID.Generate()}).ToArray();
            provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
            var sprites=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
            var clip=new ProductionClip{action=action,direction=Array.IndexOf(Directions,direction),loop=(bool)c["loop"],status=(string)c["status"],frames=new ProductionFrame[frames.Length]};
            for(int i=0;i<frames.Length;i++)
            {
                var f=frames[i];float seconds=(float)f["duration"];if(seconds<=0)throw new InvalidDataException("Duration");
                clip.frames[i]=new ProductionFrame{sprite=sprites[name+"_"+i.ToString("000")],seconds=seconds,hand=f["rightHand"].Type==JTokenType.Null?Vector2.zero:new Vector2(((float)f["rightHand"][0]-(float)f["pivot"][0])/32,((float)f["pivot"][1]-(float)f["rightHand"][1])/32),holdAngle=(float)f["equipmentAngle"],depth=(int)f["equipmentDepth"],source=(string)f["source"]};
            }
            clips.Add(clip);
        }
        // Phase clips share original Sprite/ProductionFrame references. No repeated drawings or reordered indices.
        if(data["phaseRanges"] is JObject ranges)
        {
            foreach(string direction in Directions)
            {
                var attack=clips.Single(c=>c.action=="attack"&&c.direction==Array.IndexOf(Directions,direction));int previous=-1;
                foreach(string phase in new[]{"preparation","cut","recovery"})
                {
                    var range=ranges[direction][phase];int from=(int)range[0],to=(int)range[1];
                    if(from!=previous+1||to<from||to>=attack.frames.Length)throw new InvalidDataException("Invalid ordered phase range "+direction+phase);
                    clips.Add(new ProductionClip{action="attack-"+phase,direction=attack.direction,status=attack.status,loop=false,frames=attack.frames.Skip(from).Take(to-from+1).ToArray()});previous=to;
                }
                if(previous!=attack.frames.Length-1)throw new InvalidDataException("Incomplete Slash coverage");
            }
        }
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(output+characterId+".asset");if(set==null){set=ScriptableObject.CreateInstance<ProductionCharacterSet>();AssetDatabase.CreateAsset(set,output+characterId+".asset");}
        set.characterId=characterId;set.pixelsPerUnit=32;set.referenceSpeed=3.5f;set.clips=clips.ToArray();EditorUtility.SetDirty(set);AssetDatabase.SaveAssets();
        return "Imported "+characterId+"; production and other variant assets preserved.";
    }

}

public static class IronKnight06B10
{
    const string Output="Assets/Mmorpg/Art/Experimental/IronKnightB10/";
    public static string Import()=>IronKnight06B9.ImportSet("ArtSource/Labs/IronKnight2026/B10/",Output,"IronKnightB10");
    public static string ImportAndCreate()
    {
        const string destination="Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity";
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(current.path!="Assets/Mmorpg/Scenes/Marco06B9ProfessionalHero.unity"||current.isDirty)throw new InvalidOperationException("Clean B9 required");
        if(File.Exists(destination))throw new IOException("Refusing to overwrite "+destination);
        Import();
        if(!EditorSceneManager.SaveScene(current,destination,true))throw new IOException("Scene copy failed");EditorSceneManager.OpenScene(destination);
        var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
        var renderer=actor.transform.Find("VisualRoot/BodySprite").GetComponent<SpriteRenderer>();
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB10.asset");
        actor.GetComponent<ProductionSpriteAnimator>().Configure(set,actor,renderer,actor.GetComponent<SwordSwing>());renderer.sprite=set.Find("idle",0).frames[0].sprite;
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
        return "Created isolated B10 with phase clips, reviewed grips and 1.25x visual walk cadence. Physics and B9 preserved.";
    }
    public static string VerifyImport()
    {
        Func<Dictionary<string,string>> ids=()=>AssetDatabase.FindAssets("t:Texture2D",new[]{Output}).Select(AssetDatabase.GUIDToAssetPath).SelectMany(p=>AssetDatabase.LoadAllAssetsAtPath(p).OfType<Sprite>()).ToDictionary(sprite=>sprite.name,sprite=>{AssetDatabase.TryGetGUIDAndLocalFileIdentifier(sprite,out string guid,out long local);return guid+":"+local;});
        var before=ids();Import();var after=ids();if(before.Count!=108||after.Count!=108||before.Any(p=>after[p.Key]!=p.Value))throw new Exception("Unstable sprite IDs");
        var b9=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/IronKnightB9/IronKnightB9.asset");
        var source=JObject.Parse(File.ReadAllText("ArtSource/Labs/IronKnight2026/manifest.json"));string[] directions={"south","west","north","east"};
        foreach(var c in source["clips"])
        {
            var clip=b9.Find((string)c["animation"],Array.IndexOf(directions,(string)c["direction"]));var frames=c["frames"].ToArray();
            if(clip.frames.Length!=frames.Length)throw new Exception("B9 frame regression");
            for(int i=0;i<frames.Length;i++)if(clip.frames[i].source!=(string)frames[i]["source"]||Mathf.Abs(clip.frames[i].seconds-(float)frames[i]["duration"])>.000001f||Vector2.Distance(clip.frames[i].hand,new Vector2(((float)frames[i]["rightHand"][0]-128)/32,(114-(float)frames[i]["rightHand"][1])/32))>.00001f)throw new Exception("B9 metadata regression");
        }
        var importers=AssetDatabase.FindAssets("t:Texture2D",new[]{Output}).Select(AssetDatabase.GUIDToAssetPath).Select(p=>(TextureImporter)AssetImporter.GetAtPath(p)).ToArray();
        if(importers.Length!=12||importers.Any(i=>i.spritePixelsPerUnit!=32||i.filterMode!=FilterMode.Point||i.textureCompression!=TextureImporterCompression.Uncompressed||i.mipmapEnabled||i.wrapMode!=TextureWrapMode.Clamp))throw new Exception("Native texture contract regression");
        var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var renderers=actor.GetComponentsInChildren<SpriteRenderer>();int bodies=renderers.Count(r=>r.name=="BodySprite"),weapons=renderers.Count(r=>r.name=="EquippedSword");if(bodies!=1||weapons!=1)throw new Exception("Duplicate body/weapon");
        return Newtonsoft.Json.JsonConvert.SerializeObject(new{stableSpriteIds=after.Count,b9MetadataIntact=true,b9Clips=b9.clips.Length,b10Clips=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB10.asset").clips.Length,textures=importers.Length,nativeImportSettings=true,bodies,weapons,rigidbody=actor.GetComponent<Rigidbody2D>().bodyType.ToString(),collider=actor.GetComponent<Collider2D>().GetType().Name});
    }

}

public static class IronKnight06B11
{
    const string Output="Assets/Mmorpg/Art/Experimental/IronKnightB11/";
    public static string Import()=>IronKnight06B9.ImportSet("ArtSource/Labs/IronKnight2026/B11/",Output,"IronKnightB11");
    public static string Verify()
    {
        var b10=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/IronKnightB10/IronKnightB10.asset");
        var b11=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB11.asset");
        if(b11.clips.Length!=36)throw new Exception("Expected 24 reused clips plus 12 new clips");
        foreach(var clip in b10.clips)
        {
            var next=b11.Find(clip.action,clip.direction);
            if(next==null||next.loop!=clip.loop||next.status!=clip.status||next.frames.Length!=clip.frames.Length)throw new Exception("B10 clip changed: "+clip.action);
            for(int f=0;f<clip.frames.Length;f++)
            {
                var a=clip.frames[f];var b=next.frames[f];
                if(a.sprite!=b.sprite||a.hand!=b.hand||a.seconds!=b.seconds||a.holdAngle!=b.holdAngle||a.depth!=b.depth||a.source!=b.source||!a.events.SequenceEqual(b.events))throw new Exception("B10 frame changed: "+clip.action+"/"+f);
            }
        }
        var textures=AssetDatabase.FindAssets("t:Texture2D",new[]{Output}).Select(AssetDatabase.GUIDToAssetPath).ToArray();
        foreach(string path in textures)
        {
            var i=(TextureImporter)AssetImporter.GetAtPath(path);
            if(i.spritePixelsPerUnit!=32||i.filterMode!=FilterMode.Point||i.textureCompression!=TextureImporterCompression.Uncompressed||i.mipmapEnabled)throw new Exception("Import contract "+path);
            foreach(var sprite in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>())if(sprite.rect.size!=new Vector2(256,256))throw new Exception("Resized native cel");
        }
        string result=Newtonsoft.Json.JsonConvert.SerializeObject(new{baseClipsUnchanged=b10.clips.Length,newClips=12,totalClips=b11.clips.Length,newTextures=textures.Length,newSprites=textures.Sum(p=>AssetDatabase.LoadAllAssetsAtPath(p).OfType<Sprite>().Count()),native256=true,ppu=32,point=true,uncompressed=true,mipmaps=false});
        File.WriteAllText("Docs/Validation/Marco06B11/import.json",result);return result;
    }
    public static string ImportAndCreate()
    {
        const string destination="Assets/Mmorpg/Scenes/Marco06B11CharacterStates.unity";
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(current.path!="Assets/Mmorpg/Scenes/Marco06B10CombatPolish.unity"||current.isDirty)throw new InvalidOperationException("Clean B10 required");
        if(File.Exists(destination))throw new IOException("Refusing to overwrite "+destination);
        Import();if(!EditorSceneManager.SaveScene(current,destination,true))throw new IOException("Scene copy failed");EditorSceneManager.OpenScene(destination);
        var actor=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;var animator=actor.GetComponent<ProductionSpriteAnimator>();
        var renderer=actor.transform.Find("VisualRoot/BodySprite").GetComponent<SpriteRenderer>();var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB11.asset");
        animator.Configure(set,actor,renderer,actor.GetComponent<SwordSwing>());
        var states=actor.gameObject.AddComponent<ProductionCharacterStates>();states.Configure(actor,animator,actor.GetComponent<SwordSwing>());animator.ConfigureStates(states);
        actor.GetComponent<ProductionVisualSync>().ConfigureAnimatedDeath(true);renderer.sprite=set.Find("idle",0).frames[0].sprite;
        EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());return "B11 created; B10 sprites and clips reused unchanged; new states and death hold enabled only on B11";
    }
}
