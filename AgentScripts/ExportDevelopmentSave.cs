using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

public static class ExportDevelopmentSave
{
    // Explicit files/world. Refuses overwrite; reads only the named primary, never recovers/writes source generations.
    public static string Export(string sourcePath,string outputPath,string destinationWorld,string characterName)
    {
        sourcePath=Path.GetFullPath(sourcePath); outputPath=Path.GetFullPath(outputPath);
        if(File.Exists(outputPath)||sourcePath==outputPath||string.IsNullOrWhiteSpace(destinationWorld)||string.IsNullOrWhiteSpace(characterName)) throw new ArgumentException("New destination file and explicit test world required");
        var envelope=JObject.Parse(File.ReadAllText(sourcePath));
        if(!File.Exists(sourcePath)||envelope.Value<int>("version")!=1) throw new ArgumentException("Invalid envelope");
        string json=envelope.Value<string>("json"),checksum=envelope.Value<string>("checksum");
        using(var hash=System.Security.Cryptography.SHA256.Create())
            if(json==null||Convert.ToBase64String(hash.ComputeHash(System.Text.Encoding.UTF8.GetBytes(json)))!=checksum) throw new ArgumentException("Invalid checksum");
        var saved=JsonConvert.DeserializeObject<JourneySnapshot>(json); JourneyEngine.Restore(saved);
        var facts=new JArray();
        Action<string,string,object> add=(id,kind,payload)=>facts.Add(new JObject{["id"]=id,["kind"]=kind,["payload"]=JObject.FromObject(payload)});
        add("save-header","save-header",new{saved.version,saved.actorId,saved.worldId});
        foreach(var fact in saved.facts) add("journey:"+fact.eventId,fact.eventType.ToString(),fact);
        foreach(var decision in saved.decisions) add("journey-decision:"+decision.decisionId,"decision",decision);
        var knowledge=new JArray(saved.knowledge.Select(k=>new JObject{["npcId"]=k.npcId,["factId"]="journey:"+k.sourceEventId}));
        for(int i=0;i<saved.knowledge.Count;i++) add("journey-knowledge:"+i,"npc-knowledge",saved.knowledge[i]);
        add("inventory-history","inventory-history",new { saved.evidence,saved.delivered });
        var opportunities=new JObject();
        foreach(var o in saved.opportunities.Where(o=>o.status!=OpportunityStatus.Unknown)) opportunities[o.id]=o.status==OpportunityStatus.Available?"available":o.status==OpportunityStatus.Started?"started":o.status==OpportunityStatus.Completed?"completed":"closed";
        if(saved.world!=null)
        {
            var w=saved.world;
            add("world-header","world-header",new{w.version,w.actorId,w.worldId,w.revision,w.gameTime,w.realTime,w.forestThreat,w.noticePublished,w.noticeRead,w.settings,w.consideredCandidates});
            foreach(var f in w.facts) add("world-fact:"+f.id,f.kind,f);
            foreach(var cmd in w.history) add("world-command:"+cmd.id,"world-command",cmd);
            foreach(var d in w.decisions) add("world-decision:"+d.decisionId,"world-decision",d);
            foreach(var s in w.scheduled) add("schedule:"+s.id,"archived-schedule",s);
            foreach(var o in w.opportunities) { add("world-opportunity:"+o.id,"world-opportunity",o); if(o.status!=WorldOpportunityStatus.Hidden) opportunities[o.id]=o.status==WorldOpportunityStatus.Discovered?"available":o.status.ToString().ToLowerInvariant(); }
            for(int i=0;i<w.eligibilityHistory.Count;i++) add("eligibility:"+i,"eligibility-audit",w.eligibilityHistory[i]);
            for(int i=0;i<w.knowledge.Count;i++) { var k=w.knowledge[i]; add("world-knowledge:"+i,"world-knowledge",k); knowledge.Add(new JObject{["npcId"]=k.npcId,["factId"]="world-fact:"+k.factId}); }
        }
        var inventory=new JObject(); foreach(string item in saved.evidence) inventory[item]=1;
        var relations=new JObject(); foreach(var r in saved.relations) relations[r.npcId]=r.trust;
        var export=new JObject{["version"]=1,["worldId"]=destinationWorld,["name"]=characterName,["sourceVersion"]=saved.version,["sourceActor"]=saved.actorId,["sourceWorld"]=saved.worldId,["sourceChecksum"]=checksum,["facts"]=facts,["abilities"]=new JArray(saved.abilities),["inventory"]=inventory,["opportunities"]=opportunities,["relationships"]=relations,["knowledge"]=knowledge};
        Directory.CreateDirectory(Path.GetDirectoryName(outputPath));
        using(var file=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))
        using(var writer=new StreamWriter(file)) writer.Write(export.ToString());
        return "Development export created; original save unchanged; pending schedules archived, shared world untouched";
    }
}
public static class ValidateDevelopmentImport
{
    public static string Run()
    {
        string root=Path.Combine("Temp","m05-save-fixtures-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(root);
        int checks=0;
        for(int version=1;version<=3;version++)
        {
            var engine=new JourneyEngine();
            var defeat=new GameEvent{eventId="fixture-defeat",actorId=ForestContent.Actor,worldId=ForestContent.World,sourceId="combat",eventType=Mmorpg.Domain.EventType.CreatureDefeated,creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId="fixture-wolf"}};
            if(!engine.ApplyValidated(defeat)) throw new Exception("Fixture rejected");
            var collect=new GameEvent{eventId="fixture-collect",actorId=ForestContent.Actor,worldId=ForestContent.World,sourceId="sample-drop",eventType=Mmorpg.Domain.EventType.EvidenceCollected,evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="fixture-wolf"}};engine.ApplyValidated(collect);
            var deliver=new GameEvent{eventId="fixture-deliver",actorId=ForestContent.Actor,worldId=ForestContent.World,sourceId=ForestContent.Mira,eventType=Mmorpg.Domain.EventType.EvidenceDelivered,evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="fixture-wolf",recipientId=ForestContent.Mira}};engine.ApplyValidated(deliver);
            if(version>=2) engine.TryApplyDecision(MiraReactions.Deterministic(engine.PendingMiraDecision()));
            var snapshot=engine.Snapshot();
            if(version==3)
            {
                var clock=new SimulatedWorldClock();var world=new WorldEventOrchestrator(snapshot.actorId,snapshot.worldId,clock);
                world.Synchronize(engine);var pending=world.PendingEvaluation();if(pending!=null)world.TryApplyDecision(WorldEventContent.Deterministic(pending),engine);
                snapshot.version=3;snapshot.world=world.Snapshot();
            }
            if(snapshot.version!=version)throw new Exception("Unexpected save version");
            string source=Path.Combine(root,"v"+version+".json"),output=Path.Combine(root,"v"+version+"-import.json");new JsonJourneyPersistence(source).Save(snapshot);
            byte[] original=File.ReadAllBytes(source);ExportDevelopmentSave.Export(source,output,"marco05-dev","fixture-v"+version);
            var parsed=JObject.Parse(File.ReadAllText(output));
            if(parsed.Value<int>("sourceVersion")!=version || !File.ReadAllBytes(source).SequenceEqual(original) || parsed["abilities"].Count()!=1 || parsed["facts"].Count()<snapshot.facts.Count)throw new Exception("Migration lost data or changed source");
            checks++;
            bool refused=false;try{ExportDevelopmentSave.Export(source,output,"marco05-dev","fixture");}catch(ArgumentException){refused=true;}if(!refused)throw new Exception("Overwrite accepted");checks++;
            var envelope=JObject.Parse(File.ReadAllText(source));envelope["checksum"]="invalid";string corrupt=Path.Combine(root,"v"+version+"-corrupt.json");File.WriteAllText(corrupt,envelope.ToString());
            refused=false;try{ExportDevelopmentSave.Export(corrupt,output+"-invalid","marco05-dev","fixture");}catch(ArgumentException){refused=true;}if(!refused || File.Exists(output+"-invalid"))throw new Exception("Corrupt save imported");checks++;
        }
        return "checks="+checks+"; v1/v2/v3 sources unchanged; exports="+Path.GetFullPath(root);
    }
}

