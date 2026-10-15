using System;
using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public enum Faction { Player, Wolf, Training }

    public sealed class ActorHealth : MonoBehaviour
    {
        [SerializeField] private Faction faction;
        public Faction Faction => faction;
        public CombatState State { get; private set; }
        public event Action Changed;
        public event Action Died;

        private void Awake() => ResetState();
        public void Configure(Faction value) { faction = value; ResetState(); }
        private void ResetState() => State = new CombatState(faction == Faction.Wolf ? CombatRules.WolfHealth : CombatRules.PlayerHealth);
        internal void RestoreTrainingHealth()
        {
            if(faction!=Faction.Training) return;
            ResetState();
            var body=GetComponent<Rigidbody2D>(); if(body!=null) body.simulated=true;
            Changed?.Invoke();
        }
        // Restore a world consequence without producing a new combat event.
        internal void RestoreDefeated() => ApplyDamage(State.MaximumHealth, Time.timeAsDouble);

        // Only the authority adapter calls this after spatial validation.
        internal bool ApplyDamage(int damage, double now)
        {
            if (!State.TryDamage(damage, now, CombatRules.DamageImmunity)) return false;
            Changed?.Invoke();
            if (!State.IsAlive)
            {
                var body = GetComponent<Rigidbody2D>();
                if (body != null) { if(body.bodyType!=RigidbodyType2D.Static) body.linearVelocity = Vector2.zero; body.simulated = false; }
                Died?.Invoke();
            }
            return true;
        }
    }
}
