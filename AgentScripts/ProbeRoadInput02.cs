using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
public static class ProbeRoadInput02
{
    public static string Main()
    {
        var original=Keyboard.current;var background=InputSystem.settings.backgroundBehavior;var mode=InputSystem.settings.editorInputBehaviorInPlayMode;
        InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
        InputSystem.settings.editorInputBehaviorInPlayMode=InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
        var key=InputSystem.AddDevice<Keyboard>("RoadInputProbe");var body=GameObject.Find("Player").GetComponent<Rigidbody2D>();var start=body.position;var began=Time.timeAsDouble;
        Action feed=()=>{if(InputState.currentUpdateType==InputUpdateType.Dynamic)InputSystem.QueueStateEvent(key,new KeyboardState(Key.D));};
        InputSystem.onBeforeUpdate+=feed;
        EditorApplication.CallbackFunction tick=null;tick=()=>{
            if(Time.timeAsDouble-began<.6)return;
            EditorApplication.update-=tick;InputSystem.onBeforeUpdate-=feed;
            var proof=new{pass=Vector2.Distance(start,body.position)>.5f,from=start.ToString(),to=body.position.ToString(),pressed=key.dKey.isPressed,current=Keyboard.current?.name,focus=Application.isFocused,mode=InputSystem.settings.editorInputBehaviorInPlayMode.ToString()};
            System.IO.File.WriteAllText("Docs/Validation/ValdoriaWorldStudio02/Final/input-probe.json",Newtonsoft.Json.JsonConvert.SerializeObject(proof,Newtonsoft.Json.Formatting.Indented));
            InputSystem.RemoveDevice(key);original?.MakeCurrent();InputSystem.settings.backgroundBehavior=background;InputSystem.settings.editorInputBehaviorInPlayMode=mode;
        };
        EditorApplication.update+=tick;return "Focused-independent Dynamic input probe started";
    }
}
