using UnityEngine;

namespace Mmorpg.Runtime
{
    [RequireComponent(typeof(Rigidbody2D), typeof(ActorHealth))]
    public sealed class ActorMotor : MonoBehaviour
    {
        private Rigidbody2D body;
        private ActorHealth health;
        public Vector2 Facing { get; private set; } = Vector2.down;
        public Vector2 Direction { get; private set; }
        private float speed;
        private float terrainSpeed=1;
        public void SetTerrainSpeed(float multiplier)=>terrainSpeed=Mathf.Clamp(multiplier,.3f,1);
        [SerializeField] private bool eightDirections;
        [SerializeField, Min(1)] private float acceleration = 65, deceleration = 85;
        public void ConfigureActionMovement() => eightDirections = true;
        public void Aim(Vector2 direction) { if (eightDirections && direction.sqrMagnitude > 0.001f) Facing = direction.normalized; }
        private void Awake() { body = GetComponent<Rigidbody2D>(); health = GetComponent<ActorHealth>(); }
        public void SetIntent(Vector2 direction, float movementSpeed)
        {
            Direction = eightDirections ? Vector2.ClampMagnitude(direction, 1) : Cardinal(direction);
            if (Direction != Vector2.zero) Facing = Direction;
            speed = movementSpeed;
        }
        private void FixedUpdate()
        {
            var desired = health.State.IsAlive ? Direction * speed * terrainSpeed : Vector2.zero;
            body.linearVelocity = !eightDirections || health.State.IsDodging(Time.timeAsDouble) ? desired :
                Vector2.MoveTowards(body.linearVelocity, desired, (desired == Vector2.zero ? deceleration : acceleration) * Time.fixedDeltaTime);
        }
        public static Vector2 Cardinal(Vector2 direction)
        {
            if (direction.sqrMagnitude < 0.001f) return Vector2.zero;
            return Mathf.Abs(direction.x) > Mathf.Abs(direction.y)
                ? new Vector2(Mathf.Sign(direction.x), 0) : new Vector2(0, Mathf.Sign(direction.y));
        }
    }
}
