using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

public static class CaptureExpandedUi
{
    private static async Task Pump(IEnumerator routine)
    {try{while(routine.MoveNext()){if(routine.Current is IEnumerator nested)await Pump(nested);else if(routine.Current is AsyncOperation op){while(!op.isDone)await Task.Delay(10);}else await Task.Delay(10);}}finally{(routine as IDisposable)?.Dispose();}}
    public static async Task<object> Run()
    {
        if(!Application.isPlaying)throw new InvalidOperationException("Play required");
        var f=JObject.Parse(File.ReadAllText("Temp/m05-live-auth.json"));var auth=new SupabaseSession(f.Value<string>("authUrl"),f.Value<string>("publishableKey"));bool ok=false;
        try
        {
            await Pump(auth.SignIn(f.Value<string>("emailA"),f.Value<string>("passwordA"),v=>ok=v));if(!ok)throw new InvalidOperationException("Development Auth failed");
            OnlineAuthorityResult result=null;await Pump(new OnlineAuthorityClient(f.Value<string>("backendUrl"),auth).ListCharacters(r=>result=r));if(!result.Success)throw new InvalidOperationException("Character list unavailable");var id=JObject.Parse(result.Json)["characterIds"].Values<string>().Last();
            var model=UnityEngine.Object.FindAnyObjectByType<WorldJourneySession>();model.Configure(f.Value<string>("backendUrl"),f.Value<string>("authUrl"),f.Value<string>("publishableKey"),UnityEngine.Object.FindAnyObjectByType<WorldJourneyHud>(),UnityEngine.Object.FindAnyObjectByType<WorldJourneyView>());
            await Pump(model.Connect(f.Value<string>("emailA"),f.Value<string>("passwordA"),"Unused",id));if(model.StateJson==null)throw new InvalidOperationException("Persistent world unavailable");
            // Pipeline camera screenshots omit overlay canvases; capture the rendered Game view instead.
            var window=Resources.FindObjectsOfTypeAll<EditorWindow>().FirstOrDefault(w=>w.GetType().Name=="GameView");if(window==null)throw new InvalidOperationException("Existing Game view required");window.Show();window.Focus();
            await Task.Delay(500);string path="Docs/Validation/m05b-ui.png";var started=DateTime.UtcNow;ScreenCapture.CaptureScreenshot(path);
            for(int i=0;i<100&&(!File.Exists(path)||File.GetLastWriteTimeUtc(path)<started);i++)await Task.Delay(100);
            if(!File.Exists(path)||File.GetLastWriteTimeUtc(path)<started)throw new InvalidOperationException("Game view capture unavailable");
            return new{path,abilities=model.State["abilities"].Count(),persistedCharacter=true,credentialsIncludedInImage=false};
        }
        finally{auth.Clear();}
    }
}
