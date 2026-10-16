using Mmorpg.Domain;
using UnityEngine;

namespace Mmorpg.Runtime
{
    // Optional B11 presentation. Observes confirmed health/dodge; never changes combat state.
    [DisallowMultipleComponent, DefaultExecutionOrder(35)]
    public sealed class ProductionCharacterStates : MonoBehaviour
    {
        [SerializeField] private ActorHealth health;
        [SerializeField] private ProductionSpriteAnimator animator;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private PlayerController player;
        private CombatState observedState;
        private int observedHealth, hurtDirection, deathDirection, dodgeDirection;
        private double impactAt=double.NegativeInfinity, hurtAt=double.NegativeInfinity;
        private double deathAt=double.NegativeInfinity, lastDodgeUntil=double.NegativeInfinity;
        private bool pendingHurt;
        public bool DeathComplete { get; private set; }
        public int ConfirmedReactions { get; private set; }
        public void Configure(ActorHealth actor,ProductionSpriteAnimator presentation,SwordSwing weapon)
        { health=actor;animator=presentation;sword=weapon;player=actor.GetComponent<PlayerController>(); }
        private void OnEnable()
        {
            health.Changed-=Changed;health.Changed+=Changed;ObserveReplacement();
        }
        private void OnDisable(){if(health!=null)health.Changed-=Changed;}
        private void ObserveReplacement()
        {
            if(observedState==health.State)return;
            observedState=health.State;observedHealth=health.State.Health;
            pendingHurt=false;impactAt=hurtAt=deathAt=lastDodgeUntil=double.NegativeInfinity;
            DeathComplete=false;
        }
        private void Changed()
        {
            ObserveReplacement();int next=health.State.Health;
            if(next<observedHealth&&health.State.IsAlive)
            {
                ConfirmedReactions++;pendingHurt=true;impactAt=Time.timeAsDouble;
                hurtAt=double.NegativeInfinity;hurtDirection=animator.DirectionIndex;
            }
            observedHealth=next;
        }
        private static int Direction(Vector2 v)=>Mathf.Abs(v.x)>Mathf.Abs(v.y)?(v.x<0?1:3):(v.y>0?2:0);
        public bool TrySelect(ProductionCharacterSet art,double now,out string action,out int direction,out float time)
        {
            ObserveReplacement();action=null;direction=animator.DirectionIndex;time=0;
            if(!health.State.IsAlive)
            {
                pendingHurt=false;
                if(double.IsNegativeInfinity(deathAt)){deathAt=now;deathDirection=direction;}
                var clip=art.Find("death",deathDirection);if(clip==null)return false;
                action="death";direction=deathDirection;time=(float)(now-deathAt);
                DeathComplete=time>=clip.Duration;return true;
            }
            DeathComplete=false;
            if(health.State.IsDodging(now))
            {
                if(lastDodgeUntil!=health.State.DodgeUntil)
                {lastDodgeUntil=health.State.DodgeUntil;dodgeDirection=Direction(player.DodgeDirection);}
                var clip=art.Find("dodge",dodgeDirection);if(clip==null)return false;
                action="dodge";direction=dodgeDirection;
                time=Mathf.Clamp01((float)((now-(health.State.DodgeUntil-CombatRules.DodgeDuration))/CombatRules.DodgeDuration))*Mathf.Max(0,clip.Duration-.00001f);
                return true;
            }
            // Preserve the approved Slash and authoritative Sweep. Existing flash is immediate.
            if(sword.Busy&&sword.AttackProgress<1)return false;
            if(pendingHurt)
            {
                pendingHurt=false;
                if(now-impactAt<=.8)hurtAt=now;
            }
            var hurt=art.Find("hurt",hurtDirection);
            if(hurt!=null&&now-hurtAt<hurt.Duration)
            {action="hurt";direction=hurtDirection;time=(float)(now-hurtAt);return true;}
            return false;
        }
    }
}
