using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using EventType=Mmorpg.Domain.EventType;

namespace Mmorpg.Tests
{
    public sealed class LocalDecisionTests
    {
        private JourneyEngine engine;
        private GameEvent Fact(EventType type,string source) => new GameEvent{eventId=Guid.NewGuid().ToString("N"),eventType=type,sourceId=source,actorId=ForestContent.Actor,worldId=ForestContent.World};
        [SetUp] public void Setup()
        {
            Application.runInBackground=true; engine=new JourneyEngine();
            var e=Fact(EventType.CreatureDefeated,"combat"); e.creature=new CreaturePayload{creatureId=ForestContent.Wolf,encounterId="wolf"}; engine.ApplyValidated(e);
            e=Fact(EventType.EvidenceCollected,"sample-drop"); e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="wolf"}; engine.ApplyValidated(e);
            e=Fact(EventType.EvidenceDelivered,ForestContent.Mira); e.evidence=new EvidencePayload{evidenceId=ForestContent.Sample,encounterId="wolf",recipientId=ForestContent.Mira}; engine.ApplyValidated(e);
        }
        private string Response(DecisionContext c,string selected,int version=1) =>
            "{\"version\":"+version+",\"eventId\":\""+c.eventId+"\",\"actorId\":\"player\",\"worldId\":\"offline-clearing\",\"stateVersion\":"+c.stateVersion+
            ",\"policyId\":\"mira-reaction-v1\",\"decisionId\":\"mock-decision\",\"model\":\"typesafe/jev-1.13\",\"provider\":\"TypeSafe\",\"selectedConsequence\":\""+selected+"\",\"latencyMs\":1}";
        [UnityTest] public IEnumerator LocalContractsRoundTripAndPredefinedDialogue()
        {
            var c=engine.PendingMiraDecision();
            using(var mock=new MockHTTP(Response(c,MiraReactions.Concern)))
            {
                bool applied=false;
                yield return new MiraDecisionOrchestrator(new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint)).Resolve(engine,()=>true,value=>applied=value);
                Assert.That(applied,Is.True); Assert.That(engine.Dialogue(ForestContent.Mira),Does.Contain("me preocupa"));
                Assert.That(mock.RequestBody,Does.Contain("\"eventId\":\""+c.eventId+"\""));
                Assert.That(mock.RequestBody,Does.Contain("\"eligibleConsequences\":["));
                Assert.That(mock.RequestBody,Does.Contain("\"stateVersion\":"+c.stateVersion));
                Assert.That(mock.RequestBody,Does.Not.Contain("API_KEY"));
            }
        }
        [UnityTest] public IEnumerator DeterministicModeNeverCallsHTTP()
        {
            using(var mock=new MockHTTP("{}"))
            {
                yield return new MiraDecisionOrchestrator(new LocalDecisionClient(DecisionMode.Deterministic,mock.Endpoint)).Resolve(engine,()=>true,_=>{});
                Assert.That(mock.RequestBody,Is.Null); Assert.That(engine.Snapshot().decisions.Single().fallback,Is.False);
            }
        }
        [UnityTest] public IEnumerator LowConfidenceFallbackAuditSurvivesLocalContractAndPersistence()
        {
            var c=engine.PendingMiraDecision();
            string body=Response(c,MiraReactions.Scientific).TrimEnd('}')+
                ",\"fallback\":true,\"fallbackReason\":\"low_confidence\",\"attempt\":{\"decisionId\":\"gen-dec-mock\",\"model\":\"typesafe/jev-1.13\",\"provider\":\"TypeSafe\",\"selectedConsequence\":\"mira-concern\",\"confidence\":0.1,\"probabilities\":{\"mira-scientific\":0.1,\"mira-concern\":0.7,\"mira-suspicion\":0.1,\"mira-neutral\":0.1},\"usage\":{\"input_tokens\":20,\"output_tokens\":10,\"cost\":0.000001}}}";
            using(var mock=new MockHTTP(body))
            {
                yield return new MiraDecisionOrchestrator(new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint)).Resolve(engine,()=>true,_=>{});
                var store=new MemoryJourneyPersistence();store.Save(engine.Snapshot());
                var decision=store.Load().decisions.Single();
                Assert.That(decision.fallbackReason,Is.EqualTo("low_confidence"));Assert.That(decision.selectedConsequence,Is.EqualTo(MiraReactions.Scientific));
                Assert.That(decision.attempt.selectedConsequence,Is.EqualTo(MiraReactions.Concern));
                Assert.That(decision.attempt.usage.cost,Is.EqualTo(0.000001));
                Assert.That(engine.Dialogue(ForestContent.Mira),Does.StartWith(MiraReactions.Text(MiraReactions.Scientific)));
            }
        }
        [UnityTest] public IEnumerator InvalidHTTPAndUnknownChoiceUseFallback()
        {
            var c=engine.PendingMiraDecision();
            using(var mock=new MockHTTP(Response(c,"invented-reward")))
            {
                yield return new MiraDecisionOrchestrator(new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint)).Resolve(engine,()=>true,_=>{});
                Assert.That(engine.Snapshot().decisions.Single().fallbackReason,Is.EqualTo("invalid_local_response"));
                Assert.That(engine.Snapshot().abilities,Is.EquivalentTo(new[]{ForestContent.Technique}));
            }
        }
        [UnityTest] public IEnumerator TimeoutAndInvalidStatusReturnDeterministic()
        {
            foreach(bool delay in new[]{false,true})
            {
                var c=engine.PendingMiraDecision(); DecisionRecord response=null;
                using(var mock=new MockHTTP("invalid",delay?200:502,delay?2200:0))
                {
                    yield return new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint,1).Evaluate(c,result=>response=result);
                    Assert.That(response.fallback,Is.True); Assert.That(response.selectedConsequence,Is.EqualTo(MiraReactions.Scientific));
                }
            }
        }
        [UnityTest] public IEnumerator DelayedOldResultDiscardedAfterStateChange()
        {
            var c=engine.PendingMiraDecision();
            using(var mock=new MockHTTP(Response(c,MiraReactions.Concern),200,150))
            {
                var e=Fact(EventType.TraceExamined,ForestContent.Trace); e.trace=new TracePayload{traceId=ForestContent.Trace};
                // Mutation happens after the orchestrator captured the request, at the callback boundary.
                var mutating=new MutatingClient(new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint),()=>engine.ApplyValidated(e));
                yield return new MiraDecisionOrchestrator(mutating).Resolve(engine,()=>true,_=>{});
                Assert.That(engine.Snapshot().decisions.Single().selectedConsequence,Is.EqualTo(MiraReactions.Scientific));
                Assert.That(engine.Snapshot().decisions.Single().fallbackReason,Is.EqualTo("state_changed"));
            }
        }
        [UnityTest] public IEnumerator ReplacedJourneyDoesNotApplyResponse()
        {
            var c=engine.PendingMiraDecision();
            using(var mock=new MockHTTP(Response(c,MiraReactions.Concern)))
            {
                yield return new MiraDecisionOrchestrator(new LocalDecisionClient(DecisionMode.OpenRouter,mock.Endpoint)).Resolve(engine,()=>false,_=>{});
                Assert.That(engine.Snapshot().decisions,Is.Empty);
            }
        }
        [UnityTest] public IEnumerator SceneWorksWithBackendOffAndJournalReflectsPersistedReaction()
        {
            var memory=new MemoryJourneyPersistence(); JourneySession.PersistenceFactory=()=>memory;
            try
            {
                yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity"); yield return null;
                var j=UnityEngine.Object.FindAnyObjectByType<JourneySession>(); var authority=UnityEngine.Object.FindAnyObjectByType<OfflineAuthority>();
                j.ConfigureDecisions(DecisionMode.OpenRouter,UnusedEndpoint(),1);
                j.Player.GetComponent<PlayerController>().enabled=false; j.Wolf.GetComponent<WolfBrain>().enabled=false;
                Place(j,Vector2.zero,new Vector2(0.8f,0));
                for(int i=0;i<3;i++){Assert.That(authority.RequestAttack(j.Player,Vector2.right),Is.True);yield return new WaitForSeconds(0.45f);}
                Interact(j,InteractionKind.Sample); Interact(j,InteractionKind.Mira); Interact(j,InteractionKind.Mira);
                double deadline=Time.realtimeSinceStartupAsDouble+5;
                while(j.DecisionPending&&Time.realtimeSinceStartupAsDouble<deadline) yield return null;
                Assert.That(j.DecisionPending,Is.False);
                var recorded=memory.Load().decisions.Single(); Assert.That(recorded.fallback,Is.True);
                Assert.That(j.Message,Does.StartWith(MiraReactions.Text(recorded.selectedConsequence)));
                var hud=UnityEngine.Object.FindAnyObjectByType<JourneyHud>(); if(!hud.JournalOpen)hud.ToggleJournal(); yield return null;
                var field=typeof(JourneyHud).GetField("journalText",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance);
                Assert.That(((TMPro.TMP_Text)field.GetValue(hud)).text,Does.Contain(MiraReactions.Text(recorded.selectedConsequence)));
                string dialogue=j.Engine.Dialogue(ForestContent.Mira); Interact(j,InteractionKind.Mira); yield return null;
                Assert.That(j.Engine.Snapshot().decisions.Count,Is.EqualTo(1)); Assert.That(j.Message,Is.EqualTo(dialogue));
                yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/OfflineClearing.unity");yield return null;
                j=UnityEngine.Object.FindAnyObjectByType<JourneySession>(); Assert.That(j.Engine.Dialogue(ForestContent.Mira),Is.EqualTo(dialogue));
                Assert.That(j.Engine.HasAbility(ForestContent.Technique),Is.True);
            }
            finally { JourneySession.PersistenceFactory=null; }
        }
        private static string UnusedEndpoint()
        {
            var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();int port=((IPEndPoint)listener.LocalEndpoint).Port;listener.Stop();
            return "http://127.0.0.1:"+port+"/v1/decisions/evaluate";
        }
        private static void Place(JourneySession j,Vector2 player,Vector2 wolf)
        { j.Player.transform.position=player;j.Player.GetComponent<Rigidbody2D>().position=player;j.Wolf.transform.position=wolf;j.Wolf.GetComponent<Rigidbody2D>().position=wolf;Physics2D.SyncTransforms(); }
        private static void Interact(JourneySession j,InteractionKind kind)
        {
            var target=j.Interactions.Single(i=>i.Kind==kind);j.Player.transform.position=target.transform.position;j.Player.GetComponent<Rigidbody2D>().position=target.transform.position;Physics2D.SyncTransforms();j.RequestInteraction(target);
        }
        private sealed class MutatingClient : ILocalDecisionClient
        {
            private readonly ILocalDecisionClient inner;private readonly Action mutate;
            public MutatingClient(ILocalDecisionClient inner,Action mutate){this.inner=inner;this.mutate=mutate;}
            public IEnumerator Evaluate(DecisionContext c,Action<DecisionRecord> done){yield return inner.Evaluate(c,value=>{mutate();done(value);});}
        }
        // Actual loopback HTTP, no API key and no paid calls. One request per fixture.
        private sealed class MockHTTP : IDisposable
        {
            private readonly TcpListener listener; private TcpClient active;
            public string Endpoint { get; }
            public volatile string RequestBody;
            public MockHTTP(string body,int status=200,int delayMs=0)
            {
                listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
                Endpoint="http://127.0.0.1:"+((IPEndPoint)listener.LocalEndpoint).Port+"/v1/decisions/evaluate";
                _=Task.Run(async()=>{
                    try
                    {
                        active=await listener.AcceptTcpClientAsync();
                        using(active)using(var stream=active.GetStream())
                        {
                            // Read exact bytes; StreamReader buffering must not consume part of the body.
                            var header=new System.Collections.Generic.List<byte>();int b;
                            while((b=stream.ReadByte())>=0)
                            {
                                header.Add((byte)b);int n=header.Count;
                                if(n>=4&&header[n-4]==13&&header[n-3]==10&&header[n-2]==13&&header[n-1]==10)break;
                            }
                            string headers=Encoding.ASCII.GetString(header.ToArray());
                            int length=int.Parse(headers.Split(new[]{"\r\n"},StringSplitOptions.RemoveEmptyEntries).Single(l=>l.StartsWith("Content-Length:",StringComparison.OrdinalIgnoreCase)).Split(':')[1]);
                            var bytes=new byte[length];int read=0;
                            while(read<length){int count=await stream.ReadAsync(bytes,read,length-read);if(count==0)throw new IOException();read+=count;}
                            RequestBody=Encoding.UTF8.GetString(bytes);
                            if(delayMs>0)await Task.Delay(delayMs);
                            bytes=Encoding.UTF8.GetBytes(body);
                            byte[] prefix=Encoding.ASCII.GetBytes("HTTP/1.1 "+status+" Test\r\nContent-Type: application/json\r\nContent-Length: "+bytes.Length+"\r\nConnection: close\r\n\r\n");
                            await stream.WriteAsync(prefix,0,prefix.Length);await stream.WriteAsync(bytes,0,bytes.Length);
                        }
                    }
                    catch(Exception ex) when(ex is IOException||ex is SocketException||ex is ObjectDisposedException||ex is InvalidOperationException) { }
                });
            }
            public void Dispose(){listener.Stop();active?.Close();}
        }
    }
}
