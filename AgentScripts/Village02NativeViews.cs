using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
using Object=UnityEngine.Object;

public static class Village02NativeViews
{
    public static async Task<object> Main()
    {
        if(!EditorApplication.isPlaying||!File.Exists("Docs/Validation/ValdoriaVillage02/QA/play-qa.json"))throw new IOException("Completed review Play required");
        var capture=Object.FindAnyObjectByType<Village02EvidenceCapture>();var actor=GameObject.Find("Player").GetComponent<Rigidbody2D>();var camera=Camera.main;var follow=camera.GetComponent<CameraFollow>();follow.enabled=false;
        var positions=new[]{new Vector3(64,76,-10),new Vector3(53,47,-10),new Vector3(65,76,-10),new Vector3(90,119,-10),new Vector3(83,110,-10)};
        var points=new[]{new Vector2(53,12),new Vector2(53,40),new Vector2(65,66),new Vector2(83,108),new Vector2(83,108)};
        var sizes=new[]{76f,14.0625f,14.0625f,28f,14.0625f};var names=new[]{"07-overview-native","08-entry-native","09-internal-native","10-castle-silhouette-native","11-castle-gameplay-native"};
        for(int i=0;i<names.Length;i++)
        {
            actor.position=points[i];actor.transform.position=points[i];actor.linearVelocity=Vector2.zero;Physics2D.SyncTransforms();camera.transform.position=positions[i];camera.orthographicSize=sizes[i];await Task.Delay(400);
            capture.Capture(names[i],"Actual Play, 1600x900 fixed Game View, neutral massing; review fixture, not continuous route");
            while(capture.Busy)await Task.Delay(50);
        }
        actor.position=new Vector2(53,12);actor.transform.position=actor.position;camera.orthographicSize=14.0625f;follow.enabled=true;
        return new{captured=names,frames=Time.frameCount,playMode=EditorApplication.isPlaying,resolution=new[]{Screen.width,Screen.height}};
    }
}
