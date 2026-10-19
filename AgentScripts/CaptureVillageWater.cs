using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureVillageWater
{
    static int previous=-1,count,last;static WaterSurfaceAnimator water;static VillageEvidenceCapture capture;static CameraFollow follow;
    public static object Main()
    {
        water=Object.FindAnyObjectByType<WaterSurfaceAnimator>();capture=Object.FindAnyObjectByType<VillageEvidenceCapture>();if(!capture)capture=new GameObject("Village live water evidence").AddComponent<VillageEvidenceCapture>();
        var camera=Camera.main;follow=camera.GetComponent<CameraFollow>();follow.enabled=false;camera.orthographicSize=14.0625f;camera.transform.position=new Vector3(56,24,-10);
        var actor=GameObject.Find("Player").GetComponent<Rigidbody2D>();actor.position=new Vector2(56,24);actor.transform.position=actor.position;actor.linearVelocity=Vector2.zero;count=0;previous=water.FrameIndex;EditorApplication.update+=Tick;return "Eight actual water phase changes queued; animation is not forced";
    }
    static void Tick(){if(!EditorApplication.isPlaying||count==8){EditorApplication.update-=Tick;follow.enabled=true;return;}if(Time.frameCount==last)return;last=Time.frameCount;if(water.FrameIndex==previous)return;previous=water.FrameIndex;capture.Capture("water-live-"+(count++).ToString("00"),"actual observed water phase transition, unforced runtime animation");}
}
