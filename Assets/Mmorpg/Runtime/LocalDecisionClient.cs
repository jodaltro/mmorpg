using System;
using System.Collections;
using System.Text;
using Mmorpg.Domain;
using Newtonsoft.Json;
using UnityEngine.Networking;

namespace Mmorpg.Runtime
{
    public enum DecisionMode { Deterministic, OpenRouter }
    public interface ILocalDecisionClient
    {
        IEnumerator Evaluate(DecisionContext context,Action<DecisionRecord> completed);
    }
    // Prototype loopback only. Unity never contains an OpenRouter credential.
    public sealed class LocalDecisionClient : ILocalDecisionClient
    {
        private readonly DecisionMode mode;
        private readonly string endpoint;
        private readonly int timeoutSeconds;
        public LocalDecisionClient(DecisionMode mode,string endpoint,int timeoutSeconds=8)
        { this.mode=mode; this.endpoint=endpoint; this.timeoutSeconds=Math.Max(1,Math.Min(35,timeoutSeconds)); }
        public static bool IsLocalEndpoint(string value)
        {
            return Uri.TryCreate(value,UriKind.Absolute,out var uri)&&uri.Scheme=="http"&&uri.Host=="127.0.0.1"&&uri.Port>0&&uri.UserInfo==""&&uri.AbsolutePath=="/v1/decisions/evaluate"&&uri.Query==""&&uri.Fragment=="";
        }
        public IEnumerator Evaluate(DecisionContext context,Action<DecisionRecord> completed)
        {
            long epoch=SessionEpoch.Current;
            bool remote=mode==DecisionMode.OpenRouter&&IsLocalEndpoint(endpoint);
            RuntimeDiagnostics.Begin(context.eventId,context.eligibleConsequences.Count,remote);
            if(mode==DecisionMode.Deterministic||!IsLocalEndpoint(endpoint))
            { var local=MiraReactions.Deterministic(context,mode==DecisionMode.Deterministic?null:"local_endpoint_rejected");RuntimeDiagnostics.End(context.eventId,local,0,false);completed(local);yield break; }
            using(var request=new UnityWebRequest(endpoint,"POST"))
            {
                request.uploadHandler=new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(context)));
                request.downloadHandler=new DownloadHandlerBuffer();
                request.SetRequestHeader("Content-Type","application/json");
                request.timeout=timeoutSeconds; request.redirectLimit=0;
                ActionMetrics.NetworkStarted();
                ActionDebugTrace.Record("MIRA HTTP", "Pedido iniciado; aguardando backend");
                var clock=System.Diagnostics.Stopwatch.StartNew();SessionEpoch.Track(request);
                try {yield return request.SendWebRequest();}finally{SessionEpoch.Untrack(request);}
                if(epoch!=SessionEpoch.Current)yield break;
                DecisionRecord response=null;
                if(request.result==UnityWebRequest.Result.Success&&request.responseCode==200)
                {
                    try { response=JsonConvert.DeserializeObject<DecisionRecord>(request.downloadHandler.text); }
                    catch(JsonException) { }
                }
                ActionDebugTrace.Record("MIRA HTTP", $"HTTP {request.responseCode}; {request.result}; " + (response==null?"fallback determinístico":"resposta recebida; será revalidada"));
                var final=response??MiraReactions.Deterministic(context,"local_service_unavailable");RuntimeDiagnostics.End(context.eventId,final,clock.ElapsedMilliseconds,true);completed(final);
            }
        }
    }
}
