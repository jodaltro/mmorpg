using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class BuildActionVerticalSlice
{
    public const string Path="Assets/Mmorpg/Scenes/ActionVerticalSlice.unity";
    private static Sprite square;
    private static Material material;
    private static TMP_FontAsset font;
    public static string Build()
    {
        if(EditorApplication.isPlaying || File.Exists(Path)) throw new InvalidOperationException("Stop Play; scene generation refuses existing destination.");
        for(int i=0;i<UnityEngine.SceneManagement.SceneManager.sceneCount;i++)
            if(UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).isDirty)throw new InvalidOperationException("Dirty scene: preserve user changes first.");
        var scene=EditorSceneManager.OpenScene("Assets/Mmorpg/Scenes/OfflineClearing.unity");
        // Save as a NEW scene before authoring; source is never saved by this tool.
        if(!EditorSceneManager.SaveScene(scene,Path))throw new IOException("Cannot create isolated scene");
        var game=UnityEngine.Object.FindAnyObjectByType<GameSession>();
        var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();
        square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");
        material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        journey.ConfigureIsolatedSave("action-vertical-slice.json");
        journey.ConfigureDecisions(DecisionMode.Deterministic,"http://127.0.0.1:8091/v1/decisions/evaluate");
        journey.WorldEvents.ConfigureDecisions(DecisionMode.Deterministic,"http://127.0.0.1:8091/v1/decisions/evaluate");
        game.Player.transform.position=new Vector3(-8,-1,0);
        game.Wolf.transform.position=new Vector3(4,0,0);
        game.Player.GetComponent<ActorMotor>().ConfigureActionMovement();game.Wolf.GetComponent<ActorMotor>().ConfigureActionMovement();
        game.Wolf.GetComponent<WolfBrain>().Configure(game.Player,authority,new[]{new Vector2(4,0),new Vector2(5,-1),new Vector2(4,-1)});
        var combat=game.Player.gameObject.AddComponent<ActionCombat>();
        var cue=Block("HeavyWindup",Vector2.zero,new Vector2(.5f,.5f),Color.yellow,false,game.Player.transform,300).GetComponent<SpriteRenderer>();cue.enabled=false;
        combat.Configure(authority,journey,cue);authority.ConfigureAction(combat);game.Player.GetComponent<PlayerController>().ConfigureAction(combat);
        var root=new GameObject("ValdoriaAndForest").transform;
        Block("VillageGround",new Vector2(-6,0),new Vector2(11,15),new Color(.26f,.3f,.23f),false,root,-490);
        Block("WalkingPath",new Vector2(0,0),new Vector2(22,1.8f),new Color(.43f,.36f,.25f),false,root,-480);
        Block("VillageLane",new Vector2(-7,0),new Vector2(1.5f,11),new Color(.43f,.36f,.25f),false,root,-479);
        Block("MiraHouse",new Vector2(-9,4.4f),new Vector2(3,2),new Color(.45f,.34f,.3f),true,root);
        Block("OrinHouse",new Vector2(-3,5),new Vector2(2.5f,2),new Color(.4f,.35f,.25f),true,root);
        Block("ForestHedgeNorth",new Vector2(0,4.5f),new Vector2(.8f,7),new Color(.15f,.33f,.18f),true,root);
        Block("ForestHedgeSouth",new Vector2(0,-4.5f),new Vector2(.8f,7),new Color(.15f,.33f,.18f),true,root);
        WorldLabel("VALDORIA",new Vector2(-7,6.8f),root);
        WorldLabel("FLORESTA CINZENTA",new Vector2(6,6.8f),root);
        WorldLabel("Passagem — caminhe",new Vector2(0,1.6f),root);
        foreach(var item in journey.Interactions)
        {
            if(item.Kind==InteractionKind.Mira)item.transform.position=new Vector3(-8,1,0);
            if(item.Kind==InteractionKind.Orin)item.transform.position=new Vector3(-3,3,0);
            if(item.Kind==InteractionKind.Trace)item.transform.position=new Vector3(2,1.6f,0);
            if(item.Kind==InteractionKind.NoticeBoard)item.transform.position=new Vector3(-6,3.4f,0);
            if(item.Kind==InteractionKind.Mira || item.Kind==InteractionKind.Orin) {item.gameObject.layer=8;var col=item.gameObject.AddComponent<BoxCollider2D>();col.size=new Vector2(.5f,.6f);}
        }
        Creature(game.Wolf,game.Player,authority,CreatureKind.Spider,new Vector2(8,-4),root);
        Creature(game.Wolf,game.Player,authority,CreatureKind.Golem,new Vector2(8,4),root);
        new GameObject("ActionMetrics").AddComponent<ActionMetrics>();
        UnityEngine.Object.FindAnyObjectByType<JourneyInput>().enabled=false;
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();
        var view=UnityEngine.Object.FindAnyObjectByType<JourneyHud>();
        var oldControls=canvas.GetComponentsInChildren<TMP_Text>(true).First(t=>t.name=="Controls");
        oldControls.text="WASD mover · Mouse mirar · Esq. ataque · Dir. pesado · Espaço esquiva · E interação · I inventário · Tab diário · Esc pausa · R continuar";oldControls.fontSize=12;
        var bar=UiText("ActionTechniques",canvas.transform,new Vector2(24,-84),new Vector2(910,48),15);
        var panel=new GameObject("ActionSecondaryPanel",typeof(RectTransform),typeof(UnityEngine.UI.Image));panel.transform.SetParent(canvas.transform,false);
        var pr=(RectTransform)panel.transform;pr.anchorMin=pr.anchorMax=pr.pivot=new Vector2(.5f,.5f);pr.sizeDelta=new Vector2(600,270);
        panel.GetComponent<UnityEngine.UI.Image>().color=new Color(.03f,.06f,.06f,.97f);
        var text=UiText("ActionSecondaryText",panel.transform,new Vector2(20,-20),new Vector2(560,230),20);panel.SetActive(false);
        canvas.gameObject.AddComponent<ActionSliceHud>().Configure(journey,view,combat,bar,text,panel);
        var camera=Camera.main;camera.transform.position=new Vector3(-8,-1,-10);camera.orthographicSize=5;
        CompletePresentation();
        TuneHud();
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
        return "Created ActionVerticalSlice from original action scene; local persistence isolated; source scenes preserved.";
    }
    public static string CompletePresentation()
    {
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying || scene.path!=Path)throw new InvalidOperationException("Action scene outside Play required");
        if(GameObject.Find("ActionTargets")!=null)return "Presentation already completed";
        square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();var combat=UnityEngine.Object.FindAnyObjectByType<ActionCombat>();
        var root=new GameObject("ActionTargets").transform;
        foreach(var actor in UnityEngine.Object.FindObjectsByType<ActorHealth>(FindObjectsSortMode.None).Where(a=>a.Faction!=Faction.Player))
        {
            var mark=Block("ActionTargetMark",actor.transform.position,new Vector2(.4f,.1f),Color.cyan,false,root,500).GetComponent<SpriteRenderer>();
            mark.enabled=false;mark.gameObject.AddComponent<ActionTargetVisual>().Configure(journey,combat,actor,mark);
        }
        var passage=Block("Passagem para floresta",new Vector2(-.8f,0),new Vector2(.18f,.3f),new Color(.65f,.5f,.28f),false,root).AddComponent<JourneyInteractable>();passage.Configure(InteractionKind.Passage);
        journey.ConfigureWorldEvents(journey.WorldEvents,journey.Interactions.Concat(new[]{passage}).ToArray());
        UnityEngine.Object.FindAnyObjectByType<HealthHud>().ConfigureAction();
        GameObject.Find("TreeEast").transform.position=new Vector3(10,5,0);
        var scenes=EditorBuildSettings.scenes.ToList();if(!scenes.Any(s=>s.path==Path))scenes.Add(new EditorBuildSettingsScene(Path,true));EditorBuildSettings.scenes=scenes.ToArray();
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return "Target marks, contextual passage and compact action status added";
    }
    public static string TuneHud()
    {
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();if(EditorApplication.isPlaying || scene.path!=Path)throw new InvalidOperationException("Action scene outside Play required");
        var canvas=UnityEngine.Object.FindAnyObjectByType<Canvas>();var all=canvas.GetComponentsInChildren<Transform>(true);
        var bar=all.Single(t=>t.name=="ActionTechniques");var panel=all.Single(t=>t.name=="JourneyJournal");
        if(bar.GetSiblingIndex()>panel.GetSiblingIndex())bar.SetSiblingIndex(panel.GetSiblingIndex()); // Journal covers combat row.
        var dialogue=all.Single(t=>t.name=="JourneyDialogue").GetComponent<TMP_Text>();var hint=all.Single(t=>t.name=="JourneyHint").GetComponent<TMP_Text>();
        dialogue.fontSize=14;dialogue.rectTransform.anchoredPosition=new Vector2(24,52);dialogue.rectTransform.sizeDelta=new Vector2(910,50);
        hint.fontSize=14;hint.rectTransform.anchoredPosition=new Vector2(24,106);
        Backplate("ActionTechniqueBackplate",canvas.transform,Vector2.up,new Vector2(16,-80),new Vector2(925,48),bar);
        Backplate("ActionDialogueBackplate",canvas.transform,Vector2.zero,new Vector2(16,50),new Vector2(925,54),dialogue.transform);
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);return "Compact readable dialogue; journal covers combat row; world labels do not overlap HUD text";
    }
    private static void Backplate(string name,Transform parent,Vector2 anchor,Vector2 position,Vector2 size,Transform text)
    {
        var existing=parent.GetComponentsInChildren<Transform>(true).FirstOrDefault(t=>t.name==name);
        if(existing!=null){if(existing.GetSiblingIndex()>text.GetSiblingIndex())existing.SetSiblingIndex(text.GetSiblingIndex());return;}
        var go=new GameObject(name,typeof(RectTransform),typeof(UnityEngine.UI.Image));go.transform.SetParent(parent,false);
        var rect=(RectTransform)go.transform;rect.anchorMin=rect.anchorMax=rect.pivot=anchor;rect.anchoredPosition=position;rect.sizeDelta=size;
        var image=go.GetComponent<UnityEngine.UI.Image>();image.color=new Color(.03f,.06f,.06f,.94f);image.raycastTarget=false;go.transform.SetSiblingIndex(text.GetSiblingIndex());
    }
    private static void Creature(ActorHealth original,ActorHealth player,OfflineAuthority authority,CreatureKind kind,Vector2 position,Transform root)
    {
        var go=UnityEngine.Object.Instantiate(original.gameObject);go.name=kind==CreatureKind.Spider?"VenomSpider":"StoneGolem";go.transform.position=position;go.transform.SetParent(root);
        UnityEngine.Object.DestroyImmediate(go.GetComponent<WolfBrain>());
        foreach(var mark in go.GetComponentsInChildren<Transform>().Where(t=>t.name=="WeaknessMark").ToArray())UnityEngine.Object.DestroyImmediate(mark.gameObject);
        var sprite=go.GetComponent<SpriteRenderer>();sprite.sprite=square;sprite.color=kind==CreatureKind.Spider?new Color(.45f,.18f,.48f):new Color(.55f,.59f,.62f);
        go.transform.localScale=kind==CreatureKind.Spider?new Vector3(.8f,.6f,1):new Vector3(1.2f,1.4f,1);
        var telegraph=Block(go.name+"Telegraph",position,Vector2.one,Color.red,false,root,100).GetComponent<SpriteRenderer>();telegraph.enabled=false;
        go.AddComponent<SpatialCreatureBrain>().Configure(kind,player,authority,telegraph);
        WorldLabel(kind==CreatureKind.Spider?"Aranha tóxica":"Golem — couraça",position+Vector2.up*1.1f,go.transform).transform.position=position+Vector2.up*1.1f;
        if(kind==CreatureKind.Spider)for(int i=0;i<6;i++)Block("Leg",new Vector2(i<3?-.65f:.65f,(i%3-1)*.4f),new Vector2(.6f,.13f),sprite.color,false,go.transform,1);
        else {Block("Eye",new Vector2(-.2f,.25f),new Vector2(.12f,.12f),Color.yellow,false,go.transform,2);Block("Eye",new Vector2(.2f,.25f),new Vector2(.12f,.12f),Color.yellow,false,go.transform,2);}
    }
    private static GameObject Block(string name,Vector2 position,Vector2 size,Color color,bool solid,Transform parent,int order=0)
    {
        var go=new GameObject(name);go.transform.SetParent(parent,false);go.transform.localPosition=position;go.transform.localScale=new Vector3(size.x,size.y,1);
        var sr=go.AddComponent<SpriteRenderer>();sr.sprite=square;sr.sharedMaterial=material;sr.color=color;sr.sortingOrder=order;
        if(solid){go.layer=8;go.AddComponent<BoxCollider2D>();}return go;
    }
    private static TMP_Text WorldLabel(string text,Vector2 position,Transform parent)
    {
        var go=new GameObject(text);go.transform.SetParent(parent,false);go.transform.position=position;
        var label=go.AddComponent<TextMeshPro>();label.font=font;label.text=text;label.fontSize=2;label.alignment=TextAlignmentOptions.Center;label.rectTransform.sizeDelta=new Vector2(6,.6f);label.GetComponent<MeshRenderer>().sortingOrder=400;return label;
    }
    private static TMP_Text UiText(string name,Transform parent,Vector2 position,Vector2 size,int fontSize)
    {
        var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);var rect=(RectTransform)go.transform;
        rect.anchorMin=rect.anchorMax=rect.pivot=Vector2.up;rect.anchoredPosition=position;rect.sizeDelta=size;
        var label=go.AddComponent<TextMeshProUGUI>();label.font=font;label.fontSize=fontSize;label.color=Color.white;label.raycastTarget=false;return label;
    }
}
