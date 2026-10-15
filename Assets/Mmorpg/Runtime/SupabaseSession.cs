using System;
using System.Collections;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine.Networking;

namespace Mmorpg.Runtime
{
    // Explicit online session; tokens exist only in memory and never enter journey saves.
    public sealed class SupabaseSession
    {
        private readonly string endpoint, publicKey;
        private string accessToken, refreshToken;
        private long expiresAt;
        private bool refreshing;
        private long generation;
        public bool HasSession => !string.IsNullOrEmpty(accessToken);
        internal string AccessToken => accessToken;
        public SupabaseSession(string endpoint,string publicKey)
        {
            if(!ValidEndpoint(endpoint)||!ValidPublicKey(publicKey)) throw new ArgumentException("Invalid public Auth configuration");
            this.endpoint=endpoint.TrimEnd('/'); this.publicKey=publicKey;
            OnlineSessionRegistry.Register(this);
        }
        public static bool ValidEndpoint(string value) => Uri.TryCreate(value,UriKind.Absolute,out var u)&&
            (u.Scheme=="https"||u.Scheme=="http"&&u.Host=="127.0.0.1")&&u.UserInfo==""&&u.Query==""&&u.Fragment==""&&(u.AbsolutePath=="/"||u.AbsolutePath=="");
        public static bool ValidPublicKey(string key)
        {
            if(string.IsNullOrWhiteSpace(key)||key.StartsWith("sb_secret_",StringComparison.Ordinal)) return false;
            if(key.StartsWith("sb_publishable_",StringComparison.Ordinal)) return true;
            try
            {
                var parts=key.Split('.'); if(parts.Length!=3) return false;
                string payload=parts[1].Replace('-','+').Replace('_','/'); payload=payload.PadRight((payload.Length+3)/4*4,'=');
                return JObject.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(payload))).Value<string>("role")=="anon";
            }
            catch(Exception ex) when(ex is FormatException||ex is JsonException) { return false; }
        }
        public void Clear() { generation++; accessToken=null; refreshToken=null; expiresAt=0; }
        public IEnumerator SignIn(string email,string password,Action<bool> completed)
        { Clear(); yield return Token("token?grant_type=password",new {email,password},generation,completed); }
        public IEnumerator SignUpDevelopment(string email,string password,Action<bool> completed)
        { Clear(); yield return Token("signup",new {email,password},generation,completed); }
        public IEnumerator EnsureFresh(bool force,Action<bool> completed)
        {
            while(refreshing) yield return null;
            if(!HasSession) { completed(false); yield break; }
            if(!force&&DateTimeOffset.UtcNow.ToUnixTimeSeconds()<expiresAt-30) { completed(true); yield break; }
            if(string.IsNullOrEmpty(refreshToken)) { Clear(); completed(false); yield break; }
            refreshing=true;
            try { yield return Token("token?grant_type=refresh_token",new {refresh_token=refreshToken},generation,completed); }
            finally { refreshing=false; }
        }
        private IEnumerator Token(string path,object payload,long requestedGeneration,Action<bool> completed)
        {
            using(var request=new UnityWebRequest(endpoint+"/auth/v1/"+path,"POST"))
            {
                request.uploadHandler=new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(payload)));
                request.downloadHandler=new DownloadHandlerBuffer(); request.timeout=8; request.redirectLimit=0;
                request.SetRequestHeader("Content-Type","application/json"); request.SetRequestHeader("apikey",publicKey);
                yield return request.SendWebRequest();
                bool accepted=false;
                if(requestedGeneration!=generation) { completed(false); yield break; }
                if(request.result==UnityWebRequest.Result.Success)
                {
                    try
                    {
                        var token=JObject.Parse(request.downloadHandler.text);
                        string access=token.Value<string>("access_token"),refresh=token.Value<string>("refresh_token");
                        long lifetime=token.Value<long>("expires_in");
                        if(!string.IsNullOrEmpty(access)&&!string.IsNullOrEmpty(refresh)&&token.Value<string>("token_type")=="bearer"&&lifetime>0&&lifetime<=86400)
                        { accessToken=access; refreshToken=refresh; expiresAt=DateTimeOffset.UtcNow.ToUnixTimeSeconds()+lifetime; accepted=true; }
                    }
                    catch(Exception ex) when(ex is JsonException||ex is FormatException||ex is InvalidCastException||ex is OverflowException) { }
                }
                if(!accepted) Clear(); completed(accepted);
            }
        }
    }
}
