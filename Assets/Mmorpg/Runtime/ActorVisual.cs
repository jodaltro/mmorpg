using UnityEngine;

namespace Mmorpg.Runtime
{
    [RequireComponent(typeof(SpriteRenderer), typeof(ActorHealth))]
    public sealed class ActorVisual : MonoBehaviour
    {
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private SpriteRenderer attackMarker;
        private SpriteRenderer sprite;
        private ActorHealth health;
        private Color original;
        private double flashUntil;
        private double attackUntil;
        private int attackFrame;
        [SerializeField] private bool swordPresentation;
        [SerializeField] private bool preparedArt;
        [SerializeField] private float groundOffset;
        public void ConfigurePreparedArt(float feetBelowRoot){preparedArt=true;groundOffset=feetBelowRoot;}
        public void ConfigureSwordPresentation() => swordPresentation=true;
        public void Configure(OfflineAuthority server, SpriteRenderer marker) { authority = server; attackMarker = marker; }
        private void Awake() { sprite = GetComponent<SpriteRenderer>(); health = GetComponent<ActorHealth>(); original = sprite.color; }
        private void OnEnable() { health.Changed += OnDamage; authority.AttackPerformed += OnAttack; }
        private void OnDisable() { health.Changed -= OnDamage; if (authority != null) authority.AttackPerformed -= OnAttack; }
        private void OnDamage() => flashUntil = Time.timeAsDouble + 0.15;
        private void OnAttack(ActorHealth attacker, Vector2 direction)
        {
            if (attacker != health) return;
            attackUntil = Time.timeAsDouble + 0.13;
            attackFrame = Time.frameCount;
            attackMarker.transform.localPosition = direction * 0.7f;
            attackMarker.transform.localScale = direction.x != 0 ? new Vector3(0.35f, 0.9f, 1) : new Vector3(0.9f, 0.35f, 1);
        }
        private void LateUpdate()
        {
            double now = Time.timeAsDouble;
            var wolf = GetComponent<WolfBrain>();
            sprite.color = !health.State.IsAlive ? new Color(0.3f, 0.3f, 0.3f, 0.55f)
                : now < flashUntil ? (preparedArt?new Color(1,.72f,.65f):Color.red) : health.State.IsDodging(now) ? (preparedArt?new Color(.7f,.9f,1,.8f):Color.cyan)
                : wolf != null && wolf.Mode == WolfMode.Windup ? (preparedArt?new Color(1,.65f,.5f):new Color(1,.45f,.2f)) : original;
            sprite.sortingOrder = 100 - Mathf.RoundToInt((transform.position.y-groundOffset) * 16);
            attackMarker.enabled = !swordPresentation && health.State.IsAlive && now < attackUntil;
            if(attackMarker.enabled && attackFrame>=0) { ActionMetrics.Active?.RecordVisual(Time.frameCount-attackFrame); attackFrame=-1; }
            attackMarker.sortingOrder = sprite.sortingOrder + 1;
        }
    }
}
