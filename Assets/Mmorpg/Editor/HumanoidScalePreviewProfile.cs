using System.IO;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine.SceneManagement;

// The scale study must never load or write the player's production profile.
[InitializeOnLoad]
public static class HumanoidScalePreviewProfile
{
    static readonly string[] Scenes = { "Assets/Mmorpg/Scenes/HumanoidScale2026.unity", "Assets/Mmorpg/Scenes/HumanoidOutfit2026.unity" };
    const string Profile = "humanoid-scale-profile-root";
    const string Active = "humanoid-scale-profile-active";
    const string Previous = "humanoid-scale-profile-previous";
    static HumanoidScalePreviewProfile()
    {
        if(SessionState.GetBool(Active,false))Apply();
        EditorApplication.playModeStateChanged += Changed;
    }
    static void Apply()
    {
        string path=Path.GetFullPath(SessionState.GetString(Profile,"Temp/HumanoidScale2026/ManualPlayerProfile"));
        Directory.CreateDirectory(path);
        LocalJourneyProfile.ValidationRootOverride=path;
    }
    static void Changed(PlayModeStateChange state)
    {
        if(state==PlayModeStateChange.ExitingEditMode && System.Array.IndexOf(Scenes,SceneManager.GetActiveScene().path)>=0)
        {
            SessionState.SetString(Previous,LocalJourneyProfile.ValidationRootOverride??"");
            SessionState.SetString(Profile,SceneManager.GetActiveScene().path.EndsWith("HumanoidOutfit2026.unity")?"Temp/HumanoidR5/ManualPlayerProfile":"Temp/HumanoidScale2026/ManualPlayerProfile");
            SessionState.SetBool(Active,true);Apply();
        }
        if(state==PlayModeStateChange.EnteredEditMode && SessionState.GetBool(Active,false))
        {
            string previous=SessionState.GetString(Previous,"");
            LocalJourneyProfile.ValidationRootOverride=string.IsNullOrEmpty(previous)?null:previous;
            SessionState.SetBool(Active,false);
        }
    }
}
