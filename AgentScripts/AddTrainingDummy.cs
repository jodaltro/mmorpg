using System;
using Mmorpg.Runtime;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class AddTrainingDummy
{
    public static string Run()
    {
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||scene.isDirty||scene.path!="Assets/Mmorpg/Scenes/OfflineClearing.unity") throw new InvalidOperationException("Existing clean OfflineClearing required, outside Play");
        if(UnityEngine.Object.FindAnyObjectByType<TrainingDummy>()!=null) return "Training dummy already exists; unchanged";
        var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();
        if(journey==null) throw new InvalidOperationException("Existing journey required");
        var go=new GameObject("TrainingDummy"); go.SetActive(false); go.layer=9; go.transform.position=new Vector3(-4,-2,0);
        var square=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Mmorpg/Art/Square.png");
        var material=AssetDatabase.LoadAssetAtPath<Material>("Assets/Mmorpg/Art/PlaceholderSprite.mat");
        Part(go.transform,"Post",new Vector2(0,-0.25f),new Vector2(0.2f,1.1f),new Color(0.5f,0.3f,0.15f),square,material);
        Part(go.transform,"StrawBody",Vector2.zero,new Vector2(0.65f,0.7f),new Color(0.85f,0.65f,0.25f),square,material);
        Part(go.transform,"Head",new Vector2(0,0.5f),new Vector2(0.4f,0.4f),new Color(1,0.8f,0.4f),square,material);
        Part(go.transform,"Arms",new Vector2(0,0.15f),new Vector2(1.1f,0.13f),new Color(0.5f,0.3f,0.15f),square,material);
        var marker=Part(go.transform,"WeaknessMark",new Vector2(0,0.85f),new Vector2(0.35f,0.12f),Color.yellow,square,material); marker.enabled=false; marker.sortingOrder=500;
        var body=go.AddComponent<Rigidbody2D>(); body.bodyType=RigidbodyType2D.Static;
        var collider=go.AddComponent<BoxCollider2D>(); collider.size=new Vector2(0.65f,1.1f);
        var health=go.AddComponent<ActorHealth>(); health.Configure(Faction.Training);
        var textGo=new GameObject("TrainingInstructions"); textGo.transform.SetParent(go.transform,false); textGo.transform.localPosition=new Vector3(0,-1.1f,0);
        var text=textGo.AddComponent<TextMeshPro>(); text.font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/TextMesh Pro/Resources/Fonts & Materials/LiberationSans SDF.asset");
        text.fontSize=2.3f; text.alignment=TextAlignmentOptions.Center; text.rectTransform.sizeDelta=new Vector2(5,1.1f); text.GetComponent<MeshRenderer>().sortingOrder=300;
        text.text="Boneco de treino\nQ: marcar · J/clique: atacar";
        var dummy=go.AddComponent<TrainingDummy>(); dummy.Configure(health,text,marker); journey.ConfigureTrainingDummy(dummy);
        go.SetActive(true); EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); return "Added reusable training dummy at (-4,-2)";
    }
    private static SpriteRenderer Part(Transform parent,string name,Vector2 position,Vector2 size,Color color,Sprite square,Material material)
    {
        var part=new GameObject(name); part.transform.SetParent(parent,false); part.transform.localPosition=position; part.transform.localScale=new Vector3(size.x,size.y,1);
        var sprite=part.AddComponent<SpriteRenderer>(); sprite.sprite=square; sprite.sharedMaterial=material; sprite.color=color; sprite.sortingOrder=140; return sprite;
    }
    public static string VerifyPlay()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Play required");
        Application.runInBackground=true;
        var dummy=UnityEngine.Object.FindAnyObjectByType<TrainingDummy>(); var journey=UnityEngine.Object.FindAnyObjectByType<JourneySession>();
        journey.Player.GetComponent<PlayerController>().enabled=false; journey.Wolf.GetComponent<WolfBrain>().enabled=false;
        var position=(Vector2)dummy.transform.position+Vector2.left*0.8f;
        journey.Player.transform.position=position; journey.Player.GetComponent<Rigidbody2D>().position=position; Physics2D.SyncTransforms();
        bool marked=journey.RequestWeakness();
        UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>().RequestAttack(journey.Player,Vector2.right);
        return $"dummyHealth={dummy.Health.State.Health}, lastDamage={dummy.LastDamage}, marked={marked}, frame={Time.frameCount}";
    }
}
