using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class SheetImpactFeedback : MonoBehaviour
    {
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private ActorHealth player;
        [SerializeField] private SpriteRenderer impact;
        [SerializeField] private Sprite[] frames;
        private double started=double.NegativeInfinity;
        public void Configure(OfflineAuthority server,ActorHealth owner,SpriteRenderer effect,Sprite[] art){authority=server;player=owner;impact=effect;frames=art;}
        private void OnEnable()=>authority.HitConfirmed+=Hit;
        private void OnDisable(){if(authority!=null)authority.HitConfirmed-=Hit;}
        private void Hit(ActorHealth attacker,ActorHealth target)
        {if(attacker!=player)return;started=Time.timeAsDouble;impact.transform.position=target.transform.position;impact.sortingOrder=target.GetComponent<SpriteRenderer>().sortingOrder+4;}
        private void LateUpdate()
        {int frame=(int)((Time.timeAsDouble-started)*24);impact.enabled=frame>=0&&frame<frames.Length;if(impact.enabled)impact.sprite=frames[frame];}
    }
}
