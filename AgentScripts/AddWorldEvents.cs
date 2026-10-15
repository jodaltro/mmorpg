using System;
using System.Linq;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class AddWorldEvents
{
    public static string Run()
    {
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||scene.isDirty||scene.path!="Assets/Mmorpg/Scenes/OfflineClearing.unity") throw new InvalidOperationException("Existing clean OfflineClearing required outside Play");
        var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();
        if(journey==null) throw new InvalidOperationException("Existing Journey required");
        var existing=UnityEngine.Object.FindAnyObjectByType<WorldEventSession>();
        if(existing!=null) {
            if(journey.WorldEvents!=existing||!journey.Interactions.Any(i=>i.Kind==InteractionKind.NoticeBoard)||!journey.Interactions.Any(i=>i.Kind==InteractionKind.NewTracks)) throw new InvalidOperationException("Partial world authoring; inspect references");
            return "World events already authored; unchanged";
        }
        if(GameObject.Find("WorldEvents")!=null) throw new InvalidOperationException("Conflicting WorldEvents object");
        var square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");
        var material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        var font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        if(square==null||material==null||font==null) throw new InvalidOperationException("Existing placeholder assets required");
        var root=new GameObject("WorldEvents");
        var board=Part(root.transform,"Quadro de avisos",new Vector2(-6,2.5f),new Vector2(0.95f,0.65f),new Color(0.65f,0.4f,0.2f),square,material);
        var boardInteraction=board.gameObject.AddComponent<JourneyInteractable>(); boardInteraction.Configure(InteractionKind.NoticeBoard);
        var paper=Part(board.transform,"Paper",new Vector2(0,0.1f),new Vector2(0.7f,0.6f),new Color(0.95f,0.9f,0.7f),square,material); paper.sortingOrder=201;
        var notice=Label(root.transform,"NoticeLabel",new Vector2(-6,3.5f),font,"QUADRO DA VILA\nE para consultar");
        var clue=Part(root.transform,"Novos vestígios",new Vector2(3,2.5f),new Vector2(0.7f,0.3f),new Color(0.4f,0.85f,0.7f),square,material);
        var clueInteraction=clue.gameObject.AddComponent<JourneyInteractable>(); clueInteraction.Configure(InteractionKind.NewTracks);
        var clueLabel=Label(root.transform,"ClueLabel",new Vector2(3,3.3f),font,"Vestígios recentes\nE para examinar");
        clue.enabled=false; clueLabel.enabled=false;
        var world=root.AddComponent<WorldEventSession>(); world.Configure(journey,clue,notice,clueLabel);
        journey.ConfigureWorldEvents(world,journey.Interactions.Concat(new[]{boardInteraction,clueInteraction}).ToArray());
        EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene);
        return "Extended existing scene: board (-6,2.5), interactive traces (3,2.5), serialized world session";
    }
    private static SpriteRenderer Part(Transform parent,string name,Vector2 position,Vector2 size,Color color,Sprite square,Material material)
    {
        var go=new GameObject(name); go.transform.SetParent(parent,false); go.transform.localPosition=position; go.transform.localScale=new Vector3(size.x,size.y,1);
        var sprite=go.AddComponent<SpriteRenderer>(); sprite.sprite=square; sprite.sharedMaterial=material; sprite.color=color; sprite.sortingOrder=200; return sprite;
    }
    private static TMP_Text Label(Transform parent,string name,Vector2 position,TMP_FontAsset font,string value)
    {
        var go=new GameObject(name); go.transform.SetParent(parent,false); go.transform.localPosition=position;
        var text=go.AddComponent<TextMeshPro>(); text.font=font; text.fontSize=2.1f; text.alignment=TextAlignmentOptions.Center; text.rectTransform.sizeDelta=new Vector2(4,1); text.text=value;
        text.GetComponent<MeshRenderer>().sortingOrder=300; return text;
    }
}
