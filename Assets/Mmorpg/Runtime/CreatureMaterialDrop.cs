using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class CreatureMaterialDrop : MonoBehaviour
    {
        [SerializeField] private ActorHealth actor;
        [SerializeField] private ExplorationNode drop;
        [SerializeField] private OfflineAuthority authority;
        private bool confirmed;
        public void Configure(ActorHealth body,ExplorationNode material,OfflineAuthority server){actor=body;drop=material;authority=server;}
        private void Awake(){drop.gameObject.SetActive(false);}
        private void OnEnable(){authority.HitConfirmed+=Hit;}
        private void OnDisable(){if(authority!=null)authority.HitConfirmed-=Hit;}
        private void Hit(ActorHealth attacker,ActorHealth target)
        {if(confirmed||target!=actor||attacker.Faction!=Faction.Player||actor.State.IsAlive)return;confirmed=true;drop.transform.position=actor.transform.position;drop.gameObject.SetActive(true);}
    }
}

