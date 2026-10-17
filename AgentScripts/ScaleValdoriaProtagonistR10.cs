using System;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class ScaleValdoriaProtagonistR10
{
    public static string Apply()
    {
        if(EditorApplication.isPlaying || SceneManager.GetActiveScene().path != "Assets/Mmorpg/Scenes/MmorpgWorld.unity")
            throw new InvalidOperationException("Official world outside Play required");
        var player=GameObject.Find("Player");
        var animator=player.GetComponent<ProductionSpriteAnimator>();
        var root=animator.Body.transform.parent;
        if(root==player.transform || !root.IsChildOf(player.transform))
            throw new InvalidOperationException("Expected separate presentation root");
        Undo.RecordObject(root,"Scale protagonist presentation to village");
        root.localScale=Vector3.one*.75f;
        EditorUtility.SetDirty(root);
        EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
        if(!EditorSceneManager.SaveScene(SceneManager.GetActiveScene()))throw new InvalidOperationException("Save failed");
        return $"Visual root={root.name}; scale={root.localScale}; physical root={player.transform.localScale}; body, weapon and fingers share visual parent; physics components unchanged.";
    }
}
