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

public static class BuildHumanoidGripStudyR7
{
 const string Art="Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/GripStudy/",Lab="ArtSource/Labs/Humanoid2026/R7/GripStudy/";
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

 public static string Create(){
 Check(!EditorApplication.isPlaying,"Stop first");var sprites=ImportAtlas("ProceduralGripStudyR7",Lab,12);var records=JObject.Parse(File.ReadAllText("Docs/Validation/HumanoidSwordR7/procedural-grip.json"))["records"];
 var poses=JObject.Parse(File.ReadAllText("ArtSource/Labs/Humanoid2026/R6/CombatCandidate/manifest.json"))["frames"];
 foreach(string profile in new[]{"sword-neutral","sword-adjusted-grip"}){
 var set=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>("Assets/Mmorpg/Art/Experimental/HumanoidSwordR7/ValdoriaSwordR7.asset"));set.characterId="procedural-grip-study-"+profile;
 for(int i=0;i<records.Count();i++){
 var r=records[i];if((string)r["profile"]!=profile)continue;int dir=(string)r["view"]=="south"?0:3;int f=(int)r["sourceFrame"];string phase=f==6?"attack-preparation":f==12?"attack-cut":"attack-recovery";
 var p=r["socketPixel"];var a=r["socket"];var b=r["wrist"];Vector3 delta=new Vector3((float)a[0]-(float)b[0],(float)a[1]-(float)b[1],(float)a[2]-(float)b[2]);float angle=(dir==0?0:-90)*Mathf.Deg2Rad;Vector3 camera=new Vector3(8*Mathf.Sin(angle),-8*Mathf.Cos(angle),5.5f);Vector3 forward=(new Vector3(0,0,.9f)-camera).normalized,right=Vector3.Cross(forward,Vector3.forward).normalized,up=Vector3.Cross(right,forward).normalized;
 var old=poses.First(pose=>(int)pose["direction"]==dir&&(int)pose["sourceFrame"]==f);
 var clip=set.Find(phase,dir);clip.frames=new[]{new ProductionFrame{sprite=sprites["pose_"+i.ToString("000")],seconds=.18f,hand=new Vector2(((float)p[0]-64)/32,(126-(float)p[1])/32),holdAngle=Mathf.Atan2(Vector3.Dot(delta,up),Vector3.Dot(delta,right))*Mathf.Rad2Deg,depth=(int)old["depth"],source="ProceduralGripR7 "+profile+" "+phase+" sourceFrame "+f}};clip.status="two-view-three-pose-IK-study-not-full-animation";
 }
 AssetDatabase.CreateAsset(set,Art+profile+".asset");}
 AssetDatabase.SaveAssets();return "Imported 12 procedural poses as two separate South/East studies; playable R7 scene unchanged.";
 }
}
