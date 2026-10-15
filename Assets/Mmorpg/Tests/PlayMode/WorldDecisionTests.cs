using System;
using System.Collections;
using System.Linq;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine.TestTools;

namespace Mmorpg.Tests
{
    public sealed class WorldDecisionTests
    {
        private JourneyEngine journey;
        private WorldEventOrchestrator world;
        private SimulatedWorldClock clock;
        [SetUp] public void Setup() {
            journey=new JourneyEngine(); clock=new SimulatedWorldClock(); world=new WorldEventOrchestrator(ForestContent.Actor,ForestContent.World,clock);
            var trace=new GameEvent{eventId="coordinator-trace",eventType=EventType.TraceExamined,sourceId=ForestContent.Trace,actorId=ForestContent.Actor,worldId=ForestContent.World,trace=new TracePayload{traceId=ForestContent.Trace}};
            journey.ApplyValidated(trace);
            journey.ApplyValidated(new GameEvent{eventId="coordinator-wolf",eventType=EventType.CreatureDefeated,sourceId="combat",actorId=ForestContent.Actor,worldId=ForestContent.World,creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId="wolf"}}); world.Synchronize(journey);
        }
        private sealed class FakeClient : IWorldDecisionClient {
            private readonly Action mutate; private readonly string choice;
            public int Calls { get; private set; }
            public FakeClient(string choice=null,Action mutate=null) { this.choice=choice; this.mutate=mutate; }
            public IEnumerator Evaluate(WorldEvaluation c,Action<DecisionRecord> done) { Calls++; yield return null; var d=WorldEventContent.Deterministic(c); if(choice!=null) d.selectedConsequence=choice; mutate?.Invoke(); done(d); }
        }
        [UnityTest] public IEnumerator InvalidChoiceGetsFreshDeterministicFallback() { yield return new WorldDecisionCoordinator(new FakeClient("grant-ability")).Resolve(world,journey,()=>true,_=>{}); Assert.That(world.Snapshot().decisions.Single().fallbackReason,Is.EqualTo("invalid_local_response")); Assert.That(world.ClueVisible,Is.True); Assert.That(journey.Snapshot().abilities,Is.Empty); }
        [UnityTest] public IEnumerator DelayedResultRevalidatesInvalidatedRegion() { var client=new FakeClient(mutate:()=>world.SetRegionalThreat(false,world.Snapshot().facts.First().id,journey)); yield return new WorldDecisionCoordinator(client).Resolve(world,journey,()=>true,_=>{}); Assert.That(world.Snapshot().decisions,Is.Empty); Assert.That(world.ClueVisible,Is.False); }
        [UnityTest] public IEnumerator ReplacementSessionDiscardsResult() { bool applied=true; yield return new WorldDecisionCoordinator(new FakeClient()).Resolve(world,journey,()=>false,value=>applied=value); Assert.That(applied,Is.False); Assert.That(world.Snapshot().decisions,Is.Empty); }
        [UnityTest] public IEnumerator DeterministicModeUsesNoTransportAndRecordsStableSelection() { yield return new WorldDecisionCoordinator(new WorldDecisionClient(DecisionMode.Deterministic,"http://127.0.0.1:1/v1/decisions/evaluate")).Resolve(world,journey,()=>true,_=>{}); Assert.That(world.Snapshot().decisions.Single().fallback,Is.False); Assert.That(world.Snapshot().opportunities.Single().id,Is.EqualTo(WorldEventContent.Tracks)); }
    }
}
