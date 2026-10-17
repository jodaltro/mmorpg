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
    static Dictionary<string,Sprite> ImportAtlas(string outfit,string sourceLab=null,int expected=104,string destination=null,int frameWidth=128,int frameHeight=160,Vector2? logicalPivot=null,string sourceSheet="spritesheet.png")
    {
        string source=sourceLab??Lab;
        var data=JObject.Parse(File.ReadAllText(source+"aseprite.json"));
        Check(data["frames"].Count()==expected,"Unexpected grip-study frame count");
        string art=destination??Art;string path=art+outfit+".png";Check(!File.Exists(path),"Refusing atlas overwrite");
        Directory.CreateDirectory(art);File.Copy(source+sourceSheet,path,false);AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
        var importer=(TextureImporter)AssetImporter.GetAtPath(path);
        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Multiple;importer.spritePixelsPerUnit=32;
        importer.filterMode=FilterMode.Point;importer.textureCompression=TextureImporterCompression.Uncompressed;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.wrapMode=TextureWrapMode.Clamp;importer.maxTextureSize=4096;
        var settings=new TextureImporterSettings();importer.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;importer.SetTextureSettings(settings);importer.SaveAndReimport();
        importer.GetSourceTextureWidthAndHeight(out int width,out int height);
        int w=frameWidth,h=frameHeight;var pixelPivot=logicalPivot??new Vector2(64,34);
        var pivot=new Vector2(pixelPivot.x/w,pixelPivot.y/h);
        var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(importer);provider.InitSpriteEditorDataProvider();
        var rects=data["frames"].Select((f,i)=>new SpriteRect{name="pose_"+i.ToString("000"),rect=new Rect((int)f["frame"]["x"],height-(int)f["frame"]["y"]-h,w,h),alignment=SpriteAlignment.Custom,pivot=pivot,spriteID=GUID.Generate()}).ToArray();
        provider.SetSpriteRects(rects);provider.GetDataProvider<ISpriteNameFileIdDataProvider>().SetNameFileIdPairs(rects.Select(r=>new SpriteNameFileIdPair(r.name,r.spriteID)));provider.Apply();importer.SaveAndReimport();
        var sprites=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().ToDictionary(s=>s.name);
        Check(sprites.Count==expected&&sprites.Values.All(s=>s.pixelsPerUnit==32&&s.pivot==pixelPivot),"Wrong sprite import/pivot");return sprites;
    }

 public static string Create(){Check(!EditorApplication.isPlaying,"Stop first");ImportAtlas("BowDraw",Lab,74);AssetDatabase.SaveAssets();return "Imported 74 composite diagnostic sprites; normal R7 scene unchanged.";}
 public static string CreateAnatomical(){Check(!EditorApplication.isPlaying,"Stop first");ImportAtlas("BowDraw","ArtSource/Labs/Humanoid2026/R7/BowAnatomyStudy/",74,"Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/BowAnatomyStudy/");AssetDatabase.SaveAssets();return "Imported 74 V4 anatomical diagnostic sprites; normal R7 scene unchanged.";}
 public static string CreateSwordContactR8(){Check(!EditorApplication.isPlaying,"Stop first");string source="ArtSource/Labs/Humanoid2026/R8/SwordContact/",destination="Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/";Check((bool)JObject.Parse(File.ReadAllText(source+"qa.json"))["passed"],"Contact gate required");ImportAtlas("body",source,272,destination);ImportAtlas("fingers",source,272,destination,128,160,new Vector2(64,34),"fingers.png");AssetDatabase.SaveAssets();return "Imported 272 new body frames and contact masks; historical sprites preserved";}
 public static string CreateStatesR8(){Check(!EditorApplication.isPlaying,"Stop first");Check((bool)JObject.Parse(File.ReadAllText("Docs/Validation/HumanoidStatesR8/canvas-gate.json"))["passed"],"Canvas gate required");foreach(string action in new[]{"dodge","death"}){string source="ArtSource/Labs/Humanoid2026/R8/"+action+"/";var m=JObject.Parse(File.ReadAllText(source+"manifest.json"));ImportAtlas(action,source,m["frames"].Count(),"Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/",(int)m["canvas"][0],(int)m["canvas"][1],new Vector2((float)m["pivotUnity"][0],(float)m["pivotUnity"][1]));}AssetDatabase.SaveAssets();return "Imported padded R8 action atlases through the existing importer; all historical atlas IDs preserved.";}
}
