using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Mmorpg.Runtime;
using Newtonsoft.Json.Linq;
using UnityEngine;

public static class ValidateExpandedPlay
{
    private static async Task Pump(IEnumerator routine)
    {try{while(routine.MoveNext()){if(routine.Current is IEnumerator nested)await Pump(nested);else if(routine.Current is AsyncOperation op){while(!op.isDone)await Task.Delay(10);}else await Task.Delay(10);}}finally{(routine as IDisposable)?.Dispose();}}
    private static WorldJourneySession model;
    private static int actions;
    private static async Task Do(string kind,string target="")
    {
        long before=model.State.Value<long>("revision");await Pump(model.SubmitRoutine(kind,target));
        if(model.State.Value<long>("revision")!=before+1)throw new InvalidOperationException("World interaction failed: "+kind+"/"+target);
        actions++;
    }
    private static async Task Fight(string creature)
    {
        await Do("challenge",creature);
        if(creature=="cave-bat")await Do("ability","hunter-mark");
        for(int turn=0;turn<30;turn++)
        {var e=model.State["journey"]["encounter"];if(e.Value<string>("phase")=="defeated")break;if(e.Value<string>("phase")=="preparing"||e.Value<string>("phase")=="hidden")await Do("dodge");else if(e.Value<int>("range")>0)await Do("approach");else await Do("attack");}
        if(model.State["journey"]["encounter"].Value<string>("phase")!="defeated")throw new InvalidOperationException("Encounter did not finish");await Do("loot",creature);
    }
    public static async Task<object> Run()
    {
        if(!Application.isPlaying)throw new InvalidOperationException("Play required");
        var fixture=JObject.Parse(File.ReadAllText("Temp/m05-live-auth.json"));model=UnityEngine.Object.FindFirstObjectByType<WorldJourneySession>();if(model==null)throw new InvalidOperationException("Expanded scene required");
        model.Configure(fixture.Value<string>("backendUrl"),fixture.Value<string>("authUrl"),fixture.Value<string>("publishableKey"),UnityEngine.Object.FindFirstObjectByType<WorldJourneyHud>(),UnityEngine.Object.FindFirstObjectByType<WorldJourneyView>());
        int first=Time.frameCount;actions=0;
        await Pump(model.Connect(fixture.Value<string>("emailA"),fixture.Value<string>("passwordA"),"Unity expanded test"));if(model.State==null)throw new InvalidOperationException("Expanded authentication failed");
        await Do("talk","brann");await Do("challenge","training-dummy");await Do("attack");await Do("guard");await Do("attack");await Do("loot","training-dummy");await Do("complete","guard-training");
        await Do("challenge","training-dummy");await Do("attack");await Do("dodge");await Do("attack");await Do("loot","training-dummy");await Do("complete","counter-training");
        await Do("travel","gray-forest");await Do("gather","forest-tracks");await Do("gather","forest-herbs");await Do("gather","forest-spring");await Do("talk","orin");await Do("complete","hunter-mark-training");await Fight("corrupted-wolf");await Do("talk","mira");await Do("complete","forest-sample");await Do("complete","essence-research");
        await Do("travel","echo-marsh");await Do("gather","marsh-memory");await Do("gather","marsh-reeds");await Do("talk","ivo");await Do("complete","silent-marsh-route");await Do("talk","nera");await Do("complete","toxin-study");await Do("gather","echo-lotus");await Do("complete","purification-training");
        await Do("travel","asterion");await Do("gather","ruins-inscription");await Do("talk","enya");await Do("complete","ancestral-study");await Do("gather","ancestral-glyph");
        await Do("travel","kharum");await Do("talk","dorin");await Do("complete","mining-tools");await Do("equip","mining-pick");await Do("gather","iron-vein");await Do("gather","copper-vein");await Do("complete","fracture-training");await Do("gather","crystal-seam");await Do("complete","seismic-training");await Fight("cave-bat");
        await Do("travel","valdoria");await Do("talk","selka");await Do("complete","combustion-training");await Do("equip","alchemist-kit");await Do("complete","forge-blade");await Do("equip","iron-blade");await Do("talk","helena");await Do("complete","brew-healing");await Do("use","healing-draught");
        var state=model.State;var journey=state["journey"];int skills=state["abilities"].Count();int visits=((JObject)journey["facts"]).Properties().Count(p=>p.Name.StartsWith("visited:"));if(skills!=12||visits!=5||state["inventory"].Value<int>("healing-draught")!=2)throw new InvalidOperationException("Expanded gameplay projection incomplete");
        var result=new{authenticated=true,regionsNavigated=visits,abilitiesUnlocked=skills,validatedActions=actions,distinctEncounters=new[]{"corrupted-wolf","cave-bat"},equippedWeapon=journey["equipment"].Value<string>("weapon"),consumablesRemaining=2,firstFrame=first,lastFrame=Time.frameCount,credentialsPrinted=false};
        File.WriteAllText("Docs/Validation/m05b-real-world-result.json",Newtonsoft.Json.JsonConvert.SerializeObject(result,Newtonsoft.Json.Formatting.Indented));return result;
    }
}
