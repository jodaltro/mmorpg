using System.Collections;
using System.Linq;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using EventType = Mmorpg.Domain.EventType;

namespace Mmorpg.Tests
{
    public sealed class JourneySceneTests
    {
        private JourneySession journey;
        private OfflineAuthority authority;
        private MemoryJourneyPersistence store;
        [UnitySetUp] public IEnumerator Load()
        {
            Application.runInBackground=true; store=new MemoryJourneyPersistence(); JourneySession.PersistenceFactory=()=>store;
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity");
            journey=Object.FindAnyObjectByType<JourneySession>(); authority=Object.FindAnyObjectByType<OfflineAuthority>();
            journey.Player.GetComponent<PlayerController>().enabled=false; journey.Wolf.GetComponent<WolfBrain>().enabled=false; yield return null;
        }
        [TearDown] public void Cleanup() => JourneySession.PersistenceFactory=null;
        private void Place(Vector2 player,Vector2 wolf)
        {
            journey.Player.transform.position=player; journey.Player.GetComponent<Rigidbody2D>().position=player;
            journey.Wolf.transform.position=wolf; journey.Wolf.GetComponent<Rigidbody2D>().position=wolf; Physics2D.SyncTransforms();
        }
        private bool Interact(InteractionKind kind)
        {
            var item=journey.Interactions.Single(i=>i.Kind==kind);
            journey.Player.transform.position=item.transform.position; journey.Player.GetComponent<Rigidbody2D>().position=item.transform.position; Physics2D.SyncTransforms();
            return journey.RequestInteraction(item);
        }
        private IEnumerator Defeat()
        {
            Place(Vector2.zero,new Vector2(0.8f,0));
            for(int i=0;i<3&&journey.Wolf.State.IsAlive;i++) { Assert.That(authority.RequestAttack(journey.Player,Vector2.right),Is.True); yield return new WaitForSeconds(0.45f); }
            Assert.That(journey.Wolf.State.IsAlive,Is.False); yield return null;
        }
        [UnityTest] public IEnumerator ActualCombatProducesFactThenSampleDeliveryUnlocksAndPersists()
        {
            Assert.That(journey.RequestWeakness(),Is.False);
            Assert.That(Interact(InteractionKind.Sample),Is.False);
            Place(Vector2.zero,new Vector2(0.8f,0)); authority.RequestAttack(journey.Player,Vector2.left); yield return new WaitForSeconds(0.45f);
            Assert.That(journey.Engine.Snapshot().facts,Is.Empty);
            yield return Defeat();
            Assert.That(journey.Engine.Snapshot().facts.Count(e=>e.eventType==EventType.CreatureDefeated),Is.EqualTo(1));
            Assert.That(Interact(InteractionKind.Sample),Is.True); Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.False);
            Assert.That(Interact(InteractionKind.Mira),Is.True); Assert.That(Interact(InteractionKind.Mira),Is.True); Assert.That(Interact(InteractionKind.Mira),Is.False);
            Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);
            Assert.That(JourneyEngine.Restore(store.Load()).HasAbility(ForestContent.Technique),Is.True);
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null;
            journey=Object.FindAnyObjectByType<JourneySession>(); Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True); Assert.That(journey.Wolf.State.IsAlive,Is.False);
        }
        [UnityTest] public IEnumerator TracksAndOrinThenRealCombatCompleteObservationRoute()
        {
            Assert.That(Interact(InteractionKind.Trace),Is.True); Assert.That(journey.Engine.Knows(ForestContent.Orin,ForestContent.Trace),Is.False);
            Assert.That(Interact(InteractionKind.Orin),Is.True); Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.False);
            yield return Defeat(); Assert.That(journey.Engine.Status(ForestContent.RouteB),Is.EqualTo(OpportunityStatus.Completed)); Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);
        }
        [UnityTest] public IEnumerator SecondRouteAfterMiraOffersNewEncounterAndTrustWithoutDuplicateTechnique()
        {
            yield return Defeat(); Interact(InteractionKind.Sample); Interact(InteractionKind.Mira); Interact(InteractionKind.Mira);
            Interact(InteractionKind.Trace); Interact(InteractionKind.Orin);
            Assert.That(journey.CurrentEncounter,Is.EqualTo(JourneySession.ObservationEncounter));
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null;
            journey=Object.FindAnyObjectByType<JourneySession>(); authority=Object.FindAnyObjectByType<OfflineAuthority>();
            journey.Player.GetComponent<PlayerController>().enabled=false; journey.Wolf.GetComponent<WolfBrain>().enabled=false;
            Assert.That(journey.Wolf.State.IsAlive,Is.True); yield return Defeat();
            Assert.That(journey.Engine.Snapshot().abilities.Count,Is.EqualTo(1)); Assert.That(journey.Engine.Knows(ForestContent.Orin,ForestContent.RouteB),Is.True);
            Assert.That(journey.Engine.Snapshot().relations.Single(r=>r.npcId==ForestContent.Orin).trust,Is.EqualTo(1));
        }
        [UnityTest] public IEnumerator LearnedMarkAppliesBonusOnSuccessfulHitOnlyAndWallsBlockActivation()
        {
            yield return Defeat(); Interact(InteractionKind.Sample); Interact(InteractionKind.Mira); Interact(InteractionKind.Mira); Interact(InteractionKind.Trace); Interact(InteractionKind.Orin);
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null;
            journey=Object.FindAnyObjectByType<JourneySession>(); authority=Object.FindAnyObjectByType<OfflineAuthority>();
            journey.Player.GetComponent<PlayerController>().enabled=false; journey.Wolf.GetComponent<WolfBrain>().enabled=false;
            Place(new Vector2(0,-2.2f),new Vector2(0,-3.1f)); Assert.That(journey.RequestWeakness(),Is.False);
            Place(Vector2.zero,new Vector2(0.8f,0));
            var keyboard=InputSystem.AddDevice<Keyboard>();
            try { InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.Q)); yield return null; yield return null; Assert.That(journey.Weakness.Marked(Time.timeAsDouble),Is.EqualTo(journey.CurrentEncounter)); InputSystem.QueueStateEvent(keyboard,new KeyboardState()); yield return null; }
            finally { InputSystem.RemoveDevice(keyboard); }
            authority.RequestAttack(journey.Player,Vector2.left); Assert.That(journey.Weakness.Bonus(journey.CurrentEncounter,Time.timeAsDouble),Is.EqualTo(10)); yield return new WaitForSeconds(0.45f);
            authority.RequestAttack(journey.Player,Vector2.right); Assert.That(journey.Wolf.State.Health,Is.EqualTo(30)); Assert.That(journey.Weakness.Bonus(journey.CurrentEncounter,Time.timeAsDouble),Is.Zero);
            yield return new WaitForSeconds(0.45f); authority.RequestAttack(journey.Player,Vector2.right); Assert.That(journey.Wolf.State.Health,Is.EqualTo(10));
            Assert.That(journey.RequestWeakness(),Is.False);
        }
        [UnityTest] public IEnumerator KeyboardInteractsOpensJournalAndNewJourneyResetsPersistentMemory()
        {
            var keyboard=InputSystem.AddDevice<Keyboard>();
            try
            {
                var trace=journey.Interactions.Single(i=>i.Kind==InteractionKind.Trace); Place(trace.transform.position,new Vector2(8,0));
                InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.E,Key.Tab)); yield return null; yield return null;
                Assert.That(journey.Engine.HasTrace,Is.True); Assert.That(Object.FindAnyObjectByType<JourneyHud>().JournalOpen,Is.True);
                InputSystem.QueueStateEvent(keyboard,new KeyboardState()); yield return null;
                InputSystem.QueueStateEvent(keyboard,new KeyboardState(Key.N)); yield return null; yield return null; yield return null;
                var restored=Object.FindAnyObjectByType<JourneySession>(); Assert.That(restored.Engine.Snapshot().facts,Is.Empty); Assert.That(store.Load().facts,Is.Empty);
            }
            finally { InputSystem.RemoveDevice(keyboard); }
        }
        [UnityTest] public IEnumerator DistanceCannotFabricateInteraction()
        {
            var trace=journey.Interactions.Single(i=>i.Kind==InteractionKind.Trace); Place(new Vector2(-9,0),new Vector2(8,0)); Assert.That(journey.RequestInteraction(trace),Is.False);
            yield return null; Assert.That(journey.Engine.Snapshot().facts,Is.Empty);
        }
        [UnityTest] public IEnumerator TrainingDummyAcceptsLearnedTechniqueAndRecoversWithoutStoryRewards()
        {
            var dummy=Object.FindAnyObjectByType<TrainingDummy>(); Assert.That(dummy,Is.Not.Null);
            Place((Vector2)dummy.transform.position+Vector2.left*0.8f,new Vector2(8,0));
            Assert.That(journey.RequestWeakness(),Is.False);
            Interact(InteractionKind.Trace); Interact(InteractionKind.Orin); yield return Defeat();
            Place((Vector2)dummy.transform.position+Vector2.left*0.8f,new Vector2(8,0));
            int facts=journey.Engine.Snapshot().facts.Count;
            Assert.That(journey.RequestWeakness(),Is.True); Assert.That(journey.Weakness.Marked(Time.timeAsDouble),Is.EqualTo(TrainingDummy.TargetId));
            authority.RequestAttack(journey.Player,Vector2.right); Assert.That(dummy.Health.State.Health,Is.EqualTo(70)); Assert.That(dummy.LastDamage,Is.EqualTo(30));
            yield return new WaitForSeconds(0.45f); authority.RequestAttack(journey.Player,Vector2.right); Assert.That(dummy.LastDamage,Is.EqualTo(20));
            for(int i=0;i<3;i++) { yield return new WaitForSeconds(0.45f); authority.RequestAttack(journey.Player,Vector2.right); }
            Assert.That(dummy.Health.State.IsAlive,Is.False);
            yield return new WaitForSeconds(2.1f); Assert.That(dummy.Health.State.Health,Is.EqualTo(100)); Assert.That(dummy.GetComponent<Rigidbody2D>().simulated,Is.True);
            Assert.That(journey.Engine.Snapshot().facts.Count,Is.EqualTo(facts)); Assert.That(journey.Engine.Snapshot().abilities.Count,Is.EqualTo(1));
        }
    }
}
