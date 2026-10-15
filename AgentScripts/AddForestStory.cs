using System;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// Extends the existing scene; never creates or replaces it. Repeat execution is a no-op.
public static class AddForestStory
{
    public static string Run()
    {
        if(EditorApplication.isPlaying) throw new InvalidOperationException("Stop Play first");
        for(int i=0;i<UnityEngine.SceneManagement.SceneManager.sceneCount;i++)
            if(UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).isDirty) throw new InvalidOperationException("Save dirty scenes before authoring");
        const string path="Assets/Mmorpg/Scenes/OfflineClearing.unity";
        if(!System.IO.File.Exists(path)) throw new InvalidOperationException("Existing scene required");
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(scene.path!=path) scene=EditorSceneManager.OpenScene(path);
        if(UnityEngine.Object.FindAnyObjectByType<JourneySession>()!=null) return "Forest story already authored; no changes";
        var session=UnityEngine.Object.FindAnyObjectByType<GameSession>();
        var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
        var hud=UnityEngine.Object.FindAnyObjectByType<HealthHud>();
        if(session==null||authority==null||hud==null) throw new InvalidOperationException("Existing contracts missing");
        var root=new GameObject("ForestStory"); root.SetActive(false);
        var journey=root.AddComponent<JourneySession>();
        var font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        var hero=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Hero.png");
        var square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");
        var material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        var mira=Target(root.transform,"Mira — curandeira",new Vector2(-5,0),InteractionKind.Mira,hero,new Color(0.65f,1,0.75f),material,font);
        var orin=Target(root.transform,"Orin — caçador",new Vector2(-2,3),InteractionKind.Orin,hero,new Color(1,0.8f,0.45f),material,font);
        var trace=Target(root.transform,"Rastros corrompidos",new Vector2(0,2),InteractionKind.Trace,square,new Color(0.7f,0.25f,0.9f),material,font);
        trace.transform.localScale=new Vector3(0.6f,0.35f,1);
        var traceName=trace.GetComponentInChildren<TextMeshPro>(); traceName.transform.localScale=new Vector3(1/0.6f,1/0.35f,1); traceName.transform.localPosition=new Vector3(0,0.8f/0.35f,0);
        var sample=Target(root.transform,"Amostra corrompida",session.Wolf.transform.position,InteractionKind.Sample,square,new Color(0.8f,0.35f,1),material,null);
        sample.transform.localScale=new Vector3(0.25f,0.25f,1);
        var markGo=new GameObject("WeaknessMark"); markGo.transform.SetParent(session.Wolf.transform,false); markGo.transform.localPosition=new Vector3(0,0.65f,0); markGo.transform.localScale=new Vector3(0.35f,0.12f,1);
        var mark=markGo.AddComponent<SpriteRenderer>(); mark.sprite=square; mark.sharedMaterial=material; mark.color=Color.yellow; mark.sortingOrder=500; mark.enabled=false;
        session.Wolf.GetComponent<SpriteRenderer>().color=new Color(0.8f,0.45f,1);
        journey.Configure(session,authority,new[]{mira,orin,trace,sample},sample.GetComponent<SpriteRenderer>(),mark);
        authority.ConfigureJourney(journey);
        var dialogue=Label("JourneyDialogue",hud.transform,font,new Vector2(0,0),new Vector2(24,62),new Vector2(900,65),18);
        var hint=Label("JourneyHint",hud.transform,font,Vector2.zero,new Vector2(24,140),new Vector2(900,28),18);
        var panel=Rect("JourneyJournal",hud.transform,new Vector2(0.5f,0.5f),Vector2.zero,new Vector2(800,360));
        var bg=panel.gameObject.AddComponent<UnityEngine.UI.Image>(); bg.color=new Color(0.035f,0.065f,0.075f,0.98f); bg.raycastTarget=false;
        var journal=Label("JournalText",panel,font,new Vector2(0,1),new Vector2(20,-16),new Vector2(760,330),16);
        var view=root.AddComponent<JourneyHud>(); view.Configure(journey,dialogue,hint,journal,panel.gameObject);
        root.AddComponent<JourneyInput>().Configure(journey,view);
        panel.gameObject.SetActive(false);
        var controls=hud.GetComponentsInChildren<TMP_Text>().FirstOrDefault(t=>t.name=="Controls");
        if(controls!=null) { controls.text="WASD: mover   J/Clique: atacar   Espaço: esquiva   E: interagir   Q: técnica   Tab: diário   R: continuar   N: nova jornada"; controls.fontSize=14; }
        root.SetActive(true);
        EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); AssetDatabase.SaveAssets();
        return "Extended existing OfflineClearing with serialized story, NPCs, tracks, sample, mark and journal";
    }
    public static string ImproveLayout()
    {
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||scene.isDirty||scene.path!="Assets/Mmorpg/Scenes/OfflineClearing.unity") throw new InvalidOperationException("Existing clean scene required, outside Play");
        var trace=UnityEngine.Object.FindObjectsByType<JourneyInteractable>().Single(i=>i.Kind==InteractionKind.Trace);
        var label=trace.GetComponentInChildren<TextMeshPro>(); label.transform.localScale=new Vector3(1/0.6f,1/0.35f,1); label.transform.localPosition=new Vector3(0,0.8f/0.35f,0);
        var hint=UnityEngine.Object.FindObjectsByType<TextMeshProUGUI>().Single(t=>t.name=="JourneyHint");
        var rect=hint.rectTransform; rect.anchorMin=rect.anchorMax=rect.pivot=Vector2.zero; rect.anchoredPosition=new Vector2(24,140); rect.sizeDelta=new Vector2(900,28); hint.alignment=TextAlignmentOptions.TopLeft;
        EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); return "Adjusted track label scale and hint placement";
    }
    private static JourneyInteractable Target(Transform parent,string name,Vector2 position,InteractionKind kind,Sprite art,Color color,Material material,TMP_FontAsset font)
    {
        var go=new GameObject(name); go.transform.SetParent(parent,false); go.transform.position=position;
        var sprite=go.AddComponent<SpriteRenderer>(); sprite.sprite=art; sprite.sharedMaterial=material; sprite.color=color; sprite.sortingOrder=150;
        var target=go.AddComponent<JourneyInteractable>(); target.Configure(kind);
        if(font!=null) { var label=new GameObject("Name").AddComponent<TextMeshPro>(); label.transform.SetParent(go.transform,false); label.transform.localPosition=new Vector3(0,0.8f,0); label.font=font; label.text=name; label.fontSize=2; label.alignment=TextAlignmentOptions.Center; label.rectTransform.sizeDelta=new Vector2(4,0.6f); label.GetComponent<MeshRenderer>().sortingOrder=200; }
        return target;
    }
    private static RectTransform Rect(string name,Transform parent,Vector2 anchor,Vector2 pos,Vector2 size)
    {
        var go=new GameObject(name,typeof(RectTransform)); var rect=(RectTransform)go.transform; rect.SetParent(parent,false); rect.anchorMin=rect.anchorMax=rect.pivot=anchor; rect.anchoredPosition=pos; rect.sizeDelta=size; return rect;
    }
    private static TMP_Text Label(string name,Transform parent,TMP_FontAsset font,Vector2 anchor,Vector2 pos,Vector2 size,int fontSize)
    { var text=Rect(name,parent,anchor,pos,size).gameObject.AddComponent<TextMeshProUGUI>(); text.font=font; text.fontSize=fontSize; text.color=new Color(0.94f,0.97f,0.9f); text.raycastTarget=false; return text; }
}
