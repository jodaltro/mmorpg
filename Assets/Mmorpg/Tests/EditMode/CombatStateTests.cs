using Mmorpg.Domain;
using Mmorpg.Runtime;
using NUnit.Framework;
using UnityEngine;

namespace Mmorpg.Tests
{
    public sealed class CombatStateTests
    {
        [Test] public void DamageClampsAndDeathRejectsActions()
        {
            var actor = new CombatState(100);
            Assert.That(actor.TryDamage(150,0,0),Is.True);
            Assert.That(actor.Health,Is.Zero);
            Assert.That(actor.TryAttack(1,0.4),Is.False);
            Assert.That(actor.TryDodge(1,0.2,0.9),Is.False);
            Assert.That(actor.TryDamage(1,1,0),Is.False);
        }
        [Test] public void DodgeProtectsOnlyDuringItsWindowAndHasCooldown()
        {
            var actor = new CombatState(100);
            Assert.That(actor.TryDodge(0,0.22,0.9),Is.True);
            Assert.That(actor.TryDamage(15,0.1,0.35),Is.False);
            Assert.That(actor.TryAttack(0.1,0.4),Is.False);
            Assert.That(actor.TryDamage(15,0.22,0.35),Is.True);
            Assert.That(actor.TryDodge(0.5,0.22,0.9),Is.False);
            Assert.That(actor.TryDodge(0.9,0.22,0.9),Is.True);
        }
        [Test] public void CooldownAndDamageImmunityExpireAtBoundary()
        {
            var actor = new CombatState(100);
            Assert.That(actor.TryAttack(0,0.4),Is.True);
            Assert.That(actor.TryAttack(0.39,0.4),Is.False);
            Assert.That(actor.TryAttack(0.4,0.4),Is.True);
            Assert.That(actor.TryDamage(15,0,0.35),Is.True);
            Assert.That(actor.TryDamage(15,0.34,0.35),Is.False);
            Assert.That(actor.TryDamage(15,0.35,0.35),Is.True);
            Assert.That(actor.Health,Is.EqualTo(70));
        }
        [Test] public void InvalidDamageAndClockDoNotMutateHealth()
        {
            var actor = new CombatState(100);
            Assert.That(actor.TryDamage(-20,0,0),Is.False);
            Assert.That(actor.TryDamage(20,double.NaN,0),Is.False);
            Assert.That(actor.TryAttack(double.PositiveInfinity,0.4),Is.False);
            Assert.That(actor.Health,Is.EqualTo(100));
        }
        [Test] public void DiagonalIntentIsConvertedToOneCardinalDirection()
        {
            Assert.That(ActorMotor.Cardinal(new Vector2(1,1)),Is.EqualTo(Vector2.up));
            Assert.That(ActorMotor.Cardinal(new Vector2(-2,1)),Is.EqualTo(Vector2.left));
            Assert.That(ActorMotor.Cardinal(Vector2.zero),Is.EqualTo(Vector2.zero));
        }
    }
}
