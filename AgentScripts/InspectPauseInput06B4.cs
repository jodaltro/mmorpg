using System;
using System.Linq;
using Mmorpg.Runtime;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;
using UnityEditor;
public static class InspectPauseInput06B4
{
    public static string Main()
    {
        var s=new System.Text.StringBuilder();s.AppendLine("playing="+EditorApplication.isPlaying+" scene="+UnityEngine.SceneManagement.SceneManager.GetActiveScene().path);
        foreach(var canvas in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsInactive.Include))s.AppendLine("Canvas "+canvas.name+" active="+canvas.gameObject.activeInHierarchy+" raycaster="+canvas.GetComponent<GraphicRaycaster>());
        foreach(var events in UnityEngine.Object.FindObjectsByType<EventSystem>(FindObjectsInactive.Include))
        {
            s.AppendLine("EventSystem "+events.name+" active="+events.gameObject.activeInHierarchy+" enabled="+events.enabled+" module="+events.currentInputModule);
            foreach(var module in events.GetComponents<BaseInputModule>())s.AppendLine(EditorJsonUtility.ToJson(module));
        }
        foreach(var view in UnityEngine.Object.FindObjectsByType<SessionMenuView>(FindObjectsInactive.Include))s.AppendLine("Menu "+EditorJsonUtility.ToJson(view));
        foreach(var b in UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Include).Where(b=>b.transform.IsChildOf(UnityEngine.Object.FindAnyObjectByType<SessionMenuView>(FindObjectsInactive.Include).transform)))s.AppendLine("Button "+b.name+" active="+b.gameObject.activeInHierarchy+" interactable="+b.IsInteractable()+" enabled="+b.enabled+" imageRay="+b.targetGraphic?.raycastTarget);
        return s.ToString();
    }
}
