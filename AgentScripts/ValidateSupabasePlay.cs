using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEngine;

public static class ValidateSupabasePlay
{
    private static async Task Pump(IEnumerator routine)
    {
        try
        {
            while(routine.MoveNext())
            {
                if(routine.Current is IEnumerator nested) await Pump(nested);
                else if(routine.Current is AsyncOperation operation) { while(!operation.isDone) await Task.Delay(10); }
                else await Task.Delay(10);
            }
        }
        finally { (routine as IDisposable)?.Dispose(); }
    }
    public static async Task<object> Run()
    {
        if(!Application.isPlaying) throw new InvalidOperationException("Isolated Play required");
        // Generated fixture includes only Auth public config/development player credentials, never DATABASE_URL.
        var fixture=JObject.Parse(File.ReadAllText("Temp/m05-live-auth.json"));
        var sessionA=new SupabaseSession(fixture.Value<string>("authUrl"),fixture.Value<string>("publishableKey"));
        var sessionB=new SupabaseSession(fixture.Value<string>("authUrl"),fixture.Value<string>("publishableKey"));
        int first=Time.frameCount;
        try
        {
            bool a=false,b=false;
            await Pump(sessionA.SignIn(fixture.Value<string>("emailA"),fixture.Value<string>("passwordA"),ok=>a=ok));
            await Pump(sessionB.SignIn(fixture.Value<string>("emailB"),fixture.Value<string>("passwordB"),ok=>b=ok));
            if(!a||!b) throw new InvalidOperationException("Real Supabase player authentication failed");
            var clientA=new OnlineAuthorityClient(fixture.Value<string>("backendUrl"),sessionA);
            var clientB=new OnlineAuthorityClient(fixture.Value<string>("backendUrl"),sessionB);
            OnlineAuthorityResult response=null;
            await Pump(clientA.CreateCharacter("marco05-dev","Unity A",r=>response=r));if(!response.Success) throw new InvalidOperationException("Character A creation failed");var state=JObject.Parse(response.Json);string idA=state.Value<string>("id");
            await Pump(clientB.CreateCharacter("marco05-dev","Unity B",r=>response=r));if(!response.Success) throw new InvalidOperationException("Character B creation failed");string idB=JObject.Parse(response.Json).Value<string>("id");
            await Pump(clientB.ReadCharacter(idA,r=>response=r));if(response.Status!=404) throw new InvalidOperationException("Private character disclosed");
            string encounter=null;
            foreach(string action in new[]{"examine-tracks","brief-orin","start-encounter","attack","dodge","attack","dodge","attack"})
            {
                string target=action=="examine-tracks"?"corrupted-tracks":action=="brief-orin"?"orin":action=="start-encounter"?"corrupted-wolf":encounter;
                await Pump(clientA.Intent(idA,state.Value<long>("revision"),action,target,Guid.NewGuid().ToString(),r=>response=r));
                if(!response.Success) throw new InvalidOperationException("Authoritative intention rejected: "+action);
                state=JObject.Parse(response.Json);if(state["encounter"] is JObject e) encounter=e.Value<string>("id");
            }
            if(!state["abilities"].Values<string>().Contains("weakness-reading")||state["relationships"].Value<int>("orin")!=1||state["opportunities"].Value<string>("forest-observation")!="completed") throw new InvalidOperationException("Validated observation route was not persisted");
            await Pump(clientB.ReadCharacter(idB,r=>response=r));var other=JObject.Parse(response.Json);
            if(other["abilities"].Count()!=0||other["facts"].Count()!=0||other["knowledge"].Count()!=0)throw new InvalidOperationException("Private consequences leaked");
            await Pump(clientA.ReadRegion("marco05-dev","gray-forest",r=>response=r));var regionA=JObject.Parse(response.Json);
            await Pump(clientB.ReadRegion("marco05-dev","gray-forest",r=>response=r));var regionB=JObject.Parse(response.Json);
            if(!JToken.DeepEquals(regionA,regionB))throw new InvalidOperationException("Regional projection disagrees");
            await Pump(sessionA.EnsureFresh(true,ok=>a=ok));if(!a)throw new InvalidOperationException("Real session refresh failed");
            await Pump(clientA.ReadCharacter(idA,r=>response=r));if(!response.Success||response.Revision!=state.Value<long>("revision"))throw new InvalidOperationException("Persistent state changed after refresh");
            return new{authenticatedUsers=2,separateCharacters=true,privateReadStatus=404,sharedRegion=true,ability="weakness-reading",route="forest-observation",persistedAfterRefresh=true,firstFrame=first,lastFrame=Time.frameCount,credentialsPrinted=false};
        }
        finally { sessionA.Clear();sessionB.Clear(); }
    }
}
