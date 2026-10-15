using System;

namespace Mmorpg.Domain
{
    // Time is supplied by the authority, never read from an engine or client clock.
    public sealed class CombatState
    {
        public int MaximumHealth { get; }
        public int Health { get; private set; }
        public bool IsAlive => Health > 0;
        public double DodgeUntil { get; private set; } = double.NegativeInfinity;
        private double nextAttack = double.NegativeInfinity;
        private double nextDodge = double.NegativeInfinity;
        private double nextDamage = double.NegativeInfinity;

        public CombatState(int maximumHealth)
        {
            if (maximumHealth <= 0) throw new ArgumentOutOfRangeException(nameof(maximumHealth));
            MaximumHealth = maximumHealth;
            Health = maximumHealth;
        }

        public bool IsDodging(double now) => IsAlive && now < DodgeUntil;
        public double AttackRemaining(double now) => Math.Max(0, nextAttack-now);
        public double DodgeRemaining(double now) => Math.Max(0, nextDodge-now);

        public bool TryAttack(double now, double cooldown)
        {
            if (!ValidTime(now) || cooldown < 0 || !IsAlive || IsDodging(now) || now < nextAttack) return false;
            nextAttack = now + cooldown;
            return true;
        }

        public bool TryDodge(double now, double duration, double cooldown)
        {
            if (!ValidTime(now) || duration <= 0 || cooldown < duration || !IsAlive || now < nextDodge) return false;
            DodgeUntil = now + duration;
            nextDodge = now + cooldown;
            return true;
        }

        public bool TryDamage(int amount, double now, double immunity)
        {
            if (!ValidTime(now) || amount <= 0 || immunity < 0 || !IsAlive || IsDodging(now) || now < nextDamage) return false;
            Health = Math.Max(0, Health - amount);
            nextDamage = now + immunity;
            return true;
        }

        private static bool ValidTime(double now) => !double.IsNaN(now) && !double.IsInfinity(now);
    }
}
