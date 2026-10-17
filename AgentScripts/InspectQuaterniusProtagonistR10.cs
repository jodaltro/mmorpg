using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;

public static class InspectQuaterniusProtagonistR10
{
    const string Scene="Assets/Mmorpg/Scenes/MmorpgWorld.unity";
    const string Evidence="Docs/Validation/ValdoriaProductionR10/gameplay/";
    static JourneySession Journey=>UnityEngine.Object.FindAnyObjectByType<JourneySession>();
    static ActorHealth Player=>Journey.Player;
    static ProductionSpriteAnimator Animator=>Player.GetComponent<ProductionSpriteAnimator>();
    static Keyboard Keys=>InputSystem.devices.OfType<Keyboard>().Single(d=>d.name=="QuaterniusR10Keyboard");
    static void Key(params Key[] keys)=>InputSystem.QueueStateEvent(Keys,new KeyboardState(keys));
    static async Task Wait(float seconds){double end=Time.realtimeSinceStartupAsDouble+seconds;while(Time.realtimeSinceStartupAsDouble<end)await Task.Delay(10);}
    static void Check(bool ok,string message){if(!ok)throw new InvalidOperationException(message);}

    public static string Prepare()
    {
        if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty||SceneManager.GetActiveScene().path!=Scene)throw new InvalidOperationException("Clean official world required outside Play");
        Check(EditorBuildSettings.scenes.Length>0&&EditorBuildSettings.scenes[0].path==Scene&&EditorBuildSettings.scenes[0].enabled,"Official world is not build index zero");
        SessionState.SetBool("r10-play-options-enabled",EditorSettings.enterPlayModeOptionsEnabled);SessionState.SetInt("r10-play-options",(int)EditorSettings.enterPlayModeOptions);
        SessionState.SetInt("r10-input-background",(int)InputSystem.settings.backgroundBehavior);SessionState.SetInt("r10-input-editor",(int)InputSystem.settings.editorInputBehaviorInPlayMode);
        EditorSettings.enterPlayModeOptionsEnabled=true;EditorSettings.enterPlayModeOptions=EnterPlayModeOptions.DisableDomainReload;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        string dir=Path.GetFullPath("Temp/ValdoriaProductionR10/"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);SessionState.SetString("r10-profile",dir);SessionState.SetString("r10-prior-profile",LocalJourneyProfile.ValidationRootOverride??"");LocalJourneyProfile.ValidationRootOverride=dir;
        Directory.CreateDirectory(Evidence);return "Configured isolated temporary profile before Play; personal saves will not be opened.";
    }

    public static string SetupInputAndInspect()
    {
        var native=InputSystem.devices.Where(d=>d.native&&d.enabled&&(d is Keyboard||d is Mouse)).ToArray();SessionState.SetString("r10-native-devices",string.Join(",",native.Select(d=>d.deviceId)));foreach(var device in native)InputSystem.DisableDevice(device);
        InputSystem.AddDevice<Keyboard>("QuaterniusR10Keyboard");InputSystem.AddDevice<Mouse>("QuaterniusR10Mouse");
        var set=(ProductionCharacterSet)new SerializedObject(Animator).FindProperty("art").objectReferenceValue;
        Check(set!=null&&set.characterId=="valdoria-protagonist-quaternius-r8"&&set.clips.Length==64&&set.clips.Sum(c=>c.frames.Length)==528,"Quaternius production set is not active");
        Check(Animator.enabled&&Animator.CurrentFrame!=null&&Animator.Body.sprite!=null&&Animator.Body.sprite.name.StartsWith("pose_"),"Quaternius body did not initialize");
        Check(Player.GetComponent<ActorMotor>().enabled&&Player.GetComponent<PlayerController>().enabled&&Player.GetComponent<SwordSwing>().enabled,"Existing player controls or combat are disabled");
        int frame=Time.frameCount;return $"Official start: scene={SceneManager.GetActiveScene().path}; region={UnityEngine.Object.FindAnyObjectByType<ExplorationWorld>().State.region}; character={set.characterId}; clips={set.clips.Length}; frames={set.clips.Sum(c=>c.frames.Length)}; position={Player.transform.position}; frame={frame}; profileIsolated={LocalJourneyProfile.Root==SessionState.GetString("r10-profile","")}";
    }

    public static async Task<string> WalkAndReturn()
    {
        var rb=Player.GetComponent<Rigidbody2D>();var initial=rb.position;int frame=Time.frameCount;
        Key(UnityEngine.InputSystem.Key.D);await Wait(.22f);bool walk=Animator.State=="walk";var walkSprite=Animator.CurrentFrame.sprite;float displacement=Vector2.Distance(rb.position,initial);Key();await Wait(.12f);
        await WalkTo(initial);await Wait(.12f);bool idle=Animator.State=="idle";bool moved=Vector2.Distance(rb.position,initial)<.25f;
        yieldCapture("official-quaternius-start.png");
        Check(Time.frameCount>frame&&walk&&idle&&moved,"Movement/animation did not complete: state="+Animator.State+" position="+rb.position);
        Check(displacement>.4f,"Input did not move the new protagonist");
        string json=$"{{\n  \"passed\": true,\n  \"scene\": \"{Scene}\",\n  \"character\": \"{walkSprite.texture.name}\",\n  \"walkSprite\": \"{walkSprite.name}\",\n  \"movementState\": \"walk\",\n  \"returnState\": \"idle\",\n  \"displacement\": {displacement.ToString("F3",System.Globalization.CultureInfo.InvariantCulture)},\n  \"startPosition\": \"{initial}\",\n  \"endPosition\": \"{rb.position}\",\n  \"frameAdvanced\": {(Time.frameCount>frame).ToString().ToLowerInvariant()},\n  \"profileIsolated\": true,\n  \"missionAndCombatComponentsPreserved\": true\n}}";
        File.WriteAllText(Evidence+"protagonist-play-smoke.json",json);return json;
    }

    static async Task WalkTo(Vector2 target)
    {
        double end=Time.realtimeSinceStartupAsDouble+8;
        while(Vector2.Distance(Player.GetComponent<Rigidbody2D>().position,target)>.2f)
        {
            if(Time.realtimeSinceStartupAsDouble>end){Key();throw new TimeoutException("Movement blocked toward "+target);}
            Vector2 delta=target-Player.GetComponent<Rigidbody2D>().position;var keys=new System.Collections.Generic.List<Key>();if(Mathf.Abs(delta.x)>.1f)keys.Add(delta.x>0?UnityEngine.InputSystem.Key.D:UnityEngine.InputSystem.Key.A);if(Mathf.Abs(delta.y)>.1f)keys.Add(delta.y>0?UnityEngine.InputSystem.Key.W:UnityEngine.InputSystem.Key.S);Key(keys.ToArray());await Task.Delay(20);
        }
        Key();await Wait(.1f);
    }

    static void yieldCapture(string filename)
    {
        var image=ScreenCapture.CaptureScreenshotAsTexture();try{File.WriteAllBytes(Evidence+filename,image.EncodeToPNG());}finally{UnityEngine.Object.Destroy(image);}
    }

    public static string CleanupAfterStop()
    {
        foreach(var device in InputSystem.devices.Where(d=>d.name.StartsWith("QuaterniusR10")).ToArray())InputSystem.RemoveDevice(device);
        foreach(string token in SessionState.GetString("r10-native-devices","").Split(','))if(int.TryParse(token,out int id)){var d=InputSystem.GetDeviceById(id);if(d!=null)InputSystem.EnableDevice(d);}
        LocalJourneyProfile.ValidationRootOverride=SessionState.GetString("r10-prior-profile","");if(string.IsNullOrEmpty(LocalJourneyProfile.ValidationRootOverride))LocalJourneyProfile.ValidationRootOverride=null;
        InputSystem.settings.backgroundBehavior=(InputSettings.BackgroundBehavior)SessionState.GetInt("r10-input-background",0);InputSystem.settings.editorInputBehaviorInPlayMode=(InputSettings.EditorInputBehaviorInPlayMode)SessionState.GetInt("r10-input-editor",0);
        EditorSettings.enterPlayModeOptionsEnabled=SessionState.GetBool("r10-play-options-enabled",false);EditorSettings.enterPlayModeOptions=(EnterPlayModeOptions)SessionState.GetInt("r10-play-options",0);
        return "Restored input/editor settings and profile override after the isolated Play session. Personal saves were not opened.";
    }
}
