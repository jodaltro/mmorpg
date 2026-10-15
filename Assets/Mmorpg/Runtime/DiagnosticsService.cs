using System;
using System.Collections;
using System.Diagnostics;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Networking;
namespace Mmorpg.Runtime
{
    public sealed class DiagnosticsService : MonoBehaviour
    {
        [SerializeField] private string healthEndpoint="http://127.0.0.1:8093/healthz";
        [SerializeField,Min(5)] private float intervalSeconds=20;
        private float nextSample,elapsed;private int frames;
        private void OnEnable()
        {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
            StartCoroutine(Poll());
#endif
        }
        private void Update(){frames++;elapsed+=Time.unscaledDeltaTime;if(Time.unscaledTime<nextSample)return;RuntimeDiagnostics.Frames(frames/Mathf.Max(.001f,elapsed));frames=0;elapsed=0;nextSample=Time.unscaledTime+.5f;}
        private IEnumerator Poll()
        {
            while(true)
            {
                if(Uri.TryCreate(healthEndpoint,UriKind.Absolute,out var u)&&u.Scheme=="http"&&u.Host=="127.0.0.1"&&u.AbsolutePath=="/healthz"&&u.UserInfo==""&&u.Query==""&&u.Fragment=="")
                using(var request=UnityWebRequest.Get(healthEndpoint))
                {
                    request.timeout=2;request.redirectLimit=0;var clock=Stopwatch.StartNew();
                    yield return request.SendWebRequest();bool valid=false;
                    if(request.result==UnityWebRequest.Result.Success&&request.downloadHandler.data.Length<4096)try{valid=JObject.Parse(request.downloadHandler.text).Value<string>("status")=="ok";}catch(Newtonsoft.Json.JsonException){}
                    RuntimeDiagnostics.Health(valid?"ONLINE":request.error!=null&&request.error.IndexOf("tim",StringComparison.OrdinalIgnoreCase)>=0?"TIMEOUT":"OFFLINE",clock.ElapsedMilliseconds);
                }
                yield return new WaitForSecondsRealtime(intervalSeconds);
            }
        }
    }
}
