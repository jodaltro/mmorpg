using Mmorpg.Runtime;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;

public static class ConfigureActionNarrative
{
    public static string Main()
    {
        if (EditorApplication.isPlaying) throw new System.InvalidOperationException("Stop Play before configuring.");
        const string path = "Assets/Mmorpg/Scenes/ActionVerticalSlice.unity";
        var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if (scene.path != path)
        {
            if (scene.isDirty) throw new System.InvalidOperationException("Preserve unsaved scene changes.");
            scene = EditorSceneManager.OpenScene(path);
        }
        var journey = Object.FindFirstObjectByType<JourneySession>();
        var world = Object.FindFirstObjectByType<WorldEventSession>();
        const string url = "http://127.0.0.1:8091/v1/decisions/evaluate";
        Undo.RecordObjects(new Object[] {journey, world}, "Enable action narrative backend");
        journey.ConfigureDecisions(DecisionMode.OpenRouter, url);
        world.ConfigureDecisions(DecisionMode.OpenRouter, url);
        EditorUtility.SetDirty(journey);
        EditorUtility.SetDirty(world);
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
        return "ActionVerticalSlice: both narrative sessions OpenRouter; endpoint " + url;
    }
}
