using System;
using System.Text;
using Mmorpg.Runtime;
using NUnit.Framework;

namespace Mmorpg.Tests
{
    public sealed class OnlineConfigurationTests
    {
        [TestCase("http://evil.invalid")]
        [TestCase("https://user:password@example.com")]
        [TestCase("https://example.com?token=x")]
        [TestCase("https://example.com/auth/v1")]
        [TestCase("https://example.com#token")]
        public void RejectsCredentialBearingOrUnsafeEndpoints(string endpoint)
        { Assert.Throws<ArgumentException>(()=>new SupabaseSession(endpoint,"sb_publishable_test")); }
        [Test] public void RejectsSecretAndServiceRoleKeys()
        {
            string payload=Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"role\":\"service_role\"}")).TrimEnd('=').Replace('+','-').Replace('/','_');
            foreach(string key in new[]{"sb_secret_fake","x."+payload+".x","not-a-key",""}) Assert.Throws<ArgumentException>(()=>new SupabaseSession("https://example.com",key));
        }
        [Test] public void RequiresCharacterIdentityAndStableIntentId()
        {
            var session=new SupabaseSession("http://127.0.0.1:54321","sb_publishable_test");
            var client=new OnlineAuthorityClient("http://127.0.0.1:8093",session);
            Assert.Throws<ArgumentException>(()=>client.ReadCharacter("player",_=>{}));
            Assert.Throws<ArgumentException>(()=>client.Intent(Guid.NewGuid().ToString(),0,"attack","wolf","",_=>{}));
            Assert.That(session.HasSession,Is.False);
        }
    }
}
