using System;
using System.Collections;
using System.Collections.Generic;
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
using UnityEngine.TestTools;

namespace Mmorpg.Tests
{
    public sealed class OnlineAuthorityTests
    {
        private static string Token(string access,string refresh="test-refresh") => "{\"access_token\":\""+access+"\",\"refresh_token\":\""+refresh+"\",\"expires_in\":3600,\"token_type\":\"bearer\"}";
        [SetUp] public void Setup() { Application.runInBackground=true; }
        [UnityTest] public IEnumerator AuthRefreshRetriesSameIntentAndNeverPersistsTokens()
        {
            using(var mock=new MockServer(new[]{(200,Token("test-access-1")),(401,"{}"),(200,Token("test-access-2","test-refresh-2")),(200,"{\"version\":1,\"revision\":1}")}))
            {
                var session=new SupabaseSession(mock.Endpoint,"sb_publishable_test"); bool signed=false;
                yield return session.SignIn("fixture@example.invalid","fixture-password",ok=>signed=ok); Assert.That(signed,Is.True);
                var client=new OnlineAuthorityClient(mock.Endpoint,session); OnlineAuthorityResult result=null;
                string request=Guid.NewGuid().ToString();
                yield return client.Intent(Guid.NewGuid().ToString(),0,"attack","test-encounter",request,r=>result=r);
                Assert.That(result.Success,Is.True); Assert.That(mock.Requests.Count,Is.EqualTo(4));
                Assert.That(mock.Requests[1].body,Is.EqualTo(mock.Requests[3].body));
                Assert.That(mock.Requests[1].body,Does.Contain(request).And.Not.Contain("damage").And.Not.Contain("reward").And.Not.Contain("ownerId"));
                Assert.That(mock.Requests[1].headers,Does.Contain("test-access-1")); Assert.That(mock.Requests[3].headers,Does.Contain("test-access-2"));
                Assert.That(mock.Requests[2].headers,Does.Contain("grant_type=refresh_token")); Assert.That(mock.Requests[2].body,Does.Contain("test-refresh"));
                string path=Path.Combine(Path.GetTempPath(),"mmorpg-online-save-"+Guid.NewGuid()+".json");
                try { new JsonJourneyPersistence(path).Save(new JourneyEngine().Snapshot()); Assert.That(File.ReadAllText(path),Does.Not.Contain("test-access").And.Not.Contain("test-refresh")); }
                finally { File.Delete(path); }
                session.Clear(); Assert.That(session.HasSession,Is.False);
            }
        }
        [UnityTest] public IEnumerator FailedRefreshExpiresSessionWithoutRewardFallback()
        {
            using(var mock=new MockServer(new[]{(200,Token("test-access")),(401,"{}"),(400,"{}")}))
            {
                var session=new SupabaseSession(mock.Endpoint,"sb_publishable_test");yield return session.SignIn("a@example.invalid","fixture-password",_=>{});
                OnlineAuthorityResult result=null;yield return new OnlineAuthorityClient(mock.Endpoint,session).ReadCharacter(Guid.NewGuid().ToString(),r=>result=r);
                Assert.That(session.HasSession,Is.False); Assert.That(result.Status,Is.EqualTo(401)); Assert.That(result.Json,Is.Null); Assert.That(mock.Requests.Count,Is.EqualTo(3));
            }
        }
        [UnityTest] public IEnumerator BackendUnavailableDoesNotWriteOfflineJourney()
        {
            var engine=new JourneyEngine();var memory=new MemoryJourneyPersistence();memory.Save(engine.Snapshot());
            using(var mock=new MockServer(new[]{(200,Token("test-access")),(503,"{\"error\":\"storage_unavailable\"}")}))
            {
                var session=new SupabaseSession(mock.Endpoint,"sb_publishable_test");yield return session.SignIn("a@example.invalid","fixture-password",_=>{});
                OnlineAuthorityResult result=null;yield return new OnlineAuthorityClient(mock.Endpoint,session).CreateCharacter("marco05-dev","fixture",r=>result=r);
                Assert.That(result.Success,Is.False);Assert.That(result.Json,Is.Null);Assert.That(memory.Load().facts,Is.Empty);Assert.That(memory.Load().abilities,Is.Empty);Assert.That(mock.Requests.Count,Is.EqualTo(2));
            }
        }
        [UnityTest] public IEnumerator ClearedSessionDiscardsInFlightSignIn()
        {
            using(var mock=new MockServer(new[]{(200,Token("test-access"))},200))
            {
                var session=new SupabaseSession(mock.Endpoint,"sb_publishable_test"); bool result=true;
                var auth=session.SignIn("a@example.invalid","fixture-password",ok=>result=ok);
                Assert.That(auth.MoveNext(),Is.True);var token=(IEnumerator)auth.Current;Assert.That(token.MoveNext(),Is.True);
                session.Clear();yield return token.Current;
                while(token.MoveNext()) yield return token.Current;
                while(auth.MoveNext()) yield return auth.Current;
                Assert.That(result,Is.False);Assert.That(session.HasSession,Is.False);
            }
        }
        [UnityTest] public IEnumerator NoSessionMakesNoBackendRequest()
        {
            using(var mock=new MockServer(new[]{(200,"{}")}))
            {
                var session=new SupabaseSession(mock.Endpoint,"sb_publishable_test");OnlineAuthorityResult result=null;
                yield return new OnlineAuthorityClient(mock.Endpoint,session).CreateCharacter("marco05-dev","fixture",r=>result=r);
                Assert.That(result.Status,Is.EqualTo(401));Assert.That(mock.Requests,Is.Empty);
            }
        }
        private sealed class MockServer : IDisposable
        {
            private readonly TcpListener listener;
            private TcpClient active;
            public readonly List<(string headers,string body)> Requests=new List<(string,string)>();
            public string Endpoint { get; }
            public MockServer((int status,string body)[] replies,int delay=0)
            {
                listener=new TcpListener(IPAddress.Loopback,0);listener.Start();Endpoint="http://127.0.0.1:"+((IPEndPoint)listener.LocalEndpoint).Port;
                _=Task.Run(async()=>{
                    try
                    {
                        foreach(var reply in replies)
                        {
                            active=await listener.AcceptTcpClientAsync();
                            using(active) using(var stream=active.GetStream())
                            {
                                var bytes=new List<byte>();int b;
                                while((b=stream.ReadByte())>=0) {bytes.Add((byte)b);int n=bytes.Count;if(n>=4&&bytes[n-4]==13&&bytes[n-3]==10&&bytes[n-2]==13&&bytes[n-1]==10)break;}
                                string headers=Encoding.ASCII.GetString(bytes.ToArray());string contentLength=headers.Split(new[]{"\r\n"},StringSplitOptions.RemoveEmptyEntries).FirstOrDefault(l=>l.StartsWith("Content-Length:",StringComparison.OrdinalIgnoreCase));
                                int length=contentLength==null?0:int.Parse(contentLength.Split(':')[1]);byte[] payload=new byte[length];int read=0;
                                while(read<length) {int count=await stream.ReadAsync(payload,read,length-read);if(count==0)throw new IOException();read+=count;}
                                Requests.Add((headers,Encoding.UTF8.GetString(payload)));if(delay>0)await Task.Delay(delay);
                                payload=Encoding.UTF8.GetBytes(reply.body);byte[] prefix=Encoding.ASCII.GetBytes("HTTP/1.1 "+reply.status+" Test\r\nContent-Type: application/json\r\nContent-Length: "+payload.Length+"\r\nConnection: close\r\n\r\n");
                                await stream.WriteAsync(prefix,0,prefix.Length);await stream.WriteAsync(payload,0,payload.Length);
                            }
                        }
                    }
                    catch(Exception ex) when(ex is IOException||ex is SocketException||ex is ObjectDisposedException||ex is InvalidOperationException) { }
                });
            }
            public void Dispose() {listener.Stop();active?.Close();}
        }
    }
}
