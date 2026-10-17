using System;
using System.Linq;
using System.IO;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class CalibratePlayerToWellR10
{
    static readonly string[] NpcSprites={"Healer_","Hunter_","Smith_","Scholar_"};
    public static string Apply()
    {
        var scene=SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying||scene.path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity"||scene.isDirty)
            throw new InvalidOperationException("Clean official scene outside Play required");
        var player=GameObject.Find("Player");
        var root=player.GetComponent<ProductionSpriteAnimator>().Body.transform.parent;
        Undo.RecordObject(root,"Calibrate protagonist to well");root.localScale=Vector3.one*1.25f;
        var candidates=UnityEngine.Object.FindObjectsByType<SpriteRenderer>(FindObjectsInactive.Include)
            .Where(r=>r.gameObject.scene==scene && !r.transform.IsChildOf(player.transform) && r.sprite!=null && NpcSprites.Any(n=>r.sprite.name.StartsWith(n,StringComparison.Ordinal)))
            .Select(r=>r.gameObject).Distinct().ToArray();
        foreach(var npc in candidates){Undo.RecordObject(npc,"Temporarily hide NPC for scale review");npc.SetActive(false);EditorUtility.SetDirty(npc);}
        // Hide NPC labels/interactions as well as the older duplicate body renderers.
        string[] names={"Mira —", "Orin —", "Helena —", "Brann —", "Dorin —", "Nera —"};
        var roots=Resources.FindObjectsOfTypeAll<GameObject>().Where(g=>g.scene==scene&&names.Any(n=>g.name.StartsWith(n,StringComparison.Ordinal))).ToArray();
        foreach(var npc in roots){Undo.RecordObject(npc,"Temporarily hide NPC");npc.SetActive(false);EditorUtility.SetDirty(npc);}
        EditorUtility.SetDirty(root);EditorSceneManager.MarkSceneDirty(scene);
        if(!EditorSceneManager.SaveScene(scene))throw new InvalidOperationException("Save failed");
        return $"Player visual scale=1.25 (previous 0.75); map/camera unchanged; NPC sprite nodes disabled={candidates.Length}, named roots/labels disabled={roots.Length}. Undo/reactivation restores them; no deletion or save migration.";
    }
    public static string Audit()
    {
        var player=GameObject.Find("Player");var body=player.GetComponent<ProductionSpriteAnimator>().Body;
        var visible=UnityEngine.Object.FindObjectsByType<SpriteRenderer>(FindObjectsInactive.Exclude).Where(r=>r.enabled&&r.sprite!=null&&NpcSprites.Any(n=>r.sprite.name.StartsWith(n,StringComparison.Ordinal))).ToArray();
        if(visible.Length!=0||Mathf.Abs(body.transform.lossyScale.x-1.25f)>.001f)throw new InvalidOperationException("Scale/NPC visibility failed");
        return $"frame={Time.frameCount}; bodyScale={body.transform.lossyScale}; visibleNPCs={visible.Length}; cameraSize={Camera.main.orthographicSize}; mapScale={GameObject.Find("GeneratedValdoriaEnvironmentR10").transform.localScale}; rootScale={player.transform.localScale}";
    }
}
