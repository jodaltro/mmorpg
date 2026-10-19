using UnityEngine;
using UnityEditor;
using Mmorpg.Runtime;
public static class CaptureVillageMotion
{
    static int count,last;static double next;static VillageEvidenceCapture recorder;static ActorMotor motor;
    public static object Main(){recorder=Object.FindAnyObjectByType<VillageEvidenceCapture>();motor=GameObject.Find("Player").GetComponent<ActorMotor>();count=0;next=Time.timeAsDouble;EditorApplication.update+=Tick;return "16 real moving-camera frames queued, no forced poses or interpolation";}
    static void Tick(){if(!EditorApplication.isPlaying||count==16){EditorApplication.update-=Tick;return;}if(Time.frameCount==last)return;last=Time.frameCount;if(Time.timeAsDouble<next||motor.Direction.sqrMagnitude<.1f)return;recorder.Capture("motion-"+(count++).ToString("00"),"live continuous input movement and follow camera");next=Time.timeAsDouble+.15;}
}
