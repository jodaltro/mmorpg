using System;
using System.Collections;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Mmorpg.Runtime
{
    // Expanded prototype: abstract encounters/interactions are confirmed by Go.
    // This component never grants inventory/abilities or writes offline saves.
    public sealed class WorldJourneySession : MonoBehaviour
    {
        [SerializeField] private string backendUrl="http://127.0.0.1:8093",supabaseUrl,publishableKey;
        [SerializeField] private string worldId="marco05-expanded";
        [SerializeField] private WorldJourneyHud hud;
        [SerializeField] private WorldJourneyView view;
        private SupabaseSession session;
        private OnlineAuthorityClient client;
        public JObject State { get; private set; }
        public JObject Content { get; private set; }
        public string StateJson=>State?.ToString(Newtonsoft.Json.Formatting.None);
        public bool Busy { get; private set; }
        public string Message { get; private set; }="Entre para explorar o mundo compartilhado.";
        public void Configure(string endpoint,string authUrl,string publicKey,WorldJourneyHud ui,WorldJourneyView map)
        { backendUrl=endpoint;supabaseUrl=authUrl;publishableKey=publicKey;hud=ui;view=map; }
        public IEnumerator Connect(string email,string password,string name,string existingCharacter="")
        {
            if(Busy) yield break;
            Busy=true;State=null;Content=null;session?.Clear();Refresh();
            try
            {
                if(!SupabaseSession.ValidEndpoint(supabaseUrl)||!SupabaseSession.ValidPublicKey(publishableKey))
                {Message="Configure a URL pública e publishable key do ambiente de desenvolvimento.";yield break;}
                session=new SupabaseSession(supabaseUrl,publishableKey);bool authenticated=false;
                yield return session.SignIn(email,password,ok=>authenticated=ok);
                if(!authenticated){Message="Não foi possível entrar. Confira a conta ou a sessão.";yield break;}
                client=new OnlineAuthorityClient(backendUrl,session);OnlineAuthorityResult result=null;
                yield return client.ReadContent(r=>result=r);
                if(!result.Success){Message="O mundo está indisponível. Tente novamente.";yield break;}
                Content=JObject.Parse(result.Json);
                if(string.IsNullOrWhiteSpace(existingCharacter))yield return client.CreateCharacter(worldId,name,r=>result=r);
                else if(Guid.TryParse(existingCharacter,out var character)&&character!=Guid.Empty)yield return client.ReadCharacter(character.ToString(),r=>result=r);
                else {Message="Identificador de personagem inválido.";yield break;}
                if(!result.Success){Message="Personagem indisponível para esta conta.";yield break;}
                var next=JObject.Parse(result.Json);if(next.Value<string>("worldId")!=worldId||!(next["journey"] is JObject)){Message="Escolha um personagem deste mundo.";yield break;}
                State=next;Message="Observe, converse e escolha seu caminho.";view?.Present(State);hud?.RememberCharacter(State.Value<string>("id"));
            }
            finally{Busy=false;Refresh();}
        }
        public void Submit(string kind,string target) { if(!Busy&&State!=null)StartCoroutine(SubmitRoutine(kind,target)); }
        public IEnumerator SubmitRoutine(string kind,string target)
        {
            if(Busy||State==null||client==null)yield break;Busy=true;Refresh();
            try
            {
                OnlineAuthorityResult result=null;yield return client.Intent(State.Value<string>("id"),State.Value<long>("revision"),kind,target,Guid.NewGuid().ToString(),r=>result=r);
                if(result.Success){State=JObject.Parse(result.Json);Message="Acontecimento registrado.";view?.Present(State);}
                else if(result.Status==409){yield return client.ReadCharacter(State.Value<string>("id"),r=>result=r);if(result.Success)State=JObject.Parse(result.Json);Message="O mundo mudou. Confira as ações disponíveis.";}
                else Message=result.Status==401?"Sessão expirada. Entre novamente.":"A ação não pôde ser confirmada. Nenhuma recompensa local foi aplicada.";
            }
            finally{Busy=false;Refresh();}
        }
        public void SignOut(){if(Busy)return;session?.Clear();State=null;Content=null;Message="Sessão encerrada.";Refresh();}
        private void Refresh()=>hud?.Refresh();
        private void OnDestroy()=>session?.Clear();
    }
}
