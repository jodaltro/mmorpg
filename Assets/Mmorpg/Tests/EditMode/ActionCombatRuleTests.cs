using Mmorpg.Domain;
using NUnit.Framework;
using Mmorpg.Runtime;
namespace Mmorpg.Tests
{
    public sealed class ActionCombatRuleTests
    {
        [Test] public void GolemResistanceAndTechniqueVulnerabilityDiffer()
        {
            Assert.That(ActionCombatRules.Damage(ActionStrike.Basic,true,false),Is.EqualTo(6));
            Assert.That(ActionCombatRules.Damage(ActionStrike.Heavy,true,false),Is.EqualTo(22));
            Assert.That(ActionCombatRules.Damage(ActionStrike.Basic,true,true),Is.EqualTo(20));
            Assert.That(ActionCombatRules.Damage(ActionStrike.Counter,true,false),Is.EqualTo(30));
        }
        [Test] public void ActionQueuedDiskSaveFlushesAndRestoresExistingFormat()
        {
            var path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"m06-save-"+System.Guid.NewGuid().ToString("N"),"journey.json");
            var disk=new JsonJourneyPersistence(path);var queue=new QueuedJourneyPersistence(disk);var engine=new JourneyEngine();
            for(int i=0;i<30;i++)queue.Save(engine.Snapshot());queue.Flush();
            Assert.That(System.IO.File.Exists(path),Is.True);Assert.That(queue.Load().actorId,Is.EqualTo(engine.Snapshot().actorId));
            Assert.That(disk.Load().facts,Is.Empty);
        }
    }
}
