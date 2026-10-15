using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    // Unity physics is an offline adapter. Go must eventually own equivalent spatial checks.
    public sealed class OfflineAuthority : MonoBehaviour
    {
        [SerializeField] private LayerMask obstacles = 1 << 8;
        [SerializeField] private SwordSwing sword;
        [SerializeField, Min(.34f)] private float swordCooldown = .4f;
        public float SwordCooldown => swordCooldown;
        public void ConfigureSword(SwordSwing value) => sword = value;
        public bool SwordBusy => sword != null && sword.Busy;
        public bool HasSword => sword != null;
        public bool BeginSword(ActorHealth actor, Vector2 facing, float range, ActionStrike strike, float windup)
            => sword != null && sword.Begin(actor, facing, range, strike, windup);
        internal void NotifySwordAttack(ActorHealth actor, Vector2 facing) => AttackPerformed?.Invoke(actor, facing);
        public event System.Action<ActorHealth, Vector2> AttackPerformed;
        public event System.Action<ActorHealth, ActorHealth> HitConfirmed;
        public event System.Action<ActorHealth, ActorHealth, string> PreparedAttackDodged;
        [SerializeField] private ActionCombat actionCombat;
        public void ConfigureAction(ActionCombat value) => actionCombat = value;
        [SerializeField] private ExplorationWorld exploration;
        public void ConfigureExploration(ExplorationWorld world)=>exploration=world;
        public bool IsSafePosition(Vector2 position)=>exploration!=null && exploration.IsSafePosition(position);
        public bool ActionMode => actionCombat != null;
        private sealed class PreparedStrike { public Vector2 facing; public double readyAt, expiresAt; public string id; }
        private readonly System.Collections.Generic.Dictionary<ActorHealth,PreparedStrike> prepared=new System.Collections.Generic.Dictionary<ActorHealth,PreparedStrike>();
        public bool PrepareWolfAttack(ActorHealth attacker,Vector2 facing)
        {
            if(journey==null||attacker!=journey.Wolf||!attacker.State.IsAlive||!journey.Player.State.IsAlive||Vector2.Distance(attacker.transform.position,journey.Player.transform.position)>CombatRules.WolfRange||!HasLineOfSight(attacker.transform.position,journey.Player.transform.position)) return false;
            prepared[attacker]=new PreparedStrike{facing=ActionMode?facing.normalized:ActorMotor.Cardinal(facing),readyAt=Time.timeAsDouble+0.35,expiresAt=Time.timeAsDouble+0.85,id=System.Guid.NewGuid().ToString("N")}; return true;
        }
        public bool ReleasePreparedAttack(ActorHealth attacker)
        {
            if(!prepared.TryGetValue(attacker,out var strike)||Time.timeAsDouble<strike.readyAt) return false;
            prepared.Remove(attacker);
            return Time.timeAsDouble<=strike.expiresAt&&Attack(attacker,strike.facing,strike.id);
        }
        [SerializeField] private JourneySession journey;
        public void ConfigureJourney(JourneySession value) => journey=value;

        public bool RequestDodge(ActorHealth actor)
        {
            return actor.Faction == Faction.Player && actor.State.TryDodge(Time.timeAsDouble, CombatRules.DodgeDuration, CombatRules.DodgeCooldown);
        }

        public bool RequestAttack(ActorHealth attacker, Vector2 facing) => Attack(attacker,facing,null);
        private bool Attack(ActorHealth attacker, Vector2 facing,string preparedId)
        {
            facing = ActionMode ? facing.normalized : ActorMotor.Cardinal(facing);
            if (facing == Vector2.zero) return false;
            double now = Time.timeAsDouble;
            bool player = attacker.Faction == Faction.Player;
            if (player && SwordBusy) return false;
            if (!attacker.State.TryAttack(now, player ? sword != null ? swordCooldown : CombatRules.AttackCooldown : CombatRules.WolfCooldown)) return false;
            float range = player ? CombatRules.AttackRange : CombatRules.WolfRange;
            ResolveMelee(attacker, facing, range, player ? ActionStrike.Basic : ActionStrike.Wolf, preparedId);
            return true;
        }
        internal void ResolveMelee(ActorHealth attacker, Vector2 facing, float range, ActionStrike strike, string preparedId = null)
        {
            if (!attacker.State.IsAlive || facing.sqrMagnitude < 0.001f) return;
            if (attacker.Faction == Faction.Player && sword != null)
            { sword.Begin(attacker, facing, range, strike, .06f); return; }
            double now = Time.timeAsDouble;
            facing = facing.normalized;
            var timer = System.Diagnostics.Stopwatch.StartNew();
            AttackPerformed?.Invoke(attacker, facing);
            foreach (var hit in Physics2D.OverlapCircleAll(attacker.transform.position, range, 1 << 9))
            {
                var target = hit.GetComponent<ActorHealth>();
                if (target == null || target == attacker || target.Faction == attacker.Faction || !target.State.IsAlive) continue;
                Vector2 delta = target.transform.position - attacker.transform.position;
                // Cone is evaluated from centers; walls always block melee.
                if (delta.magnitude > range || (delta.sqrMagnitude > 0.01f && Vector2.Dot(facing, delta.normalized) < 0.45f)) continue;
                if (Physics2D.Raycast(attacker.transform.position, delta.normalized, delta.magnitude, obstacles).collider != null) continue;
                ResolveDamage(attacker, target, strike, preparedId);
            }
            timer.Stop(); ActionMetrics.Active?.RecordCombat(timer.Elapsed.TotalMilliseconds, 0);
        }
        internal bool ResolveDamage(ActorHealth attacker, ActorHealth target, ActionStrike strike, string preparedId = null)
        {
            if (attacker == null || target == null || !attacker.State.IsAlive || !target.State.IsAlive || attacker.Faction == target.Faction) return false;
            if (target.Faction!=Faction.Training && attacker.Faction!=Faction.Training && (IsSafePosition(target.transform.position) || IsSafePosition(attacker.transform.position))) return false;
            double now = Time.timeAsDouble;
            if (target.State.IsDodging(now))
            {
                if (preparedId != null) { PreparedAttackDodged?.Invoke(attacker, target, preparedId); actionCombat?.ConfirmDefense(attacker); }
                return false;
            }
            int bonus = journey == null ? 0 : journey.AttackBonus(attacker, target, now);
            var creature = target.GetComponent<SpatialCreatureBrain>();
            bool exposed = bonus > 0 || actionCombat != null && actionCombat.MarkedTarget == target;
            int damage = ActionMode ? ActionCombatRules.Damage(strike, creature != null && creature.Kind == CreatureKind.Golem, exposed) : attacker.Faction == Faction.Player ? CombatRules.PlayerDamage : CombatRules.WolfDamage;
            damage += bonus + (actionCombat == null ? 0 : actionCombat.Bonus(attacker, target));
            if (!target.ApplyDamage(damage, now)) return false;
            journey?.ConfirmAttackBonus(attacker, target, now);
            actionCombat?.ConfirmHit(attacker, target);
            HitConfirmed?.Invoke(attacker, target);
            return true;
        }
        internal void ResolveArea(ActorHealth attacker, Vector2 center, float radius)
        {
            foreach (var hit in Physics2D.OverlapCircleAll(center, radius, 1 << 9))
            {
                var target = hit.GetComponent<ActorHealth>();
                if (target != null && Vector2.Distance(target.transform.position, center) <= radius && HasLineOfSight(center, target.transform.position))
                    ResolveDamage(attacker, target, ActionStrike.Golem, "golem-impact");
            }
            // This area was aimed at the player at windup. An active physical dodge
            // can leave the circle before impact; it is still a real avoided attack.
            if(actionCombat!=null && journey.Player.State.IsDodging(Time.timeAsDouble) &&
                Vector2.Distance(journey.Player.transform.position,center)<=radius+CombatRules.DodgeSpeed*(float)CombatRules.DodgeDuration &&
                HasLineOfSight(center,journey.Player.transform.position)) actionCombat.ConfirmDefense(attacker);
        }

        public bool HasLineOfSight(Vector2 from, Vector2 to, Collider2D destination = null)
        {
            Vector2 delta = to - from;
            var hit = Physics2D.Raycast(from, delta.normalized, delta.magnitude, obstacles).collider;
            return hit == null || destination != null && hit == destination;
        }
    }
}
