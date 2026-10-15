using System;
using System.IO;
using System.Linq;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;

namespace Mmorpg.Tests
{
    public sealed class DecisionTests
    {
        private JourneyEngine engine;
        private int sequence;
        private GameEvent Event(EventType type,string source) => new GameEvent{eventId="decision-test-"+(++sequence),eventType=type,sourceId=source,actorId=ForestContent.Actor,worldId=ForestContent.World,timestamp=sequence};
        private void Deliver()
        {
            var e=Event(EventType.CreatureDefeated,"combat"); e.creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId="wolf"}; Assert.That(engine.ApplyValidated(e),Is.True);
            e=Event(EventType.EvidenceCollected,"sample-drop"); e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="wolf"}; Assert.That(engine.ApplyValidated(e),Is.True);
            e=Event(EventType.EvidenceDelivered,ForestContent.Mira); e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="wolf",recipientId=ForestContent.Mira}; Assert.That(engine.ApplyValidated(e),Is.True);
        }
        [SetUp] public void Setup() { engine=new JourneyEngine(); sequence=0; }
        [Test] public void NoCandidateBeforeValidatedDelivery()
        {
            Assert.That(engine.PendingMiraDecision(),Is.Null);
            Deliver(); var context=engine.PendingMiraDecision();
            Assert.That(context.eligibleConsequences,Is.EquivalentTo(MiraReactions.Options));
            Assert.That(context.npcKnowledge,Does.Contain(ForestContent.Sample));
            Assert.That(engine.HasAbility(ForestContent.Technique),Is.True);
        }
        [TestCase(MiraReactions.Scientific)]
        [TestCase(MiraReactions.Concern)]
        [TestCase(MiraReactions.Suspicion)]
        [TestCase(MiraReactions.Neutral)]
        public void AuthorizedChoicePersistsAndCannotRepeatOrChange(string selected)
        {
            Deliver(); var context=engine.PendingMiraDecision(); var result=MiraReactions.Deterministic(context); result.selectedConsequence=selected;
            Assert.That(engine.TryApplyDecision(result),Is.True); result.selectedConsequence="invented";
            var saved=engine.Snapshot(); Assert.That(saved.version,Is.EqualTo(2)); Assert.That(saved.decisions.Single().selectedConsequence,Is.EqualTo(selected));
            Assert.That(engine.TryApplyDecision(MiraReactions.Deterministic(context)),Is.False);
            var restored=JourneyEngine.Restore(saved);
            Assert.That(restored.Dialogue(ForestContent.Mira),Does.StartWith(MiraReactions.Text(selected)));
            Assert.That(restored.Knows(ForestContent.Mira,selected),Is.True);
            Assert.That(restored.PendingMiraDecision(),Is.Null); Assert.That(restored.Snapshot().abilities.Count,Is.EqualTo(1));
        }
        [Test] public void UnknownChoiceAndWrongIdentityPolicyOrVersionRejected()
        {
            Deliver(); var context=engine.PendingMiraDecision();
            foreach(var mutate in new Action<DecisionRecord>[] {d=>d.selectedConsequence="new-reward",d=>d.eventId="other",d=>d.actorId="other",d=>d.worldId="other",d=>d.policyId="other",d=>d.version=2})
            {
                var result=MiraReactions.Deterministic(context); mutate(result); Assert.That(engine.TryApplyDecision(result),Is.False);
            }
            Assert.That(engine.Snapshot().decisions,Is.Empty);
        }
        [Test] public void ChangedStateRejectsOldResultAndFreshFallbackStillWorks()
        {
            Deliver(); var old=MiraReactions.Deterministic(engine.PendingMiraDecision()); old.selectedConsequence=MiraReactions.Concern;
            var trace=Event(EventType.TraceExamined,ForestContent.Trace); trace.trace=new TracePayload{traceId=ForestContent.Trace}; engine.ApplyValidated(trace);
            Assert.That(engine.TryApplyDecision(old),Is.False);
            Assert.That(engine.TryApplyDecision(MiraReactions.Deterministic(engine.PendingMiraDecision(),"state_changed")),Is.True);
            Assert.That(engine.Snapshot().decisions.Single().selectedConsequence,Is.EqualTo(MiraReactions.Scientific));
        }
        [Test] public void ReplayInterleavesDecisionsAndLaterEventsAndRejectsTampering()
        {
            Deliver(); engine.TryApplyDecision(MiraReactions.Deterministic(engine.PendingMiraDecision()));
            var trace=Event(EventType.TraceExamined,ForestContent.Trace); trace.trace=new TracePayload{traceId=ForestContent.Trace}; engine.ApplyValidated(trace);
            Assert.That(JourneyEngine.Restore(engine.Snapshot()).HasTrace,Is.True);
            var saved=engine.Snapshot(); saved.decisions[0].stateVersion+=100;
            Assert.Throws<ArgumentException>(()=>JourneyEngine.Restore(saved));
            saved=engine.Snapshot(); saved.decisions[0].selectedConsequence=MiraReactions.Neutral;
            Assert.Throws<ArgumentException>(()=>JourneyEngine.Restore(saved)); // Knowledge cache must match the chosen reaction.
        }
        [Test] public void JsonPersistenceRoundTripPreservesDecisionMetadataAndLegacySave()
        {
            string path=Path.Combine(Path.GetTempPath(),"m03-"+Guid.NewGuid().ToString("N"),"journey.json");
            try
            {
                Deliver(); var store=new JsonJourneyPersistence(path); store.Save(engine.Snapshot()); Assert.That(store.Load().version,Is.EqualTo(1));
                var result=MiraReactions.Deterministic(engine.PendingMiraDecision()); result.model="typesafe/jev-1.13"; result.provider="TypeSafe"; result.confidence=0.7;
                result.probabilities=new System.Collections.Generic.Dictionary<string,double>{{MiraReactions.Scientific,0.7},{MiraReactions.Concern,0.1},{MiraReactions.Suspicion,0.1},{MiraReactions.Neutral,0.1}};
                result.usage=new DecisionUsage{input_tokens=20,output_tokens=10,cost=0.000001};
                result.attempt=new DecisionAttempt{decisionId="gen-dec-low",model=result.model,provider="TypeSafe",selectedConsequence=MiraReactions.Scientific,confidence=0.1,probabilities=result.probabilities,usage=result.usage};
                engine.TryApplyDecision(result); store.Save(engine.Snapshot());
                var loaded=store.Load().decisions.Single(); Assert.That(loaded.confidence,Is.EqualTo(0.7)); Assert.That(loaded.usage.cost,Is.EqualTo(0.000001));
                Assert.That(loaded.probabilities.Count,Is.EqualTo(4));
                Assert.That(loaded.attempt.confidence,Is.EqualTo(0.1)); Assert.That(loaded.attempt.usage.cost,Is.EqualTo(0.000001));
            }
            finally { if(Directory.Exists(Path.GetDirectoryName(path))) Directory.Delete(Path.GetDirectoryName(path),true); }
        }
        [TestCase("https://127.0.0.1:8091/v1/decisions/evaluate")]
        [TestCase("http://example.com/v1/decisions/evaluate")]
        [TestCase("http://localhost:8091/v1/decisions/evaluate")]
        [TestCase("http://127.0.0.1:8091/v1/decisions/evaluate?token=x")]
        [TestCase("http://user@127.0.0.1:8091/v1/decisions/evaluate")]
        public void RuntimeRejectsNonLocalOrCredentialEndpoints(string endpoint) => Assert.That(LocalDecisionClient.IsLocalEndpoint(endpoint),Is.False);
    }
}
