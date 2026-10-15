using System;
using System.Linq;
using Mmorpg.Runtime;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using UnityEngine.Rendering.Universal;
public static class InspectLayout06B4
{
    public static string Main()
    {
        var s=new System.Text.StringBuilder();var camera=Camera.main;var p=camera.GetComponent<PixelPerfectCamera>();
        s.AppendLine("Camera rect="+camera.rect+" pixels="+camera.pixelRect+" screen="+Screen.width+"x"+Screen.height+" logical="+p.refResolutionX+"x"+p.refResolutionY+" ortho="+camera.orthographicSize+" position="+camera.transform.position);
        s.AppendLine("adaptive="+camera.GetComponent<AdaptivePixelViewport>()+" all="+string.Join(",",camera.GetComponents<Component>().Select(c=>c.GetType().Name)));
        var adaptive=camera.GetComponent<AdaptivePixelViewport>();if(adaptive!=null)s.AppendLine(UnityEditor.EditorJsonUtility.ToJson(adaptive));
        s.AppendLine("playing="+Application.isPlaying+" scene="+camera.gameObject.scene.path+" active="+camera.gameObject.activeInHierarchy+" enabled="+adaptive.isActiveAndEnabled+" awake="+adaptive.didAwake+" started="+adaptive.didStart);
        if(adaptive!=null)foreach(var field in adaptive.GetType().GetFields(System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance))s.AppendLine(field.Name+"="+field.GetValue(adaptive));
        foreach(var i in UnityEngine.Object.FindObjectsByType<Image>().Where(i=>i.gameObject.activeInHierarchy))
        {var corners=new Vector3[4];i.rectTransform.GetWorldCorners(corners);s.AppendLine(i.name+" color="+i.color+" corners="+corners[0]+" / "+corners[2]);}
        foreach(var h in UnityEngine.Object.FindObjectsByType<ActorHealth>())s.AppendLine("Actor "+h.name+" "+h.transform.position);
        return s.ToString();
    }
}
