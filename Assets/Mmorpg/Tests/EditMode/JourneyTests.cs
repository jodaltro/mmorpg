using System;
using System.IO;
using System.Linq;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;

namespace Mmorpg.Tests
{
    public sealed class JourneyTests
    {
        private JourneyEngine engine;
        private int sequence;
        [SetUp] public void Setup() { engine=new JourneyEngine(); sequence=0; }
        private GameEvent Fact(EventType type,string source)
        { return new GameEvent{eventId="test-"+(++sequence),eventType=type,sourceId=source,actorId=ForestContent.Actor,worldId=ForestContent.World,timestamp=sequence}; }
        private GameEvent Defeat(string encounter="wolf-1") { var e=Fact(EventType.CreatureDefeated,"combat"); e.creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId=encounter}; return e; }
        private GameEvent Sample(EventType type,string encounter="wolf-1") { var e=Fact(type,type==EventType.EvidenceCollected?"sample-drop":ForestContent.Mira); e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId=encounter,recipientId=type==EventType.EvidenceDelivered?ForestContent.Mira:null}; return e; }
        private GameEvent Trace() { var e=Fact(EventType.TraceExamined,ForestContent.Trace); e.trace=new TracePayload{traceId=ForestContent.Trace}; return e; }
        private GameEvent Orin(bool share=true) { var e=Fact(EventType.NpcInteracted,ForestContent.Orin); e.npc=new NpcPayload{npcId=ForestContent.Orin,sharedFact=share?ForestContent.Trace:null}; return e; }
        private void RouteA() { Assert.That(engine.ApplyValidated(Defeat()),Is.True); Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceCollected)),Is.True); Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceDelivered)),Is.True); }
        [Test] public void SampleRouteUnlocksExactlyOnceAndDeliveryIsUnique()
        {
            RouteA(); Assert.That(engine.HasAbility(ForestContent.Technique),Is.True); Assert.That(engine.Status(ForestContent.RouteA),Is.EqualTo(OpportunityStatus.Completed));
            Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceDelivered)),Is.False); Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceCollected)),Is.False);
            Assert.That(engine.Snapshot().facts.Count(e=>e.eventType==EventType.AbilityUnlocked),Is.EqualTo(1));
        }
        [Test] public void ObservationRouteRequiresRealLaterEncounter()
        {
            engine.ApplyValidated(Defeat()); engine.ApplyValidated(Trace()); engine.ApplyValidated(Orin());
            Assert.That(engine.HasAbility(ForestContent.Technique),Is.False);
            Assert.That(engine.ApplyValidated(Defeat("wolf-2")),Is.True); Assert.That(engine.HasAbility(ForestContent.Technique),Is.True);
        }
        [Test] public void ObservationRouteAndSecondRouteStillChangeKnowledgeAndRelation()
        {
            engine.ApplyValidated(Trace()); engine.ApplyValidated(Orin()); RouteA();
            Assert.That(engine.Status(ForestContent.RouteB),Is.EqualTo(OpportunityStatus.Completed));
            var s=engine.Snapshot(); Assert.That(s.abilities.Count,Is.EqualTo(1)); Assert.That(s.relations.All(r=>r.trust==1),Is.True);
            Assert.That(engine.Knows(ForestContent.Orin,ForestContent.RouteB),Is.True);
        }
        [Test] public void EventsAreIdempotentAndCopiesCannotMutateMemory()
        {
            var e=Defeat(); Assert.That(engine.ApplyValidated(e),Is.True); Assert.That(engine.ApplyValidated(e),Is.False);
            e.creature.creatureId="changed"; engine.Snapshot().facts.Clear(); Assert.That(engine.Snapshot().facts.Count,Is.EqualTo(1));
            Assert.That(engine.ApplyValidated(Defeat()),Is.False);
            var reserved=Defeat("wolf-2"); reserved.eventId="derived:AbilityUnlocked:weakness-reading"; Assert.That(engine.ApplyValidated(reserved),Is.False);
        }
        [Test] public void PreconditionsAndUnknownSourcesCannotUnlock()
        {
            Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceCollected)),Is.False); Assert.That(engine.ApplyValidated(Sample(EventType.EvidenceDelivered)),Is.False);
            Assert.That(engine.ApplyValidated(Orin()),Is.False);
            var fabricated=Fact(EventType.AbilityUnlocked,"UI"); fabricated.discovery=new DiscoveryPayload{definitionId=ForestContent.Technique}; Assert.That(engine.ApplyValidated(fabricated),Is.False);
            var defeat=Defeat(); defeat.sourceId="UI"; Assert.That(engine.ApplyValidated(defeat),Is.False); Assert.That(engine.HasAbility(ForestContent.Technique),Is.False);
        }
        [Test] public void NpcKnowledgeRequiresValidInformationTransferAndRepeatsAreNoOps()
        {
            engine.ApplyValidated(Trace()); Assert.That(engine.Knows(ForestContent.Orin,ForestContent.Trace),Is.False); Assert.That(engine.Knows(ForestContent.Mira,ForestContent.Trace),Is.False);
            engine.ApplyValidated(Orin()); int count=engine.Snapshot().facts.Count; Assert.That(engine.ApplyValidated(Orin()),Is.False); Assert.That(engine.Snapshot().facts.Count,Is.EqualTo(count));
            Assert.That(engine.Knows(ForestContent.Orin,ForestContent.Trace),Is.True); Assert.That(engine.Dialogue(ForestContent.Mira),Does.Not.Contain("confirma"));
        }
        private sealed class InvalidPolicy : IConsequencePolicy { public string Select(System.Collections.Generic.IReadOnlyList<string> eligible) => "invented-reward"; }
        [Test] public void PolicyCannotApplyUnlistedConsequence()
        {
            engine=new JourneyEngine(policy:new InvalidPolicy()); RouteA(); Assert.That(engine.HasAbility(ForestContent.Technique),Is.False); Assert.That(engine.EligibleConsequences(),Does.Contain(ForestContent.RouteA));
        }
        [Test] public void InvalidPayloadOrVersionRejected()
        {
            var e=Defeat(); e.trace=new TracePayload(); Assert.That(engine.ApplyValidated(e),Is.False);
            e.trace=null; e.payloadVersion=2; Assert.That(engine.ApplyValidated(e),Is.False);
        }
        [Test] public void SaveLoadRestoresFactsAbilitiesEvidenceOpportunitiesAndRelations()
        {
            RouteA(); var restored=JourneyEngine.Restore(engine.Snapshot()); Assert.That(restored.HasAbility(ForestContent.Technique),Is.True);
            Assert.That(restored.Snapshot().facts.Count,Is.EqualTo(engine.Snapshot().facts.Count)); Assert.That(restored.HasSample,Is.False);
            var invalid=engine.Snapshot(); invalid.relations[0].trust=100; Assert.Throws<ArgumentException>(()=>JourneyEngine.Restore(invalid));
        }
        [Test] public void PendingEvidenceAndOpportunitySurviveSaveLoad()
        {
            engine.ApplyValidated(Defeat()); engine.ApplyValidated(Sample(EventType.EvidenceCollected));
            var store=new MemoryJourneyPersistence(); store.Save(engine.Snapshot()); var restored=JourneyEngine.Restore(store.Load());
            Assert.That(restored.HasSample,Is.True); Assert.That(restored.Status(ForestContent.RouteA),Is.EqualTo(OpportunityStatus.Available)); Assert.That(restored.HasAbility(ForestContent.Technique),Is.False);
            Assert.That(restored.ApplyValidated(Sample(EventType.EvidenceDelivered)),Is.True); Assert.That(restored.HasAbility(ForestContent.Technique),Is.True);
        }
        [Test] public void JsonSaveRecoversBackupAndRejectsCorruptionAndUnsupportedVersion()
        {
            string directory=Path.Combine(Path.GetTempPath(),"mmorpg-test-"+Guid.NewGuid().ToString("N")); string path=Path.Combine(directory,"save.json");
            try
            {
                var store=new JsonJourneyPersistence(path); engine.ApplyValidated(Trace()); store.Save(engine.Snapshot()); engine.ApplyValidated(Orin()); store.Save(engine.Snapshot());
                Assert.That(JourneyEngine.Restore(store.Load()).OrinBriefed,Is.True);
                File.WriteAllText(path,"broken"); var recovered=JourneyEngine.Restore(store.Load()); Assert.That(recovered.HasTrace,Is.True); Assert.That(recovered.OrinBriefed,Is.False); Assert.That(store.RecoveryMessage,Is.Not.Null);
                store.Save(recovered.Snapshot()); Assert.That(JourneyEngine.Restore(store.Load()).HasTrace,Is.True);
                File.WriteAllText(path,"{\"version\":99}"); File.WriteAllText(path+".bak","broken"); Assert.Throws<InvalidDataException>(()=>store.Load());
            }
            finally { if(Directory.Exists(directory)) Directory.Delete(directory,true); }
        }
        [Test] public void InterruptedFirstSaveRecoversVerifiedTemporaryFile()
        {
            string dir=Path.Combine(Path.GetTempPath(),"mmorpg-test-"+Guid.NewGuid().ToString("N")); string path=Path.Combine(dir,"save.json");
            try { var store=new JsonJourneyPersistence(path); RouteA(); store.Save(engine.Snapshot()); File.Move(path,path+".tmp"); Assert.That(JourneyEngine.Restore(store.Load()).HasAbility(ForestContent.Technique),Is.True); }
            finally { if(Directory.Exists(dir)) Directory.Delete(dir,true); }
        }
        [Test] public void WeaknessRequiresLearnedTechniqueValidTargetRangeAndCooldown()
        {
            var ability=new WeaknessReading(new WeaknessParameters());
            Assert.That(ability.TryMark(false,true,"wolf",true,1,0),Is.False); Assert.That(ability.TryMark(true,true,"wolf",true,4,0),Is.False);
            Assert.That(ability.TryMark(true,true,"wolf",false,1,0),Is.False); Assert.That(ability.TryMark(true,true,"wolf",true,1,0),Is.True);
            Assert.That(ability.TryMark(true,true,"wolf",true,1,1),Is.False); Assert.That(ability.Bonus("other",1),Is.Zero); Assert.That(ability.Bonus("wolf",5),Is.Zero);
            Assert.That(ability.TryMark(true,true,"wolf",true,1,8),Is.True);
        }
        [Test] public void WeaknessBonusIsCappedAndConsumedOnlyBySuccessfulHit()
        {
            var ability=new WeaknessReading(new WeaknessParameters{bonus=100,maximumBonus=10}); ability.TryMark(true,true,"wolf",true,1,0);
            Assert.That(ability.Bonus("wolf",1),Is.EqualTo(10)); Assert.That(ability.Bonus("wolf",2),Is.EqualTo(10));
            ability.ConfirmHit("other",2); Assert.That(ability.Bonus("wolf",2),Is.EqualTo(10)); ability.ConfirmHit("wolf",2); Assert.That(ability.Bonus("wolf",2),Is.Zero);
        }
    }
}
