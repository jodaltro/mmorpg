using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using UnityEditor;
using EventType=Mmorpg.Domain.EventType;

public static class InspectSessionGuards06B4
{
    private sealed class LateClient:ILocalDecisionClient
    {
        public IEnumerator Evaluate(DecisionContext context,Action<DecisionRecord> completed)
        {SessionEpoch.Advance();completed(MiraReactions.Deterministic(context));yield break;}
    }
    public static string Main()
    {
        if(EditorApplication.isPlaying)throw new InvalidOperationException("Run isolated guard probe outside Play");
        var engine=new JourneyEngine();
        Func<EventType,string,GameEvent> fact=(type,source)=>new GameEvent{eventId=Guid.NewGuid().ToString("N"),eventType=type,sourceId=source,actorId=ForestContent.Actor,worldId=ForestContent.World};
        var e=fact(EventType.CreatureDefeated,"combat");e.creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId="guard-fixture"};engine.ApplyValidated(e);
        e=fact(EventType.EvidenceCollected,"sample-drop");e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="guard-fixture"};engine.ApplyValidated(e);
        e=fact(EventType.EvidenceDelivered,ForestContent.Mira);e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="guard-fixture",recipientId=ForestContent.Mira};engine.ApplyValidated(e);
        if(engine.PendingMiraDecision()==null)throw new Exception("Invalid fixture");
        long epoch=SessionEpoch.Current;bool applied=true;var stack=new Stack<IEnumerator>();stack.Push(new MiraDecisionOrchestrator(new LateClient()).Resolve(engine,()=>SessionEpoch.Current==epoch,value=>applied=value));
        while(stack.Count>0){var current=stack.Peek();if(!current.MoveNext()){stack.Pop();continue;}if(current.Current is IEnumerator child)stack.Push(child);}
        if(applied||engine.Snapshot().decisions.Count!=0)throw new Exception("Stale decision applied");
        string root=Path.Combine(SessionState.GetString("b4-save",""),"RecoveryProbe");Directory.CreateDirectory(root);string path=Path.Combine(root,"journey.json");
        var disk=new JsonJourneyPersistence(path);disk.Save(engine.Snapshot());File.Copy(path,path+".bak",true);File.WriteAllText(path,"corrupt-inspection-fixture");var recovered=disk.Load();
        if(recovered==null||disk.RecoveryMessage==null||!disk.RecoveryMessage.Contains(".bak"))throw new Exception("Recovery failed");
        string result="Isolated manual probes: late callback after epoch advance was rejected (0 decisions applied); checksum-corrupt Temp save recovered verified .bak. No HTTP, credentials, personal save or remote data used.";
        File.WriteAllText("Docs/Validation/Marco06B4/session-guard-probes.txt",result);return result;
    }
}
