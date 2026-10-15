using UnityEngine;
namespace Mmorpg.Runtime
{
    public enum CreatureKind { Spider, Golem }
    public enum CreatureMode { Patrol, Pursuit, Windup, Recovery, Dead }
    [RequireComponent(typeof(ActorHealth), typeof(ActorMotor))]
    public sealed class SpatialCreatureBrain : MonoBehaviour
    {
        [SerializeField] private CreatureKind kind;
        [SerializeField] private ActorHealth player;
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private SpriteRenderer telegraph;
        [SerializeField, Min(1)] private float detectionRange=5;
        private ActorHealth health;
        private ActorMotor motor;
        private Vector2 home, aim, impact;
        private double until, staggerUntil;
        public CreatureKind Kind => kind;
        public CreatureMode Mode { get; private set; }
        public Vector2 ImpactCenter => impact;
        public void Configure(CreatureKind value, ActorHealth target, OfflineAuthority server, SpriteRenderer warning) { kind=value;player=target;authority=server;telegraph=warning; }
        private void Awake() { health=GetComponent<ActorHealth>();motor=GetComponent<ActorMotor>();home=transform.position; }
        public void ReactToHit() => staggerUntil=Time.timeAsDouble+.12;
        private void Update()
        {
            double now=Time.timeAsDouble;
            if(!health.State.IsAlive) { Mode=CreatureMode.Dead;telegraph.enabled=false;motor.SetIntent(Vector2.zero,0);return; }
            if(now<staggerUntil) {motor.SetIntent(Vector2.zero,0);return;}
            if(Mode==CreatureMode.Windup)
            {
                motor.SetIntent(Vector2.zero,0);
                if(now<until)return;
                telegraph.enabled=false;
                if(kind==CreatureKind.Spider) PoisonProjectile.Spawn(authority,health,(Vector2)transform.position+aim*.65f,aim,telegraph.sprite,telegraph.sharedMaterial);
                else authority.ResolveArea(health,impact,1.7f);
                Mode=CreatureMode.Recovery;until=now+(kind==CreatureKind.Golem?1.5:.9);return;
            }
            if(Mode==CreatureMode.Recovery && now<until) {motor.SetIntent(Vector2.zero,0);return;}
            Vector2 delta=player.transform.position-transform.position;
            if(authority.IsSafePosition(player.transform.position) || !player.State.IsAlive || delta.magnitude>detectionRange || !authority.HasLineOfSight(transform.position,player.transform.position))
            { Mode=CreatureMode.Patrol; motor.SetIntent(home-(Vector2)transform.position,(home-(Vector2)transform.position).magnitude>.2f?1:0);return; }
            Mode=CreatureMode.Pursuit;
            if(kind==CreatureKind.Spider && delta.magnitude<2) {motor.SetIntent(-delta+Vector2.Perpendicular(delta)*.5f,2.1f);return;}
            if(delta.magnitude>(kind==CreatureKind.Spider?4.5f:2)) {motor.SetIntent(delta,kind==CreatureKind.Spider?2:1.1f);return;}
            aim=delta.normalized;impact=player.transform.position;Mode=CreatureMode.Windup;until=now+(kind==CreatureKind.Golem?.8:.55);
            telegraph.enabled=true;telegraph.color=kind==CreatureKind.Golem?new Color(1,.25f,.05f,.3f):Color.magenta;
            telegraph.transform.position=kind==CreatureKind.Golem?(Vector3)impact:transform.position+(Vector3)aim*.7f;
            telegraph.transform.localScale=kind==CreatureKind.Golem?new Vector3(3.4f,3.4f,1):new Vector3(.3f,.3f,1);
            motor.SetIntent(Vector2.zero,0);
        }
    }
}
