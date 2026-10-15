using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.U2D.Sprites;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;

// Invoked through Unity CLI run_script. No scene YAML or metadata editing.
public static class ProductionArt06B4
{
    private const string Destination="Assets/Mmorpg/Art/Production/";
    private const string ScenePath="Assets/Mmorpg/Scenes/Marco06B4Polish.unity";
    private static readonly string[] Directions={"south","west","north","east"};
    private static void OutsidePlay(){if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");}
    private static T Ensure<T>(GameObject go) where T:Component {var component=go.GetComponent<T>();return component!=null?component:go.AddComponent<T>();}
    private static T Asset<T>(string path,Func<T> create) where T:UnityEngine.Object
    {var asset=AssetDatabase.LoadAssetAtPath<T>(path);if(asset==null){asset=create();AssetDatabase.CreateAsset(asset,path);}return asset;}
    public static string Import()
    {
        OutsidePlay();var manifests=Directory.GetFiles("ArtSource","manifest.json",SearchOption.AllDirectories).Where(p=>p.Contains("Characters")||p.Contains("Creatures")).OrderBy(p=>p).ToArray();
        int count=0;Directory.CreateDirectory(Destination+"Animations");
        foreach(string path in manifests)
        {
            var json=JObject.Parse(File.ReadAllText(path));string id=(string)json["id"];float ppu=(float)json["ppu"];
            var clips=new List<ProductionClip>();
            foreach(var c in json["clips"])
            {
                string action=(string)c["animation"],direction=(string)c["direction"];
                var frames=c["frames"].ToArray();if((int)c["frameCount"]!=frames.Length||frames.Length==0)throw new InvalidDataException("Frame count: "+path);
                int width=(int)frames[0]["canvas"][0],height=(int)frames[0]["canvas"][1];
                var clip=new ProductionClip{action=action,direction=Array.IndexOf(Directions,direction),status=(string)c["status"],loop=(bool)c["loop"],frames=new ProductionFrame[frames.Length]};
                for(int i=0;i<frames.Length;i++)
                {
                    var f=frames[i];string source=(string)f["png"];
                    if(!source.Replace('\\','/').StartsWith("ArtSource/")||!File.Exists(source)||Path.GetFileName(source)!=$"frame_{i:000}.png")throw new InvalidDataException("Missing/ambiguous PNG: "+source);
                    if((int)f["canvas"][0]!=width||(int)f["canvas"][1]!=height)throw new InvalidDataException("Mixed canvas: "+source);
                    string output=Destination+id+"/"+action+"/"+direction+"/"+Path.GetFileName(source);Directory.CreateDirectory(Path.GetDirectoryName(output));
                    if(!File.Exists(output)||!File.ReadAllBytes(output).SequenceEqual(File.ReadAllBytes(source)))File.Copy(source,output,true);
                    AssetDatabase.ImportAsset(output,ImportAssetOptions.ForceSynchronousImport);
                    var imp=(TextureImporter)AssetImporter.GetAtPath(output);imp.GetSourceTextureWidthAndHeight(out int realW,out int realH);
                    if(realW!=width||realH!=height)throw new InvalidDataException("PNG/manifest dimensions: "+source);
                    imp.textureType=TextureImporterType.Sprite;imp.spriteImportMode=SpriteImportMode.Multiple;imp.spritePixelsPerUnit=ppu;
                    imp.filterMode=FilterMode.Point;imp.textureCompression=TextureImporterCompression.Uncompressed;imp.mipmapEnabled=false;imp.alphaIsTransparency=true;imp.wrapMode=TextureWrapMode.Clamp;imp.maxTextureSize=2048;
                    var settings=new TextureImporterSettings();imp.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;imp.SetTextureSettings(settings);imp.SaveAndReimport();
                    var factories=new SpriteDataProviderFactories();factories.Init();var provider=factories.GetSpriteEditorDataProviderFromObject(imp);provider.InitSpriteEditorDataProvider();
                    var capability=provider.GetDataProvider<ISpriteFrameEditCapability>()?.GetEditCapability();
                    if(capability==null)throw new InvalidOperationException("Sprite frame capability unavailable");
                    foreach(var flag in new[]{EEditCapability.EditSpriteRect,EEditCapability.EditPivot,EEditCapability.EditSpriteName,EEditCapability.CreateAndDeleteSprite})
                        if(!capability.Value.HasCapability(flag))throw new InvalidOperationException("Unsupported sprite operation: "+flag);
                    string name=id+"_"+action+"_"+direction+"_"+i.ToString("000");
                    var previous=provider.GetSpriteRects().FirstOrDefault(r=>r.name==name);
                    var rect=new SpriteRect{name=name,rect=new Rect(0,0,width,height),alignment=SpriteAlignment.Custom,pivot=new Vector2((float)f["pivot"][0]/width,1-(float)f["pivot"][1]/height),spriteID=previous!=null?previous.spriteID:GUID.Generate()};
                    provider.SetSpriteRects(new[]{rect});var ids=provider.GetDataProvider<ISpriteNameFileIdDataProvider>();
                    if(ids==null)throw new InvalidOperationException("Stable sprite name/ID provider unavailable");
                    ids.SetNameFileIdPairs(new[]{new SpriteNameFileIdPair(name,rect.spriteID)});provider.Apply();imp.SaveAndReimport();
                    var sprite=AssetDatabase.LoadAllAssetsAtPath(output).OfType<Sprite>().Single();var hand=f["rightHand"];
                    clip.frames[i]=new ProductionFrame{sprite=sprite,seconds=(float)f["duration"],hand=hand==null||hand.Type==JTokenType.Null?Vector2.zero:new Vector2(((float)hand[0]-(float)f["pivot"][0])/ppu,((float)f["pivot"][1]-(float)hand[1])/ppu),holdAngle=(float)f["equipmentAngle"],depth=(int)f["equipmentDepth"],source=(string)f["source"]};
                    clip.frames[i].events=f["events"]?.ToObject<string[]>()??Array.Empty<string>();
                    if(clip.frames[i].events.Any(e=>!new[]{"footstep","cloth","weapon-trail","pose-ready"}.Contains(e)))throw new InvalidDataException("Only presentation markers permitted: "+source);
                    if(clip.frames[i].seconds<=0)throw new InvalidDataException("Nonpositive frame duration");count++;
                }
                clips.Add(clip);string animPath=Destination+"Animations/"+id+"_"+action+"_"+direction+".anim";
                var animation=Asset<AnimationClip>(animPath,()=>new AnimationClip());animation.frameRate=12;
                var keys=new List<ObjectReferenceKeyframe>();float time=0;var events=new List<AnimationEvent>();
                for(int i=0;i<clip.frames.Length;i++)
                {
                    keys.Add(new ObjectReferenceKeyframe{time=time,value=clip.frames[i].sprite});
                    foreach(var e in frames[i]["events"]??new JArray())events.Add(new AnimationEvent{time=time,functionName="OnProductionVisualEvent",stringParameter=(string)e});
                    time+=clip.frames[i].seconds;
                }
                keys.Add(new ObjectReferenceKeyframe{time=time,value=clip.frames[clip.frames.Length-1].sprite});
                AnimationUtility.SetObjectReferenceCurve(animation,new EditorCurveBinding{path="BodySprite",type=typeof(SpriteRenderer),propertyName="m_Sprite"},keys.ToArray());
                var animationSettings=AnimationUtility.GetAnimationClipSettings(animation);animationSettings.loopTime=clip.loop;AnimationUtility.SetAnimationClipSettings(animation,animationSettings);AnimationUtility.SetAnimationEvents(animation,events.ToArray());EditorUtility.SetDirty(animation);
            }
            var set=Asset<ProductionCharacterSet>(Destination+id+".asset",()=>ScriptableObject.CreateInstance<ProductionCharacterSet>());set.characterId=id;set.pixelsPerUnit=ppu;set.referenceSpeed=3.5f;set.clips=clips.ToArray();EditorUtility.SetDirty(set);
        }
        ImportAuxiliary();AssetDatabase.SaveAssets();AssetDatabase.Refresh();return "Imported "+count+" existing character drawings with stable SpriteRects, pivots, clips and character sets, plus existing weapon/VFX. No new walk poses claimed.";
    }
    private static void ImportAuxiliary()
    {
        foreach(string file in Directory.GetFiles("ArtSource","manifest.json",SearchOption.AllDirectories).Where(p=>p.Contains("Weapons")||p.Contains("VFX")))
        {
            var json=JObject.Parse(File.ReadAllText(file));string id=(string)json["id"];var frames=json["frames"]?.ToArray()??new JToken[]{json};
            var keys=new List<ObjectReferenceKeyframe>();float time=0;
            for(int i=0;i<frames.Length;i++)
            {
                var f=frames[i];string source=(string)f["png"],output=Destination+"Auxiliary/"+id+"/frame_"+i.ToString("000")+".png";
                if(!File.Exists(source))throw new InvalidDataException(source);Directory.CreateDirectory(Path.GetDirectoryName(output));
                if(!File.Exists(output)||!File.ReadAllBytes(source).SequenceEqual(File.ReadAllBytes(output)))File.Copy(source,output,true);
                AssetDatabase.ImportAsset(output,ImportAssetOptions.ForceSynchronousImport);var imp=(TextureImporter)AssetImporter.GetAtPath(output);
                imp.GetSourceTextureWidthAndHeight(out int w,out int h);if(w!=(int)f["canvas"][0]||h!=(int)f["canvas"][1])throw new InvalidDataException(source+" canvas");
                imp.textureType=TextureImporterType.Sprite;imp.spriteImportMode=SpriteImportMode.Single;imp.spritePixelsPerUnit=(float)json["ppu"];imp.filterMode=FilterMode.Point;imp.textureCompression=TextureImporterCompression.Uncompressed;imp.mipmapEnabled=false;imp.wrapMode=TextureWrapMode.Clamp;imp.alphaIsTransparency=true;imp.maxTextureSize=2048;
                var settings=new TextureImporterSettings();imp.ReadTextureSettings(settings);settings.spriteMeshType=SpriteMeshType.FullRect;settings.spriteAlignment=(int)SpriteAlignment.Custom;settings.spritePivot=new Vector2((float)f["pivot"][0]/w,1-(float)f["pivot"][1]/h);imp.SetTextureSettings(settings);imp.SaveAndReimport();
                keys.Add(new ObjectReferenceKeyframe{time=time,value=AssetDatabase.LoadAssetAtPath<Sprite>(output)});time+=(float?)f["duration"]??.1f;
            }
            if(json["frames"]==null)continue;
            keys.Add(new ObjectReferenceKeyframe{time=time,value=keys[keys.Count-1].value});
            var animation=Asset<AnimationClip>(Destination+"Animations/"+id+".anim",()=>new AnimationClip());
            AnimationUtility.SetObjectReferenceCurve(animation,new EditorCurveBinding{path="",type=typeof(SpriteRenderer),propertyName="m_Sprite"},keys.ToArray());
            var settingsClip=AnimationUtility.GetAnimationClipSettings(animation);settingsClip.loopTime=(bool?)json["loop"]??false;AnimationUtility.SetAnimationClipSettings(animation,settingsClip);EditorUtility.SetDirty(animation);
        }
    }
    private static Sprite Auxiliary(string id,int i=0)=>AssetDatabase.LoadAssetAtPath<Sprite>(Destination+"Auxiliary/"+id+"/frame_"+i.ToString("000")+".png");
    public static string ReimportAndVerify()
    {
        OutsidePlay();Func<Dictionary<string,string>> ids=()=>AssetDatabase.FindAssets("t:Sprite",new[]{Destination}).Select(AssetDatabase.GUIDToAssetPath).Distinct().SelectMany(path=>AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>()).ToDictionary(s=>AssetDatabase.GetAssetPath(s)+":"+s.name,s=>{AssetDatabase.TryGetGUIDAndLocalFileIdentifier(s,out string guid,out long local);return guid+":"+local;});
        var before=ids();string result=Import();var after=ids();foreach(var pair in before)if(!after.TryGetValue(pair.Key,out string value)||pair.Value!=value)throw new Exception("Sprite reference changed: "+pair.Key);
        return result+" Reimport preserved all "+before.Count+" existing sprite GUID/local IDs.";
    }
    public static string CreateScene()
    {
        OutsidePlay();var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(current.path!="Assets/Mmorpg/Scenes/Marco06B3Art.unity"||current.isDirty)throw new InvalidOperationException("Clean B3 scene required");
        if(File.Exists(ScenePath))throw new IOException("Refusing to overwrite "+ScenePath);
        EditorSceneManager.SaveScene(current,ScenePath,true);EditorSceneManager.OpenScene(ScenePath);return ScenePath;
    }
    private static void Save(){var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();}
    private static void EnsurePauseInput(Canvas canvas)
    {
        Ensure<UnityEngine.UI.GraphicRaycaster>(canvas.gameObject);
        var systems=UnityEngine.Object.FindObjectsByType<EventSystem>(FindObjectsInactive.Include);
        if(systems.Length>1)throw new InvalidOperationException("Multiple EventSystems: review existing input before editing");
        var events=systems.Length==1?systems[0]:new GameObject("EventSystem",typeof(EventSystem)).GetComponent<EventSystem>();
        var module=Ensure<InputSystemUIInputModule>(events.gameObject);
        if(module.actionsAsset==null||module.point==null||module.leftClick==null)module.AssignDefaultActions();
        EditorUtility.SetDirty(events);EditorUtility.SetDirty(module);EditorUtility.SetDirty(canvas.gameObject);
    }
    public static string RepairPauseInput()
    {
        OutsidePlay();if(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=ScenePath)throw new InvalidOperationException("B4 scene required");
        var view=UnityEngine.Object.FindAnyObjectByType<SessionMenuView>(FindObjectsInactive.Include);
        if(view==null)throw new InvalidOperationException("Existing pause menu required");
        EnsurePauseInput(view.GetComponentInParent<Canvas>());Save();
        return "Existing HUD now has GraphicRaycaster and one EventSystem with InputSystemUIInputModule/default UI actions; menu hierarchy preserved.";
    }
    public static string Integrate()
    {
        OutsidePlay();if(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path!=ScenePath)throw new InvalidOperationException("B4 scene required");
        var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var actor=journey.Player;var root=actor.transform;
        var proxy=actor.GetComponent<SpriteRenderer>();var visual=root.Find("VisualRoot");if(visual==null){visual=new GameObject("VisualRoot").transform;visual.SetParent(root,false);}
        var bodyTransform=visual.Find("BodySprite");if(bodyTransform==null){bodyTransform=new GameObject("BodySprite").transform;bodyTransform.SetParent(visual,false);}
        var body=Ensure<SpriteRenderer>(bodyTransform.gameObject);body.sharedMaterial=proxy.sharedMaterial;
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Destination+"Hero.asset");body.sprite=set.Find("idle",0).frames[0].sprite;
        var old=actor.GetComponent<GameplaySpriteAnimator>();if(old!=null)old.enabled=false;
        var sword=actor.GetComponent<SwordSwing>();var animator=Ensure<ProductionSpriteAnimator>(actor.gameObject);animator.Configure(set,actor,body,sword);sword.ConfigureProduction(animator);
        var sync=Ensure<ProductionVisualSync>(actor.gameObject);sync.Configure(proxy,body);proxy.sprite=null;
        var hand=visual.Find("WeaponPivot")??root.Find("SwordHand");if(hand==null)throw new InvalidOperationException("Original sword missing");hand.SetParent(visual,false);hand.name="WeaponPivot";hand.localPosition=set.Find("idle",0).frames[0].hand;
        var swordRenderer=hand.Find("EquippedSword").GetComponent<SpriteRenderer>();if(Auxiliary("iron-sword")!=null)swordRenderer.sprite=Auxiliary("iron-sword");
        foreach(var effects in UnityEngine.Object.FindObjectsByType<SwordPresentationEffects>())
        {
            var so=new SerializedObject(effects);var slash=so.FindProperty("slash").objectReferenceValue as SpriteRenderer;
            if(Auxiliary("SwordCut")!=null)slash.sprite=Auxiliary("SwordCut");
            if(Auxiliary("Dodge")!=null){var array=so.FindProperty("dustFrames");array.arraySize=3;for(int i=0;i<3;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=Auxiliary("Dodge",i);so.ApplyModifiedPropertiesWithoutUndo();}
        }
        foreach(var impact in UnityEngine.Object.FindObjectsByType<SheetImpactFeedback>())if(Auxiliary("Impact")!=null)
        {var so=new SerializedObject(impact);var array=so.FindProperty("frames");array.arraySize=4;for(int i=0;i<4;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=Auxiliary("Impact",i);so.ApplyModifiedPropertiesWithoutUndo();}
        foreach(var marker in UnityEngine.Object.FindObjectsByType<ActionTargetVisual>())if(Auxiliary("WeaknessReading")!=null)marker.ConfigureArt(Auxiliary("WeaknessReading"),Auxiliary("HuntersMark"));
        var debug=Ensure<SwordSweepDebug>(actor.gameObject);debug.Configure(sword);
        foreach(var shadow in root.GetComponentsInChildren<SpriteGroundShadow>()){shadow.transform.SetParent(visual,true);shadow.Configure(body,shadow.GetComponent<SpriteRenderer>());}
        var camera=Camera.main;if(camera.GetComponent<AdaptivePixelViewport>()==null)camera.gameObject.AddComponent<AdaptivePixelViewport>();
        var ground=UnityEngine.Object.FindObjectsByType<UnityEngine.Tilemaps.Tilemap>().Single(t=>t.name=="Ground");ground.CompressBounds();var bounds=ground.localBounds;
        camera.GetComponent<CameraFollow>().ConfigureBounds(new Rect(bounds.min.x,bounds.min.y,bounds.size.x,bounds.size.y));
        var exploration=UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>();exploration.ConfigureSessionCommands();
        UnityEngine.Object.FindAnyObjectByType<ActionSliceHud>().ConfigureSessionMenu();UnityEngine.Object.FindAnyObjectByType<JourneyHud>().ConfigureTemporaryMessages();
        var commands=Ensure<LocalSessionCommands>(journey.gameObject);
        var canvas=UnityEngine.Object.FindObjectsByType<Canvas>().First(c=>c.renderMode==RenderMode.ScreenSpaceOverlay);
        EnsurePauseInput(canvas);
        var prior=canvas.transform.Find("SessionToolsB4");if(prior!=null)UnityEngine.Object.DestroyImmediate(prior.gameObject);
        var tools=new GameObject("SessionToolsB4",typeof(RectTransform));tools.transform.SetParent(canvas.transform,false);var tr=(RectTransform)tools.transform;tr.anchorMin=Vector2.zero;tr.anchorMax=Vector2.one;tr.offsetMin=tr.offsetMax=Vector2.zero;
        var menu=Panel(tools.transform,"Pause",new Vector2(.5f,.5f),new Vector2(340,310),Vector2.zero);Label(menu.transform,"Title","JORNADA",22,new Vector2(300,32),new Vector2(0,124));
        var buttons=new List<Button>();string[] names={"Continuar","Reiniciar sessão","Nova jornada · desenvolvimento","Configurações","Sair"};
        for(int i=0;i<names.Length;i++)buttons.Add(Button(menu.transform,names[i],new Vector2(0,76-i*42),new Vector2(290,34)));
        var confirmation=Panel(tools.transform,"ConfirmNewJourney",new Vector2(.5f,.5f),new Vector2(420,370),Vector2.zero);
        var description=Label(confirmation.transform,"Description","",17,new Vector2(380,270),new Vector2(0,32));description.alignment=TextAlignmentOptions.TopLeft;
        buttons.Add(Button(confirmation.transform,"Criar backup e reiniciar",new Vector2(0,-117),new Vector2(350,34)));buttons.Add(Button(confirmation.transform,"Cancelar",new Vector2(0,-159),new Vector2(350,34)));
        var settings=Panel(tools.transform,"Settings",new Vector2(.5f,.5f),new Vector2(340,210),Vector2.zero);Label(settings.transform,"Title","CONFIGURAÇÕES",22,new Vector2(300,32),new Vector2(0,72));Label(settings.transform,"VolumeLabel","Volume geral",17,new Vector2(280,30),new Vector2(0,25));
        buttons.Add(Button(settings.transform,"Voltar",new Vector2(0,-70),new Vector2(290,34)));
        var sliderGo=new GameObject("Volume",typeof(RectTransform),typeof(Slider));sliderGo.transform.SetParent(settings.transform,false);var sliderRect=(RectTransform)sliderGo.transform;sliderRect.sizeDelta=new Vector2(270,24);sliderRect.anchoredPosition=new Vector2(0,-15);
        var track=Panel(sliderGo.transform,"Track",new Vector2(.5f,.5f),new Vector2(270,8),Vector2.zero);var handle=Panel(sliderGo.transform,"Handle",new Vector2(.5f,.5f),new Vector2(14,24),Vector2.zero);handle.GetComponent<Image>().color=new Color(.8f,.66f,.35f);var slider=sliderGo.GetComponent<Slider>();slider.handleRect=(RectTransform)handle.transform;slider.targetGraphic=handle.GetComponent<Image>();slider.minValue=0;slider.maxValue=1;
        var error=Label(menu.transform,"Error","",13,new Vector2(310,50),new Vector2(0,-143));error.color=new Color(1,.7f,.5f);
        var view=tools.AddComponent<SessionMenuView>();view.Configure(commands,menu,confirmation,settings,description,error,buttons.ToArray(),slider);commands.Configure(journey,exploration,view);menu.SetActive(false);confirmation.SetActive(false);settings.SetActive(false);
        var monitor=Panel(tools.transform,"WorldDebug",new Vector2(1,0),new Vector2(270,245),new Vector2(-147,170));var label=Label(monitor.transform,"Metrics","WORLD DEBUG",13,new Vector2(250,225),Vector2.zero);label.alignment=TextAlignmentOptions.TopLeft;label.overflowMode=TextOverflowModes.Truncate;label.raycastTarget=false;
        // Passive overlay never intercepts pointer/input. History grows upward from its fixed bottom edge.
        ((RectTransform)monitor.transform).pivot=new Vector2(.5f,0);((RectTransform)monitor.transform).anchoredPosition=new Vector2(-147,48);monitor.GetComponent<Image>().raycastTarget=false;
        var lr=(RectTransform)label.transform;lr.anchorMin=Vector2.zero;lr.anchorMax=Vector2.one;lr.offsetMin=new Vector2(10,10);lr.offsetMax=new Vector2(-10,-10);
        var overlay=tools.AddComponent<WorldDebugOverlay>();overlay.Configure(monitor,label);monitor.SetActive(false);
        if(journey.GetComponent<DiagnosticsService>()==null)journey.gameObject.AddComponent<DiagnosticsService>();
        var scenes=EditorBuildSettings.scenes.ToList();if(!scenes.Any(s=>s.path==ScenePath)){scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.scenes=scenes.ToArray();}
        // Production visual-only prefab has no motor, colliders or authority.
        Directory.CreateDirectory(Destination+"Prefabs");var copy=UnityEngine.Object.Instantiate(visual.gameObject);copy.name="PlayerVisualB4";
        copy.transform.position=Vector3.zero;copy.transform.rotation=Quaternion.identity;copy.transform.localScale=Vector3.one;
        var copyBody=copy.transform.Find("BodySprite").GetComponent<SpriteRenderer>();
        Ensure<ProductionVisualDefinition>(copy).Configure(set,copyBody,copy.transform.Find("WeaponPivot"));
        foreach(var shadow in copy.GetComponentsInChildren<SpriteGroundShadow>())shadow.Configure(copyBody,shadow.GetComponent<SpriteRenderer>());
        PrefabUtility.SaveAsPrefabAsset(copy,Destination+"Prefabs/PlayerVisualB4.prefab");UnityEngine.Object.DestroyImmediate(copy);
        Save();return "B4 integrated: child body, per-frame grips, original sword and Sweep, isolated session profile, pause/reset/menu/F8, adaptive integer viewport.";
    }
    private static GameObject Panel(Transform parent,string name,Vector2 anchor,Vector2 size,Vector2 position)
    {var go=new GameObject(name,typeof(RectTransform),typeof(Image));go.transform.SetParent(parent,false);var r=(RectTransform)go.transform;r.anchorMin=r.anchorMax=anchor;r.sizeDelta=size;r.anchoredPosition=position;var img=go.GetComponent<Image>();img.color=new Color(.065f,.08f,.09f,.96f);return go;}
    private static TMP_Text Label(Transform parent,string name,string value,float size,Vector2 dimensions,Vector2 position)
    {var go=new GameObject(name,typeof(RectTransform),typeof(TextMeshProUGUI));go.transform.SetParent(parent,false);var r=(RectTransform)go.transform;r.sizeDelta=dimensions;r.anchoredPosition=position;var text=go.GetComponent<TextMeshProUGUI>();text.font=UnityEngine.Object.FindObjectsByType<TMP_Text>(FindObjectsInactive.Include).First(t=>t.font!=null).font;text.fontSize=size;text.text=value;text.color=new Color(.92f,.86f,.7f);text.alignment=TextAlignmentOptions.Center;text.raycastTarget=false;return text;}
    private static Button Button(Transform parent,string name,Vector2 position,Vector2 size)
    {var go=Panel(parent,name,new Vector2(.5f,.5f),size,position);go.GetComponent<Image>().color=new Color(.19f,.23f,.22f);var b=go.AddComponent<Button>();b.targetGraphic=go.GetComponent<Image>();Label(go.transform,"Text",name,16,size,Vector2.zero);return b;}
}
