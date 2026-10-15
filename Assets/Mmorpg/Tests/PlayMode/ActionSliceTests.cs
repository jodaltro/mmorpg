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
using EventType=Mmorpg.Domain.EventType;
namespace Mmorpg.Tests
{
    public sealed class ActionSliceTests
    {
        private GameSession game;
        private JourneySession journey;
        private OfflineAuthority authority;
        private ActionCombat combat;
        private Keyboard keyboard;
        private Mouse mouse;
        [UnitySetUp] public IEnumerator Load()
        {
            Application.runInBackground=true;Time.timeScale=1;
            JourneySession.PersistenceFactory=()=>new MemoryJourneyPersistence();
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");yield return null;
            game=Object.FindAnyObjectByType<GameSession>();journey=Object.FindAnyObjectByType<JourneySession>();authority=Object.FindAnyObjectByType<OfflineAuthority>();combat=game.Player.GetComponent<ActionCombat>();
            game.Wolf.GetComponent<WolfBrain>().enabled=false;
            foreach(var brain in Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None))brain.enabled=false;
            keyboard=InputSystem.AddDevice<Keyboard>();mouse=InputSystem.AddDevice<Mouse>();
        }
        [TearDown] public void Clean() {Time.timeScale=1;JourneySession.PersistenceFactory=null;if(keyboard!=null)InputSystem.RemoveDevice(keyboard);if(mouse!=null)InputSystem.RemoveDevice(mouse);}
        private void Place(ActorHealth actor,Vector2 p) {actor.transform.position=p;actor.GetComponent<Rigidbody2D>().position=p;actor.GetComponent<Rigidbody2D>().linearVelocity=Vector2.zero;actor.GetComponent<ActorMotor>().SetIntent(Vector2.zero,0);if(actor==game.Player)Camera.main.transform.position=new Vector3(p.x,p.y,-10);Physics2D.SyncTransforms();}
        private void Keys(params Key[] keys)=>InputSystem.QueueStateEvent(keyboard,new KeyboardState(keys));
        private void Click(Vector2 target,bool heavy=false)
        {
            var screen=Camera.main.WorldToScreenPoint(target);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=screen,buttons=(ushort)(heavy?2:1)});
        }
        private IEnumerator Release() {Keys();InputSystem.QueueStateEvent(mouse,new MouseState{position=mouse.position.ReadValue()});yield return new WaitForSeconds(.43f);}
        [UnityTest] public IEnumerator InputMovesDiagonallyAndObstacleBlocksActualBody()
        {
            Place(game.Player,new Vector2(-7,-1));Keys(Key.W,Key.D);yield return new WaitForSeconds(.25f);
            var p=game.Player.GetComponent<Rigidbody2D>().position;Assert.That(p.x,Is.GreaterThan(-6.6));Assert.That(p.y,Is.GreaterThan(-.6));
            Assert.That(game.Player.GetComponent<Rigidbody2D>().linearVelocity.magnitude,Is.LessThanOrEqualTo(3.51));
            Place(game.Player,new Vector2(-6,2));Keys(Key.A);yield return new WaitForSeconds(.6f);
            Assert.That(game.Player.transform.position.x,Is.GreaterThan(-2f-10)); // boundary remains physical
            Place(game.Player,new Vector2(-1,3));Keys(Key.D);yield return new WaitForSeconds(.6f);
            Assert.That(game.Player.GetComponent<Rigidbody2D>().position.x,Is.LessThan(-.6));
        }
        [UnityTest] public IEnumerator MouseDirectionRangeMissAndHeavyWindupUseRealInput()
        {
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));
            Click(new Vector2(0,0));yield return null;yield return null;Assert.That(game.Wolf.State.Health,Is.EqualTo(60));
            yield return Release();Click(new Vector2(8,0));yield return null;yield return null;Assert.That(game.Wolf.State.Health,Is.EqualTo(40));
            yield return Release();Place(game.Wolf,new Vector2(4,0));Click(new Vector2(8,0));yield return null;yield return null;Assert.That(game.Wolf.State.Health,Is.EqualTo(40));
            yield return Release();Place(game.Wolf,new Vector2(3,0));Click(new Vector2(8,0),true);yield return null;yield return null;
            Assert.That(combat.Committed,Is.True);Assert.That(game.Wolf.State.Health,Is.EqualTo(40));
            Assert.That(combat.RequestHeavy(Vector2.right),Is.False);yield return new WaitForSeconds(.42f);Assert.That(game.Wolf.State.Health,Is.EqualTo(4));
        }
        [UnityTest] public IEnumerator SameFrameMouseAimOrientsStationaryDodgeImmediately()
        {
            Place(game.Player,new Vector2(2,0));game.Player.GetComponent<ActorMotor>().Aim(Vector2.left);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=Camera.main.WorldToScreenPoint(new Vector2(8,0))});Keys(Key.Space);
            yield return null;yield return new WaitForFixedUpdate();
            Assert.That(game.Player.State.IsDodging(Time.timeAsDouble),Is.True);Assert.That(game.Player.GetComponent<Rigidbody2D>().linearVelocity.x,Is.GreaterThan(8));
        }
        [UnityTest] public IEnumerator LockedSkillsAndWeaknessConsumeOnlyOnAcceptedPhysicalHit()
        {
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));Assert.That(combat.MarkUnlocked,Is.False);Assert.That(journey.RequestWeakness(),Is.False);
            combat.ConfigureIsolatedAbilityTest(true);Keys(Key.Q);yield return null;yield return null;Assert.That(journey.IsWeaknessMarked(game.Wolf),Is.True);
            Click(new Vector2(0,0));yield return null;yield return null;Assert.That(journey.IsWeaknessMarked(game.Wolf),Is.True);
            yield return Release();Click(new Vector2(8,0));yield return null;yield return null;Assert.That(game.Wolf.State.Health,Is.EqualTo(30));Assert.That(journey.IsWeaknessMarked(game.Wolf),Is.False);
            Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.False,"Test mode never grants a saved ability");
        }
        [UnityTest] public IEnumerator PreparedHitDodgeConfirmsCounterAndCounterExpires()
        {
            game.Player.GetComponent<PlayerController>().enabled=false;
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.8f,0));
            Assert.That(authority.PrepareWolfAttack(game.Wolf,Vector2.left),Is.True);yield return new WaitForSeconds(.36f);
            Assert.That(authority.RequestDodge(game.Player),Is.True);Assert.That(authority.ReleasePreparedAttack(game.Wolf),Is.True);Assert.That(game.Player.State.Health,Is.EqualTo(100));
            Assert.That(journey.Engine.Snapshot().facts.Count(f=>f.eventType==EventType.CombatActionVerified),Is.EqualTo(1));
            combat.ConfigureIsolatedAbilityTest(true);yield return new WaitForSeconds(.24f);
            Assert.That(combat.RequestCounter(Vector2.right),Is.True);Assert.That(game.Wolf.State.Health,Is.EqualTo(30));Assert.That(combat.RequestCounter(Vector2.right),Is.False);
            yield return new WaitForSeconds(3.1f);Assert.That(combat.RequestCounter(Vector2.right),Is.False,"No fresh verified defense");
        }
        [UnityTest] public IEnumerator WolfPhysicallyPatrolsPursuesPreparesAndCharges()
        {
            var brain=game.Wolf.GetComponent<WolfBrain>();brain.enabled=true;
            Place(game.Player,new Vector2(-8,-1));Place(game.Wolf,new Vector2(4,0));yield return new WaitForSeconds(.3f);Assert.That(brain.Mode,Is.EqualTo(WolfMode.Patrol));
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(4,0));yield return new WaitForSeconds(.1f);Assert.That(brain.Mode,Is.EqualTo(WolfMode.Chase));
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));yield return new WaitForSeconds(.1f);Assert.That(brain.Mode,Is.EqualTo(WolfMode.Windup));
            yield return new WaitForSeconds(.3f);Assert.That(brain.Mode,Is.EqualTo(WolfMode.Charge));yield return new WaitForSeconds(.18f);Assert.That(game.Player.State.Health,Is.LessThan(100));
        }
        [UnityTest] public IEnumerator SpiderAiLaunchesPhysicalProjectileAndRealPoisonExpires()
        {
            var brain=Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None).Single(b=>b.Kind==CreatureKind.Spider);
            var spider=brain.GetComponent<ActorHealth>();Place(game.Player,new Vector2(6,-4));Place(spider,new Vector2(9,-4));brain.enabled=true;
            yield return new WaitForSeconds(.1f);Assert.That(brain.Mode,Is.EqualTo(CreatureMode.Windup));
            yield return new WaitForSeconds(.6f);Assert.That(Object.FindAnyObjectByType<PoisonProjectile>(),Is.Not.Null);brain.enabled=false;
            yield return new WaitForSeconds(.6f);Assert.That(game.Player.GetComponent<PoisonStatus>()?.Active,Is.True);int before=game.Player.State.Health;
            yield return new WaitForSeconds(1.1f);Assert.That(game.Player.State.Health,Is.LessThan(before));yield return new WaitForSeconds(3.3f);Assert.That(game.Player.GetComponent<PoisonStatus>().Active,Is.False);
        }
        [UnityTest] public IEnumerator ProjectileCanBeAvoidedByMovingInPhysics()
        {
            var brain=Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None).Single(b=>b.Kind==CreatureKind.Spider);
            Place(game.Player,new Vector2(6,-4));Place(brain.GetComponent<ActorHealth>(),new Vector2(9,-4));brain.enabled=true;
            yield return new WaitForSeconds(.6f);Keys(Key.W);yield return new WaitForSeconds(.7f);brain.enabled=false;
            Assert.That(game.Player.State.Health,Is.EqualTo(100));Assert.That(game.Player.GetComponent<PoisonStatus>(),Is.Null);
        }
        [UnityTest] public IEnumerator GolemTelegraphCanMissAndHunterMarkExposesArmor()
        {
            var brain=Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None).Single(b=>b.Kind==CreatureKind.Golem);
            var golem=brain.GetComponent<ActorHealth>();Place(game.Player,new Vector2(6,4));Place(golem,new Vector2(7.8f,4));brain.enabled=true;
            yield return new WaitForSeconds(.1f);Assert.That(brain.Mode,Is.EqualTo(CreatureMode.Windup));Keys(Key.W);yield return new WaitForSeconds(.9f);Assert.That(game.Player.State.Health,Is.EqualTo(100));brain.enabled=false;Keys();
            Place(game.Player,new Vector2(6,4));Place(golem,new Vector2(6.9f,4));authority.RequestAttack(game.Player,Vector2.right);Assert.That(golem.State.Health,Is.EqualTo(54));
            combat.ConfigureIsolatedAbilityTest(true);Keys(Key.C);yield return null;yield return null;Assert.That(combat.MarkedTarget,Is.EqualTo(golem));
            yield return new WaitForSeconds(.43f);authority.RequestAttack(game.Player,Vector2.right);Assert.That(golem.State.Health,Is.EqualTo(29));Assert.That(combat.RequestHunterMark(),Is.False);
            yield return new WaitForSeconds(8.1f);Assert.That(combat.MarkedTarget,Is.Null);
        }
        [UnityTest] public IEnumerator GolemImpactDealsDamageInsideTelegraphedArea()
        {
            var brain=Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None).Single(b=>b.Kind==CreatureKind.Golem);
            Place(game.Player,new Vector2(6,4));Place(brain.GetComponent<ActorHealth>(),new Vector2(7.8f,4));brain.enabled=true;yield return new WaitForSeconds(.95f);Assert.That(game.Player.State.Health,Is.EqualTo(72));
        }
        [UnityTest] public IEnumerator PhysicalDodgeOutOfGolemImpactOpensRealCounterWindow()
        {
            var brain=Object.FindObjectsByType<SpatialCreatureBrain>(FindObjectsSortMode.None).Single(b=>b.Kind==CreatureKind.Golem);var golem=brain.GetComponent<ActorHealth>();
            Place(game.Player,new Vector2(6,4));Place(golem,new Vector2(7.8f,4));combat.ConfigureIsolatedAbilityTest(true);brain.enabled=true;
            yield return new WaitForSeconds(.65f);Keys(Key.W,Key.Space);yield return new WaitForSeconds(.22f);Keys();
            Assert.That(game.Player.State.Health,Is.EqualTo(100));brain.enabled=false;yield return new WaitForSeconds(.1f);
            Place(game.Player,(Vector2)golem.transform.position+Vector2.left*.8f);
            Assert.That(combat.RequestCounter(Vector2.right),Is.True);Assert.That(golem.State.Health,Is.EqualTo(30));
        }
        [UnityTest] public IEnumerator ActualDefeatProximityCollectionDeliverySaveAndServicesAbsent()
        {
            // These adapters are absent: scene cannot submit combat/rewards to HTTP.
            Assert.That(Object.FindAnyObjectByType<WorldJourneySession>(),Is.Null);
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));
            for(int i=0;i<3;i++){Click(new Vector2(8,0));yield return null;yield return null;yield return Release();}
            Assert.That(game.Wolf.State.IsAlive,Is.False);Assert.That(game.Wolf.GetComponent<Rigidbody2D>().simulated,Is.False);Assert.That(journey.Engine.Defeated(JourneySession.Encounter),Is.True);
            var sample=journey.Interactions.Single(i=>i.Kind==InteractionKind.Sample);Place(game.Player,sample.transform.position);Keys(Key.E);yield return null;yield return null;Assert.That(journey.Engine.HasSample,Is.True);Assert.That(journey.RequestInteraction(sample),Is.False);
            var mira=journey.Interactions.Single(i=>i.Kind==InteractionKind.Mira);Assert.That(journey.RequestInteraction(mira),Is.False);Place(game.Player,(Vector2)mira.transform.position+Vector2.down*.8f);
            Keys();yield return null;Keys(Key.E);yield return null;yield return null;Keys();yield return null;Keys(Key.E);yield return null;yield return null;
            Assert.That(journey.Engine.HasSample,Is.False);Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);journey.Save();int count=journey.Engine.Snapshot().facts.Count;journey.Continue();yield return null;
            Assert.That(journey.Engine.Snapshot().facts.Count,Is.EqualTo(count));Assert.That(Object.FindAnyObjectByType<ActionMetrics>().NetworkOperations,Is.Zero);
        }
        [UnityTest] public IEnumerator EightDirectionWalkingCrossesGateAndReturnsWithoutTravelCommand()
        {
            Place(game.Player,new Vector2(-8,0));Keys(Key.D);yield return new WaitForSeconds(3.4f);Assert.That(game.Player.GetComponent<Rigidbody2D>().position.x,Is.GreaterThan(2));Keys(Key.A);yield return new WaitForSeconds(3.4f);Assert.That(game.Player.GetComponent<Rigidbody2D>().position.x,Is.LessThan(-7));
        }
        [UnityTest] public IEnumerator DelayedNarrativeHttpDoesNotBlockPhysicalInputAndRevalidates()
        {
            var probe=new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback,0);probe.Start();int port=((System.Net.IPEndPoint)probe.LocalEndpoint).Port;probe.Stop();
            using(var server=new System.Net.HttpListener())
            {
                server.Prefixes.Add("http://127.0.0.1:"+port+"/");server.Start();
                var delayed=System.Threading.Tasks.Task.Run(async()=>{
                    try {var context=await server.GetContextAsync();await System.Threading.Tasks.Task.Delay(1500);var bytes=System.Text.Encoding.UTF8.GetBytes("{}");context.Response.ContentType="application/json";context.Response.ContentLength64=bytes.Length;await context.Response.OutputStream.WriteAsync(bytes,0,bytes.Length);context.Response.Close();}
                    catch(System.Exception) { /* Listener teardown is allowed after timeout. */ }
                });
                journey.ConfigureDecisions(DecisionMode.OpenRouter,"http://127.0.0.1:"+port+"/v1/decisions/evaluate",3);
                Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));
                for(int i=0;i<3;i++){authority.RequestAttack(game.Player,Vector2.right);yield return new WaitForSeconds(.43f);}
                var sample=journey.Interactions.Single(i=>i.Kind==InteractionKind.Sample);Place(game.Player,sample.transform.position);Assert.That(journey.RequestInteraction(sample),Is.True);
                var mira=journey.Interactions.Single(i=>i.Kind==InteractionKind.Mira);Place(game.Player,(Vector2)mira.transform.position+Vector2.down*.8f);journey.RequestInteraction(mira);journey.RequestInteraction(mira);yield return null;
                Assert.That(journey.DecisionPending,Is.True);
                var trace=journey.Interactions.Single(i=>i.Kind==InteractionKind.Trace);Place(game.Player,trace.transform.position);journey.RequestInteraction(trace); // Revision changes while request is in flight.
                Place(game.Player,new Vector2(2,0));int frame=Time.frameCount;Keys(Key.D);yield return new WaitForSeconds(.25f);Keys();Click(new Vector2(8,0),true);yield return null;yield return null;
                Assert.That(game.Player.GetComponent<Rigidbody2D>().position.x,Is.GreaterThan(2.5));Assert.That(combat.Committed,Is.True);Assert.That(Time.frameCount,Is.GreaterThan(frame+2));
                double deadline=Time.realtimeSinceStartupAsDouble+5;while(journey.DecisionPending&&Time.realtimeSinceStartupAsDouble<deadline)yield return null;
                Assert.That(journey.DecisionPending,Is.False);Assert.That(journey.Engine.Snapshot().decisions.Single().fallback,Is.True);Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);
                server.Stop();
            }
        }
        [UnityTest] public IEnumerator MissingGoAndOpenRouterUseFallbackWhileInputKeepsMoving()
        {
            var probe=new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback,0);probe.Start();int port=((System.Net.IPEndPoint)probe.LocalEndpoint).Port;probe.Stop();
            journey.ConfigureDecisions(DecisionMode.OpenRouter,"http://127.0.0.1:"+port+"/v1/decisions/evaluate",1);
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));
            for(int i=0;i<3;i++){Click(new Vector2(8,0));yield return null;yield return null;yield return Release();}
            var sample=journey.Interactions.Single(i=>i.Kind==InteractionKind.Sample);Place(game.Player,sample.transform.position);Assert.That(journey.RequestInteraction(sample),Is.True);
            var mira=journey.Interactions.Single(i=>i.Kind==InteractionKind.Mira);Place(game.Player,(Vector2)mira.transform.position+Vector2.down*.8f);journey.RequestInteraction(mira);journey.RequestInteraction(mira);
            Place(game.Player,new Vector2(-7,0));Keys(Key.D);yield return new WaitForSeconds(.3f);Keys();Assert.That(game.Player.GetComponent<Rigidbody2D>().position.x,Is.GreaterThan(-6.4));
            double deadline=Time.realtimeSinceStartupAsDouble+3;while(journey.DecisionPending&&Time.realtimeSinceStartupAsDouble<deadline)yield return null;
            Assert.That(journey.DecisionPending,Is.False);Assert.That(journey.Engine.Snapshot().decisions.Single().fallback,Is.True);Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.True);Assert.That(Object.FindAnyObjectByType<ActionMetrics>().NetworkOperations,Is.EqualTo(1));
        }
        private sealed class SlowStorage : IJourneyPersistence
        {
            private readonly MemoryJourneyPersistence memory=new MemoryJourneyPersistence();
            private readonly int mainThread=System.Threading.Thread.CurrentThread.ManagedThreadId;
            public bool WorkerWrite;
            public void Save(JourneySnapshot state) {WorkerWrite|=System.Threading.Thread.CurrentThread.ManagedThreadId!=mainThread;System.Threading.Thread.Sleep(150);memory.Save(state);}
            public JourneySnapshot Load()=>memory.Load();
        }
        [UnityTest] public IEnumerator ImmediateSceneReloadWaitsForLastConfirmedFactOnSlowStorage()
        {
            var storage=new SlowStorage();JourneySession.PersistenceFactory=()=>new QueuedJourneyPersistence(storage);
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");yield return null;
            game=Object.FindAnyObjectByType<GameSession>();authority=Object.FindAnyObjectByType<OfflineAuthority>();
            game.Wolf.GetComponent<WolfBrain>().enabled=false;game.Player.GetComponent<PlayerController>().enabled=false;
            foreach(var brain in Object.FindObjectsByType<SpatialCreatureBrain>())brain.enabled=false;
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.9f,0));
            for(int i=0;i<2;i++){authority.RequestAttack(game.Player,Vector2.right);yield return new WaitForSeconds(.43f);}
            authority.RequestAttack(game.Player,Vector2.right);Assert.That(game.Wolf.State.IsAlive,Is.False);
            SceneManager.LoadScene("Assets/Mmorpg/Scenes/ActionVerticalSlice.unity");yield return null;yield return null;
            var restored=Object.FindAnyObjectByType<JourneySession>();
            Assert.That(restored.Engine.Defeated(JourneySession.Encounter),Is.True);Assert.That(restored.Wolf.State.IsAlive,Is.False);Assert.That(storage.WorkerWrite,Is.True);
        }
        [UnityTest] public IEnumerator NormalTechniqueUnlocksRequireConfirmedTrackingAndDefenseAndSurviveSave()
        {
            Assert.That(combat.TestMode,Is.False);Assert.That(combat.MarkUnlocked,Is.False);Assert.That(combat.CounterUnlocked,Is.False);
            var trace=journey.Interactions.Single(i=>i.Kind==InteractionKind.Trace);Place(game.Player,trace.transform.position);Keys(Key.E);yield return null;yield return null;Keys();yield return null;
            Assert.That(journey.Engine.HasTrace,Is.True);Assert.That(combat.MarkUnlocked,Is.False,"Private tracking was not shared");
            var orin=journey.Interactions.Single(i=>i.Kind==InteractionKind.Orin);Place(game.Player,(Vector2)orin.transform.position+Vector2.down*.8f);Keys(Key.E);yield return null;yield return null;Keys();yield return null;
            Assert.That(combat.MarkUnlocked,Is.True);Assert.That(combat.CounterUnlocked,Is.False);Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.False);
            Place(game.Player,new Vector2(2,0));Place(game.Wolf,new Vector2(2.8f,0));
            InputSystem.QueueStateEvent(mouse,new MouseState{position=Camera.main.WorldToScreenPoint(new Vector2(8,0))});Keys(Key.C);yield return null;yield return null;Keys();
            Assert.That(combat.MarkedTarget,Is.EqualTo(game.Wolf));Assert.That(authority.PrepareWolfAttack(game.Wolf,Vector2.left),Is.True);yield return new WaitForSeconds(.36f);
            Assert.That(authority.RequestDodge(game.Player),Is.True);Assert.That(authority.ReleasePreparedAttack(game.Wolf),Is.True);yield return new WaitForSeconds(.24f);
            Assert.That(combat.CounterUnlocked,Is.True);Keys(Key.F);yield return null;yield return null;Keys();Assert.That(game.Wolf.State.Health,Is.EqualTo(25)); // 30 counter + 5 hunter mark.
            journey.Save();journey.Continue();yield return null;
            Assert.That(combat.MarkUnlocked,Is.True);Assert.That(combat.CounterUnlocked,Is.True);Assert.That(journey.Engine.HasAbility(ForestContent.Technique),Is.False);Assert.That(combat.TestMode,Is.False);
        }
    }
}
