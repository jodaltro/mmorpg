using System.Collections;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace Mmorpg.Tests
{
    public sealed class WorldSceneTests
    {
        private MemoryJourneyPersistence store;
        private JourneySession journey;
        private OfflineAuthority authority;
        private SimulatedWorldClock clock;
        [UnitySetUp] public IEnumerator Setup() {
            Application.runInBackground=true; store=new MemoryJourneyPersistence(); JourneySession.PersistenceFactory=()=>store;
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null;
            Bind(); clock=new SimulatedWorldClock(); journey.WorldEvents.Initialize(journey.CaptureSnapshot(),clock);
        }
        private void Bind() { journey=Object.FindAnyObjectByType<JourneySession>(); authority=Object.FindAnyObjectByType<OfflineAuthority>(); journey.Player.GetComponent<PlayerController>().enabled=false; journey.Wolf.GetComponent<WolfBrain>().enabled=false; }
        [UnityTearDown] public IEnumerator Teardown() { JourneySession.PersistenceFactory=null; yield return null; }
        private void Place(Vector2 player,Vector2 wolf) { journey.Player.transform.position=player; journey.Player.GetComponent<Rigidbody2D>().position=player; journey.Wolf.transform.position=wolf; journey.Wolf.GetComponent<Rigidbody2D>().position=wolf; Physics2D.SyncTransforms(); }
        private bool Interact(InteractionKind kind) { var item=journey.Interactions.Single(i=>i.Kind==kind); Place(item.transform.position,new Vector2(8,0)); return journey.RequestInteraction(item); }
        private IEnumerator Defeat() { Place(Vector2.zero,new Vector2(0.8f,0)); for(int i=0;i<3;i++) { Assert.That(authority.RequestAttack(journey.Player,Vector2.right),Is.True); yield return new WaitForSeconds(0.45f); } }
        private IEnumerator DodgePrepared() { Place(Vector2.zero,new Vector2(0.8f,0)); Assert.That(authority.PrepareWolfAttack(journey.Wolf,Vector2.left),Is.True); yield return new WaitForSeconds(0.37f); Assert.That(authority.RequestDodge(journey.Player),Is.True); Assert.That(authority.ReleasePreparedAttack(journey.Wolf),Is.True); yield return null; }
        [UnityTest] public IEnumerator AlertHasRealSourceWaitsThenSurvivesSceneReload() {
            Assert.That(journey.WorldEvents.World.NoticePublished,Is.False); Interact(InteractionKind.NoticeBoard); Assert.That(journey.Message,Does.Contain("nenhum aviso"));
            yield return Defeat(); Assert.That(Interact(InteractionKind.Sample),Is.True); Interact(InteractionKind.Mira); Assert.That(Interact(InteractionKind.Mira),Is.True); yield return null; yield return null;
            Assert.That(store.Load().world.scheduled.Count,Is.EqualTo(1)); clock.Advance(15000); journey.WorldEvents.OnJourneyChanged();
            Assert.That(journey.WorldEvents.World.NoticePublished,Is.True); Interact(InteractionKind.NoticeBoard); Assert.That(journey.Message,Does.Contain("Mira confirmou"));
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null; Bind();
            Assert.That(journey.WorldEvents.World.NoticePublished,Is.True); Assert.That(journey.WorldEvents.World.Snapshot().scheduled.Count(s=>s.executed),Is.EqualTo(1)); Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);
        }
        [UnityTest] public IEnumerator NewThreatRequiresInteractiveClueThenOrinAndPreservesRouteB() {
            var clue=journey.Interactions.Single(i=>i.Kind==InteractionKind.NewTracks); Place(clue.transform.position,new Vector2(8,0)); Assert.That(journey.RequestInteraction(clue),Is.False);
            Interact(InteractionKind.Trace); Interact(InteractionKind.Orin); yield return Defeat(); yield return null; yield return null;
            Assert.That(clue.GetComponent<SpriteRenderer>().enabled,Is.True); Assert.That(journey.WorldEvents.World.Journal(),Does.Not.Contain("Rastros de uma"));
            Interact(InteractionKind.Orin); Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Tracks),Is.EqualTo(WorldOpportunityStatus.Hidden));
            Assert.That(Interact(InteractionKind.NewTracks),Is.True); Assert.That(Interact(InteractionKind.Orin),Is.True); yield return null;
            Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Tracks),Is.EqualTo(WorldOpportunityStatus.Completed)); Assert.That(journey.Message,Does.Contain("novos vestígios")); Assert.That(journey.Engine.Status(ForestContent.RouteB),Is.EqualTo(OpportunityStatus.Completed)); Assert.That(journey.Engine.Snapshot().abilities.Count,Is.EqualTo(1));
        }
        [UnityTest] public IEnumerator PreparedDodgeAndOptInTrainingRequireActualCombatWithoutAbilityReward() {
            yield return DodgePrepared(); Assert.That(journey.Player.State.Health,Is.EqualTo(100)); Assert.That(journey.Engine.Snapshot().inputs.Count(e=>e.eventType==Mmorpg.Domain.EventType.CombatActionVerified),Is.EqualTo(1)); Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Training),Is.Null);
            Interact(InteractionKind.Orin); yield return null; yield return null; Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Training),Is.EqualTo(WorldOpportunityStatus.Discovered));
            Interact(InteractionKind.Orin); Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Training),Is.EqualTo(WorldOpportunityStatus.Started));
            yield return new WaitForSeconds(0.23f);
            var dummy=Object.FindAnyObjectByType<TrainingDummy>(); Place((Vector2)dummy.transform.position+Vector2.left*0.8f,new Vector2(8,0)); Assert.That(authority.RequestAttack(journey.Player,Vector2.right),Is.True); yield return null;
            Assert.That(journey.WorldEvents.World.Status(WorldEventContent.Training),Is.EqualTo(WorldOpportunityStatus.Completed)); Assert.That(journey.Engine.Snapshot().abilities,Is.Empty); Assert.That(store.Load().world.opportunities.Single().status,Is.EqualTo(WorldOpportunityStatus.Completed));
        }
        [UnityTest] public IEnumerator OrdinaryAttackAndDodgeOutsideRangeCannotFabricatePreparedDodge() {
            Place(Vector2.zero,new Vector2(0.8f,0)); authority.RequestDodge(journey.Player); authority.RequestAttack(journey.Wolf,Vector2.left); yield return new WaitForSeconds(0.95f);
            Assert.That(journey.Engine.Snapshot().inputs,Is.Empty); Assert.That(authority.PrepareWolfAttack(journey.Wolf,Vector2.left),Is.True); Place(new Vector2(-2,0),new Vector2(0.8f,0)); yield return new WaitForSeconds(0.37f);
            authority.RequestDodge(journey.Player); authority.ReleasePreparedAttack(journey.Wolf); yield return null; Assert.That(journey.Engine.Snapshot().inputs,Is.Empty); Assert.That(journey.WorldEvents.World.PendingEvaluation(),Is.Null);
        }
        [UnityTest] public IEnumerator SceneWorldContinuesWithBackendOffAndPendingSaveReload() {
            var listener=new TcpListener(IPAddress.Loopback,0); listener.Start(); int port=((IPEndPoint)listener.LocalEndpoint).Port; listener.Stop();
            journey.WorldEvents.ConfigureDecisions(DecisionMode.OpenRouter,"http://127.0.0.1:"+port+"/v1/decisions/evaluate",1);
            Interact(InteractionKind.Trace); yield return Defeat();
            double deadline=Time.realtimeSinceStartupAsDouble+4; while(journey.WorldEvents.DecisionPending&&Time.realtimeSinceStartupAsDouble<deadline) yield return null;
            Assert.That(journey.WorldEvents.DecisionPending,Is.False); var saved=store.Load(); Assert.That(saved.world.decisions.Single().fallback,Is.True); Assert.That(saved.world.opportunities.Single().id,Is.EqualTo(WorldEventContent.Tracks));
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null; Bind(); Assert.That(journey.WorldEvents.World.ClueVisible,Is.True); Assert.That(store.Load().world.decisions.Count,Is.EqualTo(1));
        }
        [UnityTest] public IEnumerator ExpiredClueIsUnavailableAndNewJourneyCannotRestoreOldWorld() {
            Interact(InteractionKind.Trace); yield return Defeat(); yield return null; clock.Advance(900000); journey.WorldEvents.OnJourneyChanged(); Assert.That(journey.WorldEvents.World.ClueVisible,Is.False);
            Assert.That(Interact(InteractionKind.NewTracks),Is.False); journey.NewJourney(); yield return null; yield return null; yield return null; Bind(); Assert.That(journey.Engine.Snapshot().facts,Is.Empty); Assert.That(journey.WorldEvents.World.Snapshot().facts,Is.Empty); Assert.That(store.Load().world?.opportunities??new System.Collections.Generic.List<WorldOpportunity>(),Is.Empty);
        }
    }
}
