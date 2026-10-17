using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class BuildSwordContactR8
{
    const string Lab = "ArtSource/Labs/Humanoid2026/R8/SwordContact/";
    const string Art = "Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/SwordContact/";
    const string Scene = "Assets/Mmorpg/Scenes/HumanoidStatesR8.unity";

    public static string Create()
    {
        if (EditorApplication.isPlaying || SceneManager.GetActiveScene().isDirty
            || SceneManager.GetActiveScene().path != Scene || File.Exists(Art + "ValdoriaContactR8.asset"))
            throw new Exception("Clean stopped R8 and unused contact paths required");
        var qa = JObject.Parse(File.ReadAllText(Lab + "qa.json"));
        if (!(bool)qa["passed"] || (int)qa["headPenetrationFrames"] != 0)
            throw new Exception("Passing contact, framing and head-clearance gates required");
        var bodies = AssetDatabase.LoadAllAssetsAtPath(Art + "body.png").OfType<Sprite>().ToDictionary(s => s.name);
        var fingers = AssetDatabase.LoadAllAssetsAtPath(Art + "fingers.png").OfType<Sprite>().ToDictionary(s => s.name);
        if (bodies.Count != 272 || fingers.Count != 272) throw new Exception("Import both contact atlases first");
        var original = AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(
            "Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/ValdoriaStatesR8.asset");
        var set = UnityEngine.Object.Instantiate(original);
        var manifest = JObject.Parse(File.ReadAllText(Lab + "manifest.json"));
        foreach (var clip in manifest["clips"])
        {
            var target = set.Find((string)clip["action"], (int)clip["direction"]);
            int first = (int)clip["first"] - 1;
            if (target.frames.Length != (int)clip["last"] - first)
                throw new Exception("Approved clip frame count would change");
            for (int j = 0; j < target.frames.Length; j++)
            {
                int index = first + j;
                var row = manifest["frames"][index];
                var frame = target.frames[j];
                frame.sprite = bodies["pose_" + index.ToString("000")];
                frame.hand = new Vector2(((float)row["hand"][0] - 64) / 32,
                    (126 - (float)row["hand"][1]) / 32);
                // Recovery already interpolates toward holdAngle inside SwordSwing.
                // Supply the final guard angle, rather than interpolating it twice.
                frame.holdAngle = ((string)clip["action"]).StartsWith("attack-")
                    ? GuardAngle((int)clip["direction"]) : (float)row["holdAngle"];
                frame.depth = (int)row["depth"];
                frame.source = "R8 weapon-driven palm + cylindrical fingers / " + (string)clip["name"] + " " + j;
            }
            target.status = "r8-feedback-sword-contact-and-expressive-dodge-artistic-review-pending";
        }
        set.characterId = "quaternius-r8-sword-contact-expressive-step";
        foreach (var clip in set.clips.Where(c => c.action == "death" || c.action == "hurt"))
            clip.status = "r8-death-and-hurt-approved-by-user-after-real-unity-captures";
        AssetDatabase.CreateAsset(set, Art + "ValdoriaContactR8.asset");
        var animator = UnityEngine.Object.FindAnyObjectByType<ProductionSpriteAnimator>();
        var actor = animator.GetComponent<ActorHealth>();
        var blade = actor.GetComponentsInChildren<SpriteRenderer>(true).Single(r => r.name == "EquippedSword");
        var foreground = new GameObject("ProceduralGripFingers").AddComponent<SpriteRenderer>();
        foreground.transform.SetParent(animator.Body.transform.parent, false);
        foreground.sharedMaterial = animator.Body.sharedMaterial;
        foreground.enabled = false;
        var contacts = bodies.Select(p => new ProceduralWeaponGripPresentation.ContactFrame
            { body = p.Value, fingers = fingers[p.Key] }).ToArray();
        var presentation = actor.gameObject.AddComponent<ProceduralWeaponGripPresentation>();
        presentation.Configure(animator.Body, blade, foreground, actor, contacts);
        animator.Configure(set, actor, animator.Body, actor.GetComponent<SwordSwing>());
        EditorUtility.SetDirty(set);
        AssetDatabase.SaveAssets();
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        EditorSceneManager.SaveScene(SceneManager.GetActiveScene());
        return "R8 revised: 272 weapon-driven arm/contact frames, expressive dodge; approved Hurt/Death and all phase durations retained";
    }

    static float GuardAngle(int direction)
    {
        var manifest = JObject.Parse(File.ReadAllText(Lab + "manifest.json"));
        return (float)manifest["frames"].First(r => (string)r["action"] == "idle"
            && (int)r["direction"] == direction)["holdAngle"];
    }
}
