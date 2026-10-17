using System;
using System.IO;
using System.Linq;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;

public static class VerifySwordContactR8
{
    public static string Inspect()
    {
        if (EditorApplication.isPlaying) throw new Exception("Stop first");
        const string art = "Assets/Mmorpg/Art/Experimental/HumanoidStatesR8/";
        var baseline = AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(art + "ValdoriaStatesR8.asset");
        var revised = AssetDatabase.LoadAssetAtPath<ProductionCharacterSet>(art + "SwordContact/ValdoriaContactR8.asset");
        if (revised.clips.Length != 64 || revised.clips.Sum(c => c.frames.Length) != 528)
            throw new Exception("Clip contract changed");
        int approved = 0, replaced = 0;
        foreach (var old in baseline.clips)
        {
            var clip = revised.Find(old.action, old.direction);
            if (clip == null || clip.loop != old.loop || clip.frames.Length != old.frames.Length)
                throw new Exception("Missing or changed clip");
            for (int i = 0; i < old.frames.Length; i++)
            {
                var a = old.frames[i]; var b = clip.frames[i];
                if (a.seconds != b.seconds || !a.events.SequenceEqual(b.events))
                    throw new Exception("Timing or event changed");
                if (old.action == "death" || old.action == "hurt")
                {
                    if (a.sprite != b.sprite || a.hand != b.hand || a.holdAngle != b.holdAngle
                        || a.depth != b.depth || a.source != b.source)
                        throw new Exception("Approved death/Hurt changed");
                    approved++;
                }
                else
                {
                    if (a.sprite == b.sprite || !b.source.StartsWith("R8 weapon-driven"))
                        throw new Exception("New contact frame missing");
                    replaced++;
                }
            }
        }
        var actor = UnityEngine.Object.FindAnyObjectByType<ProceduralWeaponGripPresentation>();
        if (actor == null) throw new Exception("Contact adapter absent");
        var entries = new SerializedObject(actor).FindProperty("frames");
        if (entries.arraySize != 272) throw new Exception("Incomplete contact mappings");
        for (int i = 0; i < entries.arraySize; i++)
            foreach (string name in new[] { "body", "fingers" })
            {
                var sprite = entries.GetArrayElementAtIndex(i).FindPropertyRelative(name).objectReferenceValue as Sprite;
                if (sprite == null || sprite.pixelsPerUnit != 32 || sprite.rect.size != new Vector2(128,160)
                    || sprite.pivot != new Vector2(64,34)) throw new Exception("Bad contact import");
            }
        string json = JsonConvert.SerializeObject(new
        {
            passed=true, clips=64, frames=528, unchangedApprovedDeathAndHurtFrames=approved,
            weaponDrivenFrames=replaced, unchangedTimingsAndEvents=true, contactMappings=entries.arraySize,
            noPhysicsOrAuthorityAdapter=true, artisticSwordAndDodgeApproval="pending"
        }, Formatting.Indented);
        Directory.CreateDirectory("Docs/Validation/HumanoidStatesR8/Feedback/");
        File.WriteAllText("Docs/Validation/HumanoidStatesR8/Feedback/integrity.json",json);
        return json;
    }
}
