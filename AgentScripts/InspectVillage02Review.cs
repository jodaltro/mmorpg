using System;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEditor;
using UnityEditor.SceneManagement;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class InspectVillage02Review
{
    public static object Main()
    {
        if(EditorApplication.isPlaying||EditorSceneManager.GetActiveScene().isDirty)throw new IOException("Stopped clean editor required");
        var result=new{scene=EditorSceneManager.GetActiveScene().path,dirty=EditorSceneManager.GetActiveScene().isDirty,
            cameras=Object.FindObjectsByType<Camera>().Count(c=>c.enabled),players=Object.FindObjectsByType<PlayerController>().Length,
            physical=Object.FindObjectsByType<PolygonCollider2D>().Length,groups=Object.FindObjectsByType<VillageBlockoutDepth>().Length,
            noCutaway01=Object.FindObjectsByType<ReferenceHouseDepth>().Length==0,
            promoted=EditorBuildSettings.scenes.Any(s=>s.path=="Assets/Mmorpg/Scenes/ValdoriaVillage02Blockout.unity"),
            firstBuildScene=EditorBuildSettings.scenes.First(s=>s.enabled).path,
            timeScale=Time.timeScale,keyboards=InputSystem.devices.OfType<Keyboard>().Select(k=>new{k.name,k.enabled}),
            synthetic=InputSystem.devices.Any(d=>d.name.Contains("Village02")),
            fixedViewOverride=SessionState.GetBool("Village02.FixedView",false),temporaryCaptures=Object.FindObjectsByType<Village02EvidenceCapture>().Length};
        File.WriteAllText("Docs/Validation/ValdoriaVillage02/QA/scene-integrity.json",JsonConvert.SerializeObject(result,Formatting.Indented));
        var original=JObject.Parse(File.ReadAllText("Docs/Validation/ValdoriaVillage02/QA/editor-before.json"));EditorSceneManager.OpenScene((string)original["scene"]);
        File.WriteAllText("Docs/Validation/ValdoriaVillage02/QA/editor-restored.json",JsonConvert.SerializeObject(new{scene=EditorSceneManager.GetActiveScene().path,playing=EditorApplication.isPlaying,dirty=EditorSceneManager.GetActiveScene().isDirty,timeScale=Time.timeScale,inputRestored=!InputSystem.devices.Any(d=>d.name.Contains("Village02")),fixedViewOverride=SessionState.GetBool("Village02.FixedView",false)},Formatting.Indented));
        return result;
    }
}
