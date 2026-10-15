using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using Mmorpg.Runtime;
using TMPro;
public static class ValidateCompactDebug
{
    public static void Pause() => InputSystem.QueueStateEvent(Keyboard.current,new KeyboardState(Key.Escape));
    public static void Release() => InputSystem.QueueStateEvent(Keyboard.current,new KeyboardState());
    public static void ArmReset() => InputSystem.QueueStateEvent(Keyboard.current,new KeyboardState(Key.N));
    public static object Inspect()
    {
        var debug = GameObject.Find("ActionDebug");
        var texts = Object.FindObjectsByType<TMP_Text>(FindObjectsSortMode.None);
        string pause = "";
        foreach(var text in texts) if(text.gameObject.activeInHierarchy && text.text.Contains("NOVA JORNADA")) pause=text.text;
        return new { frame=Time.frameCount,errors=ActionMetrics.Active.Exceptions, size=debug.GetComponent<RectTransform>().sizeDelta,
            text=debug.GetComponentInChildren<TMP_Text>().text, pause, timeScale=Time.timeScale };
    }
}
