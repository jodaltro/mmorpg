using System;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering.Universal;

public static class ScaleValdoriaWorldR10
{
    public static string Apply()
    {
        var scene=SceneManager.GetActiveScene();
        if(EditorApplication.isPlaying || scene.path!="Assets/Mmorpg/Scenes/MmorpgWorld.unity" || scene.isDirty)
            throw new InvalidOperationException("Clean official world required outside Play");
        var map=GameObject.Find("GeneratedValdoriaEnvironmentR10").GetComponent<SpriteRenderer>();
        var player=GameObject.Find("Player");
        var camera=Camera.main;
        if(!(UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset))
            throw new InvalidOperationException("Expected URP camera pipeline");
        Undo.RecordObject(map.transform,"Enlarge Valdoria backdrop");
        map.transform.localScale=Vector3.one*1.74f;
        // Put the physical starting point on the illustrated road. No actor/save teleport.
        var roadPixel=new Vector2(1000,480);
        var localRoad=new Vector3((roadPixel.x-map.sprite.pivot.x)/map.sprite.pixelsPerUnit,
            (map.sprite.rect.height-roadPixel.y-map.sprite.pivot.y)/map.sprite.pixelsPerUnit,0);
        map.transform.position=player.transform.position-Vector3.Scale(localRoad,map.transform.localScale);
        // Existing integer zoom enforces discrete jumps. This scene uses a measured optical zoom.
        var adaptive=camera.GetComponent<AdaptivePixelViewport>();
        var pixels=camera.GetComponent<PixelPerfectCamera>();
        Undo.RecordObjects(new UnityEngine.Object[]{camera,adaptive,pixels},"Widen village camera");
        adaptive.enabled=false;pixels.enabled=false;
        camera.orthographic=true;camera.orthographicSize=7.03125f;
        camera.rect=new Rect(0,0,1,1);camera.allowMSAA=false;
        var framing=camera.GetComponent<FullFrameCameraPresentation>();
        if(framing==null)framing=Undo.AddComponent<FullFrameCameraPresentation>(camera.gameObject);
        framing.Configure(camera);EditorUtility.SetDirty(framing);
        var follow=camera.GetComponent<CameraFollow>();
        Undo.RecordObject(follow,"Expand village camera bounds");
        var so=new SerializedObject(follow);var bounds=so.FindProperty("worldBounds").rectValue;
        var mb=map.bounds;
        follow.ConfigureBounds(Rect.MinMaxRect(Mathf.Min(bounds.xMin,mb.min.x),Mathf.Min(bounds.yMin,mb.min.y),
            Mathf.Max(bounds.xMax,mb.max.x),Mathf.Max(bounds.yMax,mb.max.y)));
        foreach(var obj in new UnityEngine.Object[]{map.transform,camera,adaptive,pixels,follow})EditorUtility.SetDirty(obj);
        EditorSceneManager.MarkSceneDirty(scene);
        if(!EditorSceneManager.SaveScene(scene))throw new InvalidOperationException("Scene save failed");
        return $"Map scale 0.58 -> 1.74 (3x linear, 9x area), bounds={map.bounds.size}; camera half-height=7.03125 (+25%); protagonist scale retained; road aligned to starting point. Point textures retained; continuous optical zoom, no strict integer pixel zoom.";
    }

    public static string Audit()
    {
        var camera=Camera.main;var player=GameObject.Find("Player");var body=player.GetComponent<ProductionSpriteAnimator>().Body;
        var map=GameObject.Find("GeneratedValdoriaEnvironmentR10").GetComponent<SpriteRenderer>();
        if(Mathf.Abs(map.transform.localScale.x-1.74f)>.001f || Mathf.Abs(camera.orthographicSize-7.03125f)>.001f || Mathf.Abs(body.transform.lossyScale.x-.75f)>.001f || camera.rect!=new Rect(0,0,1,1))
            throw new InvalidOperationException("World/camera/player scale mismatch");
        return $"frame={Time.frameCount}; mapScale={map.transform.localScale}; bodyScale={body.transform.lossyScale}; cameraSize={camera.orthographicSize}; cameraRect={camera.rect}; mapEnabled={map.enabled}; playerRootScale={player.transform.localScale}";
    }
}
