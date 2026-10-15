using UnityEngine;
namespace Mmorpg.Runtime
{
    // After input, before the weapon's Update: body and grip are one presentation sample.
    [DefaultExecutionOrder(40)]
    public sealed class ProductionSpriteAnimator : MonoBehaviour
    {
        [SerializeField] private ProductionCharacterSet art;
        [SerializeField] private ActorMotor motor;
        [SerializeField] private ActorHealth health;
        [SerializeField] private SwordSwing sword;
        [SerializeField] private SpriteRenderer visual;
        private Rigidbody2D body;
        private float walkTime,stillTime;
        public ProductionFrame CurrentFrame {get;private set;}
        public string State {get;private set;}="idle";
        public int DirectionIndex {get;private set;}
        public SpriteRenderer Body=>visual;
        public event System.Action<string> VisualEvent;
        public void Configure(ProductionCharacterSet set,ActorHealth actor,SpriteRenderer renderer,SwordSwing weapon)
        {art=set;health=actor;motor=actor.GetComponent<ActorMotor>();visual=renderer;sword=weapon;}
        private void Awake(){body=motor.GetComponent<Rigidbody2D>();Select("idle",0,0);}
        private void Select(string action,int direction,float time)
        {
            var clip=art.Find(action,direction)??art.Find("idle",direction);
            var next=clip?.At(time);bool changed=next!=CurrentFrame;CurrentFrame=next;
            if(CurrentFrame!=null){visual.sprite=CurrentFrame.sprite;if(changed)foreach(string marker in CurrentFrame.events)OnProductionVisualEvent(marker);}
            visual.flipX=false;State=action;DirectionIndex=direction;
        }
        private void Update()
        {
            if(art==null||body==null)return;
            Vector2 facing=sword.AimDirection;
            if(health.State.IsDodging(Time.timeAsDouble)&&motor.Direction.sqrMagnitude>.01f)facing=motor.Direction;
            int d=Mathf.Abs(facing.x)>Mathf.Abs(facing.y)?(facing.x<0?1:3):(facing.y>0?2:0);
            string action="idle";float time=0;
            if(!health.State.IsAlive){Select("idle",d,0);return;} // existing health visual supplies death fade
            if(health.State.IsDodging(Time.timeAsDouble))action="dodge";
            else if(sword.Busy){action=sword.VisualPhase=="recovery"?"idle":"attack";time=sword.Active?.1f:0;}
            else if(motor.Direction.sqrMagnitude>.01f&&body.linearVelocity.sqrMagnitude>.04f)
            {
                stillTime=0;action="walk";
                walkTime+=Time.deltaTime*Mathf.Clamp(body.linearVelocity.magnitude/art.referenceSpeed,.2f,1.8f);time=walkTime;
            }
            else {stillTime+=Time.deltaTime;if(stillTime>.18f)walkTime=0;}
            Select(action,d,time);
            if(sword.Busy)State="attack-"+sword.VisualPhase;
        }
        // Generated AnimationClips may emit presentation markers. Never authority or damage events.
        public void OnProductionVisualEvent(string marker)=>VisualEvent?.Invoke(marker);
    }
}
