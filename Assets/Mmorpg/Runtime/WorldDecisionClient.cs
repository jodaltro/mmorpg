using System;
using System.Collections;
using System.Text;
using Mmorpg.Domain;
using Newtonsoft.Json;
using UnityEngine.Networking;

namespace Mmorpg.Runtime
{
    public interface IWorldDecisionClient { IEnumerator Evaluate(WorldEvaluation context,Action<DecisionRecord> completed); }
    public sealed class WorldDecisionClient : IWorldDecisionClient
    {
        private readonly DecisionMode mode;
        private readonly string endpoint;
        private readonly int timeout;
        public WorldDecisionClient(DecisionMode mode,string endpoint,int timeout=8) { this.mode=mode; this.endpoint=endpoint; this.timeout=Math.Max(1,Math.Min(35,timeout)); }
        public IEnumerator Evaluate(WorldEvaluation context,Action<DecisionRecord> completed)
        {
            long epoch=SessionEpoch.Current;
            RuntimeDiagnostics.Begin(context.eventId,context.candidates.Count,mode==DecisionMode.OpenRouter&&LocalDecisionClient.IsLocalEndpoint(endpoint));
            foreach(var candidate in context.candidates)RuntimeDiagnostics.Trace(candidate.causeId,"Candidate:"+candidate.id,context.eventId);
            if(mode==DecisionMode.Deterministic||!LocalDecisionClient.IsLocalEndpoint(endpoint)) {var local=WorldEventContent.Deterministic(context,mode==DecisionMode.Deterministic?null:"local_endpoint_rejected");RuntimeDiagnostics.End(context.eventId,local,0,false);completed(local);yield break; }
            using(var request=new UnityWebRequest(endpoint,"POST")) {
                request.uploadHandler=new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(context)));
                request.downloadHandler=new DownloadHandlerBuffer(); request.SetRequestHeader("Content-Type","application/json"); request.timeout=timeout; request.redirectLimit=0;
                ActionMetrics.NetworkStarted();
                ActionDebugTrace.Record("MUNDO HTTP", "Pedido iniciado; aguardando backend");
                var clock=System.Diagnostics.Stopwatch.StartNew();SessionEpoch.Track(request);
                try{yield return request.SendWebRequest();}finally{SessionEpoch.Untrack(request);}
                if(epoch!=SessionEpoch.Current)yield break;
                DecisionRecord result=null;
                if(request.result==UnityWebRequest.Result.Success&&request.responseCode==200&&request.downloadHandler.data.Length<=65536) {
                    try { result=JsonConvert.DeserializeObject<DecisionRecord>(request.downloadHandler.text); } catch(JsonException) { }
                }
                ActionDebugTrace.Record("MUNDO HTTP", $"HTTP {request.responseCode}; {request.result}; " + (result==null?"fallback determinístico":"resposta recebida; será revalidada"));
                var final=result??WorldEventContent.Deterministic(context,"local_service_unavailable");RuntimeDiagnostics.End(context.eventId,final,clock.ElapsedMilliseconds,true);completed(final);
            }
        }
    }
    public sealed class WorldDecisionCoordinator
    {
        private readonly IWorldDecisionClient client;
        public WorldDecisionCoordinator(IWorldDecisionClient client) { this.client=client; }
        public IEnumerator Resolve(WorldEventOrchestrator world,JourneyEngine journey,Func<bool> stillCurrent,Action<bool> completed)
        {
            bool changed=false;
            for(int i=0;i<3;i++) {
                world.Synchronize(journey); world.Tick(journey);
                var context=world.PendingEvaluation(); if(context==null) break;
                DecisionRecord result=null; yield return client.Evaluate(context,value=>result=value);
                if(!stillCurrent()) { completed(false); yield break; }
                world.Synchronize(journey); world.Tick(journey);
                bool applied=world.TryApplyDecision(result,journey);
                RuntimeDiagnostics.Applied(context.eventId,result?.selectedConsequence,applied);
                ActionDebugTrace.Record("MUNDO", applied?"Decisão validada e aplicada":"Decisão rejeitada; reavaliando fallback");
                if(!applied) {
                    var fresh=world.PendingEvaluation();
                    if(fresh!=null){var fallback=WorldEventContent.Deterministic(fresh,fresh.stateVersion!=context.stateVersion?"state_changed":"invalid_local_response");applied=world.TryApplyDecision(fallback,journey);RuntimeDiagnostics.Applied(fresh.eventId,fallback.selectedConsequence,applied);}
                }
                changed|=applied;
            }
            completed(changed);
        }
    }
}
