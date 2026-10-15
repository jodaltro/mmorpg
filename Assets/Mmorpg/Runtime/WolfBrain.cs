using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    public enum WolfMode { Patrol, Chase, Windup, Recovery, Dead, Charge }

    [RequireComponent(typeof(ActorMotor), typeof(ActorHealth))]
    public sealed class WolfBrain : MonoBehaviour
    {
        [SerializeField] private ActorHealth player;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private Vector2[] patrolPoints;
        private ActorHealth health;
        private ActorMotor motor;
        private int patrolIndex;
        private double stateUntil;
        private Vector2 attackFacing;
        public WolfMode Mode { get; private set; }
        public void Configure(ActorHealth target, OfflineAuthority server, Vector2[] points) { player = target; authority = server; patrolPoints = points; }
        private void Awake() { health = GetComponent<ActorHealth>(); motor = GetComponent<ActorMotor>(); }
        private void Update()
        {
            if (!health.State.IsAlive) { Mode = WolfMode.Dead; motor.SetIntent(Vector2.zero, 0); return; }
            double now = Time.timeAsDouble;
            if (Mode == WolfMode.Charge)
            {
                motor.SetIntent(attackFacing, 5);
                if (now >= stateUntil) { authority.ReleasePreparedAttack(health); Mode=WolfMode.Recovery; stateUntil=now+.8; }
                return;
            }
            if (Mode == WolfMode.Windup)
            {
                motor.SetIntent(Vector2.zero, 0);
                if (now >= stateUntil) {
                    if(authority.ActionMode) { Mode=WolfMode.Charge;stateUntil=now+.12; }
                    else { authority.ReleasePreparedAttack(health); Mode = WolfMode.Recovery; stateUntil = now + 0.8; }
                }
                return;
            }
            if (Mode == WolfMode.Recovery && now < stateUntil) { motor.SetIntent(Vector2.zero, 0); return; }
            Vector2 delta = player.transform.position - transform.position;
            bool seesPlayer = player.State.IsAlive && !authority.IsSafePosition(player.transform.position) && delta.magnitude < 6f && authority.HasLineOfSight(transform.position, player.transform.position);
            if (seesPlayer && delta.magnitude <= CombatRules.WolfRange)
            {
                Mode = WolfMode.Windup; stateUntil = now + 0.35; attackFacing = authority.ActionMode?delta.normalized:ActorMotor.Cardinal(delta);
                authority.PrepareWolfAttack(health,attackFacing);
                motor.SetIntent(attackFacing, 0); return;
            }
            if (seesPlayer) { Mode = WolfMode.Chase; motor.SetIntent(delta, 2.4f); return; }
            Mode = WolfMode.Patrol;
            if (patrolPoints == null || patrolPoints.Length == 0) { motor.SetIntent(Vector2.zero, 0); return; }
            Vector2 toPoint = patrolPoints[patrolIndex] - (Vector2)transform.position;
            if (toPoint.magnitude < 0.2f) patrolIndex = (patrolIndex + 1) % patrolPoints.Length;
            motor.SetIntent(toPoint, 1.3f);
        }
    }
}
