using System.IO;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine.SceneManagement;

// The scale study must never load or write the player's production profile.
[InitializeOnLoad]
public static class HumanoidScalePreviewProfile
{
    const string Scene = "Assets/Mmorpg/Scenes/HumanoidScale2026.unity";
    const string Active = "humanoid-scale-profile-active";
    const string Previous = "humanoid-scale-profile-previous";
    static HumanoidScalePreviewProfile()
    {
        if(SessionState.GetBool(Active,false))Apply();
        EditorApplication.playModeStateChanged += Changed;
    }
    static void Apply()
    {
        string path=Path.GetFullPath("Temp/HumanoidScale2026/ManualPlayerProfile");
        Directory.CreateDirectory(path);
        LocalJourneyProfile.ValidationRootOverride=path;
    }
    static void Changed(PlayModeStateChange state)
    {
        if(state==PlayModeStateChange.ExitingEditMode && SceneManager.GetActiveScene().path==Scene)
        {
            SessionState.SetString(Previous,LocalJourneyProfile.ValidationRootOverride??"");
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
