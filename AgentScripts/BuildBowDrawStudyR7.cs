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

public static class BuildBowDrawStudyR7
{
 const string Art="Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/BowDrawStudy/",Lab="ArtSource/Labs/Humanoid2026/R7/BowDrawStudy/";
 static void Check(bool b,string s){if(!b)throw new Exception(s);}
    static Dictionary<string,Sprite> ImportAtlas(string outfit,string sourceLab=null,int expected=104)
    {
        string source=sourceLab??Lab;
        var data=JObject.Parse(File.ReadAllText(source+"aseprite.json"));
        Check(data["frames"].Count()==expected,"Unexpected grip-study frame count");
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

 public static string Create(){Check(!EditorApplication.isPlaying,"Stop first");ImportAtlas("BowDraw",Lab,74);AssetDatabase.SaveAssets();return "Imported 74 composite diagnostic sprites; normal R7 scene unchanged.";}
}
