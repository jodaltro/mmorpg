using UnityEngine;
using Mmorpg.Domain;
namespace Mmorpg.Runtime
{
    [RequireComponent(typeof(Rigidbody2D),typeof(CircleCollider2D))]
    public sealed class PoisonProjectile : MonoBehaviour
    {
        private OfflineAuthority authority;
        private ActorHealth source;
        private double expires;
        public static PoisonProjectile Spawn(OfflineAuthority server,ActorHealth attacker,Vector2 position,Vector2 direction,Sprite sprite,Material material)
        {
            var go=new GameObject("VenomProjectile");go.transform.position=position;go.transform.localScale=Vector3.one*.22f;
            var visual=go.AddComponent<SpriteRenderer>();visual.sprite=sprite;visual.sharedMaterial=material;visual.color=Color.magenta;visual.sortingOrder=300;
            var body=go.AddComponent<Rigidbody2D>();body.gravityScale=0;body.collisionDetectionMode=CollisionDetectionMode2D.Continuous;body.linearVelocity=direction.normalized*5;
            go.AddComponent<CircleCollider2D>().isTrigger=true;
            var projectile=go.AddComponent<PoisonProjectile>();projectile.authority=server;projectile.source=attacker;projectile.expires=Time.timeAsDouble+3;return projectile;
        }
        private void Update() {if(Time.timeAsDouble>=expires || source==null || !source.State.IsAlive) Destroy(gameObject);}
        private void OnTriggerEnter2D(Collider2D other)
        {
            if(other.gameObject.layer==8) {Destroy(gameObject);return;}
            var target=other.GetComponent<ActorHealth>();if(target==null || target.Faction!=Faction.Player)return;
            if(authority.ResolveDamage(source,target,ActionStrike.Venom,"venom-shot"))
            {
                var poison=target.GetComponent<PoisonStatus>()??target.gameObject.AddComponent<PoisonStatus>();poison.Apply(authority,source);
            }
            Destroy(gameObject);
        }
    }
}
