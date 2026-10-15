using System.Collections;
using System.Linq;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace Mmorpg.Tests
{
    public sealed class ExpandedWorldTests
    {
        [UnityTest] public IEnumerator FiveRegionTransitionsKeepExactlyOneAreaVisible()
        {
            Application.runInBackground=true;
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/Marco05World.unity");
            var view=Object.FindFirstObjectByType<WorldJourneyView>();Assert.That(view,Is.Not.Null);
            foreach(var pair in new[]{("valdoria","Valdoria"),("gray-forest","Floresta Cinzenta"),("kharum","Minas de Kharum"),("echo-marsh","Pântano dos Ecos"),("asterion","Ruínas de Asterion")})
            {view.PresentJson("{\"regionId\":\""+pair.Item1+"\",\"journey\":{\"encounter\":null}}");yield return null;Assert.That(view.CurrentRegion,Is.EqualTo(pair.Item1));Assert.That(SceneManager.GetActiveScene().GetRootGameObjects().Count(x=>x.activeSelf&&new[]{"Valdoria","Floresta Cinzenta","Minas de Kharum","Pântano dos Ecos","Ruínas de Asterion"}.Contains(x.name)),Is.EqualTo(1));Assert.That(GameObject.Find(pair.Item2),Is.Not.Null);}
        }
        [UnityTest] public IEnumerator LoginFormUsesPasswordMaskAndAuthoritativeSession()
        {
            yield return SceneManager.LoadSceneAsync("Assets/Mmorpg/Scenes/Marco05World.unity");
            var session=Object.FindFirstObjectByType<WorldJourneySession>();Assert.That(session,Is.Not.Null);Assert.That(Object.FindFirstObjectByType<WorldJourneyHud>(),Is.Not.Null);
            var field=GameObject.Find("Password").GetComponent<TMPro.TMP_InputField>();Assert.That(field.contentType,Is.EqualTo(TMPro.TMP_InputField.ContentType.Password));
            Assert.That(Object.FindObjectsByType<JourneySession>(FindObjectsSortMode.None),Is.Empty);
            Assert.That(session.StateJson,Is.Null);session.SignOut();Assert.That(session.StateJson,Is.Null);
        }
        [UnityTest] public IEnumerator MissingPublicConfigurationFailsWithoutLocalRewards()
        {
            var go=new GameObject("Configuration test");var session=go.AddComponent<WorldJourneySession>();session.Configure("http://127.0.0.1:1","","",null,null);
            yield return session.Connect("fixture@example.invalid","fixture-password","Test");
            Assert.That(session.Busy,Is.False);Assert.That(session.StateJson,Is.Null);Assert.That(session.Message,Does.Contain("Configure"));Object.Destroy(go);
        }
    }
}
