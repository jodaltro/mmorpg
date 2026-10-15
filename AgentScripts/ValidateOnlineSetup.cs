using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class ValidateOnlineSetup
{
    public static string Refresh()
    {
        if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Stop Play/test run before compilation");
        AssetDatabase.ImportAsset("Assets/Mmorpg/Tests/PlayMode/Mmorpg.PlayMode.Tests.asmdef",ImportAssetOptions.ForceUpdate);
        AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        return "References imported";
    }
    public static string Inspect() => "playing="+EditorApplication.isPlaying+" frame="+Time.frameCount+" compiling="+EditorApplication.isCompiling;
    public static async System.Threading.Tasks.Task<object> ObserveFrames()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Isolated Play required");
        int first=Time.frameCount; await System.Threading.Tasks.Task.Delay(250);int second=Time.frameCount;
        if(second<=first) throw new InvalidOperationException("Player frames did not advance");
        return new {first,second,advancing=true};
    }
}
