#if DEVELOPMENT_BUILD && !UNITY_EDITOR
using System;
using System.Collections;
using System.IO;
using System.Linq;
using Gamekit3D;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

// Opt-in standalone evidence, absent from release and inactive in normal launches.
public sealed class Action3DBuildSmoke : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (Environment.GetCommandLineArgs().Contains("-action3d-smoke"))
            new GameObject("Action3D standalone smoke").AddComponent<Action3DBuildSmoke>();
    }
    IEnumerator Start()
    {
        Application.runInBackground=true;
        var enemy=UnityEngine.Object.FindAnyObjectByType<ChomperBehavior>();enemy.gameObject.SetActive(false);
        var keyboard=InputSystem.AddDevice<Keyboard>("StandaloneQAKeyboard");
        yield return new WaitForSeconds(1);
        var player=PlayerController.instance;Vector3 start=player.transform.position;int frame=Time.frameCount;
        InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.W));
        yield return new WaitForSeconds(1.2f);
        InputSystem.QueueStateEvent(keyboard,new KeyboardState());
        yield return new WaitForSeconds(0.3f);
        float distance=Vector3.Distance(start,player.transform.position);
        string root=Path.Combine(Environment.CurrentDirectory,"Docs/Validation/Action3DFoundation/Standalone");
        Directory.CreateDirectory(root);
        yield return new WaitForEndOfFrame();
        var texture=ScreenCapture.CaptureScreenshotAsTexture();
        File.WriteAllBytes(Path.Combine(root,"standalone-movement.png"),texture.EncodeToPNG());Destroy(texture);
        bool passed=distance>1 && Time.frameCount>frame+10;
        File.WriteAllText(Path.Combine(root,"smoke.json"),Newtonsoft.Json.JsonConvert.SerializeObject(new { passed, distance, start=start.ToString(), end=player.transform.position.ToString(), frameStart=frame, frameEnd=Time.frameCount, profile=Mmorpg.Runtime.LocalJourneyProfile.Root, unity=Application.unityVersion, scene=gameObject.scene.path },Newtonsoft.Json.Formatting.Indented));
        InputSystem.RemoveDevice(keyboard);
        Debug.Log(passed?"ACTION3D_STANDALONE_PASS":"ACTION3D_STANDALONE_FAIL");
        Application.Quit(passed?0:17);
    }
}
#endif
