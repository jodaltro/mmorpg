using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class ProductionAnimation06B5
{
    public const string ScenePath="Assets/Mmorpg/Scenes/Marco06B5Animation.unity";
    public static string CreateScene()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play first");
        var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(current.path!="Assets/Mmorpg/Scenes/Marco06B4Polish.unity"||current.isDirty)throw new InvalidOperationException("Clean B4 scene required");
        if(File.Exists(ScenePath))throw new IOException("Refusing to overwrite "+ScenePath);
        if(!EditorSceneManager.SaveScene(current,ScenePath,true))throw new IOException("Scene copy failed");
        EditorSceneManager.OpenScene(ScenePath);
        var player=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
        var pivot=player.transform.Find("VisualRoot/WeaponPivot");pivot.localScale=Vector3.one;
        var scenes=EditorBuildSettings.scenes.ToList();
        if(!scenes.Any(s=>s.path==ScenePath)){scenes.Add(new EditorBuildSettingsScene(ScenePath,true));EditorBuildSettings.scenes=scenes.ToArray();}
        EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene());AssetDatabase.SaveAssets();
        return Inspect();
    }
    public static string Inspect()
    {
        var p=UnityEngine.Object.FindAnyObjectByType<JourneySession>().Player;
        var v=p.transform.Find("VisualRoot"); var blade=v.Find("WeaponPivot/EquippedSword");
        return Newtonsoft.Json.JsonConvert.SerializeObject(new {scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,version=Application.unityVersion,rootScale=p.transform.localScale.ToString(),visualScale=v.localScale.ToString(),pivotScale=v.Find("WeaponPivot").localScale.ToString(),bladeScale=blade.localScale.ToString(),bladePosition=blade.localPosition.ToString(),bladeRotation=blade.localEulerAngles.ToString(),bodies=v.GetComponentsInChildren<SpriteRenderer>().Count(s=>s.name=="BodySprite"),weapons=v.GetComponentsInChildren<SpriteRenderer>().Count(s=>s.name=="EquippedSword"),rb=p.GetComponent<Rigidbody2D>().bodyType.ToString(),collider=p.GetComponent<Collider2D>().GetType().Name});
    }
}
