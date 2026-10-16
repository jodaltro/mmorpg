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
    public static string Import()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var data=JObject.Parse(File.ReadAllText(Source+"manifest.json"));
        if((string)data["schema"]!="iron-knight-b9-v1"||(float)data["ppu"]!=32)throw new InvalidDataException("B9-specific contract required");
        Directory.CreateDirectory(Output);AssetDatabase.Refresh();var clips=new List<ProductionClip>();
        foreach(var c in data["clips"])
        {
            string action=(string)c["animation"],direction=(string)c["direction"],name=action+"_"+direction;
            var frames=c["frames"].ToArray();if(frames.Length!=(int)c["frameCount"]||frames.Length==0)throw new InvalidDataException(name);
            string path=Output+name+".png";File.Copy(Source+"frames/"+action+"/"+direction+"/sheet.png",path,true);
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
            var importer=(TextureImporter)AssetImporter.GetAtPath(path);
            importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
            importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;
            importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=4096;
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
                clip.frames[i]=new ProductionFrame{sprite=sprites[name+"_"+i.ToString("000")],seconds=seconds,hand=new Vector2(((float)f["rightHand"][0]-(float)f["pivot"][0])/32,((float)f["pivot"][1]-(float)f["rightHand"][1])/32),holdAngle=(float)f["equipmentAngle"],depth=(int)f["equipmentDepth"],source=(string)f["source"]};
            }
            clips.Add(clip);
        }
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Output+"IronKnightB9.asset");if(set==null){set=ScriptableObject.CreateInstance<ProductionCharacterSet>();AssetDatabase.CreateAsset(set,Output+"IronKnightB9.asset");}
        set.characterId="IronKnightB9";set.pixelsPerUnit=32;set.referenceSpeed=3.5f;set.clips=clips.ToArray();EditorUtility.SetDirty(set);AssetDatabase.SaveAssets();
        return "Imported B9 only; source contracts and production assets preserved.";
    }

}
