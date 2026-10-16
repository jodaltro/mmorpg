using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class BuildHumanoidPlayerPreview
{
    const string Scene="Assets/Mmorpg/Scenes/HumanoidScale2026.unity";
    const string Art="Assets/Mmorpg/Art/Experimental/HumanoidScale2026/";
    public static string CorrectLateralDirections()
    {
        if(EditorApplication.isPlaying)throw new Exception("Stop Play before correcting the asset");
        var set=AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(Art+"MalePlayer.asset");
        if(set==null)throw new Exception("Missing preview character set");
        foreach(var clip in set.clips)
        {
            string source=clip.frames[0].source;
            if(source.EndsWith("_west"))clip.direction=3;
            else if(source.EndsWith("_east"))clip.direction=1;
        }
        EditorUtility.SetDirty(set);AssetDatabase.SaveAssets();
        return "Corrected lateral clips from their recorded source; frames and timings preserved.";
    }
    public static string Build()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Scene)throw new Exception("Open clean scale study outside Play");
        string path=Art+"MalePlayer.asset";
        if(File.Exists(path))throw new Exception("Refusing existing character asset overwrite");
        var sprites=AssetDatabase.LoadAllAssetsAtPath(Art+"Male.png").OfType<Sprite>().ToDictionary(s=>s.name);
        var manifest=JObject.Parse(File.ReadAllText("ArtSource/Labs/Humanoid2026/Preview/Male/manifest.json"));
        var timing=JObject.Parse(File.ReadAllText("ArtSource/Labs/Humanoid2026/Preview/Male/aseprite.json"));
        var clips=new List<ProductionClip>();
        foreach(var c in manifest["clips"])
        {
            string name=(string)c["name"];// Legacy source camera labels name the camera side: west renders a right-facing body.
            int direction=name.EndsWith("south")?0:name.EndsWith("west")?3:name.EndsWith("north")?2:1;
            int first=(int)c["first"]-1,last=(int)c["last"]-1;
            clips.Add(new ProductionClip{action=name.StartsWith("walk")?"walk":"idle",direction=direction,loop=true,status="experimental-locomotion-only",frames=Enumerable.Range(first,last-first+1).Select(i=>new ProductionFrame{sprite=sprites["pose_"+i.ToString("000")],seconds=(float)timing["frames"][i]["duration"]/1000f,source="Quaternius CC0 / Humanoid2026 / "+name}).ToArray()});
        }
        var set=ScriptableObject.CreateInstance<ProductionCharacterSet>();set.characterId="quaternius-male-movement-preview";set.referenceSpeed=3.5f;set.pixelsPerUnit=32;set.clips=clips.ToArray();AssetDatabase.CreateAsset(set,path);
        var animator=UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();
        var serialized=new SerializedObject(animator);serialized.FindProperty("art").objectReferenceValue=set;serialized.ApplyModifiedPropertiesWithoutUndo();
        animator.Body.sprite=sprites["pose_000"];animator.Body.transform.localScale=Vector3.one;
        // Weapon grips are still the historical Iron Knight calibration; hide the sword in this movement-only study.
        animator.GetComponentsInChildren<SpriteRenderer>(true).Single(s=>s.name=="EquippedSword").gameObject.SetActive(false);
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());EditorSceneManager.SaveScene(SceneManager.GetActiveScene());AssetDatabase.SaveAssets();
        return "Male base now controlled by the existing player motor; 8 clips, 52 sprites, native scale and original physics. Sword hidden until grips are authored.";
    }
}
