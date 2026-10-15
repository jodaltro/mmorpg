using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.InputSystem.UI;

public static class BuildExpandedWorld
{
    public const string Path="Assets/Mmorpg/Scenes/Marco05World.unity";
    private static TMP_FontAsset font;
    private static Sprite square;
    public static object Build()
    {
        if(File.Exists(Path))throw new InvalidOperationException("Scene exists; refusing overwrite.");
        if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Stop Play first.");
        for(int i=0;i<UnityEngine.SceneManagement.SceneManager.sceneCount;i++)if(UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).isDirty)throw new InvalidOperationException("Existing scene is dirty.");
        var content=JObject.Parse(File.ReadAllText("Backend/authority/journey/content.json"));
        var config=JObject.Parse(File.ReadAllText("Temp/m05-public-config.json"));
        font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        if(font==null)throw new InvalidOperationException("Existing TMP font missing.");
        square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");
        var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
        Backdrop();
        var cameraObject=new GameObject("Main Camera");cameraObject.tag="MainCamera";var camera=cameraObject.AddComponent<Camera>();camera.orthographic=true;camera.orthographicSize=6;camera.transform.position=new Vector3(0,0,-10);camera.rect=new Rect(.23f,.18f,.43f,.72f);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.08f,.12f,.14f);
        var canvasObject=new GameObject("World UI",typeof(RectTransform),typeof(Canvas),typeof(UnityEngine.UI.CanvasScaler),typeof(UnityEngine.UI.GraphicRaycaster));var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;var scaler=canvasObject.GetComponent<UnityEngine.UI.CanvasScaler>();scaler.uiScaleMode=UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;scaler.referenceResolution=new Vector2(1366,768);
        var eventSystem=new GameObject("EventSystem",typeof(UnityEngine.EventSystems.EventSystem),typeof(InputSystemUIInputModule));
        var session=new GameObject("WorldJourneySession").AddComponent<WorldJourneySession>();
        var view=new GameObject("WorldJourneyView").AddComponent<WorldJourneyView>();
        var hud=canvasObject.AddComponent<WorldJourneyHud>();var map=new List<WorldJourneyView.Area>();int regionIndex=0;
        foreach(var region in content["regions"])
        {
            string id=region.Value<string>("id");var area=new GameObject(region.Value<string>("name"));map.Add(new WorldJourneyView.Area{id=id,root=area});
            Color ground=new[]{new Color(.20f,.25f,.26f),new Color(.14f,.28f,.20f),new Color(.20f,.18f,.22f),new Color(.13f,.24f,.26f),new Color(.25f,.23f,.32f)}[regionIndex++];Sprite("Floor",area.transform,square,Vector2.zero,new Vector2(12,12),ground,-100);
            var random=new System.Random(120+regionIndex);for(int i=0;i<75;i++)Sprite("Pixel detail",area.transform,square,new Vector2((float)random.NextDouble()*10-5,(float)random.NextDouble()*10-5),new Vector2(.125f,.125f),ground*1.25f,-99);
            int index=0;
            foreach(string category in new[]{"npcs","nodes","creatures"})foreach(var entity in content[category].Where(x=>x.Value<string>("region")==id))
            {Vector2 p=new Vector2(-4+(index%3)*4,4-(index/3)*2);index++;Sprite(entity.Value<string>("id"),area.transform,category=="creatures"?AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Wolf.png"):square,p,category=="creatures"?Vector2.one:new Vector2(.6f,.6f),category=="npcs"?new Color(.9f,.75f,.45f):category=="nodes"?new Color(.4f,.7f,.55f):new Color(.7f,.55f,.7f),1);var label=new GameObject("Name").AddComponent<TextMeshPro>();label.transform.SetParent(area.transform);label.transform.position=p+new Vector2(0,-.65f);label.font=font;label.fontSize=3.7f;label.alignment=TextAlignmentOptions.Center;label.rectTransform.sizeDelta=new Vector2(3.7f,.65f);label.text=entity.Value<string>("name");}
            area.SetActive(id=="valdoria");
        }
        var hero=Sprite("Player",null,AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Hero.png"),new Vector2(-5,-3),Vector2.one,Color.white,5);
        var enemy=Sprite("Encounter",null,AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Wolf.png"),new Vector2(3,0),Vector2.one,Color.white,5);enemy.gameObject.SetActive(false);view.Configure(map.ToArray(),hero.transform,enemy);
        Transform ui=canvasObject.transform;
        Panel("Actions background",ui,new Vector2(0,.17f),new Vector2(.23f,.91f));Panel("Journal background",ui,new Vector2(.67f,.17f),new Vector2(1,.91f));Panel("Login background",ui,Vector2.zero,new Vector2(1,.16f));
        var title=Text("Title",ui,"JORNADAS DE VALDORIA",new Vector2(.02f,.92f),new Vector2(.34f,.99f),24);
        var status=Text("Status",ui,"Entre para começar",new Vector2(.35f,.92f),new Vector2(.98f,.99f),16);
        var email=Input("Email",ui,"Email",new Vector2(.02f,.09f),new Vector2(.23f,.145f));
        var password=Input("Password",ui,"Senha",new Vector2(.25f,.09f),new Vector2(.44f,.145f));password.contentType=TMP_InputField.ContentType.Password;
        var name=Input("Name",ui,"Nome",new Vector2(.46f,.09f),new Vector2(.62f,.145f));name.text="Viajante";
        var idInput=Input("Character ID",ui,"ID para continuar; vazio cria personagem",new Vector2(.02f,.015f),new Vector2(.62f,.075f));
        var login=Button("Login",ui,"Entrar / continuar",new Vector2(.65f,.09f),new Vector2(.81f,.145f));
        var logout=Button("Logout",ui,"Sair",new Vector2(.83f,.09f),new Vector2(.98f,.145f));
        Text("Instructions",ui,"WASD: caminhar • botões: interações e turnos",new Vector2(.65f,.015f),new Vector2(.98f,.075f),14);
        var buttons=new List<UnityEngine.UI.Button>();for(int i=0;i<12;i++)buttons.Add(Button("Action "+i,ui,"Ação",new Vector2(.012f,.83f-i*.05f),new Vector2(.218f,.875f-i*.05f)));
        var prev=Button("Previous",ui,"‹",new Vector2(.01f,.22f),new Vector2(.05f,.26f));var next=Button("Next",ui,"›",new Vector2(.18f,.22f),new Vector2(.22f,.26f));var page=Text("Page",ui,"Ações 1/1",new Vector2(.05f,.22f),new Vector2(.18f,.26f),14);
        // ScrollRect hierarchy: viewport image+mask, top-anchored content with preferred height.
        var scroll=Rect("Journal",ui,new Vector2(.68f,.22f),new Vector2(.99f,.89f));var sr=scroll.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();sr.horizontal=false;sr.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
        var viewport=Rect("Viewport",scroll,Vector2.zero,Vector2.one);viewport.gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(.08f,.1f,.14f);viewport.gameObject.AddComponent<UnityEngine.UI.Mask>().showMaskGraphic=false;
        var journal=Text("Content",viewport,"",new Vector2(0,1),Vector2.one,17);journal.rectTransform.pivot=new Vector2(.5f,1);journal.rectTransform.sizeDelta=new Vector2(0,100);journal.alignment=TextAlignmentOptions.TopLeft;var fit=journal.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>();fit.verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;sr.viewport=viewport;sr.content=journal.rectTransform;
        hud.Configure(session,email,password,name,idInput,title,status,journal,page,login,logout,prev,next,buttons.ToArray());session.Configure(config.Value<string>("backendUrl"),config.Value<string>("authUrl"),config.Value<string>("publishableKey"),hud,view);
        EditorSceneManager.SaveScene(scene,Path);var entries=EditorBuildSettings.scenes.ToList();entries.Add(new EditorBuildSettingsScene(Path,true));EditorBuildSettings.scenes=entries.ToArray();AssetDatabase.SaveAssets();
        return new{scene=Path,regions=map.Count,originalScenePreserved=File.Exists("Assets/Mmorpg/Scenes/OfflineClearing.unity"),secretsSerialized=false};
    }
    private static RectTransform Rect(string name,Transform parent,Vector2 min,Vector2 max){var r=new GameObject(name,typeof(RectTransform)).GetComponent<RectTransform>();r.SetParent(parent,false);r.anchorMin=min;r.anchorMax=max;r.offsetMin=new Vector2(4,2);r.offsetMax=new Vector2(-4,-2);return r;}
    private static void Backdrop(){var camera=new GameObject("WorldBackdropCamera").AddComponent<Camera>();camera.depth=-20;camera.cullingMask=0;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.06f,.08f);}
    public static object FixViewportClear()
    {
        if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Stop Play first");var scene=EditorSceneManager.GetActiveScene();if(scene.path!=Path||scene.isDirty)throw new InvalidOperationException("Saved expanded scene required");
        if(!scene.GetRootGameObjects().Any(x=>x.name=="WorldBackdropCamera"))Backdrop();
        foreach(var text in scene.GetRootGameObjects().SelectMany(x=>x.GetComponentsInChildren<TextMeshPro>(true)))text.fontSize=3.7f;
        var labels=scene.GetRootGameObjects().SelectMany(x=>x.GetComponentsInChildren<TextMeshProUGUI>(true)).ToArray();var heading=labels.Single(x=>x.name=="Title").rectTransform;heading.anchorMin=new Vector2(.02f,.92f);heading.anchorMax=new Vector2(.34f,.99f);var message=labels.Single(x=>x.name=="Status").rectTransform;message.anchorMin=new Vector2(.35f,.92f);message.anchorMax=new Vector2(.98f,.99f);
        EditorSceneManager.SaveScene(scene);return new{targetedFix=true,fullFrameCleared=true,regionLabelSize=3.7};
    }
    private static TMP_Text Text(string name,Transform parent,string value,Vector2 min,Vector2 max,int size){var r=Rect(name,parent,min,max);var t=r.gameObject.AddComponent<TextMeshProUGUI>();t.font=font;t.fontSize=size;t.color=new Color(.9f,.95f,1);t.alignment=TextAlignmentOptions.MidlineLeft;t.text=value;t.raycastTarget=false;return t;}
    private static void Panel(string name,Transform parent,Vector2 min,Vector2 max){Rect(name,parent,min,max).gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(.08f,.1f,.14f,.95f);}
    private static UnityEngine.UI.Button Button(string name,Transform parent,string label,Vector2 min,Vector2 max){var r=Rect(name,parent,min,max);r.gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(.16f,.23f,.29f);var b=r.gameObject.AddComponent<UnityEngine.UI.Button>();var text=Text("Label",r,label,Vector2.zero,Vector2.one,14);text.alignment=TextAlignmentOptions.Center;return b;}
    private static TMP_InputField Input(string name,Transform parent,string hint,Vector2 min,Vector2 max){var r=Rect(name,parent,min,max);r.gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(.16f,.23f,.29f);var viewport=Rect("Viewport",r,Vector2.zero,Vector2.one);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();var value=(TextMeshProUGUI)Text("Value",viewport,"",Vector2.zero,Vector2.one,15);var placeholder=Text("Placeholder",viewport,hint,Vector2.zero,Vector2.one,14);placeholder.color=new Color(.65f,.73f,.8f);var input=r.gameObject.AddComponent<TMP_InputField>();input.textViewport=viewport;input.textComponent=value;input.placeholder=placeholder;return input;}
    private static SpriteRenderer Sprite(string name,Transform parent,Sprite sprite,Vector2 p,Vector2 scale,Color color,int order){var go=new GameObject(name);go.transform.SetParent(parent);go.transform.position=p;go.transform.localScale=scale;var r=go.AddComponent<SpriteRenderer>();r.sprite=sprite;r.color=color;r.sortingOrder=order;r.sharedMaterial=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");return r;}
}
