using Mmorpg.Domain;
using UnityEngine;
using EventType = Mmorpg.Domain.EventType;

namespace Mmorpg.Runtime
{
    // Adds intentions/techniques to the existing authority; never accepts a damage value.
    public sealed class ActionCombat : MonoBehaviour
    {
        [SerializeField] private OfflineAuthority authority;
        [SerializeField] private JourneySession journey;
        [SerializeField] private SpriteRenderer cue;
        [SerializeField] private bool isolatedAbilityTest;
        [SerializeField, Min(.05f)] private float heavyWindup=.38f;
        [SerializeField, Min(.2f)] private float heavyCooldown=1.2f;
        [SerializeField, Min(.1f)] private float heavyRange=1.65f;
        private Vector2 heavyFacing;
        private double releaseAt, heavyNext, counterUntil, counterNext, markUntil, markNext;
        private ActorHealth defender, marked;
        private bool preparedHeavy;
        public bool Committed => preparedHeavy || authority.SwordBusy;
        public bool TestMode => isolatedAbilityTest;
        public bool CounterUnlocked => isolatedAbilityTest || journey.Engine.HasPreparedDodge && journey.Engine.OrinBriefed;
        public float BasicCooldown => authority.SwordCooldown;
        public float HeavyCooldown => heavyCooldown;
        public bool MarkUnlocked => isolatedAbilityTest || journey.Engine.HasTrace && journey.Engine.OrinBriefed;
        public ActorHealth MarkedTarget => marked != null && marked.State.IsAlive && Time.timeAsDouble < markUntil ? marked : null;
        public double HeavyRemaining => System.Math.Max(0, heavyNext - Time.timeAsDouble);
        public double CounterRemaining => System.Math.Max(0, counterNext - Time.timeAsDouble);
        public double MarkRemaining => System.Math.Max(0, markNext - Time.timeAsDouble);
        public void Configure(OfflineAuthority server, JourneySession story, SpriteRenderer visual) { authority=server; journey=story; cue=visual; }
        public void ConfigureIsolatedAbilityTest(bool value) => isolatedAbilityTest = value;
        public bool RequestHeavy(Vector2 facing)
        {
            double now=Time.timeAsDouble;
            if (Committed || now < heavyNext || heavyCooldown<heavyWindup || facing.sqrMagnitude < .001f || !journey.Player.State.TryAttack(now, heavyCooldown)) return false;
            heavyNext=now+heavyCooldown;
            if(authority.HasSword)return authority.BeginSword(journey.Player,facing,heavyRange,ActionStrike.Heavy,heavyWindup);
            preparedHeavy=true;releaseAt=now+heavyWindup;heavyFacing=facing.normalized;
            cue.enabled=true;cue.color=new Color(1,.5f,.1f,.8f);cue.transform.localPosition=heavyFacing*.8f;return true;
        }
        internal void ConfirmDefense(ActorHealth attacker) { defender=attacker; counterUntil=Time.timeAsDouble+ActionCombatRules.CounterWindow; }
        public bool RequestCounter(Vector2 facing)
        {
            double now=Time.timeAsDouble;
            if (!CounterUnlocked || Committed || now>=counterUntil || now<counterNext || defender==null || !defender.State.IsAlive || !journey.Player.State.TryAttack(now, .5)) return false;
            counterUntil=0; counterNext=now+ActionCombatRules.CounterCooldown;
            authority.ResolveMelee(journey.Player,facing,1.6f,ActionStrike.Counter); return true;
        }
        public bool RequestHunterMark()
        {
            double now=Time.timeAsDouble;
            if(!MarkUnlocked || !journey.Player.State.IsAlive || now<markNext || Committed) return false;
            ActorHealth nearest=null; float distance=4;
            foreach(var collider in Physics2D.OverlapCircleAll(journey.Player.transform.position,4,1<<9))
            {
                var target=collider.GetComponent<ActorHealth>(); float d=Vector2.Distance(collider.transform.position,journey.Player.transform.position);
                if(target!=null && target.Faction!=Faction.Player && target.State.IsAlive && d<distance && authority.HasLineOfSight(journey.Player.transform.position,target.transform.position)) {nearest=target;distance=d;}
            }
            if(nearest==null) return false;
            marked=nearest; markUntil=now+ActionCombatRules.MarkDuration; markNext=now+ActionCombatRules.MarkCooldown; return true;
        }
        internal int Bonus(ActorHealth attacker, ActorHealth target) => attacker==journey.Player && target==MarkedTarget ? 5 : 0;
        internal void ConfirmHit(ActorHealth attacker, ActorHealth target) { if(attacker==journey.Player) target.GetComponent<SpatialCreatureBrain>()?.ReactToHit(); }
        private void Update()
        {
            if(authority.HasSword){if(cue!=null)cue.enabled=false;return;}
            if(!preparedHeavy)return;
            if(!journey.Player.State.IsAlive || journey.Player.State.IsDodging(Time.timeAsDouble)){preparedHeavy=false;cue.enabled=false;return;}
            if(Time.timeAsDouble<releaseAt)return;
            preparedHeavy=false;cue.enabled=false;authority.ResolveMelee(journey.Player,heavyFacing,heavyRange,ActionStrike.Heavy);
        }
    }
}
