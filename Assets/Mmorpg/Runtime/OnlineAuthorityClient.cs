using System;
using System.Collections;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine.Networking;

namespace Mmorpg.Runtime
{
    public sealed class OnlineAuthorityResult
    {
        public long Status { get; internal set; }
        internal JObject State { get; set; }
        public string Json => State?.ToString(Formatting.None);
        public long Revision => State?.Value<long>("revision")??0;
        public string Error { get; internal set; }
        public bool Success => Status>=200&&Status<300&&State!=null;
    }
    // Opt-in adapter, never called by OfflineAuthority/JourneySession. No local reward fallback.
    public sealed class OnlineAuthorityClient
    {
        private readonly string endpoint;
        private readonly SupabaseSession session;
        public OnlineAuthorityClient(string endpoint,SupabaseSession session)
        {
            if(!SupabaseSession.ValidEndpoint(endpoint)||session==null) throw new ArgumentException("Invalid online configuration");
            this.endpoint=endpoint.TrimEnd('/'); this.session=session;
        }
        public IEnumerator CreateCharacter(string worldId,string name,Action<OnlineAuthorityResult> completed) =>
            Send("POST","/v1/characters",new {version=1,worldId,name},completed);
        public IEnumerator ListCharacters(Action<OnlineAuthorityResult> completed) => Send("GET","/v1/characters",null,completed);
        public IEnumerator ReadContent(Action<OnlineAuthorityResult> completed) => Send("GET","/v1/content",null,completed);
        public IEnumerator ReadCharacter(string characterId,Action<OnlineAuthorityResult> completed) =>
            Send("GET","/v1/characters/"+CharacterId(characterId),null,completed);
        public IEnumerator Intent(string characterId,long revision,string kind,string targetId,string requestId,Action<OnlineAuthorityResult> completed)
        {
            if(!Guid.TryParse(requestId,out var id)||id==Guid.Empty) throw new ArgumentException("Stable request ID required");
            return Send("POST","/v1/characters/"+CharacterId(characterId)+"/intentions",new {version=1,requestId=id.ToString(),expectedRevision=revision,kind,targetId},completed);
        }
        public IEnumerator ReadRegion(string worldId,string regionId,Action<OnlineAuthorityResult> completed) =>
            Send("GET","/v1/worlds/"+Uri.EscapeDataString(worldId)+"/regions/"+Uri.EscapeDataString(regionId),null,completed);
        private static string CharacterId(string value) { if(!Guid.TryParse(value,out var id)||id==Guid.Empty) throw new ArgumentException("Character ID required"); return id.ToString(); }
        private IEnumerator Send(string method,string path,object payload,Action<OnlineAuthorityResult> completed)
        {
            byte[] body=payload==null?null:Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(payload));
            for(int attempt=0;attempt<2;attempt++)
            {
                bool authenticated=false;
                yield return session.EnsureFresh(attempt>0,ok=>authenticated=ok);
                if(!authenticated) { completed(new OnlineAuthorityResult{Status=401,Error="session_expired_or_invalid"}); yield break; }
                using(var request=new UnityWebRequest(endpoint+path,method))
                {
                    var clock=System.Diagnostics.Stopwatch.StartNew();
                    if(body!=null) { request.uploadHandler=new UploadHandlerRaw(body); request.SetRequestHeader("Content-Type","application/json"); }
                    request.downloadHandler=new DownloadHandlerBuffer(); request.timeout=12; request.redirectLimit=0;
                    request.SetRequestHeader("Authorization","Bearer "+session.AccessToken);
                    yield return request.SendWebRequest();
                    if(request.responseCode==401&&attempt==0) continue;
                    JObject result=null;
                    if(request.result==UnityWebRequest.Result.Success) try { result=JObject.Parse(request.downloadHandler.text); } catch(JsonException) { }
                    if(request.responseCode==401) session.Clear();
                    // Only authenticated character routes actually access the database. /healthz and /content do not.
                    if(path.StartsWith("/v1/characters",StringComparison.Ordinal)&&request.responseCode!=401&&request.responseCode!=403)
                        RuntimeDiagnostics.Database(request.result==UnityWebRequest.Result.Success&&result!=null,clock.ElapsedMilliseconds);
                    completed(new OnlineAuthorityResult{Status=request.responseCode,State=result,Error=result==null?(request.responseCode==409?"revision_or_request_conflict":request.responseCode==401?"session_expired_or_invalid":"authority_unavailable"):null}); yield break;
                }
            }
        }
    }
}
