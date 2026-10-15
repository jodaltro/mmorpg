using Mmorpg.Domain;
using UnityEngine;
namespace Mmorpg.Runtime
{
    public sealed class PoisonStatus : MonoBehaviour
    {
        private OfflineAuthority authority;
        private ActorHealth source,target;
        private double until,nextTick;
        public bool Active => Time.timeAsDouble<until;
        public void Apply(OfflineAuthority server,ActorHealth attacker) {authority=server;source=attacker;target=GetComponent<ActorHealth>();until=Time.timeAsDouble+ActionCombatRules.PoisonDuration;nextTick=Time.timeAsDouble+1;}
        private void Update()
        {
            if(!Active || !target.State.IsAlive || Time.timeAsDouble<nextTick)return;
            nextTick=Time.timeAsDouble+1;authority.ResolveDamage(source,target,ActionStrike.Poison);
        }
    }
}
