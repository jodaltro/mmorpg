using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public static class PolishActionCharacter
{
    public const string ScenePath="Assets/Mmorpg/Scenes/Marco06B2World.unity";
    private static TMP_FontAsset font;
    public static string Inspect()
    {
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();
        return string.Join("\n",canvas.GetComponentsInChildren<RectTransform>(true).Select(t=>t.name+" "+t.anchoredPosition+" "+t.sizeDelta))+"\nPipeline="+GraphicsSettings.currentRenderPipeline?.GetType().FullName;
    }
    public static string Build()
    {
        if(EditorApplication.isPlaying || File.Exists(ScenePath))throw new InvalidOperationException("Stop Play; destination scene must not exist.");
        for(int i=0;i<EditorSceneManager.sceneCount;i++)if(EditorSceneManager.GetSceneAt(i).isDirty)throw new InvalidOperationException("Preserve dirty scenes; save them first.");
        var scene=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/Marco06B1World.unity");
        font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        var story=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var actor=story.Player;var server=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        var motor=actor.GetComponent<ActorMotor>();motor.ConfigureActionMovement();actor.GetComponent<Rigidbody2D>().interpolation=RigidbodyInterpolation2D.Interpolate;
        var renderer=actor.GetComponent<SpriteRenderer>();actor.GetComponent<ActorVisual>().ConfigureSwordPresentation();
        var hand=new GameObject("SwordHand").transform;hand.SetParent(actor.transform,false);
        var blade=new GameObject("EquippedSword").AddComponent<SpriteRenderer>();blade.transform.SetParent(hand,false);blade.sharedMaterial=renderer.sharedMaterial;
        blade.sprite=CreateSword();
        var sword=actor.gameObject.AddComponent<SwordSwing>();sword.Configure(server,actor,motor,renderer,hand,blade);server.ConfigureSword(sword);
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var scaler=canvas.GetComponent<UnityEngine.UI.CanvasScaler>();
        scaler.uiScaleMode=UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;scaler.referenceResolution=new Vector2(960,540);scaler.matchWidthOrHeight=.5f;
        var transforms=canvas.GetComponentsInChildren<Transform>(true);
        foreach(string name in new[]{"ActionTechniques","ActionTechniqueBackplate","Controls","JourneyHint","ActionDialogueBackplate"})
        {var t=transforms.FirstOrDefault(x=>x.name==name);if(t!=null)t.gameObject.SetActive(false);}
        Move(transforms,"HealthText",Vector2.up,new Vector2(18,-12),new Vector2(190,22),14);
        Move(transforms,"HealthBackground",Vector2.up,new Vector2(18,-38),new Vector2(190,12));
        Move(transforms,"HealthFill",Vector2.up,Vector2.zero,new Vector2(190,12));
        Move(transforms,"JourneyDialogue",new Vector2(.5f,0),new Vector2(0,180),new Vector2(630,38),13);
        Move(transforms,"ExplorationContext",new Vector2(.5f,0),new Vector2(0,144),new Vector2(600,42),14);
        var labels=new TMP_Text[6];var fills=new UnityEngine.UI.Image[6];
        string[] names={"LMB / J\nEspada","RMB\nPesado","Espaço\nEsquiva","Q\nLeitura","F\nContra","C\nMarca"};
        var bar=Rect("RpgSkillSlots",canvas.transform,new Vector2(.5f,0),new Vector2(0,12),new Vector2(440,58));
        for(int i=0;i<6;i++)
        {
            var slot=Rect("SkillSlot"+i,bar,new Vector2(0,0),new Vector2(i*74,0),new Vector2(68,58));slot.pivot=Vector2.zero;
            var bg=slot.gameObject.AddComponent<UnityEngine.UI.Image>();bg.color=new Color(.035f,.055f,.075f,.94f);bg.raycastTarget=false;
            var fill=Rect("Cooldown",slot,Vector2.zero,Vector2.zero,new Vector2(68,58));fill.pivot=Vector2.zero;
            fills[i]=fill.gameObject.AddComponent<UnityEngine.UI.Image>();fills[i].sprite=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");fills[i].type=UnityEngine.UI.Image.Type.Filled;fills[i].fillMethod=UnityEngine.UI.Image.FillMethod.Vertical;fills[i].fillOrigin=0;fills[i].color=new Color(.18f,.28f,.4f,.8f);fills[i].raycastTarget=false;
            labels[i]=Text("Caption",slot,Vector2.zero,new Vector2(2,2),new Vector2(64,54),names[i],12);labels[i].rectTransform.pivot=Vector2.zero;labels[i].alignment=TextAlignmentOptions.Center;
        }
        canvas.gameObject.AddComponent<RpgSkillBar>().Configure(actor,UnityEngine.Object.FindAnyObjectByType<ActionCombat>(),story,fills,labels);
        var hint=Text("CombatFeedback",canvas.transform,new Vector2(.5f,0),new Vector2(0,84),new Vector2(560,28),"",14);hint.alignment=TextAlignmentOptions.Center;
        var footer=Text("RpgControls",canvas.transform,new Vector2(1,0),new Vector2(-18,14),new Vector2(210,36),"I  Inventário     Tab  Diário\nEsc  Pausa     E  Interagir",12);footer.alignment=TextAlignmentOptions.BottomRight;
        var slash=Line("SwordArc",actor.transform,renderer.sharedMaterial,10,new Color(1,.9f,.5f,.55f),.06f);
        var impact=Line("SwordImpact",actor.transform,renderer.sharedMaterial,8,new Color(1,.95f,.7f),.06f);impact.loop=true;
        var audio=actor.gameObject.AddComponent<AudioSource>();audio.playOnAwake=false;audio.spatialBlend=0;
        actor.gameObject.AddComponent<PlayerCombatFeedback>().Configure(server,sword,actor,motor,renderer,WalkSprites(renderer.sprite),slash,impact,hint,audio);
        foreach(string name in new[]{"JourneyJournal","ActionSecondaryPanel","ExplorationDialogue"})transforms.First(t=>t.name==name).SetAsLastSibling();
        // Detect the active pipeline before using the URP implementation.
        if(!(GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset))throw new InvalidOperationException("Expected existing URP pipeline");
        var camera=Camera.main;camera.allowHDR=false;camera.allowMSAA=false;camera.allowDynamicResolution=false;
        var pp=camera.GetComponent<PixelPerfectCamera>()??camera.gameObject.AddComponent<PixelPerfectCamera>();pp.assetsPPU=16;pp.refResolutionX=320;pp.refResolutionY=180;pp.gridSnapping=PixelPerfectCamera.GridSnapping.PixelSnapping;pp.cropFrame=PixelPerfectCamera.CropFrame.Windowbox;
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene,ScenePath);
        var scenes=EditorBuildSettings.scenes.ToList();scenes.Insert(0,new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.scenes=scenes.ToArray();
        return "Created Marco06B2World from preserved B1: sword, swept melee, compact HUD and URP pixel perfect.";
    }
    private static Sprite CreateSword()
    {
        const string path="Assets/Mmorpg/Art/Sword06B2.png";if(File.Exists(path))throw new InvalidOperationException("Preserve existing sword asset");
        var t=new Texture2D(20,8,TextureFormat.RGBA32,false);var pixels=new Color[160];
        for(int x=0;x<20;x++)for(int y=0;y<8;y++)
        {Color c=Color.clear;if(x>=6&&x<18&&y>=3&&y<=4)c=y==4?new Color32(235,246,249,255):new Color32(119,156,174,255);if(x==18&&y==4)c=Color.white;if(x==5&&y>=1&&y<=6)c=new Color32(224,175,76,255);if(x>=1&&x<=4&&y>=3&&y<=4)c=new Color32(123,73,48,255);pixels[y*20+x]=c;}
        t.SetPixels(pixels);t.Apply();File.WriteAllBytes(path,t.EncodeToPNG());UnityEngine.Object.DestroyImmediate(t);return Import(path,new Vector2(.1f,.5f));
    }
    private static Sprite[] WalkSprites(Sprite idle)
    {
        var path=AssetDatabase.GetAssetPath(idle);var input=new Texture2D(2,2);input.LoadImage(File.ReadAllBytes(path));
        var frames=new Sprite[]{idle,null,null};for(int f=1;f<=2;f++)
        {
            string output="Assets/Mmorpg/Art/HeroWalk06B2_"+f+".png";if(File.Exists(output))throw new InvalidOperationException("Preserve existing walk asset");
            var t=new Texture2D(input.width,input.height,TextureFormat.RGBA32,false);var p=input.GetPixels();
            // Move alternating boot pixels one pixel, preserving the existing silhouette/palette.
            for(int y=0;y<4;y++)for(int x=0;x<input.width;x++)t.SetPixel(x,y,Color.clear);
            t.SetPixels(p);for(int y=0;y<4;y++)for(int x=0;x<input.width;x++){var c=input.GetPixel(x,y);if(c.a>.1f){t.SetPixel(x,y,Color.clear);t.SetPixel(x,Mathf.Clamp(y+((x<input.width/2)==(f==1)?1:0),0,input.height-1),c);}}
            t.Apply();File.WriteAllBytes(output,t.EncodeToPNG());UnityEngine.Object.DestroyImmediate(t);frames[f]=Import(output,new Vector2(.5f,.5f));
        }UnityEngine.Object.DestroyImmediate(input);return frames;
    }
    private static Sprite Import(string path,Vector2 pivot)
    {AssetDatabase.ImportAsset(path);var i=(TextureImporter)AssetImporter.GetAtPath(path);i.textureType=TextureImporterType.Sprite;i.spritePixelsPerUnit=16;i.filterMode=FilterMode.Point;i.mipmapEnabled=false;i.textureCompression=TextureImporterCompression.Uncompressed;var s=new TextureImporterSettings();i.ReadTextureSettings(s);s.spriteAlignment=(int)SpriteAlignment.Custom;s.spritePivot=pivot;i.SetTextureSettings(s);i.SaveAndReimport();return AssetDatabase.LoadAssetAtPath<Sprite>(path);}
    private static LineRenderer Line(string name,Transform parent,Material material,int count,Color color,float width)
    {var l=new GameObject(name).AddComponent<LineRenderer>();l.transform.SetParent(parent,false);l.sharedMaterial=material;l.positionCount=count;l.startWidth=l.endWidth=width;l.startColor=l.endColor=color;l.useWorldSpace=true;l.enabled=false;return l;}
    private static RectTransform Rect(string name,Transform parent,Vector2 anchor,Vector2 pos,Vector2 size)
    {var r=new GameObject(name,typeof(RectTransform)).GetComponent<RectTransform>();r.SetParent(parent,false);r.anchorMin=r.anchorMax=r.pivot=anchor;r.anchoredPosition=pos;r.sizeDelta=size;return r;}
    private static TMP_Text Text(string name,Transform parent,Vector2 anchor,Vector2 pos,Vector2 size,string text,int fontSize)
    {var r=Rect(name,parent,anchor,pos,size);var t=r.gameObject.AddComponent<TextMeshProUGUI>();t.font=font;t.fontSize=fontSize;t.text=text;t.raycastTarget=false;t.color=new Color(.94f,.91f,.8f);return t;}
    private static void Move(Transform[] all,string name,Vector2 anchor,Vector2 pos,Vector2 size,int fontSize=0)
    {var r=all.FirstOrDefault(t=>t.name==name) as RectTransform;if(r==null)return;r.anchorMin=r.anchorMax=r.pivot=anchor;r.anchoredPosition=pos;r.sizeDelta=size;if(fontSize>0)r.GetComponent<TMP_Text>().fontSize=fontSize;}
}
